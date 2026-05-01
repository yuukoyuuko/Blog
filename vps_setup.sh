#!/bin/bash
set -e

echo "Updating system..."
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
DEBIAN_FRONTEND=noninteractive apt-get install git nginx -y

echo "Configuring directories..."
mkdir -p /var/www/hexo
chmod -R 755 /var/www/hexo

echo "Configuring Git bare repo..."
mkdir -p /var/repo
git init --bare /var/repo/blog.git

echo "Configuring Git hook..."
cat << 'HOOK' > /var/repo/blog.git/hooks/post-receive
#!/bin/bash
git --work-tree=/var/www/hexo --git-dir=/var/repo/blog.git checkout -f
HOOK
chmod +x /var/repo/blog.git/hooks/post-receive

echo "Configuring Nginx..."
cat << 'NGINX' > /etc/nginx/sites-available/hexo
server {
    listen 80;
    server_name 178.128.68.15;
    
    root /var/www/hexo;
    index index.html index.htm;
    
    location / {
        try_files $uri $uri/ =404;
    }
}
NGINX

ln -sf /etc/nginx/sites-available/hexo /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

systemctl restart nginx

echo "VPS Setup Complete!"
