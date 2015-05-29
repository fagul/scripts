#!/bin/bash
apt-get -y update

#Install docker
apt-get -y docker.io
 
source /etc/bash_completion.d/docker.io

#Run Docker
docker run --name hello -d -p 8080:8080 preetick/mthello:1.1