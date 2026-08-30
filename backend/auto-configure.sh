#!/bin/bash

# BeautyClinic HTTPS 自动配置脚本
# 运行前请确保：1. 域名已解析到服务器IP 2. PM2 应用正在运行

SERVER_IP="124.221.217.56"
PASSWORD="sw4)3Vhm\$9eX!~W"
DOMAIN="andychenpersonal.top"

echo "=========================================="
echo "BeautyClinic HTTPS 配置自动脚本"
echo "=========================================="
echo ""

# Step 1: Stop PM2 app
echo "[步骤 1/8] 停止 PM2 应用..."
expect << EOF
spawn ssh -o StrictHostKeyChecking=no ubuntu@${SERVER_IP} "pm2 stop beautyclinic-api || true"
expect {
    "*password:" { send "${PASSWORD}\r"; exp_continue }
    eof
}
EOF

# Step 2: Install Certbot
echo ""
echo "[步骤 2/8] 安装 Certbot..."
expect << EOF
spawn ssh -o StrictHostKeyChecking=no ubuntu@${SERVER_IP} "sudo apt update && sudo apt install certbot -y"
expect {
    "*password:" { send "${PASSWORD}\r"; exp_continue }
    eof
}
EOF

# Step 3: Get SSL certificate
echo ""
echo "[步骤 3/8] 获取 SSL 证书..."
expect << EOF
spawn ssh -o StrictHostKeyChecking=no ubuntu@${SERVER_IP} "sudo certbot certonly --standalone -d ${DOMAIN} --agree-tos --non-interactive --register-unsafely-without-email"
expect {
    "*password:" { send "${PASSWORD}\r"; exp_continue }
    eof
}
EOF

# Step 4: Configure Nginx
echo ""
echo "[步骤 4/8] 配置 Nginx..."
cat > /tmp/beautyclinic-nginx.conf << 'NGINX'
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
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location /health {
        proxy_pass http://127.0.0.1:3000/health;
    }
}

server {
    listen 80;
    server_name andychenpersonal.top;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}
NGINX

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

# Step 5: Restart PM2 app
echo ""
echo "[步骤 5/8] 启动 PM2 应用..."
expect << EOF
spawn ssh -o StrictHostKeyChecking=no ubuntu@${SERVER_IP} "pm2 start beautyclinic-api || npm start &"
expect {
    "*password:" { send "${PASSWORD}\r"; exp_continue }
    eof
}
EOF

# Step 6: Test HTTPS
echo ""
echo "[步骤 6/8] 测试 HTTPS 连接..."
expect << EOF
spawn ssh -o StrictHostKeyChecking=no ubuntu@${SERVER_IP} "curl -I https://${DOMAIN}/health"
expect {
    "*password:" { send "${PASSWORD}\r"; exp_continue }
    eof
}
EOF

# Step 7: Setup auto-renewal
echo ""
echo "[步骤 7/8] 设置自动续期..."
expect << EOF
spawn ssh -o StrictHostKeyChecking=no ubuntu@${SERVER_IP} "echo '0 0,12 * * * /usr/bin/certbot renew --quiet --deploy-hook \"systemctl reload nginx\"' | sudo crontab -"
expect {
    "*password:" { send "${PASSWORD}\r"; exp_continue }
    eof
}
EOF

# Step 8: Update iOS Info.plist
echo ""
echo "[步骤 8/8] 更新 iOS App Info.plist..."

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
		<key>NSExceptionDomains</key>
		<dict>
			<key>${DOMAIN}</key>
			<dict>
				<key>NSExceptionAllowsInsecureHTTPLoads</key>
				<false/>
				<key>NSExceptionRequiresForwardSecrecy</key>
				<false/>
				<key>NSIncludesSubdomains</key>
				<true/>
			</dict>
		</dict>
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
echo "下一步：在 Xcode 中重新编译应用"
echo "1. Product → Clean Build Folder (Shift + Command + K)"
echo "2. Product → Run (Command + R)"
echo ""
