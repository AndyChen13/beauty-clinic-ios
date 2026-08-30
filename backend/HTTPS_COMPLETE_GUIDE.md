# BeautyClinic HTTPS 配置完整指南

## ✅ 你已完成的步骤

1. ✅ 注册域名：`andychenpersonal.top`
2. ✅ 更新 iOS App 的 Info.plist（已配置 andychenpersonal.top 域名）

---

## 🚀 接下来要做的（在腾讯云服务器上）

### 步骤 1：将域名解析到服务器 IP

登录腾讯云控制台 → 域名服务 → 解析 `andychenpersonal.top`

添加 A 记录：
- 主机记录：`@`
- 记录值：`124.221.217.56`

等待几分钟让 DNS 生效。

---

### 步骤 2：SSH 登录服务器

在你的 Mac 终端执行：

```bash
ssh ubuntu@124.221.217.56
```

输入密码：`sw4)3Vhm$9eX!~W`

---

### 步骤 3：安装 Certbot

```bash
sudo apt update && sudo apt install certbot -y
```

按提示输入服务器密码。

---

### 步骤 4：停止 Node.js 应用

```bash
ps aux | grep "node src/index.js"
```

会看到类似这样的输出：
```
ubuntu   12345  0.0  ...  node src/index.js
```

记录进程 ID（如 `12345`），然后执行：

```bash
kill 12345
```

---

### 步骤 5：获取 SSL 证书

```bash
sudo certbot certonly --standalone \
    -d andychenpersonal.top \
    -d www.andychenpersonal.top \
    --agree-tos \
    --non-interactive \
    --email andy.chen@example.com
```

如果 email 验证失败，用这个命令：

```bash
sudo certbot certonly --standalone \
    -d andychenpersonal.top \
    -d www.andychenpersonal.top \
    --agree-tos \
    --non-interactive \
    --register-unsafely-without-email
```

如果出现提示：
- 输入 `Y` 确认邮箱？
- 输入 `1` 或 `2` 选择验证方式？

按提示操作即可。

---

### 步骤 6：配置 Nginx

```bash
sudo nano /etc/nginx/sites-available/beautyclinic
```

复制粘贴以下内容：

```nginx
server {
    listen 443 ssl http2;
    server_name andychenpersonal.top www.andychenpersonal.top;

    # SSL Certificate - Let's Encrypt 路径
    ssl_certificate /etc/letsencrypt/live/andychenpersonal.top/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/andychenpersonal.top/privkey.pem;

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
    server_name andychenpersonal.top www.andychenpersonal.top;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}
```

保存退出：
- 按 `Ctrl+O` → 回车
- 按 `Ctrl+X`

---

### 步骤 7：启用配置

```bash
sudo ln -sf /etc/nginx/sites-available/beautyclinic /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl restart nginx
```

---

### 步骤 8：测试 HTTPS

```bash
curl -I https://andychenpersonal.top/health
```

应该返回 `HTTP/2 200`。

---

## 📱 最后一步（在 Xcode 中）

1. 在 Xcode 中打开项目
2. Product → Clean Build Folder (Shift + Command + K)
3. Product → Run (Command + R)

应用现在会通过 HTTPS 连接 `andychenpersonal.top`。

---

## 🔁 证书自动续期

Let's Encrypt 证书有效期 90 天，设置自动续期：

```bash
echo "0 0,12 * * * /usr/bin/certbot renew --quiet --deploy-hook 'systemctl reload nginx'" | sudo crontab -
```

---

## ❓遇到问题？

- 端口被拒绝：`sudo ufw allow 'Nginx Full'`
- 域名解析失败：等待几分钟或检查 DNS 设置
- 证书获取失败：确保域名已解析到服务器 IP
