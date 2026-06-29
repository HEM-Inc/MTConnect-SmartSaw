#!/bin/bash

SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/lib.sh" || { echo "ERROR: lib.sh not found at $SCRIPT_DIR/lib.sh"; exit 1; }
detect_container_runtime

if [[ $(id -u) -ne 0 ]] ; then echo "Please run bash ssStatus.sh as sudo" ; exit 1 ; fi

echo "Container status for HEMSaw MTConnect-SmartAdapter, MTConnect Agent, Mosquitto, ODS, Devctl, Mongodb and Watchtower..."
$CONTAINER_RUNTIME ps
echo "<<DONE>>"
