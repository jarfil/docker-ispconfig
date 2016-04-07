#!/bin/bash

# Let the container know that there is no tty
export DEBIAN_FRONTEND="noninteractive"

# --- 1 Preliminary
apt-get -y update && apt-get -y upgrade && apt-get -y install rsyslog rsyslog-relp logrotate supervisor
touch /var/log/cron.log
# Create the log file to be able to run tail
touch /var/log/auth.log

# --- 2 Install the SSH server
apt-get -y install ssh openssh-server rsync

# --- 3 Install a shell text editor
apt-get -y install nano vim-nox

# --- 5 Update Your Debian Installation
apt-get -y update && apt-get -y upgrade

# --- 6 Change The Default Shell
echo "dash  dash/sh boolean no" | debconf-set-selections
dpkg-reconfigure dash

# --- 7 Synchronize the System Clock
apt-get -y install ntp ntpdate

# --- 8 Install Postfix, Dovecot, MySQL, phpMyAdmin, rkhunter, binutils
echo 'mysql-server mysql-server/root_password password pass' | debconf-set-selections
echo 'mysql-server mysql-server/root_password_again password pass' | debconf-set-selections
echo 'mariadb-server mariadb-server/root_password password pass' | debconf-set-selections
echo 'mariadb-server mariadb-server/root_password_again password pass' | debconf-set-selections
apt-get -y install postfix postfix-mysql postfix-doc mariadb-client mariadb-server openssl getmail4 rkhunter binutils dovecot-imapd dovecot-pop3d dovecot-mysql dovecot-sieve dovecot-lmtpd sudo
service postfix restart
service mysql restart

# --- 9 Install Amavisd-new, SpamAssassin And Clamav
apt-get -y install amavisd-new spamassassin clamav clamav-daemon zoo unzip bzip2 arj nomarch lzop cabextract apt-listchanges libnet-ldap-perl libauthen-sasl-perl clamav-docs daemon libio-string-perl libio-socket-ssl-perl libnet-ident-perl zip libnet-dns-perl
service spamassassin stop
systemctl disable spamassassin

# --- 10 Install Apache2, PHP5, phpMyAdmin, FCGI, suExec, Pear, And mcrypt
echo 'phpmyadmin phpmyadmin/dbconfig-install boolean true' | debconf-set-selections
# echo 'phpmyadmin phpmyadmin/app-password-confirm password your-app-pwd' | debconf-set-selections
echo 'phpmyadmin phpmyadmin/mysql/admin-pass password pass' | debconf-set-selections
# echo 'phpmyadmin phpmyadmin/mysql/app-pass password your-app-db-pwd' | debconf-set-selections
echo 'phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2' | debconf-set-selections
service mysql restart && apt-get -y install apache2 apache2.2-common apache2-doc apache2-mpm-prefork apache2-utils libexpat1 ssl-cert libapache2-mod-php5 php5 php5-common php5-gd php5-mysql php5-imap phpmyadmin php5-cli php5-cgi libapache2-mod-fcgid apache2-suexec php-pear php-auth php5-mcrypt mcrypt php5-imagick imagemagick libruby libapache2-mod-python php5-curl php5-intl php5-memcache php5-memcached php5-pspell php5-recode php5-sqlite php5-tidy php5-xmlrpc php5-xsl memcached libapache2-mod-passenger
a2enmod suexec rewrite ssl actions include dav_fs dav auth_digest cgi

# --- 12 XCache and PHP-FPM
apt-get -y install php5-xcache
# php5 fpm (non-free)
# apt-get -y install libapache2-mod-fastcgi php5-fpm
# a2enmod actions fastcgi alias
# service apache2 restart

# --- 13 Install Mailman
echo 'mailman mailman/default_server_language en' | debconf-set-selections
apt-get -y install mailman
# /usr/lib/mailman/bin/newlist -q mailman mail@mail.com pass
newaliases
service postfix restart
ln -s /etc/mailman/apache.conf /etc/apache2/conf-enabled/mailman.conf

# --- 14 Install PureFTPd And Quota

# install package building helpers
apt-get -y --force-yes install dpkg-dev debhelper openbsd-inetd
# install dependancies
apt-get -y build-dep pure-ftpd
# build from source
mkdir /tmp/pure-ftpd-mysql/ && \
    cd /tmp/pure-ftpd-mysql/ && \
    apt-get source pure-ftpd-mysql && \
    cd pure-ftpd-* && \
    sed -i '/^optflags=/ s/$/ --without-capabilities/g' ./debian/rules && \
    dpkg-buildpackage -b -uc
# install the new deb files
dpkg -i /tmp/pure-ftpd-mysql/pure-ftpd-common*.deb
dpkg -i /tmp/pure-ftpd-mysql/pure-ftpd-mysql*.deb
# Prevent pure-ftpd upgrading
apt-mark hold pure-ftpd-common pure-ftpd-mysql
# setup ftpgroup and ftpuser
groupadd ftpgroup
useradd -g ftpgroup -d /dev/null -s /etc ftpuser
apt-get -y install quota quotatool
echo 1 > /etc/pure-ftpd/conf/TLS
mkdir -p /etc/ssl/private/
# openssl req -x509 -nodes -days 7300 -newkey rsa:2048 -keyout /etc/ssl/private/pure-ftpd.pem -out /etc/ssl/private/pure-ftpd.pem
# chmod 600 /etc/ssl/private/pure-ftpd.pem
# service pure-ftpd-mysql restart

# --- 15 Install BIND DNS Server
apt-get -y install bind9 dnsutils

# --- 16 Install Vlogger, Webalizer, And AWStats
apt-get -y install vlogger webalizer awstats geoip-database libclass-dbi-mysql-perl

# --- 17 Install Jailkit
apt-get -y install build-essential autoconf automake libtool flex bison debhelper binutils
cd /tmp && wget http://olivier.sessink.nl/jailkit/jailkit-2.17.tar.gz && tar xvfz jailkit-2.17.tar.gz && cd jailkit-2.17 && ./debian/rules binary
cd /tmp && dpkg -i jailkit_2.17-1_*.deb && rm -rf jailkit-2.17*

# --- 18 Install fail2ban
apt-get -y install fail2ban
echo "ignoreregex =" >> /etc/fail2ban/filter.d/postfix-sasl.conf
service fail2ban restart

# --- 19 Install squirrelmail
apt-get -y install squirrelmail
mkdir /var/lib/squirrelmail/tmp
chown www-data /var/lib/squirrelmail/tmp
service mysql restart

# --- 20 Install ISPConfig 3
cd /tmp && cd . && wget http://www.ispconfig.org/downloads/ISPConfig-3-stable.tar.gz
cd /tmp && tar xfz ISPConfig-3-stable.tar.gz
service mysql restart
# cat /tmp/install_ispconfig.txt | php -q /tmp/ispconfig3_install/install/install.php
# sed -i -e"s/^bind-address\s*=\s*127.0.0.1/bind-address = 0.0.0.0/" /etc/mysql/my.cnf
# sed -i -e "s/upload_max_filesize\s*=\s*2M/upload_max_filesize = 100M/g" /etc/php5/fpm/php.ini
# sed -i -e "s/post_max_size\s*=\s*8M/post_max_size = 100M/g" /etc/php5/fpm/php.ini

echo "export TERM=xterm" >> /root/.bashrc

# ISPCONFIG Initialization and Startup Script
chmod 755 /start.sh
mkdir -p /var/run/sshd
mkdir -p /var/log/supervisor
mv /bin/systemctl /bin/systemctloriginal

sed -i "s/^hostname=server1.example.com$/hostname=$HOSTNAME/g" /tmp/ispconfig3_install/install/autoinstall.ini
# mysqladmin -u root password pass
service mysql restart && php -q /tmp/ispconfig3_install/install/install.php --autoinstall=/tmp/ispconfig3_install/install/autoinstall.ini
cp -r /tmp/ISPConfig_Clean-3.0.5/interface /usr/local/ispconfig/
service mysql restart && mysql -ppass < /tmp/ISPConfig_Clean-3.0.5/sql/ispc-clean.sql
# Directory for dump SQL backup
mkdir -p /var/backup/sql
freshclam

# --- cleanup
apt-get -y autoremove
apt-get clean
rm -rf /var/lib/apt/lists/*
