# BeautyClinic HTTPS Setup Guide

## Prerequisites

1. **Domain Name (Recommended)**: 
   - For Let's Encrypt, you need a domain name (e.g., `api.beautyclinic.com`)
   - If using IP only, SSL will work but browsers may show security warnings

2. **Server Access**: SSH access to your腾讯云 Ubuntu server

---

## Step 1: Prepare Your Server

SSH into your server:
```bash
ssh ubuntu@124.221.217.56
```

Update system packages:
```bash
sudo apt update && sudo apt upgrade -y
```

---

## Step 2: Install Nginx (if not already installed)

```bash
sudo apt install nginx -y
```

Check if Nginx is running:
```bash
sudo systemctl status nginx
```

---

## Step 3: Get SSL Certificate

### Option A: Using Let's Encrypt (Recommended for free certificate)

Install Certbot:
```bash
sudo apt install certbot python3-certbot-nginx -y
```

Stop the current Node.js app (to free port 80):
```bash
# Find and stop your Express app process
ps aux | grep node
kill <node_process_id>
```

Obtain certificate (replace with your domain or IP):
```bash
sudo certbot certonly --standalone -d api.beautyclinic.com --agree-tos --email your-email@example.com --no-eff-email
```

If using IP address only:
```bash
sudo certbot certonly --standalone --preferred-challenges http -d 124.221.217.56 --agree-tos --email your-email@example.com --no-eff-email
```

Certificate will be saved in `/etc/letsencrypt/live/your-domain-or-ip/`

### Option B: Using Tencent Cloud SSL Certificate

1. Go to [Tencent Cloud SSL Console](https://console.cloud.tencent.com/ssl)
2. Click "Apply" → Select "Free Certificate"
3. Fill in domain information
4. Complete DNS verification
5. Download certificate for Nginx

Upload the downloaded files to your server:
```bash
# On your local machine, upload to server
scp -r /path/to/tencent-cert.zip ubuntu@124.221.217.56:~/certs/
```

Extract and move to proper location:
```bash
sudo mkdir -p /etc/ssl/certs/beautyclinic
sudo unzip ~/certs/*.zip -d /etc/ssl/certs/beautyclinic/
sudo cp /etc/ssl/certs/beautyclinic/*/*.pem /etc/ssl/private/beautyclinic.key
```

---

## Step 4: Configure Nginx

### Create Nginx configuration file:

```bash
sudo nano /etc/nginx/sites-available/beautyclinic
```

Copy the content from `backend/nginx-https-config.conf` (already created in your project)

Modify these lines:
- `server_name your-domain.com;` → Replace with your domain or IP: `124.221.217.56`
- `ssl_certificate /etc/ssl/certs/your-cert.pem;` → Update with actual path
  - Let's Encrypt: `/etc/letsencrypt/live/124.221.217.56/fullchain.pem`
  - Tencent Cloud: `/etc/ssl/certs/beautyclinic/cert.pem`

- `ssl_certificate_key /etc/ssl/private/your-key.pem;` → Update with actual path
  - Let's Encrypt: `/etc/letsencrypt/live/124.221.217.56/privkey.pem`
  - Tencent Cloud: `/etc/ssl/certs/beautyclinic/private.key`

Test Nginx configuration:
```bash
sudo nginx -t
```

Enable the site and restart Nginx:
```bash
sudo ln -s /etc/nginx/sites-available/beautyclinic /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default  # Remove default config

sudo systemctl reload nginx
```

### Step 5: Update Your Backend Environment

Edit `.env` file:
```bash
cd ~/beautyclinic/backend
nano .env
```

Update the `DATABASE_URL` if needed, then start your Node.js app:
```bash
# Install dependencies (first time only)
npm install

# Start the server
pm2 start src/index.js --name beautyclinic-api
# or
npm start
```

### Step 6: Update iOS App Info.plist

Update `BeautyClinic/Info.plist` to use HTTPS:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>124.221.217.56</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <false/>  <!-- Changed from true to false -->
            <key>NSExceptionRequiresForwardSecrecy</key>
            <false/>
            <key>NSIncludesSubdomains</key>
            <false/>
        </dict>
    </dict>
</dict>
```

Or better yet, if you have a domain:
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>api.beautyclinic.com</key>
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
```

### Step 7: Test HTTPS Connection

Test from your local machine:
```bash
curl -v https://124.221.217.56/health
```

If using a domain, replace IP with domain name.

---

## Automatic Certificate Renewal (Let's Encrypt)

Let's Encrypt certificates expire every 90 days. Set up automatic renewal:

```bash
# Test renewal
sudo certbot renew --dry-run

# Add to crontab for auto-renewal
sudo crontab -e

# Add this line (renews twice daily)
0 0,12 * * * /usr/bin/certbot renew >/dev/null 2>&1
```

---

## Troubleshooting

### Connection Refused on Port 443
```bash
# Check if Nginx is running
sudo systemctl status nginx

# Check firewall rules
sudo ufw status

# Allow HTTPS through firewall
sudo ufw allow 'Nginx Full'
```

### Certificate Validation Failed
- Make sure port 80 or 443 is open in腾讯云 security group
- For Let's Encrypt, ensure domain DNS points to your server IP

### App Still Shows ATS Error
- Clean build folder in Xcode: `Product → Clean Build Folder`
- Delete app from device and reinstall
- Check Info.plist has correct settings (not cached)

---

## Quick Start Script

Save this as `setup-https.sh` on your server:

```bash
#!/bin/bash
set -e

echo "=== BeautyClinic HTTPS Setup ==="

# Install Certbot if not installed
if ! command -v certbot &> /dev/null; then
    sudo apt update
    sudo apt install certbot python3-certbot-nginx -y
fi

# Stop current server to free port 80
echo "Stopping current Node.js app..."
ps aux | grep "node src/index.js" | awk '{print $2}' | xargs kill -9 || true

# Get certificate (replace with your domain/IP)
DOMAIN="124.221.217.56"
sudo certbot certonly --standalone -d "$DOMAIN" --agree-tos --email admin@example.com --no-eff-email

echo "Certificate installed successfully!"
echo "Now configure Nginx using the template in backend/nginx-https-config.conf"
```

Run it:
```bash
chmod +x setup-https.sh
sudo ./setup-https.sh
```
