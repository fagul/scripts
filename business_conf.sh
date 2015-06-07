#!/bin/bash
apt-get update
wget -qO- https://get.docker.com/ | sh
#Run Docker
docker run --name vapp -d -p 8080:8080 -e DB_IP=dockerjenkinserver.cloudapp.net -e DB_PASSWORD=root -e DB_PORT=3306 -e DB=VehicleRental preetick/business:2.1.4