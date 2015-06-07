#!/bin/bash

# This script is only tested on CentOS 6.5 and Ubuntu 12.04 LTS with Percona XtraDB Cluster 5.6.
# You can customize variables such as MOUNTPOINT, RAIDCHUNKSIZE and so on to your needs.
# You can also customize it to work with other Linux flavours and versions.
# If you customize it, copy it to either Azure blob storage or Github so that Azure
# custom script Linux VM extension can access it, and specify its location in the 
# parameters of DeployPXC powershell script or runbook or Azure Resource Manager CRP template.   

CLUSTERADDRESS=${1}
NODEADDRESS=${2}
NODENAME=$(hostname)
MYSQLSTARTUP=${3}
MYCNFTEMPLATE=${4}
SECONDNIC=${5}

MOUNTPOINT="/datadrive"
RAIDCHUNKSIZE=512

RAIDDISK="/dev/md127"
RAIDPARTITION="/dev/md127p1"
# An set of disks to ignore from partitioning and formatting
BLACKLIST="/dev/sda|/dev/sdb"

check_os() {
    grep ubuntu /proc/version > /dev/null 2>&1
    isubuntu=${?}
    grep centos /proc/version > /dev/null 2>&1
    iscentos=${?}
}





open_ports() {
    iptables -A INPUT -p tcp -m tcp --dport 3306 -j ACCEPT
    iptables -A INPUT -p tcp -m tcp --dport 4444 -j ACCEPT
    iptables -A INPUT -p tcp -m tcp --dport 4567 -j ACCEPT
    iptables -A INPUT -p tcp -m tcp --dport 4568 -j ACCEPT
    iptables -A INPUT -p tcp -m tcp --dport 9200 -j ACCEPT
    iptables-save
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

install_mysql_ubuntu() {
    dpkg -s percona-xtradb-cluster-56
    if [ ${?} -eq 0 ];
    then
        return
    fi
    echo "installing mysql"
    apt-key adv --keyserver keys.gnupg.net --recv-keys 1C4CBDCDCD2EFD2A
    grep "repo.percona.com" /etc/apt/sources.list >/dev/null 2>&1
    if [ ${?} -ne 0 ];
    then
        echo "deb http://repo.percona.com/apt precise main" >> /etc/apt/sources.list
        echo "deb-src http://repo.percona.com/apt precise main" >> /etc/apt/sources.list
    fi
    apt-get update
    export DEBIAN_FRONTEND=noninteractive
    apt-get -q -y install percona-xtradb-cluster-56
    apt-get -y install xinetd
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

allow_passwordssh() {
	grep -q '^PasswordAuthentication yes' /etc/ssh/sshd_config
    if [ ${?} -eq 0 ];
    then
		return
	fi
    sed -i "s/^#PasswordAuthentication.*/PasswordAuthentication yes/I" /etc/ssh/sshd_config
    sed -i "s/^PasswordAuthentication no.*/PasswordAuthentication yes/I" /etc/ssh/sshd_config
	/etc/init.d/sshd reload
}

# temporary workaround form CRP 
allow_passwordssh  

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
