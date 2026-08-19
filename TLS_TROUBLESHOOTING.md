# Beauty Clinic iOS - TLS 连接错误排查指南

## 错误分析

错误代码 `-9816` = `SSLPeerHandshakeFail`（SSL 握手失败）

从日志看，你的请求通过 `127.0.0.1:1082` 代理转发，这是典型的本地代理工具（如 Clash、Shadowrocket、V2Ray）配置问题。

## 排查步骤（按优先级）

### 步骤 1：关闭代理测试

**Shadowrocket 用户：**
1. 打开 Shadowrocket
2. 点击顶部开关，关闭代理
3. 重新运行 App，尝试登录

**Clash 用户：**
1. 打开 Clash for Windows / Clash Verge
2. 点击「系统代理」关闭
3. 重新运行 App

**如果关闭代理后正常** → 问题在代理配置，继续步骤 2

### 步骤 2：检查代理是否支持 HTTPS

部分代理配置不正确会导致 HTTPS 握手失败：

1. 在 Safari 中访问 `https://ugwhgxtutochaodgrrqn.supabase.co`
2. 如果能正常打开（显示 JSON 错误页面），说明代理支持 HTTPS
3. 如果也失败，说明代理配置有问题

### 步骤 3：检查系统代理设置

```bash
# 查看当前系统代理
networksetup -getwebproxy "Wi-Fi"
networksetup -getsecurewebproxy "Wi-Fi"
```

如果显示 `Enabled: Yes`，说明系统代理已开启。

### 步骤 4：关闭系统代理后测试

```bash
# 关闭 Wi-Fi 的系统代理
sudo networksetup -setwebproxystate "Wi-Fi" off
sudo networksetup -setsecurewebproxystate "Wi-Fi" off
```

然后重新运行 App。

### 步骤 5：检查 ATS 配置

项目的 `Info.plist` 已配置：
- `NSAllowsArbitraryLoads` = true
- `supabase.co` 域名例外

这通常足够，但如果代理使用自签名证书，可能需要额外配置。

## 推荐解决方案

### 方案 A：使用 VPN 模式（推荐）

将代理工具从「规则模式」切换为「全局模式」或「VPN 模式」：

**Shadowrocket：**
1. 首页 → 全局路由 → 选择「代理」
2. 重新连接

**Clash：**
1. 系统托盘 → 模式 → 选择「全局」
2. 重新连接

### 方案 B：关闭代理直接连接

如果 Supabase 在国内访问正常，可以直接关闭代理：

```bash
# 一键关闭所有代理
sudo networksetup -setwebproxystate "Wi-Fi" off
sudo networksetup -setsecurewebproxystate "Wi-Fi" off
sudo networksetup -setwebproxystate "Ethernet" off
sudo networksetup -setsecurewebproxystate "Ethernet" off
```

### 方案 C：配置代理绕过本地连接

在代理工具中添加规则，让 `127.0.0.1` 和 `localhost` 不走代理：

**Clash 配置：**
```yaml
rules:
  - IP-CIDR,127.0.0.1/8,DIRECT
  - IP-CIDR,172.16.0.0/12,DIRECT
  - IP-CIDR,192.168.0.0/16,DIRECT
```

## 验证连接

修改后，在终端测试：

```bash
# 测试到 Supabase 的 HTTPS 连接
curl -I https://ugwhgxtutochaodgrrqn.supabase.co
```

如果返回 HTTP 200 或 401，说明连接正常。

## 其他可能原因

1. **时间不同步**：检查系统时间是否正确
   ```bash
   date
   ```
   如果时间不对，SSL 握手会失败。

2. **DNS 污染**：尝试更换 DNS
   ```bash
   # 使用 Cloudflare DNS
   networksetup -setdnsservers "Wi-Fi" 1.1.1.1 8.8.8.8
   ```

3. **防火墙/安全软件**：检查是否有安全软件拦截连接

## 快速诊断脚本

```bash
#!/bin/bash
echo "=== 网络诊断 ==="
echo "1. 系统时间: $(date)"
echo ""
echo "2. Wi-Fi 代理设置:"
networksetup -getwebproxy "Wi-Fi"
networksetup -getsecurewebproxy "Wi-Fi"
echo ""
echo "3. 测试 Supabase 连接:"
curl -s -o /dev/null -w "HTTP状态: %{http_code}, 耗时: %{time_total}s" https://ugwhgxtutochaodgrrqn.supabase.co
echo ""
echo ""
echo "4. 端口 1082 占用:"
lsof -i :1082 | head -3
echo ""
echo "5. Shadowrocket 状态:"
networksetup -listallnetworkservices | grep -i shadow
```

## 联系支持

如果以上步骤都无法解决，请提供以下信息：
1. 使用的代理工具名称和版本
2. 代理模式（规则/全局/VPN）
3. 上述诊断脚本的输出结果
