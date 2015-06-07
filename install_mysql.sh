#!/bin/bash
apt-get -y update

# set up a silent install of MySQL
dbpass=$1

install_mysql(){
export DEBIAN_FRONTEND=noninteractive
echo mysql-server-5.6 mysql-server/root_password password $dbpass | debconf-set-selections
echo mysql-server-5.6 mysql-server/root_password_again password $dbpass | debconf-set-selections

# install the LAMP stack
apt-get -y install apache2 mysql-server 

}

create_mycnf() {
    wget "${MYCNFTEMPLATE}" -O /etc/my.cnf
    sed -i "s/^wsrep_cluster_address=.*/wsrep_cluster_address=gcomm:\/\/${CLUSTERADDRESS}/I" /etc/my.cnf
    sed -i "s/^wsrep_node_address=.*/wsrep_node_address=${NODEADDRESS}/I" /etc/my.cnf
    sed -i "s/^wsrep_node_name=.*/wsrep_node_name=${NODENAME}/I" /etc/my.cnf
    if [ $isubuntu -eq 0 ];
    then
        sed -i "s/^wsrep_provider=.*/wsrep_provider=\/usr\/lib\/libgalera_smm.so/I" /etc/my.cnf
    fi
}

open_ports() {
    iptables -A INPUT -p tcp -m tcp --dport 3306 -j ACCEPT
    iptables -A INPUT -p tcp -m tcp --dport 4444 -j ACCEPT
    iptables -A INPUT -p tcp -m tcp --dport 4567 -j ACCEPT
    iptables -A INPUT -p tcp -m tcp --dport 4568 -j ACCEPT
    iptables -A INPUT -p tcp -m tcp --dport 9200 -j ACCEPT
    iptables-save
}

configure_mysql() {
    /etc/init.d/mysql status
	if [ ${?} -eq 0 ];
    then
	   return
	fi
    create_mycnf

    mkdir "${MOUNTPOINT}/mysql"
    ln -s "${MOUNTPOINT}/mysql" /var/lib/mysql
    chmod o+x /var/lib/mysql
    if [ $iscentos -eq 0 ];
    then
        install_mysql_centos
    elif [ $isubuntu -eq 0 ];
    then
        install_mysql_ubuntu
    fi
    /etc/init.d/mysql stop
    chmod o+x "${MOUNTPOINT}/mysql"
    
    grep "mysqlchk" /etc/services >/dev/null 2>&1
    if [ ${?} -ne 0 ];
    then
        sed -i "\$amysqlchk  9200\/tcp  #mysqlchk" /etc/services
    fi
    service xinetd restart

    sstmethod=$(sed -n "s/^wsrep_sst_method=//p" /etc/my.cnf)
    sst=$(sed -n "s/^wsrep_sst_auth=//p" /etc/my.cnf | cut -d'"' -f2)
    declare -a sstauth=(${sst//:/ })
    if [ $sstmethod == "mysqldump" ]; #requires root privilege for sstuser on every node
    then
        /etc/init.d/mysql bootstrap-pxc
        echo "CREATE USER '${sstauth[0]}'@'localhost' IDENTIFIED BY '${sstauth[1]}';" > /tmp/mysqldump-pxc.sql
        echo "GRANT ALL PRIVILEGES ON *.* TO '${sstauth[0]}'@'localhost' with GRANT OPTION;" >> /tmp/mysqldump-pxc.sql
        echo "CREATE USER '${sstauth[0]}'@'%' IDENTIFIED BY '${sstauth[1]}';" >> /tmp/mysqldump-pxc.sql
        echo "GRANT ALL PRIVILEGES ON *.* TO '${sstauth[0]}'@'%' with GRANT OPTION;" >> /tmp/mysqldump-pxc.sql
        echo "FLUSH PRIVILEGES;" >> /tmp/mysqldump-pxc.sql
        mysql < /tmp/mysqldump-pxc.sql
        /etc/init.d/mysql stop
    fi
    /etc/init.d/mysql $MYSQLSTARTUP
    if [ $MYSQLSTARTUP == "bootstrap-pxc" ];
    then
        if [ $sstmethod != "mysqldump" ];
        then
            echo "CREATE USER '${sstauth[0]}'@'localhost' IDENTIFIED BY '${sstauth[1]}';" > /tmp/bootstrap-pxc.sql
            echo "GRANT RELOAD, LOCK TABLES, REPLICATION CLIENT ON *.* TO '${sstauth[0]}'@'localhost';" >> /tmp/bootstrap-pxc.sql
        fi
        echo "CREATE USER 'clustercheckuser'@'localhost' identified by 'clustercheckpassword!';" >> /tmp/bootstrap-pxc.sql
        echo "GRANT PROCESS on *.* to 'clustercheckuser'@'localhost';" >> /tmp/bootstrap-pxc.sql
        echo "CREATE USER 'test'@'%' identified by '${sstauth[1]}';" >> /tmp/bootstrap-pxc.sql
        echo "GRANT select on *.* to 'test'@'%';" >> /tmp/bootstrap-pxc.sql
        echo "FLUSH PRIVILEGES;" >> /tmp/bootstrap-pxc.sql
        mysql < /tmp/bootstrap-pxc.sql
    fi
}

check_os
if [ $iscentos -ne 0 ] && [ $isubuntu -ne 0 ];
then
    echo "unsupported operating system"
    exit 1 
else
    configure_network
    configure_disks
    configure_mysql
fi
