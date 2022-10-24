#!/usr/bin/env bash

echo "Enter your domain, and confirm the dns is right."
read domain

apt update

apt install nginx
"server {
  listen 80 default_server;
  listen [::]:80 default_server;

  server_name $domain

  root /var/www/html;

  location / {
    try_files \$uri \$uri/ =404;
  }

}" > '/etc/nginx/sites-available/default'
systemctl restart nginx

ufw disable

curl https://get.acme.sh | sh -s email=t@t.tt
source .bashrc
acme.sh --issue -d $domain --nginx

bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u root
acme.sh --install-cert -d $domain --key-file /usr/local/etc/xray/$domain.key --fullchain-file /usr/local/etc/xray/$domain.cer --reloadcmd "systemctl restart xray"

uuid = uuidgen

"{
  \"log\": {
    \"loglevel\": \"warning\",
    \"access\": \"/var/log/xray/access.log\",
    \"error\": \"/var/log/xray/error.log\"
  },
  \"inbounds\": [
    {
      \"port\": 443,
      \"protocol\": \"vless\",
      \"settings\": {
        \"clients\": [
          {
            \"id\": \"$uuid\",
            \"level\": 0
          }
        ],
        \"decryption\": \"none\",
        \"fallbacks\": [
          {
            \"dest\": 80
          },
          {
            \"path\": \"/api\",
            \"dest\": 4593,
            \"xver\": 1
          }
        ]
      },
      \"streamSettings\": {
        \"network\": \"tcp\",
        \"security\": \"tls\",
        \"tlsSettings\": {
          \"alpn\": [
            \"h2\",
            \"http/1.1\"
          ],
          \"certificates\": [
            {
              \"certificateFile\": \"/usr/local/etc/xray/$domain.cer\",
              \"keyFile\": \"/usr/local/etc/xray/$domain.key\"
            }
          ]
        }
      }
    },
    {
      \"port\": 4593,
      \"listen\": \"127.0.0.1\",
      \"protocol\": \"vless\",
      \"settings\": {
        \"clients\": [
          {
            \"id\": \"$uuid\",
            \"level\": 0
          }
        ],
        \"decryption\": \"none\"
      },
      \"streamSettings\": {
        \"network\": \"ws\",
        \"security\": \"none\",
        \"wsSettings\": {
          \"acceptProxyProtocol\": true,
          \"path\": \"/api\"
        }
      }
    }
  ],
  \"outbounds\": [
    {
      \"protocol\": \"freedom\"
    }
  ]
}" > '/usr/local/etc/xray/config.json'

systemctl restart xray

echo "不出意外的话应该是可以了，你的 uuid 为 $uuid，路径为 '/api'，类型为 VLESS + tcp + ws 和 VLESS + tcp + tls。"