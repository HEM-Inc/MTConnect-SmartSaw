# MTConnect Smart Saw

This is the release repo for all released devices and afg information to implement on the machine IPC.

This is a Repo for the released MTConnect agent and device file for the SmartSaw platform

## Getting started

To get the agent working on the IPC for the first time the github repoistory needs to be cloned. 

``` bash 

git clone --recurse-submodules --progress --depth 1 https://github.com/HEM-Inc/MTConnect_SmartSaw.git mtconnect

```
After cloning the repository for the first time run the install script. This will locate the files into the correct locations.

``` bash

sudo bash ssInstall.sh

```
IF the agent has already be loaded then use the update script to update the files and restart the service. 

``` bash

sudo bash ssUpgrade.sh

```

Help syntax for the `ssInstall.sh`.

``` bash

Syntax: ssInstall [-h|-a File_Name|-d File_Name|-u Serial_number]

options:

-a File_Name        Declare the afg file name; Defaults to - SmartSaw_DC_HA.afg

-d File_Name        Declare the MTConnect agent device file name; Defaults to - SmartSaw_DC_HA.xml

-u Serial_number    Declare the serial number for the uuid; Defaults to - SmartSaw

-h                  Print this Help.

```

Help syntax for the `ssUpgrade.sh`.

``` bash

Syntax: ssUpgrade [-H|-a File_Name|-A|-d File_Name|-u Serial_number|-M|-O|-S|-m|-h]

options:

-H                Update the HEMsaw adapter application

-a File_Name      Declare the afg file name; Defaults to - SmartSaw_DC_HA.afg

-A                Update the MTConnect Agent application

-d File_Name      Declare the MTConnect agent device file name; Defaults to - SmartSaw_DC_HA.xml

-u Serial_number  Declare the serial number for the uuid; Defaults to - SmartSaw

-M                Update the mosquitto broker application

-O                Update the HEMsaw ODS application

-S                Update the HEMsaw MongoDB application

-m                Update the mongodb database to have default materials

-h                Print this Help.

```

Help syntax for the `ssClean.sh`.

``` bash

Syntax: ssUninstall.sh [-H|-A|-M|-O|-S|-D|-h]

options:

-H                Uninstall the HEMsaw adapter application

-A                Uninstall the MTConnect Agent application

-M                Uninstall the Mosquitto broker application

-O                Uninstall the HEMsaw ODS application

-S                Uninstall the HEMsaw MongoDB application

-D                Uninstall Docker

-h                Print this Help.

```
