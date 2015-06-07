#!/bin/bash
apt-get update
wget -qO- https://get.docker.com/ | sh
#Run Docker
docker run --name app -d -p 8082:8080 -e DB_IP=dockerjenkinserver.cloudapp.net -e DB_PORT=3306 -e DB_PASSWORD=Welcome@123 -e DB=vehiclerental preetick/vehiclebusiness:1.0