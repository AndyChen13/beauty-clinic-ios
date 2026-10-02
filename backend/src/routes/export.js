const express = require('express');
const { PrismaClient } = require('@prisma/client');
const { authMiddleware, requireSuperAdmin } = require('../middleware/auth');
const archiver = require('archiver');
const axios = require('axios');
const fs = require('fs');
const path = require('path');
const ExcelJS = require('exceljs');
const COS = require('cos-nodejs-sdk-v5');

const router = express.Router();
const prisma = new PrismaClient();

// COS client
const cosClient = new COS({
  SecretId: process.env.COS_SECRET_ID,
  SecretKey: process.env.COS_SECRET_KEY,
});

const COS_BUCKET = process.env.COS_BUCKET || 'beautyclinic-images-1472260859';
const COS_REGION = process.env.COS_REGION || 'ap-shanghai';

// Memory task store
const exportTasks = new Map();

function formatFileSize(bytes) {
  if (bytes < 1024) return bytes + ' B';
  if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
  return (bytes / (1024 * 1024)).toFixed(2) + ' MB';
}

function cleanupOldExports() {
  try {
    const tmpDir = '/tmp';
    const entries = fs.readdirSync(tmpDir);
    let cleaned = 0;
    let freed = 0;
    for (const entry of entries) {
      if (entry.startsWith('export_')) {
        const fullPath = path.join(tmpDir, entry);
        try {
          const stats = fs.statSync(fullPath);
          const age = Date.now() - stats.mtime.getTime();
          if (age > 2 * 60 * 60 * 1000) {
            const size = getDirSize(fullPath);
            fs.rmSync(fullPath, { recursive: true, force: true });
            cleaned++;
            freed += size;
          }
        } catch (e) {}
      }
    }
    if (cleaned > 0) {
      console.log(`[Export] Startup cleanup: removed ${cleaned} old exports, freed ${formatFileSize(freed)}`);
    }
  } catch (e) {
    console.error('[Export] Startup cleanup error:', e);
  }
}

function getDirSize(dirPath) {
  let size = 0;
  try {
    const files = fs.readdirSync(dirPath);
    for (const file of files) {
      const fullPath = path.join(dirPath, file);
      const stats = fs.statSync(fullPath);
      if (stats.isDirectory()) {
        size += getDirSize(fullPath);
      } else {
        size += stats.size;
      }
    }
  } catch (e) {}
  return size;
}

cleanupOldExports();

setInterval(() => {
  console.log('[DEBUG] exportTasks Map size:', exportTasks.size, 'keys:', Array.from(exportTasks.keys()));
}, 10000);

async function addWatermark(imagePath, info) {
  const { execFile } = require('child_process');
  const util = require('util');
  const execFileAsync = util.promisify(execFile);
  const pythonScript = `/tmp/watermark_script.py`;
  // 每次都重写脚本，保证脚本更新后即时生效（/tmp 在重启后仍保留，只靠 existsSync 判断会永远用旧版）
  const scriptContent = `import sys
from PIL import Image, ImageDraw, ImageFont

def load_font(size):
    candidates = [
        '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
        '/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc',
        '/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc',
        '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    ]
    for p in candidates:
        try:
            return ImageFont.truetype(p, size)
        except Exception:
            pass
    return ImageFont.load_default()

img = Image.open(sys.argv[1]).convert('RGBA')
font = load_font(36)
overlay = Image.new('RGBA', img.size, (0, 0, 0, 0))
draw = ImageDraw.Draw(overlay)
width, height = img.size
margin = 20
line_height = 46
lines = [
    "客户: " + sys.argv[2],
    "门店: " + sys.argv[3],
    "交付日期: " + sys.argv[4]
]
max_width = 0
for line in lines:
    bbox = draw.textbbox((0, 0), line, font=font)
    max_width = max(max_width, bbox[2] - bbox[0])
box_width = max_width + margin * 2
box_height = line_height * len(lines) + margin * 2
box_x = margin
box_y = height - box_height - margin
draw.rectangle([box_x, box_y, box_x + box_width, box_y + box_height], fill=(0, 0, 0, 55))
for i, line in enumerate(lines):
    y = box_y + margin + i * line_height
    draw.text((box_x + margin, y), line, fill=(255, 255, 255, 255), font=font)
img = Image.alpha_composite(img, overlay).convert('RGB')
img.save(sys.argv[1], quality=95)
print("Watermark added")
`;
  fs.writeFileSync(pythonScript, scriptContent);
  const pythonPath = '/home/ubuntu/venv/bin/python';
  await execFileAsync(pythonPath, [pythonScript, imagePath, info.customerName, info.storeName, info.serviceDate]);
}

function cleanupTempDir(tempDir) {
  if (fs.existsSync(tempDir)) {
    fs.rmSync(tempDir, { recursive: true, force: true });
  }
}

async function uploadToCOS(localPath, key) {
  return new Promise((resolve, reject) => {
    cosClient.putObject({
      Bucket: COS_BUCKET,
      Region: COS_REGION,
      Key: key,
      Body: fs.createReadStream(localPath),
      ContentType: 'application/zip',
    }, (err, data) => {
      if (err) reject(err);
      else resolve(data);
    });
  });
}

function getCOSUrl(key) {
  return `https://${COS_BUCKET}.cos.${COS_REGION}.myqcloud.com/${key}`;
}

function generateTaskKey(type, storeId, startDate, endDate, customerIds, includeImages) {
  const ids = customerIds ? customerIds.sort().join(',') : '';
  return type + ':' + (storeId || '') + ':' + (startDate || '') + ':' + (endDate || '') + ':' + ids + ':' + includeImages;
}

function findExistingTask(type, storeId, startDate, endDate, customerIds, includeImages) {
  const key = generateTaskKey(type, storeId, startDate, endDate, customerIds, includeImages);
  const now = Date.now();
  const twoHours = 2 * 60 * 60 * 1000;
  for (const [taskId, task] of exportTasks) {
    if (task._taskKey === key && task.status === 'completed' && task.result) {
      const age = now - task.createdAt.getTime();
      if (age < twoHours) {
        console.log('[DEBUG] Reusing existing task:', taskId, 'age:', Math.round(age / 1000), 'seconds');
        return task;
      }
    }
  }
  return null;
}

// 任务状态持久化：写入 tempDir/task.json，pm2 重启后可恢复，避免 iOS 端轮询 404 永久卡死
function saveTaskMeta(task) {
  try {
    const meta = {
      status: task.status,
      progress: task.progress,
      currentStep: task.currentStep,
      result: task.result,
      error: task.error,
      createdAt: task.createdAt ? task.createdAt.toISOString() : null,
    };
    fs.writeFileSync(path.join(task.tempDir, 'task.json'), JSON.stringify(meta));
  } catch (e) {
    console.error('[Export] saveTaskMeta error:', e.message);
  }
}

function loadTaskMeta(taskId) {
  try {
    const metaPath = path.join('/tmp', taskId, 'task.json');
    if (!fs.existsSync(metaPath)) return null;
    return JSON.parse(fs.readFileSync(metaPath, 'utf8'));
  } catch (e) {
    return null;
  }
}

// iOS 端发送的 type 与后端约定兼容：customers→customer、dateRange→date
function normalizeExportType(type) {
  if (type === 'customers') return 'customer';
  if (type === 'dateRange') return 'date';
  return type;
}

// 结束日期按「当天结束」解析：iOS 日期粒度选择器发送的是当天 0 点（带时区），
// 若时间部分恰为 00:00:00 则扩展到该日 23:59:59.999（按原时区，+24h-1ms，中国无夏令时安全）
function parseEndDateInclusive(dateStr) {
  const d = new Date(dateStr);
  if (isNaN(d.getTime())) return d;
  const m = String(dateStr).match(/T(\d{2}):(\d{2})(?::(\d{2})(?:\.\d+)?)?/);
  if (!m || (m[1] === '00' && m[2] === '00' && (!m[3] || m[3] === '00'))) {
    return new Date(d.getTime() + 24 * 60 * 60 * 1000 - 1);
  }
  return d;
}

router.post('/tasks', authMiddleware, requireSuperAdmin, async (req, res) => {
  try {
    const { storeId, startDate, endDate, customerIds, includeImages = true } = req.body;
    const type = normalizeExportType(req.body.type);
    if (!['all', 'store', 'customer', 'date'].includes(type)) {
      return res.status(400).json({ error: '无效的导出类型: ' + req.body.type });
    }
    // Check for existing completed task within 2 hours
    const existingTask = findExistingTask(type, storeId, startDate, endDate, customerIds, includeImages);
    if (existingTask) {
      console.log("[DEBUG] Returning existing task:", existingTask.id);
      return res.json({
        success: true,
        taskId: existingTask.id,
        status: existingTask.status,
        message: "使用最近生成的导出文件（2小时内）",
      });
    }

    const taskId = `export_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    const tempDir = path.join('/tmp', taskId);
    fs.mkdirSync(tempDir, { recursive: true });
    fs.mkdirSync(path.join(tempDir, 'images'), { recursive: true });
    const task = {
      id: taskId,
      _taskKey: generateTaskKey(type, storeId, startDate, endDate, customerIds, includeImages),
      status: 'pending',
      progress: 0,
      currentStep: '准备中',
      tempDir,
      result: null,
      error: null,
      createdAt: new Date(),
    };
    exportTasks.set(taskId, task);
    saveTaskMeta(task);
    console.log('[DEBUG] Task created:', taskId, 'Map size:', exportTasks.size);
    processExportTask(task, { type, storeId, startDate, endDate, customerIds, includeImages });
    res.json({
      success: true,
      taskId,
      status: 'pending',
      message: '导出任务已创建，正在处理中',
    });
  } catch (error) {
    console.error('Create export task error:', error);
    res.status(500).json({ error: '创建导出任务失败', details: error.message });
  }
});

router.get('/tasks/:taskId', authMiddleware, async (req, res) => {
  const { taskId } = req.params;
  console.log('[DEBUG] Query task:', taskId, 'Map size:', exportTasks.size, 'has:', exportTasks.has(taskId));
  const task = exportTasks.get(taskId);
  if (!task) {
    // 内存中不存在（如 pm2 重启导致 Map 清空），尝试从磁盘恢复
    const saved = loadTaskMeta(taskId);
    if (saved) {
      console.log('[DEBUG] Task recovered from disk:', taskId, 'status:', saved.status);
      if (saved.status === 'processing' || saved.status === 'pending') {
        // 处理中状态在重启后无法续跑，明确告知客户端失败而不是永久卡住
        return res.json({
          success: true,
          taskId,
          status: 'failed',
          progress: saved.progress || 0,
          currentStep: '失败',
          result: null,
          error: '服务器重启导致导出中断，请重新导出',
        });
      }
      return res.json({
        success: true,
        taskId,
        status: saved.status,
        progress: saved.progress,
        currentStep: saved.currentStep,
        result: saved.result,
        error: saved.error,
      });
    }
    return res.status(404).json({ error: '任务不存在' });
  }
  res.json({
    success: true,
    taskId: task.id,
    status: task.status,
    progress: task.progress,
    currentStep: task.currentStep,
    result: task.result,
    error: task.error,
  });
});

router.get('/download/:taskId', authMiddleware, async (req, res) => {
  const { taskId } = req.params;
  const task = exportTasks.get(taskId);
  if (!task) {
    return res.status(404).json({ error: '任务不存在' });
  }
  if (task.status !== 'completed') {
    return res.status(400).json({ error: '任务尚未完成', status: task.status });
  }
  if (!task.result || !task.result.filename) {
    return res.status(500).json({ error: '文件不存在' });
  }
  const zipPath = path.join(task.tempDir, task.result.filename);
  if (!fs.existsSync(zipPath)) {
    return res.status(404).json({ error: '文件已过期' });
  }
  res.download(zipPath, path.basename(zipPath), (err) => {
    if (err) {
      console.error('Download error:', err);
      if (!res.headersSent) {
        res.status(500).json({ error: '下载失败' });
      }
    }
  });
});

async function processExportTask(task, options) {
  const { type, storeId, startDate, endDate, customerIds, includeImages } = options;
  try {
    task.status = 'processing';
    task.progress = 10;
    task.currentStep = '查询客户数据';
    saveTaskMeta(task);
    const where = {};
    if (type === 'store' && storeId) {
      where.associatedStoreId = storeId;
    } else if (type === 'customer' && customerIds && customerIds.length > 0) {
      where.id = { in: customerIds };
    } else if (type === 'date' && (startDate || endDate)) {
      where.createdAt = {};
      if (startDate) where.createdAt.gte = new Date(startDate);
      // iOS 日期选择器发送的是结束日当天 0 点（本地时区），直接 lte 会漏掉整个结束日；恰为 0 点时扩展到当天结束
      if (endDate) where.createdAt.lte = parseEndDateInclusive(endDate);
    }
    const customers = await prisma.customer.findMany({
      where,
      include: {
        store: true,
        transactions: {
          orderBy: { transactionDate: 'asc' },
          include: {
            serviceRecords: {
              orderBy: { createdAt: 'asc' },
            },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
    task.progress = 30;
    task.currentStep = '生成 Excel';
    saveTaskMeta(task);
    const xlsxPath = path.join(task.tempDir, '客户成交记录.xlsx');
    const workbook = new ExcelJS.Workbook();
    const worksheet = workbook.addWorksheet('成交记录');
    worksheet.columns = [
      { header: '客户ID', key: 'customerId', width: 36 },
      { header: '客户姓名', key: 'customerName', width: 12 },
      { header: '手机号', key: 'phone', width: 14 },
      { header: '归属门店', key: 'storeName', width: 20 },
      { header: '门店地址', key: 'storeAddress', width: 30 },
      { header: '板块', key: 'branch', width: 8 },
      { header: '已收金额', key: 'amountReceived', width: 12 },
      { header: '待收金额', key: 'outstandingAmount', width: 12 },
      { header: '剩余次数', key: 'remainingSessions', width: 10 },
      { header: '首次成交时间', key: 'firstTransactionDate', width: 16 },
      { header: '交易ID', key: 'transactionId', width: 36 },
      { header: '交易状态', key: 'transactionStatus', width: 10 },
      { header: '交易板块', key: 'transactionBranch', width: 10 },
      { header: '成交金额', key: 'transactionAmount', width: 12 },
      { header: '实收金额', key: 'transactionAmountReceived', width: 12 },
      { header: '待收金额', key: 'transactionOutstanding', width: 12 },
      { header: '总次数', key: 'totalSessions', width: 10 },
      { header: '已完成次数', key: 'completedSessions', width: 12 },
      { header: '交易时间', key: 'transactionDate', width: 16 },
      { header: '交易备注', key: 'transactionNotes', width: 30 },
      { header: '门店返利', key: 'storeRebate', width: 12 },
      { header: '交付ID', key: 'serviceRecordId', width: 36 },
      { header: '操作人', key: 'operatorName', width: 12 },
      { header: '操作部位', key: 'bodyPart', width: 12 },
      { header: '服务详情', key: 'serviceDetails', width: 30 },
      { header: '消耗次数', key: 'sessionsUsed', width: 10 },
      { header: '额外付款', key: 'extraPayment', width: 12 },
      { header: '客户反馈', key: 'customerFeedback', width: 30 },
      { header: '交付时间', key: 'serviceDate', width: 16 },
    ];
    worksheet.getRow(1).eachCell((cell) => {
      cell.font = { bold: true, color: { argb: 'FFFFFFFF' } };
      cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFC9A24B' } };
      cell.alignment = { horizontal: 'center', vertical: 'middle' };
    });
    worksheet.views = [{ state: 'frozen', ySplit: 1 }];
    customers.forEach(customer => {
      const baseData = {
        customerId: customer.id,
        customerName: customer.name || '',
        phone: customer.phone || '',
        storeName: customer.store?.name || '未分配',
        storeAddress: customer.store?.address || '',
        branch: customer.preferences?.branch || '光电',
        amountReceived: customer.amountReceived || 0,
        outstandingAmount: customer.outstandingAmount || 0,
        remainingSessions: customer.remainingSessions || 0,
        firstTransactionDate: customer.firstTransactionDate || '',
      };
      if (customer.transactions.length === 0) {
        worksheet.addRow(baseData);
      } else {
        customer.transactions.forEach(transaction => {
          const transactionData = {
            transactionId: transaction.id,
            transactionStatus: transaction.status,
            transactionBranch: transaction.branch || '光电',
            transactionAmount: transaction.amount || 0,
            transactionAmountReceived: transaction.amountReceived || 0,
            transactionOutstanding: transaction.outstandingAmount || 0,
            totalSessions: transaction.totalSessions || 0,
            completedSessions: transaction.completedSessions || 0,
            transactionDate: transaction.transactionDate || '',
            transactionNotes: transaction.notes || '',
            storeRebate: transaction.storeRebateAmount || 0,
          };
          if (transaction.serviceRecords.length === 0) {
            worksheet.addRow({ ...baseData, ...transactionData });
          } else {
            transaction.serviceRecords.forEach(sr => {
              worksheet.addRow({
                ...baseData,
                ...transactionData,
                serviceRecordId: sr.id,
                operatorName: sr.operatorName || '',
                bodyPart: sr.bodyPart || '',
                serviceDetails: sr.serviceDetails || '',
                sessionsUsed: sr.sessionsUsed || 0,
                extraPayment: sr.extraPayment || 0,
                customerFeedback: sr.customerFeedback || '',
                serviceDate: sr.createdAt || '',
              });
            });
          }
        });
      }
    });
    ['amountReceived', 'outstandingAmount', 'transactionAmount', 'transactionAmountReceived',
     'transactionOutstanding', 'storeRebate', 'extraPayment'].forEach(key => {
      const col = worksheet.getColumn(key);
      if (col) {
        col.eachCell({ includeEmpty: true }, (cell, rowNumber) => {
          if (rowNumber > 1 && typeof cell.value === 'number') {
            cell.numFmt = '#,##0.00';
          }
        });
      }
    });
    await workbook.xlsx.writeFile(xlsxPath);
    task.progress = 60;
    task.currentStep = '处理图片';
    saveTaskMeta(task);
    const imagesDir = path.join(task.tempDir, 'images');
    let imageCount = 0;
    if (includeImages) {
      const allPhotos = [];
      for (const customer of customers) {
        for (const transaction of customer.transactions) {
          for (const sr of transaction.serviceRecords) {
            if (sr.photos && sr.photos.length > 0) {
              for (let i = 0; i < sr.photos.length; i++) {
                allPhotos.push({
                  photoUrl: sr.photos[i],
                  customer,
                  sr,
                  index: i
                });
              }
            }
          }
        }
      }
      
      const batchSize = 5;
      for (let i = 0; i < allPhotos.length; i += batchSize) {
        const batch = allPhotos.slice(i, i + batchSize);
        await Promise.all(batch.map(async ({ photoUrl, customer, sr, index }) => {
          const ext = path.extname(photoUrl) || '.jpg';
          const filename = customer.name + '_' + (customer.store?.name || '未分配') + '_' + (sr.createdAt ? new Date(sr.createdAt).toISOString().split('T')[0] : 'unknown') + '_' + (index + 1) + ext;
          const outputPath = path.join(imagesDir, filename);
          try {
            const response = await axios.get(photoUrl, { responseType: 'arraybuffer', timeout: 30000 });
            fs.writeFileSync(outputPath, response.data);
            await addWatermark(outputPath, {
              customerName: customer.name || '未知客户',
              storeName: customer.store?.name || '未分配门店',
              serviceDate: sr.createdAt ? new Date(sr.createdAt).toISOString().split('T')[0] : '未知日期'
            });
            imageCount++;
          } catch (err) {
            console.error('Download/watermark image error:', photoUrl, err.message);
          }
        }));
        
        task.progress = 60 + Math.floor((i + batch.length) / allPhotos.length * 20);
        task.currentStep = '处理图片 (' + Math.min(i + batchSize, allPhotos.length) + '/' + allPhotos.length + ')';
        saveTaskMeta(task);
      }
    }
    task.progress = 80;
    task.currentStep = '打包 ZIP';
    saveTaskMeta(task);
    const zipFilename = `BeautyManager导出_${new Date().toISOString().split('T')[0]}.zip`;
    const zipPath = path.join(task.tempDir, zipFilename);
    const output = fs.createWriteStream(zipPath);
    const archive = archiver('zip', { zlib: { level: 9 } });
    await new Promise((resolve, reject) => {
      output.on('close', resolve);
      archive.on('error', reject);
      archive.on('warning', (err) => {
        if (err.code !== 'ENOENT') reject(err);
      });
      archive.pipe(output);
      archive.file(xlsxPath, { name: '客户成交记录.xlsx' });
      if (includeImages && imageCount > 0) {
        archive.directory(imagesDir, 'images');
      }
      archive.finalize();
    });
    task.progress = 90;
    task.currentStep = '上传 COS';
    saveTaskMeta(task);
    const cosKey = `exports/${task.id}/${zipFilename}`;
    await uploadToCOS(zipPath, cosKey);
    const cosUrl = getCOSUrl(cosKey);
    task.progress = 100;
    task.status = 'completed';
    task.currentStep = '完成';
    const fileSize = fs.statSync(zipPath).size;
    task.result = {
      downloadUrl: cosUrl,
      filename: zipFilename,
      fileSize: fileSize,
      fileSizeFormatted: formatFileSize(fileSize),
      customerCount: customers.length,
      transactionCount: customers.reduce((sum, c) => sum + c.transactions.length, 0),
      imageCount,
    };
    saveTaskMeta(task);
    console.log('[DEBUG] Task completed:', task.id, 'COS URL:', cosUrl);
    setTimeout(() => {
      cleanupTempDir(task.tempDir);
      exportTasks.delete(task.id);
      console.log('[DEBUG] Task cleaned up:', task.id);
    }, 2 * 60 * 60 * 1000);
  } catch (error) {
    console.error('Export task error:', error);
    task.status = 'failed';
    task.error = error.message;
    task.currentStep = '失败';
    saveTaskMeta(task);
    cleanupTempDir(task.tempDir);
  }
}

module.exports = router;
