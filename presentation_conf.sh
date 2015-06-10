#!/bin/bash
apt-get update
wget -qO- https://get.docker.com/ | sh
#Run Docker
docker run --name webp -d -p 8080:8080 -e BUSINESS_IP=businessvminstance.southeastasia.cloudapp.azure.com preetick/mt_presentation:latest