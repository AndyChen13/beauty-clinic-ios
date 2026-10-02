# 小功能两项（2026-10-01）

## 1. 操作记录照片长按保存到相册

**需求**：客户 → 操作记录 → 单张照片全屏查看时，长按保存到系统相册（非批量）。

**改动**（iOS，`ServiceRecordDetailView.swift` 的 `PhotoViewer`）：
- 图片加载从 `AsyncImage` 改为 `URLSession`（保存需要原始 `UIImage`）
- 长按 0.5 秒 → 触觉反馈 → `PHPhotoLibrary` 申请 addOnly 权限 → `PHAssetChangeRequest.creationRequestForAsset` 保存原图
- 成功：底部「已保存到相册」胶囊提示 1.5 秒；权限被拒/失败：弹窗提示
- 图片加载后底部常驻提示「长按图片可保存到相册」
- `Info.plist` 的 `NSPhotoLibraryAddUsageDescription` 原本已配置，无需改动
- 状态：xcodebuild BUILD SUCCEEDED，需重新 Build 安装生效

## 2. 成交记录支持修改成交时间，Dashboard 按修改后时间统计

**需求**：真实成交 0917、0919 才录入，修改后 Dashboard 应记在 0917。

**根因**：「修改成交」表单里根本没有成交时间选择器；后端 `editableFields` 也不含 `transactionDate`——该功能整体缺失（Dashboard 本身按 transactionDate 统计，是对的）。

**改动**：
- iOS `TransactionEditSheet.swift`：「修改字段」区顶部加「成交时间」DatePicker；保存时发送
- iOS `Transaction.swift`：`TransactionUpdate` 加 `transactionDate: Date?`（CodingKeys 为 `transaction_date`，与既有 snake_case 风格一致）；`fieldDisplayName` 加「成交时间」映射
- 后端 `transactions.js`（两处：`router.put` 和 `applyTransactionUpdate` helper）：
  - `editableFields` 增加 `transactionDate`
  - 特殊处理：字符串→Date 解析校验（非法 400/throw）、与旧值按时间戳比较去重、审计日志记 `YYYY-MM-DD`
  - 部署前备份 `transactions.js.bak_20261001`

**端到端验证**（用真实交易 0a26d705，¥22000，改后已恢复原值 2026-09-30 10:23:46Z）：
- PUT `{"transactionDate":"2026-10-01T01:00:00.000Z"}` → 数据库更新 → Dashboard 当日医美板块立即显示 ¥22000/1 笔
- 恢复后 Dashboard 当日归零 ✅
- 审计日志正确记录两条 transactionDate 变更（旧值→新值，YYYY-MM-DD 格式）✅
- xcodebuild BUILD SUCCEEDED

**注意**：客户的「首次成交时间」（Customer.firstTransactionDate）是独立字段，本次未联动；如需要可在改成交时间时同步校正。

## 3. 长按保存照片自动添加水印（追加）

**需求**：操作记录照片长按保存到相册时，像导出一样带水印（客户/门店/交付日期）。

**实现**（iOS 端绘制，`PhotoViewer`）：
- `PhotoViewer` 新增 `customerName/storeName/serviceDate` 参数；调用方 `ServiceRecordDetailView` 异步加载门店名（按 `customer.associatedStoreId` 匹配）
- 保存前用 `UIGraphicsImageRenderer`（scale=1 保原图质量）绘制与导出一致的水印：左下角圆角半透明黑底（alpha 0.4）+ 白字三行；字号 = 图宽/150（与导出端 36px/5657px 同比例）
- 行距用 `boundingRect(usesLineFragmentOrigin)` 实测行高 ×1.2——第一版用固定 `fontSize*1.3` 行距偏小，预览时发现中文叠字风险已修正
- 提示文案改为「长按图片可保存到相册（自动添加水印）」

**验证**：xcodebuild BUILD SUCCEEDED；按 iOS 相同参数生成预览图，数学验证墨水高 36-40px < 行距 46px 无叠字。

**注意**：此前 Archive 的 Build 14 不含本功能；下次 Archive 需用 Build 15。

## 4. 照片查看器首点加载不出来（根因：SwiftUI sheet 套 sheet）

**现象**：操作记录照片缩略图预览很快，但点进第一张图一直白屏/加载不出；关掉再点（或先看第二张再回第一张）就正常。

**排查过程**（模拟器 iPhone 17 Pro，实证）：
- 一度怀疑网络/缓存，给 PhotoViewer 加过加载加固（双触发 + 6 秒超时自动重试），用户反馈无效——方向错了
- 在 App.swift 加临时调试入口（`PHOTOVIEWER_TEST` 启动参数），用与客户详情页完全相同的嵌套结构复现：
  - PhotoViewer 直接放根视图（冷启动）→ 正常
  - 单层 `.sheet` 包 PhotoViewer → 正常
  - **sheet 里再套 sheet（真实页面结构：CustomerDetailView.sheet → ServiceRecordDetailView.sheet）→ 白屏，PhotoViewer 完全没渲染**
- 截图证据：`tmp_export_check/sim_nested_sheet2.png`（白屏）vs `sim_fsc_test.png`（正常）

**根因**：SwiftUI 的已知缺陷——sheet 内再呈现 sheet 时，首次 presentation 不可靠（内层 sheet 的 hosting controller 在动画事务中状态错乱，content 不渲染）。与图片加载无关，所以一切加载加固都无效。

**修复**：`ServiceRecordDetailView.swift` 的照片查看器从 `.sheet(isPresented:)` 换成 `.fullScreenCover(item: $fullPhotoURL)`：
- 删除 `showPhotoViewer` / `selectedPhotoIndex` 两个状态，新增 `@State private var fullPhotoURL: URL?`
- `URL` 的 `Identifiable` 扩展在 `CustomerDetailView.swift` 顶部已有（`id = absoluteString`），直接复用，无需新类型
- 缩略图 `onTapGesture`：`fullPhotoURL = URL(string: photos[index])`
- `PhotoViewer` 本体不动，`onDismiss` 置 `nil`
- 与头像大图查看器（CustomerDetailView 的 `.fullScreenCover(item:)`，用户从未抱怨过它）同一方案

**验证**：同样的嵌套 sheet 调试场景下，fullScreenCover 首次呈现即正常渲染照片 ✅；清除全部调试代码后 xcodebuild BUILD SUCCEEDED，正式入口启动冒烟正常 ✅。

**注意**：fullScreenCover 是全屏黑底覆盖（非底部弹窗），顶部「关闭」按钮、长按保存水印均不变；交互体验与头像大图一致。

**Build 15 包含**：本修复 + 水印字号加大（最长行 = 图宽 1/3）+ 长按保存水印 + 成交时间可修改 + 导出防卡死。

## 5. Dashboard 新增「上月收入」「全年累计收入」卡片（2026-10-02）

**需求**：在 Dashboard「本月收入」「今日成交」下面加两张卡片，明细结构与本月收入一致（光电/医美 应收/实收/待收/返利），只是时间段不同。

**后端**（`dashboard.js`，备份 `dashboard.js.bak_20261002`，已部署重启）：
- `/api/dashboard/summary` 新增 `lastMonth`（上月初 ≤ transactionDate < 本月初）和 `year`（本年初至今）两段 groupBy 统计，结构与 `month` 完全一致（photoElectric/medicalBeauty 各含 amount/received/outstanding/count + rebate）
- 返利按 `confirmedAt` 落在对应时间段归集

**iOS**：
- `DashboardSummaryResponse` 加可选 `lastMonth`/`year`（防旧后端解码崩溃）
- `HomeView`：新增 `startOfLastMonth`/`startOfYear`  helper 和两组计算属性（summary 优先、本地 transactions 过滤兜底）；`DashboardDetail` 新增 `.lastMonthRevenue`/`.yearRevenue`；两张 StatCard 插在「今日成交」后面（顺序：本月/今日/上月/全年）
- 点「上月收入」→ `MonthlyRevenueTrendView` 新增 `anchor` 参数（默认本月，传上月初即显示上月每日走势，标题自动变成「2026年9月收入」）
- 点「全年累计收入」→ 新增 `YearRevenueTrendView`（12 个月度柱状图 + 有成交月数/月均/最高单月）

**验证**：
- API 实测：lastMonth received = 1,115,893 + 371,199 = **1,487,092**；year received = 1,229,193 + 371,199 = **1,600,392**，与模拟器卡片显示完全一致 ✅
- 卡片明细（光电/医美 应收/实收/待收/笔数）与 API 逐字段一致 ✅
- 上月 drill-down：标题「2026 年 9 月收入」、9 月每日柱状图、18 天有成交 ✅
- 全年 drill-down：¥1,751,526（9 月 1,638,226 + 8 月 113,300）、2 个月有成交 ✅
- 注意：drill-down 视图头条用的是「成交额(amount)」口径，与既有「本月收入」drill-down 一致；卡片大数字用「实收-返利」口径（与既有卡片一致）——两口径差异为既有设计，未改动

**Build 16 包含**：本功能 + 照片查看器修复 + 水印放大 + 成交时间可修改 + 导出防卡死。Archive 已放入 Xcode Organizer（2026-10-2, 02.30）。

## 6. Dashboard 金额隐私打码（2026-10-02 凌晨）

**需求**：Dashboard 所有收入数字默认隐藏（星号），手动点击才显示，方便截图给别人时脱敏。

**实现**（纯 iOS，HomeView.swift）：
- 新增环境值 `maskAmounts`；`SubItem`/`RebateSubItem`（BranchStack 明细行）响应打码：金额 → `¥****`、笔数 → `(**笔)`
- `@AppStorage("dashboardPrivacyMask")` 全局开关，**默认 true（打码）**，重启后保持
- 7 张金额卡片（本月收入/今日成交/上月收入/全年累计/待收款/当月最佳/门店返利）打码时点击 = 单独显示该卡片，再次点击才进明细；客户总数/待交付不受影响
- 导航栏右上角眼睛按钮：一键全部显示/全部打码（切换时清空已显示集合）

**验证**（模拟器截图留存）：
- 默认打码态：所有金额 `¥****`、笔数 `(**笔)`、眼睛斜杠图标 ✅
- 点「本月收入」→ 仅该卡片显示数值，其余仍打码 ✅
- 持久化关闭打码（关机改 plist 重启）→ 全部数值显示 + 睁眼图标 ✅
- 已知小坑：模拟器运行时直接改容器 plist 会被 cfprefsd 缓存覆盖，须 shutdown 后改再 boot；`simctl spawn defaults write` 也写不进 App 容器

**Build 17 包含**：本功能 + 上月/全年收入卡片（Build 16 全部内容）。Archive 已放入 Organizer（2026-10-2, 02.55，构建号 17），02.30 的旧包已移除。

## 7. 修复：长按保存照片水印显示「未分配门店」（2026-10-02）

**现象**：操作记录照片长按保存到相册，水印门店一行显示「未分配门店」，但所有客户都有归属门店。

**排查**：
- 服务端导出路径实测正常（真实导出 ZIP，水印正确显示门店名，见图）——排除服务端
- 根因在 iOS 端：原实现 `ServiceRecordDetailView.loadStoreName()` 异步请求门店列表，但 `PhotoViewer` 在**呈现那一刻**就捕获了 `storeName` 值；用户打开详情后立刻点照片，异步请求还没回来，水印就被定格成默认值「未分配门店」

**修复**（不再异步加载）：
- `Customer` 模型新增 `storeName: String?` 字段
- `DataService` 的 `listCustomers` / `getCustomer` 解码接口返回的 `store` 关系（接口本就返回 `store: {id, name}`，之前被丢弃），映射进 `Customer.storeName`
- `ServiceRecordDetailView` 删除 `loadStoreName()` 和 `.task`，PhotoViewer 直接用 `customer.storeName ?? "未分配门店"`——数据随客户对象同步到位，无竞争窗口

**验证**：API 响应确认含 `store.name`（curl 实测）；xcodebuild BUILD SUCCEEDED + Release ARCHIVE SUCCEEDED；服务端导出水印门店名正确（实测导出 ZIP 验图）。模拟器 UI 点击验证因 Simulator 窗口不稳定未完成（截图链路正常，点击链路受阻），数据链路静态验证完整。

**Build 18**（Archive 在 Organizer：2026-10-2, 03.40）：本修复 + 金额打码 + 上月/全年卡片 + 照片查看器修复等全部内容。注意：本次 CLI 导出 IPA 时报 "No signing certificate iOS Distribution found"（钥匙串分发证书问题，不影响 Archive 本身），用户在 Xcode Organizer 里 Distribute 走自动签名不受影响。

## 8. 优化：水印背景半透明黑底调浅（2026-10-02）

**需求**：水印的半透明黑底太显眼，遮挡画面信息，要求调浅。

**改动（两条水印路径同步调）**：
- iOS 长按保存（`BeautyClinic/Views/ServiceRecordDetailView.swift` PhotoViewer 绘图层）：`UIColor.black.withAlphaComponent(0.4)` → `0.22`
- 服务端导出（服务器 `/home/ubuntu/app/backend/src/routes/export.js` 的 `addWatermark`，Python Pillow 绘制）：`fill=(0, 0, 0, 100)` → `fill=(0, 0, 0, 55)`（alpha 0~255，约 0.39 → 0.22）
- 白字不变；背景变浅后白字在明暗两种背景下均验证可读

**部署**：服务器端已备份 `export.js.bak_20261002b` 后上传新版，`pm2 restart beautyclinic-api` 生效。

**验证**：
- 服务端实测导出（13295152146 账号，单客户含图导出）→ 下载 ZIP 看图：水印底色明显变浅、不遮挡画面，白字清晰（`tmp_verify_wm/` 留存验图）
- iOS 模拟器 BUILD SUCCEEDED；Release ARCHIVE SUCCEEDED

**Build 19**（Archive 在 Organizer：2026-10-2, 11.59，构建号 19）：本次水印调浅 + Build 18 全部内容（水印门店名修复、金额打码、上月/全年收入卡片、照片查看器修复等）。提醒：01.33 / 02.05 / 02.55 / 03.40 的旧 Archive 均已过时，勿上传；上传 11.59 这个最新包。

## 9. 新增：历史最佳成交卡片 + 待收款卡片下移（2026-10-02）

**需求**：
1. Dashboard 新增「历史最佳成交」卡片，与「当月最佳成交」同类（最佳门店 + 最佳客户），时间轴为自使用 App 至今
2. 「待收款」卡片下移，让底部区域对称

**实现**（纯 iOS，无后端改动）：
- 数据从全量 `transactions`（`/api/transactions` 全量返回，无分页）本地分组统计：`allTimeTopStores` / `allTimeTopCustomers`（按 `amount` 求和排序），与「当月最佳」的本地 fallback 同一算法，仅时间轴不同
- `HomeView.swift`：
  - `DashboardDetail` 新增 `allTimeTop` case
  - StatsGrid 卡片顺序调整为：…全年累计收入 → 当月最佳成交 → 历史最佳成交 → 待收款 → 门店返利（10 张卡 5 行 × 2，对称）
  - 新卡片 icon `crown.fill` 粉色，金额打码键 `allTimeTop`，行为与当月最佳一致（打码时点击显示、再点击进明细）
- `DashboardDetailViews.swift` 新增 `AllTimeTopView`：历史累计成交总额 + 笔数 + 「自 <最早成交日> 至今」+ 最佳门店/最佳客户排行（金银铜牌样式与 MonthlyTopView 一致）

**验证**（模拟器真机数据实测）：
- 首页布局：当月最佳成交(暂无)/历史最佳成交 一行，待收款/门店返利 一行 ✅
- 点进历史最佳成交明细：历史累计 ¥1,751,526（81 笔，自 2026-08-27 至今，与全年累计 ¥1,600,392 口径正确：历史 > 全年因含 8 月）✅ 最佳门店/客户排行正确 ✅
- BUILD SUCCEEDED + Release ARCHIVE SUCCEEDED

**Build 20**（Archive 在 Organizer：2026-10-2, 12.35，构建号 20）：本次功能 + Build 19 全部内容（水印调浅等）。提醒：03.40 / 11.59 的旧包已过时，上传 12.35 最新包。
