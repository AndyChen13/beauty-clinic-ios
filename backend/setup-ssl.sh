#!/bin/bash
# BeautyClinic SSL 证书获取脚本（Let's Encrypt 免费版）

set -e

echo "=========================================="
echo "BeautyClinic SSL 证书自动配置脚本"
echo "使用 Let's Encrypt 免费证书"
echo "=========================================="

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SERVER_IP="124.221.217.56"
EMAIL="admin@beautyclinic.com"  # 替换为你的邮箱

echo ""
echo -e "${YELLOW}步骤 1: 检查 Certbot 是否已安装${NC}"
if ! command -v certbot &> /dev/null; then
    echo "正在安装 Certbot..."
    sudo apt update
    sudo apt install certbot python3-certbot-nginx -y
else
    echo -e "${GREEN}Certbot 已安装${NC}"
fi

echo ""
echo -e "${YELLOW}步骤 2: 停止 Nginx（释放端口）${NC}"
sudo systemctl stop nginx || true

echo ""
echo -e "${YELLOW}步骤 3: 获取 SSL 证书${NC}"
echo "使用 --standalone 模式（不需要 Nginx 运行）"
echo ""

# 使用 standalone 模式获取证书
sudo certbot certonly --standalone \
    -d "$SERVER_IP" \
    --agree-tos \
    --email "$EMAIL" \
    --no-eff-email \
    --preferred-challenges http \
    --register-unsafely-without-email 2>/dev/null || \
sudo certbot certonly --standalone \
    -d "$SERVER_IP" \
    --agree-tos \
    --non-interactive \
    --email "$EMAIL" \
    --no-eff-email

echo ""
echo -e "${GREEN}证书获取成功！${NC}"
echo ""

# 显示证书信息
echo "=========================================="
echo -e "${GREEN}证书信息:${NC}"
echo "位置: /etc/letsencrypt/live/$SERVER_IP/"
ls -la /etc/letsencrypt/live/$SERVER_IP/ 2>/dev/null || echo "证书目录不存在"
echo ""
echo "证书有效期:"
openssl x509 -in /etc/letsencrypt/live/$SERVER_IP/cert.pem 2>/dev/null | grep "Not After" || echo "无法读取证书"
echo "=========================================="

# 显示 Nginx 配置
echo ""
echo -e "${YELLOW}下一步: 配置 Nginx${NC}"
echo ""
echo "请运行以下命令配置 Nginx:"
echo ""
cat << 'NGINX_CONFIG'
# 创建 Nginx 配置文件
sudo nano /etc/nginx/sites-available/beautyclinic

# 粘贴以下内容（替换服务器 IP）:
server {
    listen 443 ssl http2;
    server_name 124.221.217.56;

    # SSL Certificate - Let's Encrypt 路径
    ssl_certificate /etc/letsencrypt/live/124.221.217.56/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/124.221.217.56/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;

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
NGINX_CONFIG

echo ""
echo "保存后运行:"
echo "  sudo ln -s /etc/nginx/sites-available/beautyclinic /etc/nginx/sites-enabled/"
echo "  sudo rm /etc/nginx/sites-enabled/default"
echo "  sudo nginx -t && sudo systemctl restart nginx"

# 设置自动续期
echo ""
echo -e "${YELLOW}步骤 4: 设置自动续期（推荐）${NC}"
echo ""
cat << 'RENEW_CRON'
# 添加到 crontab 自动续期证书（每天检查两次）
sudo crontab -e

# 添加以下行:
0 0,12 * * * /usr/bin/certbot renew --quiet --deploy-hook "systemctl reload nginx"
RENEW_CRON

echo ""
echo -e "${GREEN}配置完成！${NC}"
