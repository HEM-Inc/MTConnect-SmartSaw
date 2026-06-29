#!/bin/sh

echo 'Loading the default files...'
# Optional: pin the container runtime to "podman" or "docker".
# Leave unset to auto-detect (Podman preferred when both are present).
# export CONTAINER_RUNTIME=""
export Afg_File="SmartSaw_DC_HA.afg"
export Json_File="SmartSaw_alarms.json"
export Device_File="SmartSaw_DC_HA.xml"
export Serial_Number="SmartSaw"
export DevCTL_File="devctl_json_config.json"
export Use_MQTT_Bridge="false"
echo 'Done'
echo ' '
