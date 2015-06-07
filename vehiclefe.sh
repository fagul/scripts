#!/bin/bash
apt-get update
wget -qO- https://get.docker.com/ | sh
#Run Docker
docker run --name webp -d -p 8083:8080 -e BUSINESS_IP=dockerjenkinserver.cloudapp.net preetick/mt_presentation:1.0
