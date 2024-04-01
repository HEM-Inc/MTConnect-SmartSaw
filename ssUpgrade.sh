#!/bin/sh

############################################################
# Help                                                     #
############################################################
Help(){
    # Display Help
    echo "This function updates HEMSaw MTConnect-SmartAdapter, ODS, MTconnect Agent and MQTT."
    echo "Any associated device files for MTConnect and Adapter files are updated as per this repo."
    echo
    echo "Syntax: ssUpgrade.sh [-H|-a File_Name|-A|-d File_Name|-u Serial_number|-M|-O|-h]"
    echo "options:"
    echo "-H                Update the HEMsaw adapter application"
    echo "-a File_Name      Declare the afg file name; Defaults to - SmartSaw_DC_HA.afg"
    echo "-A                Update the MTConnect Agent application"
    echo "-d File_Name      Declare the MTConnect agent device file name; Defaults to - SmartSaw_DC_HA.xml"
    echo "-u Serial_number  Declare the serial number for the uuid; Defaults to - SmartSaw"
    echo "-M                Update the MQTT broker application"
    echo "-O	          Update the HEMsaw ODS application"
    echo "-h                Print this Help."
}

############################################################
# Docker                                                   #
############################################################
RunDocker(){
    if service_exists docker; then
        echo "Starting up the Docker image"
        docker-compose pull
        docker-compose up --remove-orphans -d 
    else
        echo "Installing Docker..."
        apt update
        apt install -y docker-compose
        apt clean

        echo "Starting up the Docker image"
        docker-compose up --remove-orphans -d 
    fi
    docker-compose logs
}

############################################################
# Updaters                                                 #
############################################################
Update_Adapter(){
    if test -d /etc/adapter/config/; then
        echo "Updating adapter files..."
        rm -rf /etc/adapter/config/*.afg
        cp -r ./adapter/config/$Afg_File /etc/adapter/config/
    else
        echo "Installing adapter files..."
        mkdir -p /etc/adapter/
        mkdir -p /etc/adapter/config/
        cp -r ./adapter/config/$Afg_File /etc/adapter/config/
    fi
    echo  ""
    chown -R 1000:1000 /etc/adapter/
}

Update_Agent(){
    if test -f /etc/mtconnect/config/agent.cfg; then
        echo "Updating MTConnect Agent files..."
        cp -r ./agent/config/agent.cfg /etc/mtconnect/config/
        rm -rf /etc/mtconnect/config/*.xml
        sed -i '1 i\Devices = /mtconnect/config/'$Device_File /etc/mtconnect/config/agent.cfg
        cp -r ./agent/config/devices/$Device_File /etc/mtconnect/config/
        sed -i "11 i\        <Device id=\"saw\" uuid=\"HEMSaw_$Serial_Number\" name=\"Saw\">" /etc/mtconnect/config/$Device_File
        cp -r ./agent/data/styles/. /etc/mtconnect/data/styles/
        cp -r ./agent/data/schemas/. /etc/mtconnect/data/schemas/
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
        cp -r ./agent/data/styles/. /etc/mtconnect/data/styles/
        cp -r ./agent/data/schemas/. /etc/mtconnect/data/schemas/
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
    chown -R 1000:1000 /etc/ods/
}

############################################################
############################################################
# Main program                                             #
############################################################
############################################################

if [[ $(id -u) -ne 0 ]] ; then echo "Please run ssUpgrade.sh as sudo" ; exit 1 ; fi

# Set default variables
Afg_File="SmartSaw_DC_HA.afg"
Device_File="SmartSaw_DC_HA.xml"
Serial_Number="SmartSaw"
run_update_adapter=false
run_update_agent=false
run_update_mqtt_broker=false
run_update_ods=false
run_install=false

# check if install or upgrade
if ! test -f /etc/mtconnect/config/agent.cfg; 
    then echo 'mtconnect agent.cfg not found, running bash ssInstall.sh instead'; run_install=true
else
    echo 'Mtconnect agent.cfg found, continuing upgrade...'
fi

echo ""

#check if systemd services are running
if systemctl is-active --quiet adapter || systemctl is-active --quiet ods; then
    echo "Adapter and/or ODS is running as a systemd service, Please run 1.0.0 version of ssUpgrade"
    exit 1
    #Optionally we can stop the Adapter and/or ODS systemd services
    #sudo systemctl stop adapter
    #sudo systemctl stop ods
fi

############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options
while getopts ":a:d:u:HAMhO" option; do
    case ${option} in
        h) # display Help
            Help
            exit;;
        H) # Update the Adapter
            run_update_adapter=true;;
        a) # Enter an AFG file name
            Afg_File=$OPTARG;;
        A) # Update the Agent
            run_update_agent=true;;
        d) # Enter a Device file name
            Device_File=$OPTARG;;
        u) # Enter a serial number for the UUID
            Serial_Number=$OPTARG;;
        M) # Update mqtt broker
            run_update_mqtt_broker=true;;
        O) # Update ODS
            run_update_ods=true;;
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
    bash ssInstall.sh -a $Afg_File -d $Device_File -u $Serial_Number
else
    echo "Printing the options..."
    echo "Update Adapter set to run = "$run_update_adapter
    echo "Update MTConnect Agent set to run = "$run_update_agent
    echo "Update MQTT Broker set to run = "$run_update_mqtt_broker
    echo "Update ODS set to run = "$run_update_ods
    if $run_update_adapter; then
        echo "AFG file = "$Afg_File
    fi
    if $run_update_agent; then
        echo "MTConnect Agent file = "$Device_File
        echo "MTConnect UUID = HEMSaw_"$Serial_Number
    fi

    echo ""
    if service_exists docker; then
        echo "Shutting down any old Docker containers"
        docker-compose down
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

    RunDocker
fi

echo ""
echo "Check to verify containers are running:"
docker system prune --all --force --volumes
docker ps
