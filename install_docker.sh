#!/bin/bash
apt-get update
apt-get -y install docker
#Run Docker
docker run --name hello -d -p 8080:8080 preetick/mthello:1.1