#!/bin/bash
apt-get update
wget -qO- https://get.docker.com/ | sh
#Run Docker
docker run --name webp -d -p 8080:8080 -e BUSINESS_IP=businessvminstance.westus.cloudapp.azure.com nijisha/mt-vehicle-rental-presentaion
