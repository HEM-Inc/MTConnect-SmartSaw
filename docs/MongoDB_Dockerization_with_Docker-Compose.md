# MongoDB Dockerization with Docker Compose 

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
| 0.1 |  04/29/2024           |       Adithya     |    Initial version  |



### Definition/Abbreviation
#### Table 1: Abbreviations
| 	**Term**			   |         **Meaning**                 |
|--------------------------|-------------------------------------|
| ODS                      | Object Database Server              |                      |
| IPC | Industrial PC |
|PLC|Programmable Logic Controller|
|HMI|Human Machine Interface|
|ssUpgrade| SmartSaw Upgrade|
|ssInstall| SmartSaw Install|
|ssClean| SmartSaw Clean|
|ssStatus| SmartSaw Status|

## **1. Feature Overview**

Docker Compose is a tool for defining and running multi-container Docker applications. It allows you to use a YAML file to configure your application's services, networks, and volumes, and then run and manage them with a single command.

SmartSaw MTConnect Agent, MTConnect-SmartAdapter ,MQTT broker, ODS and MongoDB can be run as Docker service.

ssUpgrade script can be used to start MongoDB, ODS, MTConnect-SmartAdapter, Agent
and MQTT broker. By this way, ssUpgrade can automate SmartSaw software docker services MongoDB, ODS, MTConnect-SmartAdapter, Agent and MQTT service bring up.

HEMSaw MTConnect_SmartSaw repo maintains ssUpgrade and related Docker-Compose tools.  

This feature introduces the ability to add dockerized MongoDB containers within the docker-compose.yml file. Additionally, scripts such as ssInstall.sh, ssUpgrade.sh, ssClean.sh, and ssStatus.sh will be updated to maintain the HEMSaw software. 

### **1.1 Requirements**
#### 1.1.1 Functional Requirements
1. *Docker Compose*:
   Docker compose utility shall be updated to include MongoDB service.
2. *ssUpgrade*:
   Script shall be updated to incorporate MongoDB configuration files.Additionally,script option -S shall be added to selectively update MongoDB component. 
 
3. *ssInstall*:
Script shall be updated to install MongoDB software.
4. *ssCleanup*:
Script shall be updated to uninstall MongoDB software.

5. *ssStatus*:
 Script shall be updated to display the status of docker compose for MongoDB.

#### 1.1.2  Configuration and Management Requirements
1. MongoDB Configuration files required for docker compose shall be newly created.
2. ODS configuration file, odscfg.yml it is required to set 'mongodb_host' to 'mongodb' and 'mongodb_port' to '27017' for connecting to MongoDB.

#### 1.1.3 Scalability Requirements
Not applicable

#### 1.1.4 Restart Requirements
Any Modification in configuration files related to MongoDB, ODS, MTConnect-SmartAdapter, MQTT and MTConnect Agent shall come into effect only upon ssUpgrade with required restart option.
Restart options for MongoDB shall be -S respectively.


#### 1.1.5 Error Handling
Not Applicable

## **2. Functionality**
### **2.1. Functional Description**
 
Docker Compose Script orchestartes the docker start trigger for all user specified dockers.Watchtower is a tool for automatically updating docker containers with the latest available images. 

ssUpgrade is a bash script designed for the HEMSaw software. It installs and manages Docker compose, updates key components such as  MTConnect Agent, MQTT Broker, MTConnect-SmartAdapter, ODS and MongoDB. Users can easily customize settings, and the script ensures smooth operation by verifying permissions and simplifies system maintenance.

ssInstall is a bash script automating the task of installing the MTConnect-Agent, MTConnect-SmartAdapter, MQTT, ODS and MongoDB. 

ssClean is a bash script which automates the task of uninstalling components such as MTConnect-Agent,  MTConnect-SmartAdapter, MQTT, ODS, MongoDB and cleans the locally stored docker images.

ssStatus is a bash script which provides the status of the docker compose of the each component such as MTConnect Agent,MTConnect-SmartAdapter, MQTT, ODS and MongoDB.


## **3. Design**
### **3.1. Overview**
### **3.1.1 Docker-Compose** :
Following Docker-Compose.yml file attributes needs to be updated for MongoDB. 
    
 - container_name: This attribute sets the hostname for the container which will be 'mongodb' respectively.
 - hostname: This abbtribute sets the hostname for the container. 'mongodb'
 - image: mongo:4.4 image is pulled from the official MongoDB Docker Hub repository. 
 - labels: Adds a label to enable automatic updates using Watchtower.
 - volumes: Mounts the  directory on the host to the directory inside the container.Persistant Mongodb data is stored in etc/mongodb_data/
 - logging: Configures logging for the container with a JSON file driver and limits log file size to 10 MB with a maximum of 3 log files.
 - ports: This attribute will map port on the host to port/tcp inside the container for communication. Port number 27017 will be used for Mongodb.
 - restart: Specifies the container to restart automatically unless explicitly stopped.

 In the updated ODS compose attributes, the usage of 'network_mode':'host' has been removed, and instead, port mapping for '9625' is implemented to facilitate ODS connection Additionally, the 'depends_on' field has been included to specify the dependency on MongoDB.

 Note: MongoDB image version 4.4 is chosen due to limitations with the IPC not supporting the CPU AVX instruction set which is a requirement for the MongoDB versions released after 5.0.
    
### **3.1.2 ssInstall script**
 It is required to run ssInstall script for the first time while setting up SmartSaw software in IPC.

 ssInstall will be modified to install Dockerized MongoDB.
 This action will copy all the configuration files required for MongoDB into etc corresponding directories.

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
ssUpgrade script will be modified to include additional option '-S' for MongoDB specific upgrade. When '-S' option is used, only MongoDB docker will be updated and other dockers will not be updated unless until specified.

ssUpgrade command syntax will be as below after adding new option '-S'.

   ```
   sudo bash ssUpgrade.sh [-H|-a File_Name|-A|-d File_Name|-u Serial_number|-M|-O|-S|-m|-h]
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
      -S                Update the HEMsaw MongoDB application
      -m                Update the MongoDB database with default materials
      -h                Print this Help.
   ```

### **3.1.4 ssClean Script**
ssClean script will be modified to include addtional option '-S' for MongoDB specific clean. When '-S' option is used only MongoDB configurations within etc will be removed.  

ssClean command syntax will be as below after adding new option '-S'.


   ```
    sudo bash ssClean.sh [-H|-A|-M|-O|-S|-D|-h]
   ```
   ```
    options:
    -H                Uninstall the HEMsaw adapter application
    -A                Uninstall the MTConnect Agent application
    -M                Uninstall the Mosquitto broker application
    -O                Uninstall the HEMsaw ODS application
    -S                Uninstall the HEMsaw MongoDB application 
    -D                Uninstall Docker
    -h                Print this Help.

   ```
 

### **3.1.5 ssStatus Script**
- To display the status of the MTConnect Agent, MTConnect-SmartAdapter, MQTT broker,ODS and MongoDB inside Docker compose container.
   ```
   sudo bash ssStatus.sh
   ```
   
### **3.1.6 Docker-Compose Logs**
- Below command will be used to list the logs generated during docker compose activity.

   ```
   docker-compose logs [<container_name>]
   ```

### **3.1.7 MongoDB Configurations**
MongoDB configurations such as mongod.conf.orig are being added to MTConnect-SmartSaw within mongodb/config directory inorder to run the Dockerised MongoDB container.

### **3.1.8 Interaction with MongoDB**
- Docker Command Line Access:
   - below command will be used to access the MongoDB shell within the Docker container.

     ```
     docker exec -it mongodb bash 
     ```
- Direct MongoDB Shell Access:
   - Once inside the Docker container, execute the **mongo** command to access the MongoDB command line interface.

- Note: When adding data to MongoDB using scripts, ensure to use "mongodb" as the hostname instead of "localhost" to establish the connection with Dockerized MongoDB.
### **3.2. DB Changes**
No direct database changes are required, as MongoDB instances are deployed as containers and use persistent volumes for data storage.

## **4. Flow Diagrams**
Not Applicable

## **5. Serviceability and Debug**
Serviceability includes options for logging MongoDB containers using tools like Docker-compose logs.

## **6. Restart Support**
Changes to the configuration files related to Mongodb, ODS, MTConnect-SmartAdapter, MQTT broker, and MTConnect Agent will take effect exclusively through ssUpgrade along with the necessary restart option.

The restart options for MongoDB will be -S, respectively.

## **7. Upgrade**
HEMSaw utilizes ssUpgrade script to restart MTConnect Agent, MTConnect-SmartAdapter, MQTT broker, ODS and MongoDB.
## **8. Restrictions/Limitations**
Not Applicable 

## **9. Test plan**

### **9.1 Test cases**
| Test Case   ID |                        Test Case   Description                       |                     Expected Result                     | Status | Comments |
|:--------------:|--------------------------------------------------------------------|-------------------------------------------------------|:------:|:--------:|
| 1| Verify ssInstall script for installation of all components | Installs all the docker components|PASS | |
| 2 | Verify ssInstall script with -a \<afg_file>  | Installs adapter component with specified afg file| PASS| |
| 3 | Verify ssInstall script with -d \<device_file>| Installs Agent component with specified Device XML file| PASS| |
| 4 | Verify ssInstall script with -u \<UUID> |Declares the specified serial number for uuid within Agent device xml file |PASS| |
|5|  Verify ssInstall script with -h option  | Displays Help options|PASS | |
| 6|Verify ssInstall script with invalid options |Displays the valid options for ssInstall |PASS | Negative testcase
|        7       | Verify ssUpgrade script                                            |Successful execution of all docker components. |  PASS   |          |
|        8       | Verify ssUpgrade script with -H option                                            | Docker compose runs with updated Adapter configuration files                    |  PASS      |          |
|        9       | Verify ssUpgrade script without -H option when adapter configurations are modified | Docker compose runs with previous adapter configurations               |   PASS     |          |
| 10|Verify ssUpgrade script with -H -a \<afg_file> option |Successful execution with the specified afg file for adapter |PASS  | |
|       11     | Verify ssUpgrade script with -a \<afg_file>                                            |Docker compose runs with previous afg file for Adapter           |  PASS      |          |
|        12       | Verify ssUpgrade script with -A option                                             | Successful execution with Agent updated files                      | PASS      |          |
|        13       | Verify ssUpgrade script without -A option when agent configurations are modified   | Docker compose runs with previous agent configurations| PASS | |
|14                 |Verify for the change in values of different data items in REST API        |Verified for functionalmode and saw_controller_mode dataItem.          |PASS||
|       15      | Verify ssUpgrade script with -d \<device_file>                                             | Docker compose runs with previous device file for Agent             |  PASS      |          |
|16|Verify ssUpgrade script with -A -d \<device_file>| Successful execution with specified device file for agent|PASS| |
|       17       | Verify ssUpgrade script with -A -u \<UUID>                                             | Updates Agent device xml file with specified serial number           |  PASS      |          |
|       18       | Verify ssUpgrade script with -u \<UUID>                                             | Agent device file will not be updated with specified serial number number           |  PASS     |          |
|        19      | Verify ssUpgrade script with -O option                                            |Successful execution with ods updated files                  |  PASS      |          |
|        20      | Verify ssUpgrade script without -O option when ODS configurations are modified     |Docker compose runs with previous ods configurations |PASS | |
|        21     | Verify ssUpgrade script with -S option                                            |Successful execution with Mongodb updated files                  |PASS        |          |
|        22      | Verify ssUpgrade script without -S option when Mongodb configurations are modified     |Docker compose runs with previous Mongodb configurations | PASS| |
|        23      | Verify ssUpgrade script with -M option                                             |Successful execution with Mosqitto updated files                        |   PASS     |          |
|        24      | Verify ssUpgrade script without -M option when mqtt configurations are modified    |Docker compose runs with previous mqtt configurations                  | PASS       |          |
|       25     | Verify ssUpgrade script with -h option                                             | Displays Help options                                    |  PASS      |          |
| 26|Verify ssUpgrade script with invalid options |Displays the valid options for ssUpgrade script |PASS  | Negative testcase|
|       27       | Verify ssClean script with -H option                                              | Deletes adapter configurations from etc                                |   PASS     |          |
|       28       | Verify ssClean script with -A option                                               | Deletes Agent configurations from etc                                  |  PASS      |          |
|       29       | Verify ssClean script with -D option                                               | Shutting down all existing Docker containers                                       | PASS       |         |
|       30       | Verify ssClean script with -O option                                               | Deletes ODS configurations from etc                                    |PASS        |          |
|       31       | Verify ssClean script with -M option                                               | Deletes MQTT configurations from etc                                    |   PASS     |          |
|       32       | Verify ssClean script with -S option                                               | Deletes Mongodb configurations from etc                                    | PASS       |          |
| 33|Verify ssClean script with invalid options |Displays the valid options in ssClean |PASS|Negative testcase|
|34|Verify data persists across MongoDB container restarts.| Ensure changes are retained after container restarts|PASS | |
|       35       | Verify ssStatus script                                                      |  Provides the status of each container                     |  PASS      |          |
|36|Verify Docker Compose logs for Mongodb|Displays Mongodb-specific logs |PASS | 
|37|Verify Docker Compose logs for ODS|Displays ODS-specific logs based on provided severity in yml file|PASS | 
|38|Verify Docker Compose logs for Adapter|Displays Adapter-specific logs based on provided severity in afg file|PASS |
|39|Verify Docker Compose logs for MQTT broker|Displays MQTT broker-specific logs|PASS | |
|40|Verify Docker Compose logs for Agent|Displays Agent-specific logs based on provided severity in cfg file|PASS |  

### **9.2 Integration test cases**
| Test Case ID |                  Test Case Description                 |                    Expected Result                    | Status | Comments |
|:------------:|------------------------------------------------------|-----------------------------------------------------|:------:|:--------:|
|1| verify ssUpgrade script with -u \<UUID> '-A'and '-H' options |Successful execution with changed UUID in agent device file and  latest adapter configuration file |PASS| |
|2| verify ssUpgrade script with -d  \<device_file>  '-A'and '-S' options |Successful execution with changed device file for agent and  latest MongoDB configuration file |PASS  | |
|3|Verify ssUpgrade script with '-H' -a \<afg_file> and '-A' options|Successful execution with specified afg file for adapter and updated configuration for agent.|PASS | |
|4| verify ssUpgrade script with '-A' '-H' '-M' '-O' '-S' options |Successful execution with latest configuration files | PASS| | 
|5|Verify Mongodb Connection with invalid Host name and IP Address in ODS configuration | unsuccessful connection between ODS and Mongodb|PASS | |  
|6|Verify Adding Jobs in HMI|Successful appending jobs in MongoDB|PASS | |
|7|Verify deleting Jobs in HMI| Successful deleting jobs in MongoDB|PASS | | 
|       8     | Verify the connection between adapter and agent in IPC | Successful sending of data to agent                   |  PASS      |          |
| 9 | Verify the connection between Agent and Mosquitto | Data sent from agent to MQTT on topic 'mtconnect/'|PASS | |
|       10      | Verify the connection between PLC and ODS in IPC       | Successful connection between PLC and ODS             |  PASS     |          |
|       11      | Verify the connection between ODS and MongoDB in IPC   | Successfully able to access job and material from HMI | PASS       |          |





