#!/bin/bash
apt-get -y update

#Run Docker
docker run --name hello -d -p 8080:8080 preetick/mthello:1.1