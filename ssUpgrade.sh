#!/bin/sh

############################################################
# Help                                                     #
############################################################
Help(){
    # Display Help
    echo "This function updates HEMSaw MTConnect-SmartAdapter, ODS, MTconnect Agent and MQTT."
    echo "Any associated device files for MTConnect and Adapter files are updated as per this repo."
    echo
    echo "Syntax: ssUpgrade.sh [-A|-a File_Name|-j File_Name|-d File_Name|-u Serial_number|-b|-m|-2|-h]"
    echo "options:"
    echo "-A                Update the MTConnect Agent, HEMsaw adapter, ODS, MQTT, and Mongodb application"
    echo "-a File_Name      Declare the afg file name; Defaults to - SmartSaw_DC_HA.afg"
    echo "-j File_Name      Declare the JSON file name; Defaults to - SmartSaw_alarms.json"
    echo "-d File_Name      Declare the MTConnect agent device file name; Defaults to - SmartSaw_DC_HA.xml"
    echo "-u Serial_number  Declare the serial number for the uuid; Defaults to - SmartSaw"
    echo "-b                Update the MQTT broker to use the bridge configuration; runs - mosq_bridge.conf"
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
        sed -i "11 s/.*/        <Device id=\"saw\" uuid=\"HEMSaw-$Serial_Number\" name=\"Saw\">/" /etc/mtconnect/config/$Device_File
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
        sed -i "11 s/.*/        <Device id=\"saw\" uuid=\"HEMSaw-$Serial_Number\" name=\"Saw\">/" /etc/mtconnect/config/$Device_File
        cp -r ./agent/data/ruby/. /etc/mtconnect/data/ruby/
        echo ""
    fi

    chown -R 1000:1000 /etc/mtconnect/
}

Update_MQTT_Broker(){
    if $run_update_mqtt_bridge; then
        if test -d /etc/mqtt/config/; then
            echo "Updating MQTT bridge files"

            # Load the Broker UUID
            cp -r ./mqtt/config/mosq_bridge.conf /etc/mqtt/config/mosquitto.conf
            sed -i "27 i\remote_clientid hemsaw-$Serial_Number" /etc/mqtt/config/mosquitto.conf

            cp -r ./mqtt/data/acl_bridge /etc/mqtt/data/acl
            cp -r ./mqtt/certs/. /etc/mqtt/certs/
            chmod 0700 /etc/mqtt/data/acl
        else
            echo "Installing MQTT bridge files"
            mkdir -p /etc/mqtt/config/
            mkdir -p /etc/mqtt/data/
            mkdir -p /etc/mqtt/certs/

            # Load the Broker UUID
            cp -r ./mqtt/config/mosq_bridge.conf /etc/mqtt/config/mosquitto.conf
            sed -i "27 i\remote_clientid hemsaw-$Serial_Number" /etc/mqtt/config/mosquitto.conf

            cp -r ./mqtt/data/acl_bridge /etc/mqtt/data/acl
            cp -r ./mqtt/certs/. /etc/mqtt/certs/
            chmod 0700 /etc/mqtt/data/acl
        fi
    else
        if test -d /etc/mqtt/config/; then
            echo "Updating MQTT files..."
            cp -r ./mqtt/config/mosquitto.conf /etc/mqtt/config/
            cp -r ./mqtt/data/acl /etc/mqtt/data/
            chmod 0700 /etc/mqtt/data/acl
        else
            echo "Updating MQTT files..."
            mkdir -p /etc/mqtt/config/
            mkdir -p /etc/mqtt/data/
            cp -r ./mqtt/config/mosquitto.conf /etc/mqtt/config/
            cp -r ./mqtt/data/acl /etc/mqtt/data/
            chmod 0700 /etc/mqtt/data/acl
        fi
    fi
    echo ""
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

## Set default variables
# Source the env.sh file
if [ -f "./env.sh" ]; then
    set -a
    source ./env.sh
    set +a
else
    echo "env.sh file not found. Using default values."
    Afg_File="SmartSaw_DC_HA.afg"
    Json_File="SmartSaw_alarms.json"
    Device_File="SmartSaw_DC_HA.xml"
    Serial_Number="SmartSaw"
fi

run_update_adapter=false
run_update_agent=false
run_update_mqtt_broker=false
run_update_mqtt_bridge=false
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
while getopts ":a:j:d:u:Ahbm2" option; do
    case ${option} in
        h) # display Help
            Help
            exit;;
        A) # Update All Containers
            run_update_mqtt_broker=true
            run_update_adapter=true
            run_update_agent=true
            run_update_ods=true
            run_update_mongodb=true;;
        a) # Enter an AFG file name
            Afg_File=$OPTARG
            sed -i "4 s/.*/export Afg_File=\"$Afg_File\"/" env.sh;;
        j) # Enter JSON file name
            Json_File=$OPTARG;
            sed -i "5 s/.*/export Json_File=\"$Json_File\"/" env.sh;;
        d) # Enter a Device file name
            Device_File=$OPTARG
            sed -i "6 s/.*/export Device_File=\"$Device_File\"/" env.sh;;
        u) # Enter a serial number for the UUID
            Serial_Number=$OPTARG
            sed -i "7 s/.*/export Serial_Number=\"$Serial_Number\"/" env.sh;;
        m) # Update Mongodb
           run_update_materials=true;;
        b) # Enter MQTT Bridge file name
            run_update_mqtt_bridge=true;;
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
    if $run_update_mqtt_bridge; then
        bash ssInstall.sh -a $Afg_File -j $Json_File -d $Device_File -u $Serial_Number -b $Bridge_File
    else
        bash ssInstall.sh -a $Afg_File -j $Json_File -d $Device_File -u $Serial_Number
    fi
else
    echo "Printing the options..."
    echo "Update Adapter set to run = "$run_update_adapter
    echo "Update MTConnect Agent set to run = "$run_update_agent
    echo "Update MQTT Broker set to run = "$run_update_mqtt_broker
    echo "Update MQTT Bridge set to run = "$run_update_mqtt_bridge
    echo "Update ODS set to run = "$run_update_ods
    echo "Update Mongodb set to run = "$run_update_mongodb
    echo "Update Materials set to run = "$run_update_materials
    echo "Use Docker Compose V2 commands = " $Use_Docker_Compose_v2
    echo ""
    echo "Printing the settings..."
    echo "AFG file = "$Afg_File
    echo "JSON file = "$Json_File
    echo "MTConnect Agent file = "$Device_File
    echo "MTConnect UUID = HEMSaw-"$Serial_Number

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
    if $run_update_mqtt_broker || $run_update_mqtt_bridge; then
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
