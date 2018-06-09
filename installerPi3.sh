#!/bin/bash

#Installing Asterisk & FreePBX
##############################

# Allow login as root via SSH
sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' /etc/ssh/sshd_config
service sshd restart

#Update Your System
apt-get update && apt-get upgrade -y 

#Install Required Dependencies
apt-get install -y build-essential raspberrypi-kernel-headers openssh-server apache2 mysql-server
apt-get install -y mysql-client bison flex php7.0 php7.0-curl php7.0-gd php7.0-db php7.0-soap php7.0-imap
apt-get install -y php7.0-json php7.0-mcrypt php7.0-mysql php7.0-opcache php7.0-xmlrpc libapache2-mod-php7.0 curl sox
apt-get install -y libncurses5-dev libssl-dev default-libmysqlclient-dev libavutil-dev libavcodec-dev
apt-get install -y libavformat-dev libavdevice-dev libavfilter-dev libavresample-dev libswscale-dev libswresample-dev
apt-get install -y libpostproc-dev mpg123 libxml2-dev libnewt-dev sqlite3
apt-get install -y libsqlite3-dev pkg-config automake libtool libtool-bin autoconf git unixodbc-dev uuid uuid-dev gcc make
apt-get install -y libasound2-dev libogg-dev libvorbis-dev libcurl4-openssl-dev libical-dev libneon27-dev libsrtp0-dev
apt-get install -y libspandsp-dev sudo subversion vim-tiny python-dev install perl libnet-ssleay-perl openssl libauthen-pam-perl
apt-get install -y libpam-runtime libio-pty-perl apt-show-versions python

#Install Legacy pear requirements
pear install Console_Getopt

#Install iksemel (Google Voice)
cd /usr/src
git clone https://github.com/meduketto/iksemel.git
cd iksemel
./autogen.sh
./configure
make
make install
ldconfig

#Install nodejs
curl -sL https://deb.nodesource.com/setup_10.x | sudo -E bash -
sudo apt-get install -y nodejs

#Install and Configure Asterisk
cd /usr/src
wget http://downloads.asterisk.org/pub/telephony/asterisk/asterisk-15-current.tar.gz
wget -O jansson.tar.gz https://github.com/akheron/jansson/archive/v2.11.tar.gz
wget http://www.pjsip.org/release/2.7/pjproject-2.7.1.tar.bz2

#Compile and install pjproject
cd /usr/src
tar -xjvf pjproject-2.7.2.tar.bz2
rm -f pjproject-2.7.2.tar.bz2
cd pjproject-*
./configure --enable-shared --enable-sound --enable-resample --enable-video --enable-opencore-amr
make dep
make
make install

#Compile and Install jansson
cd /usr/src
tar vxfz jansson.tar.gz
rm -f jansson.tar.gz
cd jansson-*
autoreconf -i
./configure
make
make install

#Compile and install Asterisk
cd /usr/src
tar xvfz asterisk-15-current.tar.gz
rm -f asterisk-15-current.tar.gz
cd asterisk-*
contrib/scripts/get_mp3_source.sh
contrib/scripts/install_prereq install
./configure --with-pjproject-bundled
make menuselect
make
make install
make config
ldconfig
update-rc.d -f asterisk remove

#COMPILING G729
#apt-get update && apt-get upgrade -y
#apt-get install -y dh-autoreconf
#cd /usr/local/src
#wget http://download-mirror.savannah.gnu.org/releases/linphone/plugins/sources/bcg729-1.0.0.tar.gz
#tar xzf bcg729-1.0.0.tar.gz
#rm -f bcg729-1.0.0.tar.gz
#cd bcg729-*
#./configure --libdir=/lib
#make
#make install

#Building codec_g729.so
#cd /usr/local/src
#wget http://asterisk.hosting.lv/src/asterisk-g72x-1.4.tar.bz2
#tar -jxvf asterisk-g72x-1.4.tar.bz2
#rm -f asterisk-g72x-1.4.tar.bz2
#cd asterisk-g72x-*
#./autogen.sh 
#./configure CFLAGS='-march=armv6' --with-asterisk130 --with-bcg729 --with-asterisk-includes=/usr/include
#make
#make install
#chmod +x /usr/lib/asterisk/modules/codec_g729.so

#Install and Configure FreePBX
useradd -m asterisk
chown asterisk. /var/run/asterisk
chown -R asterisk. /etc/asterisk
chown -R asterisk. /var/{lib,log,spool}/asterisk
chown -R asterisk. /usr/lib/asterisk
rm -rf /var/www/html

#A few small modifications to Apache.
sed -i 's/\(^upload_max_filesize = \).*/\120M/' /etc/php/7.0/apache2/php.ini
cp /etc/apache2/apache2.conf /etc/apache2/apache2.conf_orig
sed -i 's/^\(User\|Group\).*/\1 asterisk/' /etc/apache2/apache2.conf
sed -i 's/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf
service apache2 restart

#Configure ODBC
cat >> /etc/odbcinst.ini << EOF
[MySQL]
Description = ODBC for MySQL
Driver = /usr/lib/arm-linux-gnueabihf/odbc/libmyodbc.so
Setup = /usr/lib/arm-linux-gnueabihf/odbc/libodbcmyS.so
FileUsage = 1

EOF

cat >> /etc/odbc.ini << EOF
[MySQL-asteriskcdrdb]
Description=MySQL connection to 'asteriskcdrdb' database
driver=MySQL
server=localhost
database=asteriskcdrdb
Port=3306
Socket=/var/run/mysqld/mysqld.sock
option=3

EOF

# Download and install FreePBX.
cd /usr/src
wget http://mirror.freepbx.org/modules/packages/freepbx/freepbx-14.0-latest.tgz
tar vxfz freepbx-14.0-latest.tgz
rm -f freepbx-14.0-latest.tgz
cd freepbx
touch /etc/asterisk/ari.conf
./start_asterisk start
./install -n

#Restart Apache
a2enmod rewrite
service apache2 restart

#systemd startup script for FreePBX
rm -f /etc/systemd/system/freepbx.service
cat >> /etc/systemd/system/freepbx.service << EOF
[Unit]
Description=FreePBX VoIP Server
After=mysql.service
 
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/sbin/fwconsole start
ExecStop=/usr/sbin/fwconsole stop
 
[Install]
WantedBy=multi-user.target

EOF

systemctl enable freepbx.service
ln -s '/etc/systemd/system/freepbx.service' '/etc/systemd/system/multi-user.target.wants/freepbx.service'
systemctl start freepbx

#checking the output of the startup
systemctl status -l freepbx.service

#Installing WebMin
##########################
wget http://prdownloads.sourceforge.net/webadmin/webmin_1.880_all.deb
dpkg --install webmin_1.880_all.deb

#Installing A2Billing
##########################
mkdir -p /usr/share/a2billing/latest/
cd /usr/share/a2billing/
wget -O master.tar.gz --no-check-certificate https://codeload.github.com/Star2Billing/a2billing/tar.gz/master
tar zxf master.tar.gz
mv a2billing-master/* /usr/share/a2billing/latest/
rm -rf a2billing-master master.tar.gz

chmod u+xwr /usr/share/a2billing/latest/admin/templates_c
chmod a+w /usr/share/a2billing/latest/admin/templates_c
chmod u+xwr /usr/share/a2billing/latest/agent/templates_c
chmod a+w /usr/share/a2billing/latest/agent/templates_c
chmod u+xwr /usr/share/a2billing/latest/customer/templates_c
chmod a+w /usr/share/a2billing/latest/customer/templates_c

rm -rf /usr/share/a2billing/latest/admin/templates_c/*
rm -rf /usr/share/a2billing/latest/agent/templates_c/*
rm -rf /usr/share/a2billing/latest/customer/templates_c/*

# copy conf files
cp /usr/share/a2billing/latest/a2billing.conf /etc/a2billing.conf

cd /etc/apache2/sites-enabled/
wget https://raw.github.com/Star2Billing/a2billing/develop/addons/apache2/a2billing_admin.conf
wget https://raw.github.com/Star2Billing/a2billing/develop/addons/apache2/a2billing_customer.conf

ln -s /usr/share/a2billing/latest/AGI/a2billing.php /usr/share/asterisk/agi-bin/a2billing.php
chown asterisk:asterisk /usr/share/asterisk/agi-bin/a2billing.php
chmod +x /usr/share/asterisk/agi-bin/a2billing.php

# Install Audio files
cd /usr/share/a2billing/latest/addons/sounds
./install_a2b_sounds.sh
#set ownership on sounds
chown -R asterisk:asterisk /usr/share/asterisk/

cd /etc/asterisk
wget -O extensions_a2billing.conf https://raw.github.com/Star2Billing/a2billing/develop/addons/asterisk-conf/extensions_a2billing_1_8.conf

#include "extensions_a2billing.conf"
echo "Adding A2Billing extensions to /etc/asterisk/extensions_custom.conf"
cat /etc/asterisk/extensions_a2billing.conf > /etc/asterisk/extensions_custom.conf

#Install A2billing DB
/etc/init.d/mysql start
mysql -uroot -praspberrypi -e "CREATE DATABASE a2billing_db;"
cd /usr/share/a2billing/latest/DataBase/mysql-5.x
bash install-db.sh

sed -i "s/a2billing_dbuser/root/g" /etc/a2billing.conf
sed -i "s/a2billing_dbpassword/raspberrypi/g" /etc/a2billing.conf
sed -i "s/a2billing_dbname/a2billing_db/g" /etc/a2billing.conf

#Install Composer needed to avoid "Error 500" when loading a2billing admin page.
cd /usr/share/a2billing/latest
curl -sS https://getcomposer.org/installer | php
php composer.phar update
php composer.phar install

#Create a2billing symbolic link to apache2 web root directory.
cd /
ln -s /usr/share/a2billing/latest /var/www/html/a2billing
chown -R asterisk:asterisk /var/www/html/a2billing

#Restart Mysql & Apache2 service
/etc/init.d/mysql restart
/etc/init.d/apache2 restart

#write out current crontab
crontab -l > a2billing_cron

#echo new cron into cron file
echo "00 09 * * 1-5 echo hello" >> a2billing_cron

# update the currency table
echo "0 6 * * * php /usr/local/src/a2billing/Cronjobs/currencies_update_yahoo.php" >> a2billing_cron

# manage the monthly services subscription
echo "0 6 1 * * php /usr/local/src/a2billing/Cronjobs/a2billing_subscription_fee.php" >> a2billing_cron

# To check account of each Users and send an email if the balance is
#less than the user have choice.
echo "0 * * * * php /usr/local/src/a2billing/Cronjobs/a2billing_notify_account.php" >> a2billing_cron

# this script will browse all the DID that are reserve and check if
#the customer need to pay for it
# bill them or warn them per email to know if they want to pay in
#order to keep their DIDs
echo "0 2 * * * php /usr/local/src/a2billing/Cronjobs/a2billing_bill_diduse.php" >> a2billing_cron

# This script will take care of the recurring service.
echo "0 12 * * * php /usr/local/src/a2billing/Cronjobs/a2billing_batch_process.php" >> a2billing_cron

# To generate invoices and for each user.
echo "0 6 * * * php /usr/local/src/a2billing/Cronjobs/a2billing_batch_billing.php" >> a2billing_cron

# to proceed the autodialer
echo "*/5 * * * * php /usr/local/src/a2billing/Cronjobs/a2billing_batch_autodialer.php" >> a2billing_cron

# manage alarms
echo "0 * * * * php /usr/local/src/a2billing/Cronjobs/a2billing_alarm.php" >> a2billing_cron

#install new cron file
crontab -u asterisk a2billing_cron
rm a2billing_cron

# Creating A2Billing log file
mkdir /var/log/a2billing
touch /var/log/a2billing/a2billing_agi.log
chown -R asterisk:asterisk /var/log/a2billing

#Log rotation
cd /etc/logrotate.d
touch a2billing
cat >> /etc/logrotate.d/a2billing << EOF
/var/log/a2billing/*.log {
daily
missingok
rotate 4
sharedscripts
postrotate
endscript
}

EOF
