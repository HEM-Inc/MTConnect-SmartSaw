#!/bin/sh

############################################################
# Help                                                     #
############################################################
Help(){
    # Display Help
    echo "This function updates HEMSaw MTConnect-SmartAdapter, ODS, MTconnect Agent and MQTT."
    echo "Any associated device files for MTConnect and Adapter files are updated as per this repo."
    echo
    echo "Syntax: ssUpgrade.sh [-H|-a File_Name|-j File_Name|-A|-d File_Name|-u Serial_number|-M|-O|-S|-m|-2|-h]"
    echo "options:"
    echo "-H                Update the HEMsaw adapter application"
    echo "-a File_Name      Declare the afg file name; Defaults to - SmartSaw_DC_HA.afg"
    echo "-j File_Name      Declare the JSON file name; Defaults to - SmartSaw_alarms.json"
    echo "-A                Update the MTConnect Agent application"
    echo "-d File_Name      Declare the MTConnect agent device file name; Defaults to - SmartSaw_DC_HA.xml"
    echo "-u Serial_number  Declare the serial number for the uuid; Defaults to - SmartSaw"
    echo "-M                Update the MQTT broker application"
    echo "-O                Update the HEMsaw ODS application"
    echo "-S                Update the HEMsaw MongoDB application"
    echo "-m                Update the MongoDB database with default materials"
    echo "-2                Use the docker V2 scripts for Ubuntu 24.04 and up base OS"
    echo "-h                Print this Help."
    echo ""
    echo "AFG files"
    ls adapter/config/
    echo ""
    echo "MTConnect Device files"
    ls agent/config/devices
    echo ""
}

############################################################
# Docker                                                   #
############################################################
RunDocker(){
    if service_exists docker; then
        echo "Starting up the Docker image"
        if $Use_Docker_Compose_v2; then
            docker compose pull
            docker compose up --remove-orphans -d
        else
            docker-compose pull
            docker-compose up --remove-orphans -d
        fi
    else
        echo "Installing and Starting up the Docker images"
        if $Use_Docker_Compose_v2; then
            apt update --fix-missing
            apt install -y docker-compose-v2 --fix-missing
            docker compose up --remove-orphans -d
        else
            apt update --fix-missing
            apt install -y docker-compose --fix-missing
            docker-compose up --remove-orphans -d
        fi
        apt clean
    fi
    if $Use_Docker_Compose_v2; then
        docker compose logs mtc_adapter mtc_agent mosquitto ods
    else
        docker-compose logs mtc_adapter mtc_agent mosquitto ods
    fi
}

############################################################
# Updaters                                                 #
############################################################
Update_Adapter(){
    if test -d /etc/adapter/config/; then
        echo "Updating adapter files..."
        rm -rf /etc/adapter/config/*.afg
        rm -rf /etc/adapter/data/*.json
        rm -rf /etc/adapter/log/*
        cp -r ./adapter/config/$Afg_File /etc/adapter/config/
	cp -r ./adapter/data/$Json_File /etc/adapter/data/
    else
        echo "Installing adapter files..."
        mkdir -p /etc/adapter/
        mkdir -p /etc/adapter/config/
        mkdir -p /etc/adapter/data/
        mkdir -p /etc/adapter/log
        cp -r ./adapter/config/$Afg_File /etc/adapter/config/
        cp -r ./adapter/data/$Json_File /etc/adapter/data/
    fi
    echo  ""
    chown -R 1100:1100 /etc/adapter/
}

Update_Agent(){
    if test -f /etc/mtconnect/config/agent.cfg; then
        echo "Updating MTConnect Agent files..."
        cp -r ./agent/config/agent.cfg /etc/mtconnect/config/
        rm -rf /etc/mtconnect/config/*.xml
        sed -i '1 i\Devices = /mtconnect/config/'$Device_File /etc/mtconnect/config/agent.cfg
        cp -r ./agent/config/devices/$Device_File /etc/mtconnect/config/
        sed -i "11 i\        <Device id=\"saw\" uuid=\"HEMSaw_$Serial_Number\" name=\"Saw\">" /etc/mtconnect/config/$Device_File
        cp -r ./agent/data/ruby/. /etc/mtconnect/data/ruby/
        echo ""
    else
        echo "Installing MTConnect Agent files..."
        mkdir -p /etc/mtconnect/
        mkdir -p /etc/mtconnect/config/
        mkdir -p /etc/mtconnect/data/

        cp -r ./agent/config/agent.cfg /etc/mtconnect/config/
        sed -i '1 i\Devices = /mtconnect/config/'$Device_File /etc/mtconnect/config/agent.cfg
        cp -r ./agent/config/devices/$Device_File /etc/mtconnect/config/
        sed -i "11 i\        <Device id=\"saw\" uuid=\"HEMSaw_$Serial_Number\" name=\"Saw\">" /etc/mtconnect/config/$Device_File
        cp -r ./agent/data/ruby/. /etc/mtconnect/data/ruby/
        echo ""
    fi

    chown -R 1000:1000 /etc/mtconnect/
}

Update_MQTT_Broker(){
    if test -d /etc/mqtt/config/; then
        echo "Updating mqtt files..."
        cp -r ./mqtt/config/. /etc/mqtt/config
        cp -r ./mqtt/data/. /etc/mqtt/data
        chmod 0700 /etc/mqtt/data/acl
    else
        echo "Updating mqtt files..."
        mkdir -p /etc/mqtt/config/
        mkdir -p /etc/mqtt/data/
        cp -r ./mqtt/config/. /etc/mqtt/config
        cp -r ./mqtt/data/. /etc/mqtt/data
        chmod 0700 /etc/mqtt/data/acl
    fi
}

Update_ODS(){
    if test -d /etc/ods/config/; then
        echo "Updating ods files..."
        cp -r ./ods/config/. /etc/ods/config
    else
        echo "Installing ods files.."
        mkdir -p /etc/ods/config/
        cp -r ./ods/config/. /etc/ods/config
    fi
    echo ""
    chown -R 1200:1200 /etc/ods/
}

Update_Mongodb(){
      if test -d /etc/mongodb/config/; then
        echo "Updating mongodb files..."
        cp -r ./mongodb/config/* /etc/mongodb/config/
        cp -r ./mongodb/data/* /etc/mongodb/data/
    else
        echo "Installing mongodb files.."
        mkdir -p /etc/mongodb/
        mkdir -p /etc/mongodb/config/
        mkdir -p /etc/mongodb/data/
        mkdir -p /etc/mongodb/data/db
        cp -r ./mongodb/config/* /etc/mongodb/config/
        cp -r ./mongodb/data/* /etc/mongodb/data/
    fi
    echo ""
    chown -R 1000:1000 /etc/mongodb/
}

Update_Materials(){
    if python3 -c "import pymongo" &> /dev/null; then
        echo "Updating or reseting the materials..."
        sudo python3 /etc/mongodb/data/upload_materials.py
    else
        echo "Setting the default materials..."
        sudo pip3 install pyaml --break-system-packages
        sudo pip3 install pymongo --break-system-packages
        sudo python3 /etc/mongodb/data/upload_materials.py
    fi
}

############################################################
############################################################
# Main program                                             #
############################################################
############################################################

if [[ $(id -u) -ne 0 ]] ; then echo "Please run ssUpgrade.sh as sudo" ; exit 1 ; fi

# Set default variables
Afg_File="SmartSaw_DC_HA.afg"
Json_File="SmartSaw_alarms.json"
Device_File="SmartSaw_DC_HA.xml"
Serial_Number="SmartSaw"
run_update_adapter=false
run_update_agent=false
run_update_mqtt_broker=false
run_update_ods=false
run_update_mongodb=false
run_update_materials=false
run_install=false
Use_Docker_Compose_v2=false

# check if install or upgrade
if ! test -f /etc/mtconnect/config/agent.cfg; then
    echo 'MTConnect agent.cfg not found, running bash ssInstall.sh instead'; run_install=true
else
    echo 'MTConnect agent.cfg found, continuing upgrade...'
fi

echo ""

#check if systemd services are running
if systemctl is-active --quiet adapter || systemctl is-active --quiet ods || systemctl is-active --quiet mongod; then
    echo "Adapter, ODS and/or Mongodb is running as a systemd service, stopping the systemd services..."
    echo " -- Recommend running 'sudo bash ssClean.sh -d' to disable the daemons for future updates"
    systemctl stop adapter
    systemctl stop ods
    systemctl stop mongod
fi

############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options
while getopts ":a:j:d:u:HAMhOSm2" option; do
    case ${option} in
        h) # display Help
            Help
            exit;;
        H) # Update the Adapter
            run_update_adapter=true;;
        a) # Enter an AFG file name
            Afg_File=$OPTARG;;
        j) # Enter JSON file name
            Json_File=$OPTARG;;
        A) # Update the Agent
            run_update_agent=true;;
        d) # Enter a Device file name
            Device_File=$OPTARG;;
        u) # Enter a serial number for the UUID
            Serial_Number=$OPTARG;;
        m) #Update Mongodb
           run_update_materials=true;;
        M) # Update mqtt broker
            run_update_mqtt_broker=true;;
        O) # Update ODS
            run_update_ods=true;;
        S) #Update Mongodb
	       run_update_mongodb=true;;
        2) # Run the Docker Compose V2
            Use_Docker_Compose_v2=true;;
        \?) # Invalid option
            Help
            exit;;
    esac
done

############################################################
# Service exists function                                  #
############################################################

service_exists() {
    local n=$1
    if [[ $(systemctl list-units --all -t service --full --no-legend "$n.service" | sed 's/^\s*//g' | cut -f1 -d' ') == $n.service ]]; then
        return 0
    else
        return 1
    fi
}

############################################################
############################################################
# Main program                                             #
############################################################
############################################################

if $run_install; then
    echo "Running Install script..."
    bash ssInstall.sh -a $Afg_File -j $Json_File -d $Device_File -u $Serial_Number
else
    echo "Printing the options..."
    echo "Update Adapter set to run = "$run_update_adapter
    echo "Update MTConnect Agent set to run = "$run_update_agent
    echo "Update MQTT Broker set to run = "$run_update_mqtt_broker
    echo "Update ODS set to run = "$run_update_ods
    echo "Update Mongodb set to run = "$run_update_mongodb
    echo "Update Materials set to run = "$run_update_materials
    echo "Use Docker Compose V2 commands = " $Use_Docker_Compose_v2
    if $run_update_adapter; then
        echo "AFG file = "$Afg_File
        echo "JSON file = "$Json_File
    fi
    if $run_update_agent; then
        echo "MTConnect Agent file = "$Device_File
        echo "MTConnect UUID = HEMSaw_"$Serial_Number
    fi

    echo ""
    if service_exists docker; then
        echo "Shutting down any old Docker containers"
        if $Use_Docker_Compose_v2; then
            docker compose down
        else
            docker-compose down
        fi
    fi

    echo ""
    if $run_update_adapter; then
        Update_Adapter
    fi
    if $run_update_agent; then
        Update_Agent
    fi
    if $run_update_mqtt_broker; then
        Update_MQTT_Broker
    fi
    if $run_update_ods; then
        Update_ODS
    fi
    if $run_update_mongodb; then
        Update_Mongodb
    fi
    RunDocker
    if $run_update_materials; then
        Update_Materials
    fi
fi

echo ""
echo "Check to verify containers are running:"
docker system prune --all --force --volumes
docker ps
