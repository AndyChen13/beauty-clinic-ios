# 使用自签名 SSL 证书进行开发测试

## 在腾讯云服务器上执行以下命令

### 步骤 1: 创建自签名证书

```bash
# 创建目录
sudo mkdir -p /etc/ssl/private/beautyclinic

# 生成私钥
sudo openssl genrsa -out /etc/ssl/private/beautyclinic.key 2048

# 生成自签名证书（有效期 365 天）
sudo openssl req -new -x509 -key /etc/ssl/private/beautyclinic.key -out /etc/ssl/certs/beautyclinic.crt -days 365 -subj "/C=CN/ST=Shanghai/L=Shanghai/O=BeautyClinic/OU=IT/CN=124.221.217.56"
```

### 步骤 2: 配置 Nginx

```bash
sudo nano /etc/nginx/sites-available/beautyclinic
```

粘贴以下配置：

```nginx
server {
    listen 443 ssl http2;
    server_name 124.221.217.56;

    # SSL Certificate - 自签名证书路径
    ssl_certificate /etc/ssl/certs/beautyclinic.crt;
    ssl_certificate_key /etc/ssl/private/beautyclinic.key;

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
    return 301 https://$host$request_uri;
}
```

保存并退出（`Ctrl+O` → 回车 → `Ctrl+X`）

### 步骤 3: 启用配置

```bash
sudo ln -s /etc/nginx/sites-available/beautyclinic /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl restart nginx
```

### 步骤 4: 测试 HTTPS

```bash
curl -I https://124.221.217.56/health --insecure
```

---

## 在 iOS 端配置（重要！）

由于使用自签名证书，iOS 首次连接时会拒绝连接。你需要在 `Info.plist` 中添加以下配置：

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

或者更精细的配置：

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>124.221.217.56</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
            <key>NSExceptionRequiresForwardSecrecy</key>
            <false/>
        </dict>
    </dict>
</dict>
```

---

## 验证证书

```bash
# 查看证书信息
openssl x509 -in /etc/ssl/certs/beautyclinic.crt -text -noout

# 测试连接
curl -v https://124.221.217.56/health --insecure
```

---

## 安全提示

- 自签名证书仅用于开发测试，**不要用于生产环境**
- 生产环境请使用 Let's Encrypt 或购买商业 SSL 证书
- 如果你有域名，可以申请 Let's Encrypt 免费证书
