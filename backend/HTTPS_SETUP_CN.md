# BeautyClinic Backend - SSL Certificate Setup

## 腾讯云服务器 HTTPS 配置快速指南

### 1. SSH 登录到腾讯云服务器

```bash
ssh ubuntu@124.221.217.56
```

### 2. 安装 Certbot（用于获取免费 SSL 证书）

```bash
sudo apt update
sudo apt install certbot python3-certbot-nginx -y
```

### 3. 停止当前的 Node.js 应用

```bash
# 查找并停止 Express 应用进程
ps aux | grep node
kill <node_process_id>
```

或者使用 PM2：
```bash
pm2 stop beautyclinic-api
```

### 4. 获取 SSL 证书

#### 方式 A：使用域名（推荐）

```bash
sudo certbot --nginx -d api.beautyclinic.com
```

#### 方式 B：使用 IP 地址（用于测试）

```bash
# 先停止 Nginx，因为 Certbot 需要占用 80 端口
sudo systemctl stop nginx

# 使用 HTTP-01 挑战获取证书
sudo certbot certonly --standalone -d 124.221.217.56 \
  --agree-tos --email your-email@example.com \
  --no-eff-email --preferred-challenges http
```

**证书位置**：
- Let's Encrypt: `/etc/letsencrypt/live/124.221.217.56/`
  - `fullchain.pem` → SSL 证书
  - `privkey.pem` → 私钥

### 5. 配置 Nginx

创建配置文件：
```bash
sudo nano /etc/nginx/sites-available/beautyclinic
```

粘贴以下内容（根据你的实际情况修改路径）：

```nginx
# HTTPS Server
server {
    listen 443 ssl http2;
    server_name 124.221.217.56;

    # SSL Certificate - 根据你获取证书的方式调整路径
    # Let's Encrypt 方式：
    ssl_certificate /etc/letsencrypt/live/124.221.217.56/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/124.221.217.56/privkey.pem;
    
    # 或者使用腾讯云证书：
    # ssl_certificate /etc/ssl/certs/beautyclinic/cert.pem;
    # ssl_certificate_key /etc/ssl/private/beautyclinic.key;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;

    location /api/ {
        proxy_pass http://127.0.0.1:3000/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /health {
        proxy_pass http://127.0.0.1:3000/health;
    }
}

# HTTP 重定向到 HTTPS
server {
    listen 80;
    server_name 124.221.217.56;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}
```

启用配置：
```bash
sudo ln -s /etc/nginx/sites-available/beautyclinic /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default

# 测试配置
sudo nginx -t

# 重启 Nginx
sudo systemctl restart nginx
```

### 6. 更新 iOS App 配置

修改 `BeautyClinic/Info.plist`：

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>124.221.217.56</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <false/>  <!-- 使用 HTTPS，不需要允许 HTTP -->
            <key>NSExceptionRequiresForwardSecrecy</key>
            <false/>
            <key>NSIncludesSubdomains</key>
            <false/>
        </dict>
    </dict>
</dict>
```

或者使用 `NSAllowsArbitraryLoads`（仅用于开发测试）：

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>  <!-- 允许所有 HTTPS 连接 -->
</dict>
```

### 7. 启动 Node.js 应用

```bash
cd ~/beautyclinic/backend
pm2 start src/index.js --name beautyclinic-api
# 或
npm start &
```

### 8. 测试 HTTPS 连接

```bash
curl -v https://124.221.217.56/health
```

### 9. 设置自动续期（Let's Encrypt）

```bash
# 测试续期
sudo certbot renew --dry-run

# 添加到 crontab
sudo crontab -e

# 添加以下行（每天凌晨检查两次）
0 0,12 * * * /usr/bin/certbot renew >/dev/null 2>&1
```

---

## 安全组配置（腾讯云）

确保腾讯云安全组允许以下端口：
- **80** (HTTP) - 用于证书验证和重定向
- **443** (HTTPS) - 主要的 HTTPS 流量

---

## 验证 SSL 配置

```bash
# 使用 OpenSSL 检查
openssl s_client -connect 124.221.217.56:443 -servername 124.221.217.56

# 使用 curl 测试
curl -I https://124.221.217.56/api/health
```

---

## 故障排查

### 端口被拒绝
```bash
sudo ufw allow 'Nginx Full'
sudo ufw status
```

### 证书未找到
检查路径是否正确：
```bash
ls -la /etc/letsencrypt/live/124.221.217.56/
```

### App 连接失败
- 清理 Xcode 构建：`Product → Clean Build Folder`
- 重新编译应用
- 检查 Info.plist 配置
