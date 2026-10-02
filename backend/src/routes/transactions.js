const express = require('express');
const prisma = require('../config/database');
const { authMiddleware } = require('../middleware/auth');

const router = express.Router();
router.use(authMiddleware);

function snakeToCamelKeys(obj) {
  if (Array.isArray(obj)) return obj.map(snakeToCamelKeys);
  if (obj && typeof obj === 'object' && !(obj instanceof Date)) {
    return Object.keys(obj).reduce((acc, key) => {
      const camelKey = key.replace(/_([a-z])/g, (_, letter) => letter.toUpperCase());
      acc[camelKey] = snakeToCamelKeys(obj[key]);
      return acc;
    }, {});
  }
  return obj;
}

// GET /api/transactions - List transactions
router.get('/', async (req, res) => {
  try {
    const { storeId, customerId, status } = req.query;
    const where = {};

    if (storeId) where.storeId = storeId;
    if (customerId) where.customerId = customerId;
    if (status) where.status = status;

    if (req.user.role === 'store_user') {
      where.storeId = req.user.storeId;
    }

    const transactions = await prisma.transaction.findMany({
      where,
      orderBy: { transactionDate: 'desc' },
      include: {
        customer: { select: { id: true, name: true, phone: true } },
        store: { select: { id: true, name: true } },
        package: { select: { id: true, name: true } },
        _count: { select: { deliveries: true } },
      },
    });

    res.json(transactions);
  } catch (error) {
    console.error('List transactions error:', error);
    res.status(500).json({ error: '获取交易列表失败' });
  }
});

// GET /api/transactions/:id
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;

    const transaction = await prisma.transaction.findUnique({
      where: { id },
      include: {
        customer: true,
        store: { select: { id: true, name: true } },
        package: true,
        deliveries: { orderBy: { sessionNumber: 'asc' } },
        serviceRecords: { orderBy: { serviceDate: 'desc' } },
        auditLogs: { orderBy: { editedAt: 'desc' } },
      },
    });

    if (!transaction) {
      return res.status(404).json({ error: '交易不存在' });
    }

    if (req.user.role === 'store_user' && transaction.storeId !== req.user.storeId) {
      return res.status(403).json({ error: '无权访问' });
    }

    res.json(transaction);
  } catch (error) {
    console.error('Get transaction error:', error);
    res.status(500).json({ error: '获取交易信息失败' });
  }
});

// POST /api/transactions - Create transaction
router.post('/', async (req, res) => {
  try {
    const data = snakeToCamelKeys(req.body);

    // Permission check
    if (req.user.role === 'store_user' && data.storeId !== req.user.storeId) {
      return res.status(403).json({ error: '无权为该门店创建交易' });
    }

    // Custom deals without a package are linked to a placeholder package
    let packageId = data.packageId;
    if (!packageId) {
      let customPackage = await prisma.servicePackage.findFirst({
        where: { name: '自定义项目' },
      });
      if (!customPackage) {
        customPackage = await prisma.servicePackage.create({
          data: {
            name: '自定义项目',
            description: '自定义成交项目占位套餐',
            totalSessions: 0,
            durationMinutes: 0,
            price: 0,
            isActive: false,
          },
        });
      }
      packageId = customPackage.id;
    }

    const transaction = await prisma.transaction.create({
      data: {
        ...data,
        packageId,
        staffUserId: req.user.userId,
        createdByName: req.user.name,
        branch: data.branch || '光电',
      },
      include: {
        customer: { select: { id: true, name: true } },
        store: { select: { id: true, name: true } },
        package: { select: { id: true, name: true } },
      },
    });

    // 首次成交时间回填：如果客户此前没有首次成交时间，且本条是正式成交，则记录
    if (transaction && transaction.status && ['confirmed','inProgress','completed'].includes(transaction.status)) {
      const existingCustomer = await prisma.customer.findUnique({
        where: { id: transaction.customerId },
        select: { firstTransactionDate: true }
      });
      if (existingCustomer && !existingCustomer.firstTransactionDate && transaction.transactionDate) {
        await prisma.customer.update({
          where: { id: transaction.customerId },
          data: { firstTransactionDate: transaction.transactionDate }
        });
      }
    }

    // Update customer remaining sessions
    await prisma.customer.update({
      where: { id: data.customerId },
      data: { remainingSessions: { increment: data.totalSessions } },
    });

    res.status(201).json(transaction);
  } catch (error) {
    console.error('Create transaction error:', error);
    res.status(500).json({ error: '创建交易失败' });
  }
});

// PUT /api/transactions/:id - Edit amount / amountReceived / totalSessions / branch with audit log
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const data = snakeToCamelKeys(req.body);

    // Only admin/superAdmin can edit financial fields
    if (req.user.role === 'store_user') {
      return res.status(403).json({ error: '无权修改成交金额' });
    }

    const existing = await prisma.transaction.findUnique({
      where: { id },
      include: { customer: true },
    });

    if (!existing) {
      return res.status(404).json({ error: '交易不存在' });
    }

    if (req.user.role === 'store_user' && existing.storeId !== req.user.storeId) {
      return res.status(403).json({ error: '无权修改' });
    }

    const editableFields = ['amount', 'amountReceived', 'storeRebateAmount', 'branch', 'totalSessions', 'notes', 'transactionDate'];
    const changed = [];
    const updatePayload = {};

    const fmtDate = (d) => {
      if (!d) return '';
      const dt = d instanceof Date ? d : new Date(d);
      return dt.toISOString().split('T')[0];
    };

    for (const field of editableFields) {
      if (data[field] === undefined) continue;
      if (field === 'transactionDate') {
        const newDate = new Date(data[field]);
        if (isNaN(newDate.getTime())) {
          return res.status(400).json({ error: '成交时间格式不正确' });
        }
        if (!existing.transactionDate || newDate.getTime() !== existing.transactionDate.getTime()) {
          changed.push({
            field,
            oldValue: fmtDate(existing.transactionDate),
            newValue: fmtDate(newDate),
          });
          updatePayload[field] = newDate;
        }
        continue;
      }
      if (data[field] !== existing[field]) {
        changed.push({
          field,
          oldValue: String(existing[field] ?? ''),
          newValue: String(data[field] ?? ''),
        });
        updatePayload[field] = data[field];
      }
    }

    if (changed.length === 0) {
      return res.json(existing);
    }

    // Validate financial fields
    const newAmount = updatePayload.amount !== undefined ? parseFloat(updatePayload.amount) : existing.amount;
    const newAmountReceived = updatePayload.amountReceived !== undefined ? parseFloat(updatePayload.amountReceived) : (existing.amountReceived ?? 0);
    const isRefundUpdate = existing.status === 'refunded';
    if (isNaN(newAmount) || isNaN(newAmountReceived)) {
      return res.status(400).json({ error: '金额格式不正确' });
    }
    if (isRefundUpdate) {
      if (newAmount > 0 || newAmountReceived > 0) {
        return res.status(400).json({ error: '退款金额必须为负数' });
      }
      if (newAmountReceived !== newAmount) {
        return res.status(400).json({ error: '退款金额与已退金额必须一致' });
      }
    } else {
      if (newAmount < 0 || newAmountReceived < 0) {
        return res.status(400).json({ error: '金额不能为负数' });
      }
      if (newAmountReceived > newAmount) {
        return res.status(400).json({ error: '已收金额不能大于成交金额' });
      }
    }
    const newStoreRebate = updatePayload.storeRebateAmount !== undefined ? parseFloat(updatePayload.storeRebateAmount) : (existing.storeRebateAmount ?? 0);
    if (isNaN(newStoreRebate) || newStoreRebate < 0) {
      return res.status(400).json({ error: '返利金额不能为负数' });
    }
    if (newStoreRebate > newAmount) {
      return res.status(400).json({ error: '返利金额不能大于成交金额' });
    }

    // Validate totalSessions
    const newTotalSessions = updatePayload.totalSessions !== undefined ? parseInt(updatePayload.totalSessions) : existing.totalSessions;
    if (isNaN(newTotalSessions)) {
      return res.status(400).json({ error: '次数格式不正确' });
    }
    if (isRefundUpdate) {
      if (newTotalSessions > 0) {
        return res.status(400).json({ error: '退款次数必须为负数或零' });
      }
    } else {
      if (newTotalSessions < 0) {
        return res.status(400).json({ error: '应交付次数不能为负数' });
      }
    }
    if (newTotalSessions < existing.completedSessions) {
      return res.status(400).json({ error: `应交付次数不能小于已交付次数（${existing.completedSessions} 次）` });
    }

    updatePayload.outstandingAmount = newAmount - newAmountReceived;
    updatePayload.modifiedAt = new Date();
    updatePayload.modifiedBy = req.user.userId;
    updatePayload.modifiedByName = req.user.name || '';

    const totalSessionsDelta = newTotalSessions - existing.totalSessions;

    const result = await prisma.$transaction(async (tx) => {
      const updated = await tx.transaction.update({
        where: { id },
        data: updatePayload,
      });

      for (const change of changed) {
        await tx.TransactionAuditLog.create({
          data: {
            transactionId: id,
            field: change.field,
            oldValue: change.oldValue,
            newValue: change.newValue,
            editedBy: req.user.userId,
            editedByName: req.user.name || '',
          },
        });
      }

      // Adjust customer remaining sessions when totalSessions changes
      if (totalSessionsDelta !== 0) {
        await tx.customer.update({
          where: { id: existing.customerId },
          data: { remainingSessions: { increment: totalSessionsDelta } },
        });
      }

      // Recalculate customer aggregates from all transactions
      const agg = await tx.transaction.aggregate({
        where: { customerId: existing.customerId },
        _sum: { amountReceived: true, outstandingAmount: true },
      });

      await tx.customer.update({
        where: { id: existing.customerId },
        data: {
          amountReceived: agg._sum.amountReceived || 0,
          outstandingAmount: agg._sum.outstandingAmount || 0,
        },
      });

      return updated;
    });

    const fullTransaction = await prisma.transaction.findUnique({
      where: { id },
      include: {
        customer: true,
        store: { select: { id: true, name: true } },
        package: true,
        auditLogs: { orderBy: { editedAt: 'desc' } },
      },
    });

    res.json(fullTransaction);
  } catch (error) {
    console.error('Update transaction error:', error);
    res.status(500).json({ error: '更新失败' });
  }
});

// DELETE /api/transactions/:id - Delete transaction and adjust customer sessions/aggregates
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;

    if (req.user.role === 'store_user') {
      return res.status(403).json({ error: '无权删除成交记录' });
    }

    const existing = await prisma.transaction.findUnique({
      where: { id },
      include: { customer: true },
    });

    if (!existing) {
      return res.status(404).json({ error: '交易不存在' });
    }

    if (req.user.role === 'store_user' && existing.storeId !== req.user.storeId) {
      return res.status(403).json({ error: '无权删除' });
    }

    const remainingToRemove = existing.totalSessions - existing.completedSessions;

    await prisma.$transaction(async (tx) => {
      await tx.TransactionAuditLog.deleteMany({ where: { transactionId: id } });
      await tx.delivery.deleteMany({ where: { transactionId: id } });
      await tx.serviceRecord.deleteMany({ where: { transactionId: id } });
      await tx.transaction.delete({ where: { id } });

      if (remainingToRemove !== 0) {
        await tx.customer.update({
          where: { id: existing.customerId },
          data: { remainingSessions: { increment: -remainingToRemove } },
        });
      }

      const agg = await tx.transaction.aggregate({
        where: { customerId: existing.customerId },
        _sum: { amountReceived: true, outstandingAmount: true },
      });

      await tx.customer.update({
        where: { id: existing.customerId },
        data: {
          amountReceived: agg._sum.amountReceived || 0,
          outstandingAmount: agg._sum.outstandingAmount || 0,
        },
      });
    });

    res.json({ success: true, message: '成交记录已删除' });
  } catch (error) {
    console.error('Delete transaction error:', error);
    res.status(500).json({ error: '删除失败' });
  }
});


async function applyTransactionUpdate(id, rawData, userId, userName) {
  const data = snakeToCamelKeys(rawData);

  const existing = await prisma.transaction.findUnique({
    where: { id },
    include: { customer: true },
  });

  if (!existing) {
    throw new Error('交易不存在');
  }

  const editableFields = ['amount', 'amountReceived', 'storeRebateAmount', 'branch', 'totalSessions', 'notes', 'transactionDate'];
  const changed = [];
  const updatePayload = {};

  const fmtDate = (d) => {
    if (!d) return '';
    const dt = d instanceof Date ? d : new Date(d);
    return dt.toISOString().split('T')[0];
  };

  for (const field of editableFields) {
    if (data[field] === undefined) continue;
    if (field === 'transactionDate') {
      const newDate = new Date(data[field]);
      if (isNaN(newDate.getTime())) {
        throw new Error('成交时间格式不正确');
      }
      if (!existing.transactionDate || newDate.getTime() !== existing.transactionDate.getTime()) {
        changed.push({
          field,
          oldValue: fmtDate(existing.transactionDate),
          newValue: fmtDate(newDate),
        });
        updatePayload[field] = newDate;
      }
      continue;
    }
    if (data[field] !== existing[field]) {
      changed.push({
        field,
        oldValue: String(existing[field] ?? ''),
        newValue: String(data[field] ?? ''),
      });
      updatePayload[field] = data[field];
    }
  }

  if (changed.length === 0) {
    return existing;
  }

  const newAmount = updatePayload.amount !== undefined ? parseFloat(updatePayload.amount) : existing.amount;
  const newAmountReceived = updatePayload.amountReceived !== undefined ? parseFloat(updatePayload.amountReceived) : (existing.amountReceived ?? 0);
  const isRefundUpdateHelper = existing.status === 'refunded';
  if (isNaN(newAmount) || isNaN(newAmountReceived)) {
    throw new Error('金额格式不正确');
  }
  if (isRefundUpdateHelper) {
    if (newAmount > 0 || newAmountReceived > 0) {
      throw new Error('退款金额必须为负数');
    }
    if (newAmountReceived !== newAmount) {
      throw new Error('退款金额与已退金额必须一致');
    }
  } else {
    if (newAmount < 0 || newAmountReceived < 0) {
      throw new Error('金额不能为负数');
    }
    if (newAmountReceived > newAmount) {
      throw new Error('已收金额不能大于成交金额');
    }
  }
  const newStoreRebate = updatePayload.storeRebateAmount !== undefined ? parseFloat(updatePayload.storeRebateAmount) : (existing.storeRebateAmount ?? 0);
  if (isNaN(newStoreRebate) || newStoreRebate < 0) {
    throw new Error('返利金额不能为负数');
  }
  if (newStoreRebate > newAmount) {
    throw new Error('返利金额不能大于成交金额');
  }

  const newTotalSessions = updatePayload.totalSessions !== undefined ? parseInt(updatePayload.totalSessions) : existing.totalSessions;
  if (isNaN(newTotalSessions)) {
    throw new Error('次数格式不正确');
  }
  if (isRefundUpdateHelper) {
    if (newTotalSessions > 0) {
      throw new Error('退款次数必须为负数或零');
    }
  } else {
    if (newTotalSessions < 0) {
      throw new Error('应交付次数不能为负数');
    }
  }
  if (newTotalSessions < existing.completedSessions) {
    throw new Error(`应交付次数不能小于已交付次数（${existing.completedSessions} 次）`);
  }

  updatePayload.outstandingAmount = newAmount - newAmountReceived;
  updatePayload.modifiedAt = new Date();
  updatePayload.modifiedBy = userId;
  updatePayload.modifiedByName = userName || '';

  const totalSessionsDelta = newTotalSessions - existing.totalSessions;

  return await prisma.$transaction(async (tx) => {
    const updated = await tx.transaction.update({
      where: { id },
      data: updatePayload,
    });

    for (const change of changed) {
      await tx.TransactionAuditLog.create({
        data: {
          transactionId: id,
          field: change.field,
          oldValue: change.oldValue,
          newValue: change.newValue,
          editedBy: userId,
          editedByName: userName || '',
        },
      });
    }

    if (totalSessionsDelta !== 0) {
      await tx.customer.update({
        where: { id: existing.customerId },
        data: { remainingSessions: { increment: totalSessionsDelta } },
      });
    }

    const agg = await tx.transaction.aggregate({
      where: { customerId: existing.customerId },
      _sum: { amountReceived: true, outstandingAmount: true },
    });

    await tx.customer.update({
      where: { id: existing.customerId },
      data: {
        amountReceived: agg._sum.amountReceived || 0,
        outstandingAmount: agg._sum.outstandingAmount || 0,
      },
    });

    return updated;
  });
}

async function applyTransactionDelete(id, userId, userName) {
  const existing = await prisma.transaction.findUnique({
    where: { id },
    include: { customer: true },
  });

  if (!existing) {
    throw new Error('交易不存在');
  }

  const remainingToRemove = existing.totalSessions - existing.completedSessions;

  await prisma.$transaction(async (tx) => {
    await tx.TransactionAuditLog.deleteMany({ where: { transactionId: id } });
    await tx.delivery.deleteMany({ where: { transactionId: id } });
    await tx.serviceRecord.deleteMany({ where: { transactionId: id } });
    await tx.transaction.delete({ where: { id } });

    if (remainingToRemove !== 0) {
      await tx.customer.update({
        where: { id: existing.customerId },
        data: { remainingSessions: { increment: -remainingToRemove } },
      });
    }

    const agg = await tx.transaction.aggregate({
      where: { customerId: existing.customerId },
      _sum: { amountReceived: true, outstandingAmount: true },
    });

    await tx.customer.update({
      where: { id: existing.customerId },
      data: {
        amountReceived: agg._sum.amountReceived || 0,
        outstandingAmount: agg._sum.outstandingAmount || 0,
      },
    });
  });

  return { success: true, message: '成交记录已删除' };
}

module.exports = router;
module.exports.applyTransactionUpdate = applyTransactionUpdate;
module.exports.applyTransactionDelete = applyTransactionDelete;
