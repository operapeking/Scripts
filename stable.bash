#!/usr/bin/env bash

domain = $1
fakedomain = $2

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
mkdir /etc/nginx/cert
acme.sh --install-cert -d $domain --key-file /etc/nginx/cert/$domain.key --fullchain-file /etc/nginx/cert/$domain.cer --reloadcmd "systemctl restart nginx"

bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u root

uuid = uuidgen

"{
  \"log\": {
    \"loglevel\": \"warning\",
    \"access\": \"/var/log/xray/access.log\",
    \"error\": \"/var/log/xray/error.log\"
  },
  \"inbounds\": [
    {
      \"port\": 4593,
      \"listen\": \"127.0.0.1\",
      \"protocol\": \"vless\",
      \"settings\": {
        \"clients\": [
          {
            \"id\": \"$uuid\"
          }
        ],
        \"streamSettings\": {
          \"network\": \"ws\",
          \"wsSettings\": {
            \"path\": \"/api\"
          }
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

"server {
    listen 443 ssl;
    ssl_certificate /etc/nginx/cert/$domain.cer;
    ssl_certificate_key /etc/nginx/cert/$domain.key;
    server_name $domain;
    if (\$host != $domain) {
        return 403;
    }
    location /api {
        proxy_pass http://127.0.0.1:4593;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection upgrade;
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
    location / {
        proxy_pass https://$fakedomain;
        proxy_set_header Host $fakedomain;
        proxy_set_header Referer https://$fakedomain;
    }
}" > '/etc/nginx/sites-available/xray'

ln -s /etc/nginx/sites-available/xray /etc/nginx/sites-enabled/

systemctl restart nginx

echo "不出意外的话应该是可以了，你的 uuid 为 $uuid，路径为 '/api'，类型为 VLESS + tcp + ws。"