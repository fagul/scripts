#!/bin/bash
apt-get update
wget -qO- https://get.docker.com/ | sh
#Run Docker
docker run --name dbmysql -d -p 3306:3306 -v /data/mysql:/var/lib/mysql preetick/dbimage:v1