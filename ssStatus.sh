#!/bin/sh

if [[ $(id -u) -ne 0 ]] ; then echo "Please run bash ssStatus.sh as sudo" ; exit 1 ; fi

echo "ODS Status..."
systemctl status ods
echo "<<DONE>>"
echo

echo "Adapter Status..."
systemctl status adapter
echo "<<DONE>>"
echo

echo "Docker container status for Agent, Mosquitto, and Watchtower..."
docker-compose ps
echo "<<DONE>>"
