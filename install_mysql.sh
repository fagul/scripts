#!/bin/bash
apt-get update

# set up a silent install of MySQL



export DEBIAN_FRONTEND=noninteractive
echo mysql-server-5.6 mysql-server/root_password password welcome123 | debconf-set-selections
echo mysql-server-5.6 mysql-server/root_password_again password welcome123 | debconf-set-selections

# install the LAMP stack
apt-get -y install mysql-server 

sed -i -e"s/^bind-address\s*=\s*127.0.0.1/bind-address = 0.0.0.0/" /etc/mysql/my.cnf

sudo service mysql restart

echo "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY 'welcome123'; flush privileges;" | mysql 


echo "create database testdb" | mysql -u root -pwelcome123
