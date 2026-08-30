#!/bin/bash

# BeautyClinic SSL 证书自动化配置脚本

SERVER_IP="124.221.217.56"
PASSWORD='sw4)3Vhm$9eX!~W'
EMAIL="andy.chen@example.com"

echo "=========================================="
echo "BeautyClinic SSL 证书自动配置"
echo "使用 Let's Encrypt 免费证书"
echo "=========================================="

# Step 1: Install Certbot
echo ""
echo "[步骤 1/7] 安装 Certbot..."
expect << EOF
spawn ssh -o StrictHostKeyChecking=no ubuntu@${SERVER_IP} "sudo apt update && sudo apt install certbot -y"
expect {
    "*password:" { send "${PASSWORD}\r"; exp_continue }
    "*yes/no*" { send "yes\r"; exp_continue }
    eof
}
EOF

# Step 2: Stop Node.js app
echo ""
echo "[步骤 2/7] 停止 Node.js 应用..."
expect << EOF
spawn ssh -o StrictHostKeyChecking=no ubuntu@${SERVER_IP} "ps aux | grep 'node src/index.js' | grep -v grep"
expect {
    "*password:" { send "${PASSWORD}\r"; exp_continue }
    eof
}
EOF

# Step 3: Get SSL certificate
echo ""
echo "[步骤 3/7] 获取 SSL 证书..."
expect << EOF
spawn ssh -o StrictHostKeyChecking=no ubuntu@${SERVER_IP} "sudo certbot certonly --standalone --preferred-challenges http -d ${SERVER_IP} --agree-tos --non-interactive --register-unsafely-without-email"
expect {
    "*password:" { send "${PASSWORD}\r"; exp_continue }
    "*Yes*" { send "yes\r"; exp_continue }
    eof
}
EOF

# Step 4: Configure Nginx
echo ""
echo "[步骤 4/7] 配置 Nginx..."
cat > /tmp/beautyclinic-nginx.conf << 'NGINX'
server {
    listen 443 ssl http2;
    server_name 124.221.217.56;

    ssl_certificate /etc/letsencrypt/live/124.221.217.56/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/124.221.217.56/privkey.pem;

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
    server_name 124.221.217.56;
    return 301 https://$host$request_uri;
}
NGINX

# Upload and configure Nginx
expect << EOF
spawn scp /tmp/beautyclinic-nginx.conf ubuntu@${SERVER_IP}:/tmp/beautyclinic-nginx.conf
expect {
    "*password:" { send "${PASSWORD}\r"; exp_continue }
    eof
}
EOF

expect << EOF
spawn ssh -o StrictHostKeyChecking=no ubuntu@${SERVER_IP} "sudo cp /tmp/beautyclinic-nginx.conf /etc/nginx/sites-available/beautyclinic && sudo ln -sf /etc/nginx/sites-available/beautyclinic /etc/nginx/sites-enabled/ && sudo rm -f /etc/nginx/sites-enabled/default && sudo nginx -t && sudo systemctl restart nginx"
expect {
    "*password:" { send "${PASSWORD}\r"; exp_continue }
    eof
}
EOF

# Step 5: Test HTTPS
echo ""
echo "[步骤 5/7] 测试 HTTPS 连接..."
expect << EOF
spawn ssh -o StrictHostKeyChecking=no ubuntu@${SERVER_IP} "curl -I https://${SERVER_IP}/health"
expect {
    "*password:" { send "${PASSWORD}\r"; exp_continue }
    eof
}
EOF

# Step 6: Setup auto-renewal
echo ""
echo "[步骤 6/7] 设置自动续期..."
expect << EOF
spawn ssh -o StrictHostKeyChecking=no ubuntu@${SERVER_IP} "echo '0 0,12 * * * /usr/bin/certbot renew --quiet' | sudo crontab -"
expect {
    "*password:" { send "${PASSWORD}\r"; exp_continue }
    eof
}
EOF

# Step 7: Update iOS app Info.plist
echo ""
echo "[步骤 7/7] 更新 iOS App Info.plist..."

cat > /tmp/new-infoplist.plist << 'INFOPLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>zh_CN</string>
	<key>CFBundleExecutable</key>
	<string>$(EXECUTABLE_NAME)</string>
	<key>CFBundleIdentifier</key>
	<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>$(PRODUCT_NAME)</string>
	<key>CFBundlePackageType</key>
	<string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSRequiresIPhoneOS</key>
	<true/>
	<key>NSAppTransportSecurity</key>
	<dict>
		<key>NSAllowsArbitraryLoads</key>
		<true/>
		<key>NSAllowsLocalNetworking</key>
		<true/>
	</dict>
	<key>NSCameraUsageDescription</key>
	<string>此应用需要访问相机以拍摄客户照片。</string>
	<key>NSPhotoLibraryAddUsageDescription</key>
	<string>此应用需要保存照片到相册。</string>
	<key>NSPhotoLibraryUsageDescription</key>
	<string>此应用需要访问相册以选择客户照片。</string>
	<key>UIApplicationSceneManifest</key>
	<dict>
		<key>UIApplicationSupportsMultipleScenes</key>
		<false/>
	</dict>
	<key>UILaunchScreen</key>
	<dict>
		<key>UIImageName</key>
		<string></string>
	</dict>
	<key>UIRequiredDeviceCapabilities</key>
	<array>
		<string>armv7</string>
	</array>
	<key>UISupportedInterfaceOrientations</key>
	<array>
		<string>UIInterfaceOrientationPortrait</string>
	</array>
</dict>
</plist>
INFOPLIST

cp /tmp/new-infoplist.plist "/Users/andychen/Desktop/beauty-clinic-ios/BeautyClinic/Info.plist"

echo ""
echo "=========================================="
echo -e "\033[0;32m✅ 配置完成！\033[0m"
echo "=========================================="
echo ""
echo "现在请在 Xcode 中重新编译应用："
echo "1. Product → Clean Build Folder (或按 Shift + Command + K)"
echo "2. Product → Run (或按 Command + R)"
echo ""
