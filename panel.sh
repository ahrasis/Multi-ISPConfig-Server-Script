#!/bin/bash

# export DEBIAN_FRONTEND=noninteractive
# uncomment the above on Ubuntu 22.04

# change all these ips and hostnames or rename or comment them out accordingly
cat <<EOF > temp.txt
192.168.0.201	ispc.server.tld		ispc
192.168.0.202	web01.server.tld	web01
192.168.0.203	mx1.server.tld		mx1
192.168.0.204	mx2.server.tld		mx2
192.168.0.205	ns1.server.tld		ns1
192.168.0.206	ns2.server.tld		ns2
192.168.0.207	mail.server.tld		mail
EOF
sed -i -e "/.*192.*/r temp.txt" -e "//d" /etc/hosts
cat /etc/hosts
rm temp.txt

HOST=ispc
echo $HOST > /etc/hostname
hostname $HOST

# change all these ips or comment out accordingly of you don't have any of them
OLIPV4=192.168.0.200 # normally based on your vm's image ip
NUIPV4=192.168.0.201
OLIPV6=fe80::ac:76ff:fe2c:166e  # normally based on your vm's image ip
NUIPV6=$(/usr/bin/ip a | sed '/inet6/!d; /2001/d;  /dadfailed/d; /host/d; s/.*inet6 //; s_/.*__p; d')
sed -i "s/#OLIPV4/$IPV4/" /etc/netplan/01-netcfg.yaml
sed -i "s/#OLIPV6/$NUIPV6/" /etc/netplan/01-netcfg.yaml

cd /etc/ssl/private
curl https://ssl-config.mozilla.org/ffdhe4096.txt > dhparam4096.pem
ln -s dhparam4096.pem dh.pem
ln -s dhparam4096.pem dhparams.pem
ln -s dhparam4096.pem pure-ftpd-dhparams.pem

mkdir -p .secrets
cat <<EOF > .secrets/$HOST.server.tld.ini
dns_cloudflare_api_key = xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
dns_cloudflare_e= $HOST.server.tld@gmail.com
EOF
chmod 600 .secrets -R

apt -y install snapd
snap install core; snap refresh core; snap install --classic certbot
ln -s /snap/bin/certbot /usr/bin/certbot
ln -s /snap/bin/certbot /usr/local/bin/certbot
apt -y install python3-certbot-dns-cloudflare python3-cloudflare

cd /tmp
wget https://git.ispconfig.org/ispconfig/ispconfig3/-/raw/develop/server/scripts/letsencrypt_renew_hook.sh
ln -s /tmp/letsencrypt_renew_hook.sh /usr/local/bin/letsencrypt_renew_hook.sh
chmod +x /usr/local/bin/letsencrypt_renew_hook.sh

certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials /etc/ssl/private/.secrets/$HOST.server.tld.ini \
  --server https://acme-v02.api.letsencrypt.org/directory \
  --agree-tos \
  --non-interactive \
  --email $HOST@server.tld \
  --no-eff-email \
  --rsa-key-size 4096 \
  --renew-hook letsencrypt_renew_hook.sh \
  --cert-name $HOST.server.tld \
  -d $HOST.server.tld

# note that I prefer this to be interactive
wget -O - https://get.ispconfig.org | sh -s -- --use-nginx --unattended-upgrades --use-certbot --no-mail --no-dns --use-php=system --interactive

# Do not run ISPConfig until you change the root password for mysql and use fixed installer_base.lib.php which you must do by opening another CLI interface via ssh