# SmartSaw Upgrade and Docker Compose 

# Functional Specification Document
#### Rev 0.1

## Table of Contents
* [List of Tables](#list-of-tables)
* [Revision](#revision)
* [Definition/Abbreviation](#definitionabbreviation)
	* [Table 1: Abbreviations](#table-1-abbreviations)
* [Feature Overview](#1-feature-overview)
	* [Requirements](#11-requirements)
		* [Functional Requirements](#111-functional-requirements)
		* [Configuration and Management Requirements](#112-configuration-and-management-requirements)
		* [Scalability Requirements](#113-scalability-requirements)
		* [Restart Requirements](#114-restart-requirements)
		* [Error Handling](#115-error-handling)
* [Functionality](#2-functionality)
	* [Functional Description](#21-functional-description)
* [Design](#3-design)
	* [Overview](#31-overview)
	* [DB Changes](#32-db-changes)
* [Flow Diagrams](#4-flow-diagrams)
* [Serviceability and Debug](#5-serviceability-and-debug)
* [Restart Support](#6-restart-support)
* [Upgrade](#7-upgrade)
* [Restrictions/Limitations](#8-restrictionslimitations)
* [Test plan](#9-test-plan)
	* [Test cases](#91-test-cases)
	* [Integration test cases](#92-integration-test-cases)

### List of Tables
[Table 1: Abbreviations](#table-1-abbreviations)

### Revision
| Rev |     Date    |       Author                | Change Description                |
|:---:|:-----------:|:-------------------------:|:-----------------------------------:|
| 0.1 |  03/27/2024           |      Prarthana and Adithya     |    Initial version  |


### Definition/Abbreviation
#### Table 1: Abbreviations
| 	**Term**			   |         **Meaning**                 |
|--------------------------|-------------------------------------|
| ODS                      | Object Database Server              |                      |
| IPC | Industrial PC |
| MQTT|  Message Queuing Telemetry Transport|
|YAML|Yet another markup language|
|PLC|Programmable Logic Controller|
|HMI|Human Machine Interface|
|ssUpgrade| SmartSaw Upgrade|
|ssInstall| SmartSaw Install|
|ssClean| SmartSaw Clean|
|ssStatus| SmartSaw Status|

## **1. Feature Overview**

Docker Compose is a tool for defining and running multi-container Docker applications. It allows you to use a YAML file to configure your application's services, networks, and volumes, and then run and manage them with a single command.

SmartSaw MTConnect Agent, MTConnect-SmartAdapter ,MQTT broker and ODS can be run as Docker service.

ssUpgrade script can be used to start ODS, MTConnect-SmartAdapter, Agent
and MQTT broker. By this way, ssUpgrade can automate SmartSaw software docker services ODS, MTConnect-SmartAdapter, Agent and MQTT service bring up.

HEMSaw MTConnect_SmartSaw repo maintains ssUpgrade and related Docker-Compose tools.  

This feature introduces the ability to add dockerized ODS and MTConnect-SmartAdapter containers within the docker-compose.yml file. Additionally, scripts such as ssInstall.sh, ssUpgrade.sh, ssClean.sh, and ssStatus.sh will be updated to maintain the HEMSaw software. 

### **1.1 Requirements**
#### 1.1.1 Functional Requirements
1. *Docker Compose*:
   Docker compose utility shall be updated to include MTConnect-SmartAdapter and ODS software.
2. *ssUpgrade*:
   Script shall be updated to incorporate ODS and MTConnect-SmartAdapter configuration files.Additionally,script option -O shall be added to selectively update ODS component. 
 
3. *ssInstall*:
Script shall be updated to install ODS and MTConnect-SmartAdapter software.
4. *ssCleanup*:
Script shall be updated to uninstall ODS and MTConnect-SmartAdapter software.

5. *ssStatus*:
 Script shall be updated to display the status of docker compose for ODS and MTConnect-SmartAdapter.

#### 1.1.2  Configuration and Management Requirements
1. ODS Configuration files required for docker compose shall be newly created.

2. Existing adapter configurations shall be used for docker compose of MTConnect-SmartAdapter.

#### 1.1.3 Scalability Requirements
Not applicable

#### 1.1.4 Restart Requirements
Any Modification in configuration files related to ODS, MTConnect-SmartAdapter, MQTT and MTConnect Agent shall come into effect only upon ssUpgrade with required restart option.
Restart options for Adapter and ODS shall be -H and -O respectively.

#### 1.1.5 Error Handling
Not Applicable

## **2. Functionality**
### **2.1. Functional Description**
 
Docker Compose Script orchestartes the docker start trigger for all user specified dockers.Watchtower is a tool for automatically updating docker containers with the latest available images. 

ssUpgrade is a bash script designed for the HEMSaw software. It installs and manages Docker compose, updates key components such as  MTConnect Agent, MQTT Broker, MTConnect-SmartAdapter and ODS. Users can easily customize settings, and the script ensures smooth operation by verifying permissions and simplifies system maintenance.

ssInstall is a bash script automating the task of installing the MTConnect-Agent, MTConnect-SmartAdapter, MQTT and ODS. 

ssClean is a bash script which automates the task of uninstalling components such as MTConnect-Agent,  MTConnect-SmartAdapter, MQTT, ODS and cleans the locally stored docker images.

ssStatus is a bash script which provides the status of the docker compose of the each component such as MTConnect Agent,MTConnect-SmartAdapter, MQTT and ODS.


## **3. Design**
### **3.1. Overview**
### **3.1.1 Docker-Compose** :
Following Docker-Compose.yml file attributes needs to be updated for ODS and MTConnect-SmartAdapter. 
    
 - container_name: This attribute sets the hostname for the container which will be 'ods' or 'smartsaw_adapter' for ODS and MTConnect-SmartAdapter respectively.
 - hostname: This abbtribute sets the hostname for the container. 'ods' or 'smartsaw_adapter'
 - image: ODS or MTConnect-SmartAdpater image name is to be used.
 - user: This specifies the user to run processes inside the container. 'ods' or 'adapter' as specified in respective Dockerfile. 
 - labels: Adds a label to enable automatic updates using Watchtower.
 - volumes: Mounts the  directory on the host to the directory inside the container.
 - logging: Configures logging for the container with a JSON file driver and limits log file size to 10 MB with a maximum of 3 log files.
 - ports: This attribute will map port on the host to port/tcp inside the container for communication. Port number 9800 will be used for MTConnect-SmartAdapter. There is no port mapping for ODS
 - network_mode: Sets the host's network for ODS and MongoDB. 
 - working_dir: '/ods or /adapter sets the working directory inside the container for ODS and MTConnect-SmartAdapter respectively.
 - restart: Specifies the container to restart automatically unless explicitly stopped.
    
### **3.1.2 ssInstall script**
 It is required to run ssInstall script for the first time while setting up SmartSaw software in IPC.

 ssInstall will be modified to install Dockerized ODS and MTConnect-SmartAdapter.
 This action will copy all the configuration files required for ODS and MTConnect-SmartAdapter into etc corresponding directories.

   ```
     sudo bash ssInstall.sh [-h|-a File_Name|-d File_Name|-u Serial_number]
   ```
   ``` 
     options:
     -a File_Name        Declare the afg file name; Defaults to - SmartSaw_DC_HA.afg
     -d File_Name        Declare the MTConnect agent device file name; Defaults to - SmartSaw_DC_HA.xml
     -u Serial_number    Declare the serial number for the uuid; Defaults to - SmartSaw
     -h                  Print this Help.
   ```

### **3.1.3 ssUpgrade Script**
ssUpgrade script will be modified to include additional option '-O' for ODS specific upgrade. When '-O' option is used, only ODS docker will be updated and other dockers will not be updated unless until specified.
This script already contains -H option for upgrading MTConnect-SmartAdapter. Same will be used to update the MTConnect-SmartAdapter Docker.

ssUpgrade command syntax will be as below after adding new option '-O'.

   ```
   sudo bash ssUpgrade.sh [-H|-a File_Name|-A|-d File_Name|-u Serial_number|-M|-O|-h]
   ```
   ``` 
      options:
      -H                Update the HEMsaw Adapter application
      -a File_Name      Declare the afg file name; Defaults to - SmartSaw_DC_HA.afg
      -A                Update the MTConnect Agent application
      -d File_Name      Declare the MTConnect agent device file name; Defaults to - SmartSaw_DC_HA.xml
      -u Serial_number  Declare the serial number for the uuid; Defaults to - SmartSaw
      -M                Update the mosquitto broker application
      -O                Update the HEMsaw ODS application
      -h                Print this Help.
   ```

### **3.1.4 ssClean Script**
ssClean script will be modified to include addtional option '-O' for ODS specific clean. When '-O' option is used only ODS configurations within etc will be removed. 
This script already contains -H option for removing adapter configurations within etc. 

ssClean command syntax will be as below after adding new option '-O'.


   ```
    sudo bash ssClean.sh [-H|-A|-M|-O|-D|-h]
   ```
   ```
    options:
    -H                Uninstall the HEMsaw adapter application
    -A                Uninstall the MTConnect Agent application
    -M                Uninstall the Mosquitto broker application
    -O				   Uninstall the HEMsaw ODS application
    -D                Uninstall Docker
    -h                Print this Help.

   ```

In addition to feature enhancement, ssClean script deletes MTConnect Agent service file, mosquitto and mosquitto-clients software. This is no longer required as Agent and Mosquitto are dockerized. 

### **3.1.5 ssStatus Script**
- To display the status of the MTConnect Agent, MTConnect-SmartAdapter, MQTT broker and ODS inside Docker compose container.
   ```
   sudo bash ssStatus.sh
   ```
   At present this status script shows ODS and Adapter status with systemd. This status retreivel is no more required as ODS and MTConnect-SmartAdapter is dockerized as part of this feature.
### **3.1.6 Docker-Compose Logs**
- Below command will be used to list the logs generated during docker compose activity.

   ```
   docker-compose logs [<container_name>]
   ```

### **3.1.7 ODS Configurations**
ODS configurations such as odscfg.yml and db_object_definitions.json are being added to MTConnect-SmartSaw within ods directory inorder to run the Dockerised ODS container.
### **3.2. DB Changes**
This feature does not involve any  DB Changes.

## **4. Flow Diagrams**
Not Applicable

## **5. Serviceability and Debug**
Not applicable

## **6. Restart Support**
Changes to the configuration files related to ODS, MTConnect-SmartAdapter, MQTT broker, and MTConnect Agent will take effect exclusively through ssUpgrade along with the necessary restart option.

The restart options for MTConnect-SmartAdapter and ODS will be -H and -O, respectively.

## **7. Upgrade**
HEMSaw utilizes ssUpgrade script to restart MTConnect Agent, MTConnect-SmartAdapter, MQTT broker and ODS.
## **8. Restrictions/Limitations**
Not Applicable 

## **9. Test plan**

### **9.1 Test cases**
| Test Case   ID |                        Test Case   Description                       |                     Expected Result                     | Status | Comments |
|:--------------:|--------------------------------------------------------------------|-------------------------------------------------------|:------:|:--------:|
| 1| Verify ssInstall script for installation of all components | Installs all the docker components| | |
| 2 | Verify ssInstall script with -a \<afg_file>  | Installs adapter component with specified afg file| | |
| 3 | Verify ssInstall script with -d \<device_file>| Installs Agent component with specified Device XML file| | |
| 4 | Verify ssInstall script with -u \<UUID> |Declares the specified serial number for uuid within Agent device xml file | | |
|5|  Verify ssInstall script with -h option  | Displays Help options| | |
| 6|Verify ssInstall script with invalid options |Displays the valid options for ssInstall | | Negative testcase
|        7       | Verify ssUpgrade script                                            |Successful execution of all docker components. |        |          |
|        8       | Verify ssUpgrade script with -H option                                            | Docker compose runs with updated Adapter configuration files                    |        |          |
|        9       | Verify ssUpgrade script without -H option when adapter configurations are modified | Docker compose runs with previous adapter configurations               |        |          |
| 10|Verify ssUpgrade script with -H -a \<afg_file> option |Successful execution with the specified afg file for adapter | | |
|       11     | Verify ssUpgrade script with -a \<afg_file>                                            |Docker compose runs with previous afg file for Adapter           |        |          |
|        12       | Verify ssUpgrade script with -A option                                             | Successful execution with Agent updated files                      |        |          |
|        13       | Verify ssUpgrade script without -A option when agent configurations are modified   | Docker compose runs with previous agent configurations| | |
|14                 |Verify for the change in values of different data items in REST API        |Verified for functionalmode and saw_controller_mode dataItem.          |
|       15      | Verify ssUpgrade script with -d \<device_file>                                             | Docker compose runs with previous device file for Agent             |        |          |
|16|Verify ssUpgrade script with -A -d \<device_file>| Successful execution with specified device file for agent
|       17       | Verify ssUpgrade script with -A -u \<UUID>                                             | Updates Agent device xml file with specified serial number           |        |          |
|       18       | Verify ssUpgrade script with -u \<UUID>                                             | Agent device file will not be updated with specified serial number number           |        |          |
|        19      | Verify ssUpgrade script with -O option                                            |Successful execution with ods updated files                  |        |          |
|        20      | Verify ssUpgrade script without -O option when ODS configurations are modified     |Docker compose runs with previous ods configurations | | |
|        21      | Verify ssUpgrade script with -M option                                             |Successful execution with Mosqitto updated files                        |        |          |
|        22      | Verify ssUpgrade script without -M option when mqtt configurations are modified    |Docker compose runs with previous mqtt configurations                  |        |          |
|       23      | Verify ssUpgrade script with -h option                                             | Displays Help options                                    |        |          |
| 24|Verify ssUpgrade script with invalid options |Displays the valid options for ssUpgrade script | | Negative testcase|
|       25       | Verify ssClean script with -H option                                              | Deletes adapter configurations from etc                                |        |          |
|       26       | Verify ssClean script with -A option                                               | Deletes Agent configurations from etc                                  |        |          |
|       27       | Verify ssClean script with -D option                                               | Shutting down all existing Docker containers                                       |        |          |
|       28       | Verify ssClean script with -O option                                               | Deletes ODS configurations from etc                                    |        |          |
|       29       | Verify ssClean script with -M option                                               | Deletes MQTT configurations from etc                                    |        |          |
| 30|Verify ssClean script with invalid options |Displays the valid options in ssClean | |Negative testcase|
|       31       | Verify ssStatus script                                                      |  Provides the status of each container                     |        |          |
|32|Verify Docker Compose logs for ODS|Displays ODS-specific logs based on provided severity in yml file| | 
|33|Verify Docker Compose logs for Adapter|Displays Adapter-specific logs based on provided severity in afg file| |
|34|Verify Docker Compose logs for MQTT broker|Displays MQTT broker-specific logs| |
|35|Verify Docker Compose logs for Agent|Displays Agent-specific logs based on provided severity in cfg file| |  

### **9.2 Integration test cases**
| Test Case ID |                  Test Case Description                 |                    Expected Result                    | Status | Comments |
|:------------:|------------------------------------------------------|-----------------------------------------------------|:------:|:--------:|
|1| verify ssUpgrade script with -u \<UUID> '-A'and '-H' options |Successful execution with changed UUID in agent device file and  latest adapter configuration file | | |
|2| verify ssUpgrade script with -d  \<device_file>  '-A'and '-O' options |Successful execution with changed device file for agent and  latest ODS configuration file | | |
|3|Verify ssUpgrade script with '-H' -a \<afg_file> and '-A' options|Successful execution with specified afg file for adapter and updated configuration for agent.| | |
|4| verify ssUpgrade script with '-A' '-H' '-M' '-O' options |Successful execution with latest configuration files | | | 
|       5      | Verify the connection between PLC and adapter in IPC   | Successful connection between PLC and adapter         |        |          |
|       6      | Verify the connection between adapter and agent in IPC | Successful sending of data to agent                   |        |          |
| 7 | Verify the connection between Agent and Mosquitto | Data sent from agent to MQTT on topic 'mtconnect/'| | |
|       8      | Verify the connection between PLC and ODS in IPC       | Successful connection between PLC and ODS             |       |          |
|       9      | Verify the connection between ODS and MongoDB in IPC   | Successfully able to access job and material from HMI |        |          |





