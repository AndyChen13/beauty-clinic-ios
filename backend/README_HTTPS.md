# BeautyClinic HTTPS 配置步骤（简化版）

## 你已经完成的：
1. ✅ 注册域名：`andychenpersonal.top`
2. ✅ 更新 iOS App 的 Info.plist

---

## 现在只需要 3 步（在腾讯云服务器上）：

### 步骤 1：添加 DNS 解析
登录腾讯云控制台 → 域名服务 → 解析 `andychenpersonal.top`  
添加 A 记录：记录值填 `124.221.217.56`

---

### 步骤 2：执行以下命令（SSH 登录后）

```bash
sudo apt update && sudo apt install certbot -y

ps aux | grep "node src/index.js"
kill <进程ID>

sudo certbot certonly --standalone \
    -d andychenpersonal.top \
    --agree-tos \
    --non-interactive \
    --register-unsafely-without-email
```

---

### 步骤 3：配置 Nginx

```bash
cat > /etc/nginx/sites-available/beautyclinic << 'EOF'
server {
    listen 443 ssl http2;
    server_name andychenpersonal.top;

    ssl_certificate /etc/letsencrypt/live/andychenpersonal.top/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/andychenpersonal.top/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;

    location /api/ {
        proxy_pass http://127.0.0.1:3000/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /health {
        proxy_pass http://127.0.0.1:3000/health;
    }
}

server {
    listen 80;
    server_name andychenpersonal.top;
    return 301 https://$host$request_uri;
}
EOF

sudo ln -sf /etc/nginx/sites-available/beautyclinic /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl restart nginx
```

---

### 步骤 4：测试

```bash
curl -I https://andychenpersonal.top/health
```

应该返回 `HTTP/2 200`。

---

### 步骤 5：在 Xcode 中重新编译应用

Product → Clean Build Folder  
Product → Run

---

## 🎉 完成！

现在你的 App 会通过 HTTPS 连接后端 API。
