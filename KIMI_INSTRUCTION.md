# Kimi接手说明：Beauty Clinic iOS 项目

## 📋 项目概述

**项目名称**: Beauty Clinic（医美服务公司内部管理 App）  
**技术栈**: SwiftUI + SwiftData + Supabase (iOS 17+)  
**目标平台**: iOS (iPhone only, iOS 17.0+)

---

## 🗂️ 项目文件结构说明

```
~/Desktop/beauty-clinic-ios/              ← 当前工作目录
├── BeautyClinic/                        ← 所有源代码文件
│   ├── App.swift                        ← App入口（已修复 Supabase API 参数名）
│   ├── Info.plist                       ← 权限说明配置
│   ├── Models/                          ← 数据模型 (SwiftData)
│   │   ├── User.swift
│   │   ├── Customer.swift
│   │   ├── Package.swift
│   │   ├── Store.swift
│   │   └── Transaction.swift
│   ├── Services/                        ← Supabase客户端封装
│   │   ├── SupabaseClient.swift         ← 客户端初始化逻辑
│   │   ├── SupabaseClient+Auth.swift    ← OTP登录流程扩展
│   │   └── SupabaseClient+Environment.swift  ← SwiftUI环境注入支持
│   ├── Views/                           ← UI视图
│   │   ├── Auth/
│   │   │   └── OTPVerificationView.swift
│   │   ├── Common/
│   │   │   ├── AvatarView.swift
│   │   │   ├── SearchBar.swift
│   │   │   └── FilterBar.swift
│   │   ├── CustomerDetailView.swift
│   │   ├── CustomerEditView.swift
│   │   ├── CustomerListView.swift
│   │   ├── CustomerRow.swift
│   │   ├── HomeView.swift
│   │   ├── LoginView.swift
│   │   ├── MainTabView.swift
│   │   ├── PackageListView.swift
│   │   ├── SettingsView.swift
│   │   ├── StoreDetailView.swift
│   │   ├── StoreEditView.swift
│   │   ├── StoreListView.swift
│   │   ├── StoreRow.swift
│   │   ├── TransactionListView.swift
│   │   ├── TransactionRecordView.swift
│   │   └── TransactionRow.swift
│   └── Extensions/                      ← Swift扩展
│       └── SupabaseClient+Auth.swift
├── supabase/
│   └── migrations/
│       └── 001_init_schema.sql          ← 数据库Schema + RLS策略
├── .env.example                         ← 环境变量模板（需填充真实凭证）
└── KIMI_INSTRUCTION.md                  ← 本说明文档

~/Documents/GitHub/beauty-clinic-ios/    ← GitHub远程仓库的本地克隆（与上面同步）
```

---

## 🔑 关键文件说明

### 1. App.swift (入口点)
**路径**: `BeautyClinic/App.swift`  
**功能**: Supabase 客户端初始化，环境注入

**已修复的问题**:
- ✅ API参数名更新 (`url:` → `supabaseURL:`, `apiKey:` → `supabaseKey:`)
- ✅ URL字符串包装为 `URL(string:)!`

**需手动配置**（在 Xcode 中）:
```swift
supabaseURL: URL(string: ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? "YOUR_REAL_URL")!,
supabaseKey: ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? "YOUR_REAL_KEY"
```

---

### 2. Supabase 客户端封装

#### SupabaseClient.swift
- 初始化客户端（带 Session 持久化）
- 提供环境注入支持 (`@Environment(\.supabaseClient)`)

#### SupabaseClient+Auth.swift
- 手机号 OTP 登录流程：
  - `sendOTP(to:)`: 发送验证码
  - `verifyOTP(code:for:)`: 验证验证码
  - 登录状态管理

#### SupabaseClient+Environment.swift
- SwiftUI 环境变量扩展 (`@Environment(\.supabaseClient)`)

---

### 3. 数据库 Schema (SQL)

**路径**: `supabase/migrations/001_init_schema.sql`  
**功能**: 初始化数据库表结构 + Row Level Security (RLS) 策略

**需手动执行**:
1. 登录 [Supabase Dashboard](https://supabase.com/dashboard)
2. 进入您的项目 → Database → SQL Editor
3. 复制此文件内容并运行

---

## 🚀 Xcode 项目配置步骤（Kimi 接手必读）

### 步骤 1: 清理混乱的 Xcode 项目文件

```bash
cd ~/Desktop/beauty-clinic-ios
rm -rf BeautyClinic/*.xcodeproj  # 删除所有损坏的Xcode项目
```

---

### 步骤 2: 在 Xcode 中创建新项目

1. 打开 Xcode → **File → New → Project...**
2. 选择 **iOS → App**
3. 填写：
   - Product Name: `BeautyClinic`
   - Organization Identifier: `com.andychen`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - ✅ Use SwiftData (可选)
4. 保存位置：`~/Desktop/beauty-clinic-ios/BeautyClinicXcodeProject`

---

### 步骤 3: 添加所有源代码文件

1. 在 Xcode 项目导航器中，**右键点击项目名称（蓝色图标）**
2. 选择 **Add Files...**
3. 选择以下目录：
   ```
   ~/Desktop/beauty-clinic-ios/BeautyClinic/
   ```
4. 勾选：
   - ✅ **Copy items if needed**
   - ✅ **Create groups** (重要！)
   - ✅ 勾选所有文件（包括子目录）
5. 点击 **Add**

---

### 步骤 4: 添加 Supabase Swift Package

1. Xcode 菜单：**File → Add Packages...**
2. 在搜索框中输入 URL：
   ```
   https://github.com/supabase/supabase-swift.git
   ```
3. 点击 **Add Package**
4. 选择版本策略：**Up to Next Major Version (from 2.0.0)**
5. 点击 **Add Package**

---

### 步骤 5: 配置 bundle identifier

1. 在 Xcode 中点击项目名称（蓝色图标）
2. 选择 `BeautyClinic` Target
3. 进入 **Signing & Capabilities** 标签
4. Bundle Identifier 应为：`com.andychen.BeautyClinic`
5. Team: 选择您的 Apple Developer 账号

---

### 步骤 6: 配置 Info.plist 权限说明

确保包含以下权限描述（已存在于 `BeautyClinic/Info.plist`）：
- `NSCameraUsageDescription`
- `NSPhotoLibraryAddUsageDescription`
- `NSPhotoLibraryUsageDescription`
- `NSPushNotificationUsageDescription`

---

## 🔧 环境变量配置

1. 复制 `.env.example` → `.env`
2. 填充真实凭证：
   ```bash
   SUPABASE_URL=https://YOUR_PROJECT_ID.supabase.co
   SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
   ```

---

## 📱 功能模块说明

### 1. 认证模块 (Auth)
- **LoginView**: 手机号输入界面
- **OTPVerificationView**: 验证码输入界面
- **流程**:
  1. 用户输入手机号
  2. 点击 "Send OTP"
  3. 接收验证码 → 输入验证码
  4. 自动登录成功

### 2. 主 Tab 导航 (MainTabView)
- 🏠 首页 (HomeView): 数据概览 + 快捷入口
- 👥 客户管理:
  - `CustomerListView`: 列表视图 + 搜索/过滤
  - `CustomerEditView`: 新增/编辑客户
  - `CustomerDetailView`: 客户详情
- 🎯 套餐管理 (PackageListView)
- 🏢 门店管理 (StoreListView)
- 💰 交易记录 (TransactionListView)

### 3. 通用组件 (Views/Common/)
- **SearchBar**: 全局搜索栏
- **FilterBar**: 分类过滤器
- **AvatarView**: 头像显示组件

---

## ⚠️ 已知问题 & 待办事项

### 当前状态
✅ 所有 Swift 源代码文件完整  
✅ Supabase 客户端封装完毕（参数名已修复）  
✅ 数据库 Schema + RLS 策略已生成  
❌ Xcode 项目文件损坏（需手动重建）

### 待完成配置
1. 在 Xcode 中添加所有 `.swift` 文件到 Target
2. 配置 Supabase 凭证
3. 运行数据库迁移 SQL
4. 编译并测试登录流程

---

## 🧪 测试清单

编译成功后，按以下顺序测试：

- [ ] 1. 编译无错误 (`Cmd+B`)
- [ ] 2. 登录流程：输入手机号 → 发送验证码 → 验证成功
- [ ] 3. 主 Tab 导航切换正常
- [ ] 4. 客户列表显示（空数据状态）
- [ ] 5. 添加新客户（测试表单）

---

## 📚 相关资源

- Supabase Swift 文档: https://supabase.com/docs/reference/swift/introduction
- SwiftUI 官方文档: https://developer.apple.com/documentation/swiftui
- iOS Human Interface Guidelines: https://developer.apple.com/design/human-interface-guidelines/

---

## 🤝 支持与协作

如有问题：
1. 先检查 Xcode 构建日志 (`Cmd+Shift+B` 查看详细输出)
2. 检查 Supabase 凭证是否正确
3. 确认数据库表已通过迁移 SQL 创建

---

**最后更新**: 2026-08-20  
**项目路径**: `~/Desktop/beauty-clinic-ios/`  
**GitHub 仓库**: `https://github.com/AndyChen13/beauty-clinic-ios`
