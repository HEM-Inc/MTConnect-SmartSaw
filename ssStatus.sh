#!/bin/sh

if [[ $(id -u) -ne 0 ]] ; then echo "Please run ssStatus.sh as sudo" ; exit 1 ; fi

systemctl status ods
systemctl status adapter

docker-compose logs --tail=100
