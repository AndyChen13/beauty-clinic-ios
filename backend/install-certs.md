# BeautyClinic SSL 证书安装指南

## 快速复制粘贴命令到你的终端

### 步骤 1: SSH 登录服务器

```bash
ssh ubuntu@124.221.217.56
```
密码：`sw4)3Vhm$9eX!~W`

---

### 步骤 2: 安装 Certbot

```bash
sudo apt update && sudo apt install certbot -y
```

---

### 步骤 3: 停止当前 Node.js 应用

```bash
ps aux | grep "node src/index.js"
kill <进程ID>
# 或者使用 PM2
pm2 stop all
```

---

### 步骤 4: 获取 SSL 证书

```bash
sudo certbot certonly --standalone --preferred-challenges http \
    -d 124.221.217.56 \
    --agree-tos \
    --non-interactive \
    --register-unsafely-without-email
```

如果出现选择，输入 `Y` 确认。

---

### 步骤 5: 创建 Nginx 配置

```bash
sudo nano /etc/nginx/sites-available/beautyclinic
```

粘贴以下内容：

```nginx
server {
    listen 443 ssl http2;
    server_name 124.221.217.56;

    # SSL Certificate - Let's Encrypt 路径
    ssl_certificate /etc/letsencrypt/live/124.221.217.56/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/124.221.217.56/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;

    location /api/ {
        proxy_pass http://127.0.0.1:3000/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location /health {
        proxy_pass http://127.0.0.1:3000/health;
    }
}

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

保存：按 `Ctrl+O` → 回车 → `Ctrl+X`

---

### 步骤 6: 启用配置

```bash
sudo ln -s /etc/nginx/sites-available/beautyclinic /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl restart nginx
```

---

### 步骤 7: 测试 HTTPS

```bash
curl -I https://124.221.217.56/health
```

应该返回 `HTTP/2 200`。

---

### 步骤 8: 设置自动续期（可选但推荐）

```bash
sudo crontab -e
```

添加：
```
0 0,12 * * * /usr/bin/certbot renew --quiet --deploy-hook "systemctl reload nginx"
```

---

## 在 iOS 端

在 Xcode 中打开项目，更新 `BeautyClinic/Info.plist`：

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>  <!-- 允许 HTTPS 连接 -->
</dict>
```

或者使用更严格的配置：
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>124.221.217.56</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <false/>
        </dict>
    </dict>
</dict>
```

---

## 故障排查

### 端口被拒绝
```bash
sudo ufw allow 'Nginx Full'
sudo ufw status
```

### 证书获取失败
- 检查腾讯云安全组是否开放 80 和 443 端口
- 确保没有其他服务占用这些端口
