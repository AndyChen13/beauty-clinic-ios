# 按客户导出卡死修复（2026-10-01）

## 现象
选择「按客户导出」，即使只选 1 个客户，进度也卡在「处理图片」不往下走。

## 根因（两层）

1. **导出类型字符串不匹配（主因）**：iOS 发送 `type: "customers"`（以及 `"dateRange"`），后端只认 `"customer"` / `"date"`。条件不命中 → 查询无 where 过滤 → **实际导出全部客户**。数据库单个客户最多 7 张照片，但导出的 ZIP 高达 **440MB**（比全部导出 370MB 还大），处理全部照片耗时 2 分 14 秒，表现为「卡在处理图片」。
2. **pm2 重启后任务状态丢失（次因）**：14:46:56 服务被重启（任务 14:45:10 其实已完成），内存 Map 清空，iOS 轮询收到 404 后 catch 只 print 不处理 → 界面永久停在最后一次收到的「处理图片」状态。

## 附带发现的 bug
水印 Python 脚本只在 `/tmp/watermark_script.py` 不存在时才写入——`/tmp` 重启后保留，导致 10-01 部署的中文字体修复**从未真正生效**（服务器上仍是 DejaVuSans 旧版脚本）。

## 修复内容

### 后端 `/home/ubuntu/app/backend/src/routes/export.js`（已部署，备份 export.js.bak_20261001）
- `normalizeExportType()`：`customers→customer`、`dateRange→date`；非法 type 返回 400 不再静默导出全部
- `saveTaskMeta()`/`loadTaskMeta()`：任务状态写 `tempDir/task.json`，pm2 重启后 GET 查询可从磁盘恢复；恢复时若状态为 processing/pending 则明确返回 failed「服务器重启导致导出中断，请重新导出」
- `addWatermark()`：每次强制重写 Python 脚本；脚本升级为 NotoSansCJK→wqy-zenhei→DejaVuSans 字体优先级 + RGBA alpha_composite（解决中文方块与黑色衬底）

### iOS `BeautyClinic/Views/ExportView.swift`（已编译通过，需重新 Build 安装生效）
- 轮询收到 404 → 停止轮询并弹窗「导出任务已丢失（服务器可能重启），请重新导出」
- 其他错误连续失败 15 次（约 30 秒）→ 同样停止并提示，不再无限卡死

## 验证
- 模拟 iOS 参数 `type:"customers"` + 单个客户 → 3 秒内完成，1 客户 / 3 张图 / 6.79MB（修复前 440MB）
- pm2 restart 后同一 taskId 查询 → 从磁盘恢复 completed 状态与 COS 下载链接 ✅
- xcodebuild BUILD SUCCEEDED

## 追加修复（同日）：按时间导出边界 bug
- iOS DatePicker（.date 粒度）发送的 endDate 是结束当天 0 点（本地时区），后端直接 `lte` → 整个结束日被漏掉
- 修复：`parseEndDateInclusive()`，时间部分恰为 00:00:00 时扩展到该日 23:59:59.999（+24h-1ms）
- 验证：9月1日~9月30日导出 customerCount=73，与数据库精确一致
- 中文水印端到目检验证：客户/门店/交付日期三行中文清晰（Noto Sans CJK），半透明衬底+白字，无方块乱码、无黑色衬底外溢（原图 5657×4243 原画质保留）

## 注意
- **按客户导出现在立刻就能用**（后端修复，现有 App 不用重新装）
- iOS 端的 404 防卡死需要重新 Build/Archive 后才生效
- 数据库中有两个同名客户「邹玲」（fc09ad45… 与 3e21f085…），后续可考虑重名提示
