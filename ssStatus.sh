#!/bin/sh

if [[ $(id -u) -ne 0 ]] ; then echo "Please run bash ssStatus.sh as sudo" ; exit 1 ; fi

echo "Docker container status for HEMSaw MTConnect-SmartAdapter, MTConnect Agent, Mosquitto, ODS, Mongodb and Watchtower..."
docker-compose ps
echo "<<DONE>>"
