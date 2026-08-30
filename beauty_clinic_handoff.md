# Beauty Clinic iOS + 后端 + Cloudflare 迁移 — 完整交接文档（v2，2026-08-25 更新）

> 生成时间：2026-08-25 10:25 (Asia/Shanghai)
> 用途：交给下一个 AI 接手。读完即可继续，无需追问本会话历史。
> 版本说明：本版取代 2026-08-24 旧版。核心变化——**域名已切到 `andychenpersonal.com` 且全链路实测通过**，iOS `baseURL` 已改，之前摘要里的「iOS 未修复编译问题」经实盘核对**已在磁盘上解决**。

---

## 0. 一句话现状（2026-08-25）

医美培训 App（iOS SwiftUI + Node 后端）。原域名 `andychenpersonal.top` 源站 IP 被国内 SNI 封锁 → 中间迁 `andychenpersonal.cn`（Cloudflare 但 Universal SSL 证书卡死在 nxdomain，DNSPod 的 DNSSEC 管理又在付费墙后）→ **最终注册 `andychenpersonal.com`（Cloudflare Registrar）绕过所有坑，已实测全通**。超级管理员权限体系后端已完成。iOS 代码已自洽，待 Xcode Clean Build 验证。

**已实测验证的事实（不是计划，是已发生）：**
```
$ curl https://andychenpersonal.com/api/stores
{"error":"缺少认证令牌"}
```
返回的是**后端自己的 JSON**（无 token 时后端返回 401 语义），证明：DNS 解析 ✅ / Cloudflare CDN ✅ / HTTPS 证书 ✅ / nginx 反代 ✅ / 后端运行 ✅ 全部打通。「缺少认证令牌」是预期行为（该接口需登录态），**不是错误**。

---

## 1. 环境与凭据（接手必读）

### 服务器（腾讯云轻量，国内广州）
- SSH：`ssh ubuntu@111.231.164.58`
- **sudo 密码：`sw4)3Vhm$9eX!~W`**（勿外泄）
- OS：Ubuntu 24.04，OpenSSL 3.0.13，nginx 1.24.0
- 后端路径：`/home/ubuntu/app/backend`
- 后端入口：`/home/ubuntu/app/backend/src/index.js`（监听 **3000**）
- PM2 进程名：`beautyclinic-api`（重启：`pm2 restart beautyclinic-api`）
- 数据库：postgres `127.0.0.1:5432`
- Let's Encrypt 证书目录：`/etc/letsencrypt/live/andychenpersonal.cn/`（给 .cn 签的，有效期至 2026-11-22；.com 用 Cloudflare 边缘证书，源站证书不相关）

> 注：此前 `ssh ubuntu@111.231.164.58` 曾报 Permission denied（凭据问题）。本次迁移**未依赖 SSH**（证书问题靠换 .com 域名绕开，没动 nginx）。如要改 nginx 才需先解决 SSH。

### 域名与 Cloudflare（最终状态）
| 项目 | 值 |
|------|-----|
| **在用域名（已通）** | `andychenpersonal.com`（Cloudflare Registrar 注册） |
| 中间域名（已弃，证书卡死） | `andychenpersonal.cn`（Cloudflare，Universal SSL 卡 nxdomain） |
| 旧域名（已弃，SNI 封锁） | `andychenpersonal.top`（源站 IP 被封锁） |
| Cloudflare NS | 注册 .com 后 Cloudflare **自动接管**，无需手动设（aliza/anton 这组） |
| Cloudflare DNS | A 记录 `@` → `111.231.164.58`，**Proxied（橙色云）**；`www` 同（可选） |
| Cloudflare SSL 模式 | **Full**（不能 Flexible：会与 nginx 80→443 跳转冲突；不能 Full Strict：源站证书是 .cn 的，主机名不匹配） |
| 边缘证书 | Cloudflare Universal SSL，**.com 实测秒发**（比 .cn 稳，因 .com 无 .cn 的 DNSSEC/验证链路问题） |
| DNSSEC | Cloudflare 侧 Disabled；注册商（腾讯云/DNSPod）DNSSEC 管理在付费墙后，未动 |

### 本地（Mac mini，andy）
- iOS 项目：`/Users/andychen/Desktop/beauty-clinic-ios/BeautyClinic/BeautyClinic.xcodeproj`（SwiftUI，6 个 tab）
- 曾修复本地 DNS 污染：小米路由器把域名解析成假地址 `198.18.0.53`，已改 DNS 为 `8.8.8.8`/`1.1.1.1` 并重启。当前 Mac 解析正常。
- `/etc/hosts` 曾残留 `111.231.164.58 andychenpersonal.cn`（强制直连被封锁源站），已删除。

### 测试账号（后端已创建，可登录验权）
| 手机号 | 密码 | 角色 |
|--------|------|------|
| 13295152146 | Test1234 | super_admin |
| 18210275277 | Test1234 | super_admin |
| 13900000002 | Test1234 | admin |
| 13900000003 | Test1234 | store_user |

---

## 2. 后端修改（全部完成并实测通过）

### 2.1 超级管理员白名单
- `.env`（`/home/ubuntu/app/backend/.env`）：`SUPER_ADMIN_PHONES=13295152146,18210275277`
- `auth.js`：命中白名单 → `super_admin`，否则 → `store_user`
- 新增中间件 `requireSuperAdmin`；另有 `requireAdmin`、`requireManagerOrAbove`、`authMiddleware`
- JWT_SECRET 回退 `'fallback-secret-change-me'`，token 30 天
- Bearer token 注入，UserDefaults key = `api_auth_token`

### 2.2 用户管理接口 `routes/users.js`（已测试通过）
- `GET /api/users`（store_user → 403）、`POST /api/users`、`PUT /api/users/:id/role`、`PUT /api/users/:id`、`DELETE /api/users/:id`
- 安全保护：最后一个 super_admin 不可降级/删除（409）；admin 无法删除用户；store_user 不能改角色（403）

### 2.3 角色模型（已定，不再改）
`super_admin` / `admin` / `store_user` / `staff`（staff 仍存在于后端默认创建逻辑，App 端枚举保留）

---

## 3. iOS App 状态（代码已自洽，待 Xcode 验证）

### 3.1 本次（2026-08-25）已完成的修改
- **`Services/APIClient.swift`：`baseURL` 已由 `https://andychenpersonal.cn` 改为 `https://andychenpersonal.com`** ✅
  - 全项目 `grep` 确认：除这一处外**无任何 `.cn` 残留**（Info.plist 等也无）
  - Bearer token 注入逻辑完好（UserDefaults `api_auth_token`）
- `Info.plist`：删 `NSAllowsArbitraryLoads`，保留 `NSAllowsLocalNetworking`（ATS 合规）

### 3.2 历史已写入的文件（此前摘要说「未编译验证」，实盘核对已自洽）
| 文件 | 说明 | 当前状态 |
|------|------|----------|
| `Views/UserManagementView.swift` | 用户管理页（含 UserService/UserRow/CreateUserSheet） | 已在 Xcode target 中 ✅ |
| `Models/User.swift` | UserRole 枚举 + CodingKeys(snake_case) + isAdmin(含superAdmin) + isSuperAdmin + displayName | 已在 target 中 ✅ |
| `Views/MainTabView.swift` | 新增「用户」tab，仅 super_admin 可见（`userState.currentUser?.isSuperAdmin`） | 已在 target 中 ✅ |
| `Views/SettingsView.swift` | roleColor/RoleBadge，`userState.currentUser` 引用 | 已在 target 中 ✅ |
| `Views/StoreDetailView.swift` | 添加 StoreDetailView 结构体 | — |

### 3.3 ⚠️ 重要更正：旧摘要里的「未修复编译问题」经核对已在磁盘解决
此前（2026-08-24）摘要称以下为「待修复」，但**本次实盘 `grep` 确认它们当前已正确**：
1. `userState.user` → `userState.currentUser`：**已无 `userState.user` 残留**，全项目统一用 `currentUser`（MainTabView/SettingsView/UserManagementView/ContentView 均是）。✅
2. `isAdmin` 包含 `superAdmin`：**三处均已正确**——`User.swift:24` `role == .admin || role == .superAdmin`、`App.swift:10` `currentUser?.isAdmin ?? false`、`APIClient.swift:129` 同逻辑。✅
3. `Untitled.swift`：**已不存在**（find 无结果）。✅
4. 文件未加入 target：**project.pbxproj 已包含** User.swift / UserManagementView.swift / MainTabView.swift 的 fileRef + Sources 编译项。✅

### 3.4 代码自洽性核对结果（本次 grep 确认）
- `UserRole` 枚举：`superAdmin="super_admin"` / `admin` / `storeUser="store_user"` / `staff`，**无 `.manager` 残留** ✅
- `isSuperAdmin`（User.swift:23）存在且被 MainTabView/UserManagementView 引用 ✅
- `displayName`（User.swift:33）、`RoleBadge`（SettingsView.swift:119）存在 ✅
- 全项目无 `\.manager\b` / `isManager` 残留 ✅

### 3.5 唯一未确认项
- **实际能否编译通过**：需 Xcode `Cmd+B` / Clean Build Folder 验证。代码层面已自洽，但本环境无 Xcode，无法替你编译。下一步就是让下一个 AI 打开 Xcode 跑一次 Clean Build，修任何残留报错（若有）。

---

## 4. 待办清单（按优先级）

### P0 — 域名/链路（已完成 ✅，仅记录）
- [x] 注册 `andychenpersonal.com`（Cloudflare Registrar）
- [x] Cloudflare DNS：A `@` → `111.231.164.58`，Proxied
- [x] SSL 模式 Full
- [x] `curl https://andychenpersonal.com/api/stores` 返回后端 JSON ✅ 链路通
- [x] iOS `APIClient.swift` baseURL → `.com`

### P1 — iOS 编译验证（接手者必做，预计 10-30 分钟）
- [ ] 打开 Xcode，Product → Clean Build Folder → Build
- [ ] 修任何残留编译报错（按 3.3/3.4 的代码现状，大概率一次过；若报错贴给 AI 即可定位）
- [ ] 模拟器/真机登录测试：用 `13295152146 / Test1234`（super_admin）
  - 验「用户」tab 是否仅 super_admin 可见
  - 验用户管理页能拉取/创建/改角色/删除用户
  - 验 admin（`13900000002`）看不到「用户」tab
- [ ] 登录后 `curl` 同接口带 token 应返回门店数据（可选深测）

### P2 — 功能完善（未开工）
- [ ] dashboard 汇总按角色过滤（super_admin 全量、admin 受限）
- [ ] 前端菜单按 role 显隐（除「用户」tab 外）
- [ ] 清理测试账号（可选）
- [ ] `.cn` / `.top` 旧域名处理（建议：在 Cloudflare 给 .cn 加 Page Rule 301 跳转到 .com，或彻底不管）

---

## 5. 关键决策与教训（避免接手者踩坑）

1. **根因是源站 IP 被 SNI 封锁**，不是域名问题。换 IP（111.231.164.58）仍失败，最终用 Cloudflare CDN 绕开。App 端改动极小（只换 baseURL 域名）。
2. **`.cn` 在 Cloudflare Universal SSL 上反复 nxdomain**：Google Trust Services 的 DNS-01 验证在 `.cn` 上抽风（疑似与 DNSSEC/注册商链路有关），且腾讯云 DNSPod 的 DNSSEC 管理在**付费墙后**，手动无法清理 DS 记录。**换 `.com` 一刀解决**，免费、秒发、零摩擦。
3. **Cloudflare SSL 模式必须 Full**，不能 Flexible（与 nginx 80→443 冲突），不能 Full Strict（源站证书是 .cn 的，主机名不匹配会被拒）。
4. **源站 nginx 无需为 .com 改**：实测 `.com` 请求打到源站（nginx `server_name` 仍是 .cn）也能正常反代 `/api/` 到 3000 并返回 JSON——因 Full 模式不校验源站证书主机名，且 `/api/` 反代与 Host 无关。除非以后要做基于域名的虚拟主机，否则别动 nginx。
5. **"An identical record already exists" 不能盲信**——Cloudflare Universal SSL 自己管 `_acme-challenge` TXT，手动加无用且干扰。
6. **Xcode 写文件必须 Add to target**——之前的坑。本次核对确认三个 swift 文件已在 target，无需再手动加。
7. **角色改名后全链路同步**：`.manager`/`isManager` 已删，所有判定为 `superAdmin`/`admin`/`storeUser`/`staff`。当前代码已无残留。
8. **摘要可能与磁盘不一致**：本会话多次出现「摘要说未修复、实际已修复」。接手者凡遇「待修复」描述，**先 grep 实盘核对**再动手，别盲信旧摘要。

---

## 6. 接手者第一步建议

1. 读本文档第 1–3 节，确认环境/凭据/当前状态。
2. 打开 Xcode（项目在 `/Users/andychen/Desktop/beauty-clinic-ios/BeautyClinic/BeautyClinic.xcodeproj`）。
3. Product → Clean Build Folder → Build。按 §3.3/§3.4 现状，预期一次编译通过；若有报错，贴报错文本即可快速定位（代码已自洽，不会是大结构问题）。
4. 模拟器登录 `13295152146 / Test1234`，验 super_admin 权限（「用户」tab 可见、用户管理页可用）。
5. 如需改后端：SSH `ubuntu@111.231.164.58`（sudo 密码见 §1），`pm2 restart beautyclinic-api` 重启。

---

## 7. 相关文件清单
- iOS：`/Users/andychen/Desktop/beauty-clinic-ios/BeautyClinic/`（Services/APIClient.swift 已改 baseURL；Views/、Models/ 已自洽）
- 后端：`/home/ubuntu/app/backend/`（src/index.js、routes/users.js、auth.js、.env）
- 历史诊断：`/Users/andychen/.qclaw/workspace/TLS诊断_20260824_确诊.md`（.top SNI 封锁确诊报告，历史参考）
- 记忆：`/Users/andychen/.qclaw/workspace/memory/2026-08-24.md`、`2026-08-25.md`（本次会话全程记录）
- 其他交付（非主线，备查）：海报 `/Users/andychen/Desktop/慕夏形体卡.pptx`、利润工具 `/Users/andychen/Desktop/profit_sharing_tool.html`
