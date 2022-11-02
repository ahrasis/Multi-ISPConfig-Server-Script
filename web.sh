#!/bin/bash

# export DEBIAN_FRONTEND=noninteractive
# uncomment the above on Ubuntu 22.04

# PLEASE CHANGE ALL THESE VARIABLES TO SUIT YOURS
HOST=ispc
DOMAIN=server.tld
OLIPV4=192.168.0.200 # normally based on your vm's image ip
NUIPV4=192.168.0.201
OLIPV6=fe80::ac:76ff:fe2c:166e  # normally based on your vm's image ip
DNSKEY=XXXXXXXXXXXXXXXXXXXXXX
DNSMAIL=$HOST@ispc.$DOMAIN
NEWPW=nEwPw

# change all these ips and hostnames or rename or comment them out accordingly
cat <<EOF > temp.txt
192.168.0.201	ispc.$DOMAIN	ispc
192.168.0.202	web01.$DOMAIN	web01
192.168.0.203	mx1.$DOMAIN	mx1
192.168.0.204	mx2.$DOMAIN	mx2
192.168.0.205	ns1.$DOMAIN	ns1
192.168.0.206	ns2.$DOMAIN	ns2
192.168.0.207	mail.$DOMAIN	mail
EOF
sed -i -e "/.*192.*/r temp.txt" -e "//d" /etc/hosts
cat /etc/hosts
rm temp.txt

echo $HOST > /etc/hostname
hostname $HOST

# change all these ips or comment out accordingly of you don't have any of them
NUIPV6=$(/usr/bin/ip a | sed '/inet6/!d; /2001/d;  /dadfailed/d; /host/d; s/.*inet6 //; s_/.*__p; d')
sed -i "s/#OLIPV4/$IPV4/" /etc/netplan/01-netcfg.yaml
sed -i "s/#OLIPV6/$NUIPV6/" /etc/netplan/01-netcfg.yaml

cd /etc/ssl/private
curl https://ssl-config.mozilla.org/ffdhe4096.txt > dhparam4096.pem
ln -s dhparam4096.pem dh.pem
ln -s dhparam4096.pem dhparams.pem
ln -s dhparam4096.pem pure-ftpd-dhparams.pem

mkdir -p .secrets
cat <<EOF > .secrets/$HOST.$DOMAIN.ini
dns_cloudflare_api_key = $DNSKEY
dns_cloudflare_email = $DNSMAIL
EOF
chmod 600 .secrets -R

apt -y install snapd
snap install core; snap refresh core
snap install --classic certbot
ln -s /snap/bin/certbot /usr/bin/certbot
ln -s /snap/bin/certbot /usr/local/bin/certbot
apt -y install python3-pip
pip3 install certbot-dns-cloudflare

cd /tmp
wget https://git.ispconfig.org/ispconfig/ispconfig3/-/raw/develop/server/scripts/letsencrypt_renew_hook.sh
ln -s /tmp/letsencrypt_renew_hook.sh /usr/local/bin/letsencrypt_renew_hook.sh
chmod +x /usr/local/bin/letsencrypt_renew_hook.sh

certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials /etc/ssl/private/.secrets/$HOST.$DOMAIN.ini \
  --server https://acme-v02.api.letsencrypt.org/directory \
  --agree-tos \
  --non-interactive \
  --email $DNSMAIL \
  --no-eff-email \
  --rsa-key-size 4096 \
  --renew-hook letsencrypt_renew_hook.sh \
  --cert-name $HOST.$DOMAIN \
  -d $HOST.$DOMAIN
  
cat <<EOF > /etc/init.d/installer-lib-temporary-fixer.sh
#!/bin/sh
### BEGIN INIT INFO
# Provides: ISPC INSTALLER LIB TEMPORARY FIXER FOR CERTBOT
# Required-Start: $local_fs $network
# Required-Stop: $local_fs
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: INSTALLER LIB TEMPORARY FIXER
# Description: Fix installer_base.lib.php v3.2.8p2 from line 3179 to 3188.
### END INIT INFO

# installer fixer
cd /tmp
wget https://www.ispconfig.org/downloads/ISPConfig-3.2.8p2.tar.gz
tar xvfz ISPConfig-3.2.8p2.tar.gz
cd /tmp/ispconfig*/install/lib
wget https://raw.githubusercontent.com/ahrasis/Multi-ISPConfig-Server-Script/main/replace.txt
sed -i $'3179r replace.txt\n;3179,3188d' installer_base.lib.php

# change mysql root password
SLOG=$(ls /tmp/ispconfig-ai/var/log/setup*)
LINE=$(awk '/Your MySQL root password is/' $SLOG)
GENPW=$($echo "$LINE" | awk '{print $NF}')
user=root
password=$GENPW # change to password given by ISPConfig AI accordingly
database=mysql
mysql --user="$user" --password="$password" --database="$database" --execute="ALTER USER 'root'@'localhost' IDENTIFIED BY '$NEWPW';"
EOF
chmod +x /etc/init.d/installer-lib-temporary-fixer.sh

cat <<EOF > /etc/systemd/system/installer-lib-temporary-fix.service
[Unit] 
Description="Run script to fix installer_base.lib.php v3.2.8p2"

[Service]
ExecStart=/etc/init.d/installer-lib-temporary-fixer.sh
EOF

cat <<EOF > /etc/systemd/system/installer-lib-temporary-fix.path
[Unit]
Description="Monitor installer path to trigger a temporary fix service"

[Path]
PathModified=/tmp/ispconfig3_install/install/
Unit=installer-lib-temporary-fix.service

[Install]
WantedBy=multi-user.target
EOF

systemctl start installer-lib-temporary-fix.path
systemctl enable installer-lib-temporary-fix.path

# note that I prefer this to be interactive
wget -O - https://get.ispconfig.org | sh -s -- --use-nginx --unattended-upgrades --use-certbot --no-mail --no-dns --interactive

# Do not run ISPConfig until you change the root password for mysql and use fixed installer_base.lib.php which you must do by opening another CLI interface via ssh

ufw allow from 192.168.0.0/24 to any port 3306 proto tcp

systemctl disable installer-lib-temporary-fix.path
systemctl stop installer-lib-temporary-fix.path
rm /etc/init.d/installer-lib-temporary-fixer.sh
rm /etc/systemd/system/installer-lib-temporary-fix.service
rm /etc/systemd/system/installer-lib-temporary-fix.path
