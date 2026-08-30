# COS 签名云函数部署指南（函数 URL 版）

## 概述
将本地 Python 签名服务器部署到腾讯云 SCF，使用**函数 URL**（API 网关已停服）对外提供签名服务。

---

## 部署步骤

### 第 1 步：登录腾讯云控制台
1. 打开 https://console.cloud.tencent.com/
2. 登录腾讯云账号
3. 顶部搜索「**云函数 SCF**」，点击进入

### 第 2 步：新建云函数
1. 点击「**新建**」→ 选择「**从头开始**」
2. 填写基本信息：
   - **函数名称**：`beautyclinic-cos-sign`
   - **运行环境**：`Python 3.9`
   - **内存**：`128MB`
   - **超时时间**：`10秒`
3. 点击「**完成**」创建函数

### 第 3 步：粘贴代码
1. 进入函数详情页，点击「**函数代码**」标签
2. 在编辑器中删除默认代码
3. 将 `cos_sign_scf.py` 文件中的**全部代码**粘贴进去
4. 点击「**保存**」或「**部署**」

### 第 4 步：配置环境变量（关键！）
1. 点击「**函数配置**」标签
2. 找到「**环境变量**」区域，点击「**编辑**」
3. 添加以下变量：

| 变量名 | 值 |
|--------|-----|
| `COS_SECRET_ID` | 你的腾讯云 SecretId |
| `COS_SECRET_KEY` | 你的腾讯云 SecretKey |
| `COS_BUCKET` | `beautyclinic-images-1472260859` |
| `COS_REGION` | `ap-shanghai` |

> SecretId/SecretKey 在腾讯云控制台 → **访问管理** → **API 密钥管理** 中获取

4. 点击「**保存**」

### 第 5 步：开启函数 URL
1. 在函数详情页，点击「**函数 URL**」标签（或「**触发管理**」→「**函数 URL**」）
2. 点击「**开启函数 URL**」
3. 配置：
   - **访问策略**：选择「**公网访问**」
   - **CORS 配置**：点击「**编辑**」
     - **Access-Control-Allow-Origin**：`*`
     - **Access-Control-Allow-Methods**：`POST, OPTIONS`
     - **Access-Control-Allow-Headers**：`Content-Type`
     - ✅ **开启 CORS**
4. 点击「**保存**」

### 第 6 步：复制函数 URL
1. 开启成功后，页面会显示一个地址，类似：
   ```
   https://beautyclinic-cos-sign-xxxxxxxxxx.shanghai.fcapp.run
   ```
2. **复制这个地址发给我**，我会更新 iOS 代码

### 第 7 步：测试（可选）
在 Terminal 中运行：
```bash
curl -X POST https://你的函数URL \
  -H 'Content-Type: application/json' \
  -d '{"key":"test.jpg","method":"put"}'
```

如果返回类似下面的 JSON，说明部署成功 ✅：
```json
{
  "authorization": "q-sign-algorithm=sha1&q-ak=...",
  "host": "beautyclinic-images-1472260859.cos.ap-shanghai.myqcloud.com",
  "bucket": "beautyclinic-images-1472260859",
  "region": "ap-shanghai"
}
```

---

## 费用说明
- 腾讯云 SCF **每月 100 万次调用免费**
- 函数 URL **免费**
- 你的 App 用量完全在免费额度内

---

## 部署完成后
把函数 URL 地址发给我，我会：
1. 修改 iOS 代码，从 `localhost:3000` 切换到函数 URL
2. Build 测试
3. 推送代码
