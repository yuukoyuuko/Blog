#!/bin/bash
set -e

echo "Installing Xray..."
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

echo "Generating Reality Keys..."
UUID=$(xray uuid)
KEYS=$(xray x25519)
PRIVATE_KEY=$(echo "$KEYS" | grep "PrivateKey:" | awk '{print $2}')
PUBLIC_KEY=$(echo "$KEYS" | grep "PublicKey" | awk '{print $3}')
SHORT_ID=$(openssl rand -hex 8)

echo "Configuring Xray..."
cat <<EOF > /usr/local/etc/xray/config.json
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "listen": "127.0.0.1",
      "port": 8443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "www.microsoft.com:443",
          "xver": 0,
          "serverNames": [
            "www.microsoft.com",
            "microsoft.com"
          ],
          "privateKey": "$PRIVATE_KEY",
          "shortIds": [
            "$SHORT_ID"
          ]
        },
        "sockopt": {
          "acceptProxyProtocol": true
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "blocked"
    }
  ]
}
EOF

echo "Configuring Nginx Stream Routing..."
cat <<EOF > /etc/nginx/stream.conf
stream {
    map \$ssl_preread_server_name \$backend_name {
        yuukoyuuko.me web;
        www.yuukoyuuko.me web;
        default xray;
    }

    upstream web {
        server 127.0.0.1:4443;
    }

    upstream xray {
        server 127.0.0.1:8443;
    }

    server {
        listen 443;
        listen [::]:443;
        proxy_pass \$backend_name;
        proxy_protocol on;
        ssl_preread on;
    }
}
EOF

if ! grep -q "stream.conf" /etc/nginx/nginx.conf; then
    echo "include /etc/nginx/stream.conf;" >> /etc/nginx/nginx.conf
fi

echo "Modifying Nginx Web Routing for proxy_protocol..."
sed -i 's/listen 443 ssl;/listen 127.0.0.1:4443 ssl proxy_protocol;/g' /etc/nginx/sites-available/hexo

if ! grep -q "set_real_ip_from" /etc/nginx/sites-available/hexo; then
    sed -i '/listen 127.0.0.1:4443 ssl proxy_protocol;/a \    set_real_ip_from 127.0.0.1;\n    real_ip_header proxy_protocol;' /etc/nginx/sites-available/hexo
fi

echo "Restarting Services..."
systemctl restart xray
systemctl restart nginx

echo "=========================================="
echo "VLESS+Reality Configuration Details:"
echo "Address: yuukoyuuko.me"
echo "Port: 443"
echo "UUID: $UUID"
echo "Flow: xtls-rprx-vision"
echo "Network: tcp"
echo "TLS: reality"
echo "SNI / ServerName: www.microsoft.com"
echo "Fingerprint: chrome"
echo "PublicKey: $PUBLIC_KEY"
echo "ShortId: $SHORT_ID"
echo "SpiderX: (empty)"
echo "=========================================="
