# MTConnect Smart Saw

This is the release repo for all released devices and afg information to implement on the machine IPC.

This is a Repo for the released MTConnect agent and device file for the SmartSaw platform

## Getting started

To get the agent working on the IPC for the first time the github repoistory needs to be cloned.

```bash

git clone --recurse-submodules --progress --depth 1 https://github.com/HEM-Inc/MTConnect_SmartSaw.git mtconnect

```

After cloning the repository for the first time run the install script. This will locate the files into the correct locations.

```bash

sudo bash ssInstall.sh

```

IF the agent has already be loaded then use the update script to update the files and restart the service.

```bash

sudo bash ssUpgrade.sh

```

Edit the `env.sh` file for setting the default install file names on this unique install. These will persist across all updates and installs on that machine. Note use of the parameters will overwrite the file names in the `env.sh` file.

Help syntax for the `ssInstall.sh`.

```bash

Syntax: ssInstall [-h|-a File_Name|-j File_Name|-d File_Name|-c File_Name|-u Serial_number]

options:

-a File_Name        Declare the afg file name; Defaults to - SmartSaw_DC_HA.afg

-j File_Name 	    Declare the json file name; Defaults to - SmartSaw_alarms.json

-d File_Name        Declare the MTConnect agent device file name; Defaults to - SmartSaw_DC_HA.xml

-c File_Name      Declare the Device control config file name; Defaults to - devctl_json_config.json

-u Serial_number    Declare the serial number for the uuid; Defaults to - SmartSaw

-h                  Print this Help.

```

Help syntax for the `ssUpgrade.sh`.

```bash

Syntax: ssUpgrade.sh [-A|-a File_Name|-j File_Name|-d File_Name|-c File_Name|-u Serial_number|-b|-m|-i|-2|-h]

options:

-A                Update the MTConnect Agent, HEMsaw adapter, ODS, MQTT, and Mongodb application

-a File_Name      Declare the afg file name; Defaults to - SmartSaw_DC_HA.afg

-j File_Name      Declare the JSON file name; Defaults to - SmartSaw_alarms.json

-d File_Name      Declare the MTConnect agent device file name; Defaults to - SmartSaw_DC_HA.xml

-c File_Name      Declare the Device control config file name; Defaults to - devctl_json_config.json

-u Serial_number  Declare the serial number for the uuid; Defaults to - SmartSaw

-b                Update the MQTT broker to use the bridge configuration; runs - mosq_bridge.conf

-m                Update the MongoDB database with default materials

-i                ReInit the MongoDB parts and job databases

-2                Use the docker V2 scripts for Ubuntu 24.04 and up base OS

-h                Print this Help.

```

Help syntax for the `ssClean.sh`.

```bash

Syntax: ssClean.sh [-H|-A|-M|-O|-C|-S|-D|-d|-h]

options:

-H                Uninstall the HEMsaw adapter application

-A                Uninstall the MTConnect Agent application

-M                Uninstall the MQTT broker application

-O                Uninstall the HEMsaw ODS application

-C                Uninstall the HEMsaw Devctl application

-S                Uninstall the HEMsaw MongoDB application

-D                Uninstall Docker

-d                Disable mongod, ods, and agent daemons

-h                Print this Help.

```
