#!/bin/bash
apt-get update
wget -qO- https://get.docker.com/ | sh
#Run Docker
docker run --name hello -d -p 8080:8080 preetick/mthello:1.1