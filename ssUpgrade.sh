#!/bin/sh

############################################################
# Help                                                     #
############################################################
Help(){
    # Display Help
    echo "This function updates the systemd files for the HEMsaw Adapter and the Agent."
    echo "Any associated device files for MTConnect and Adapter files are updated as per this repo."
    echo
    echo "Syntax: ssUpgrade [-D|-H|-a File_Name|-A|-d File_Name|-u Serial_number|-M|-h]"
    echo "options:"
    echo "-D                Use a Docker image for the Agent and MQTT Broker"
    echo "-H                Update the HEMsaw adapter application"
    echo "-a File_Name      Declare the afg file name; Defaults to - SmartSaw_DC_HA.afg"
    echo "-A                Update the MTConnect Agent application"
    echo "-d File_Name      Declare the MTConnect agent device file name; Defaults to - SmartSaw_DC_HA.xml"
    echo "-u Serial_number  Declare the serial number for the uuid; Defaults to - SmartSaw"
    echo "-M                Update the mosquitto broker application"
    echo "-h                Print this Help."
}

############################################################
# Docker                                                   #
############################################################
RunAsDocker(){
    if service_exists docker; then
        echo "Stopping the daemons..."
        systemctl stop agent

        echo "Starting up the Docker image"
        docker-compose pull
        docker-compose up -d 
    else
        echo "Installing Docker..."
        apt update
        apt install -y docker-compose
        apt clean

        touch /etc/mosquitto/passwd
        mosquitto_passwd -b /etc/mosquitto/passwd mtconnect mtconnect
        chmod 0700 /etc/mosquitto/passwd

        echo "Stopping the daemons..."
        systemctl stop agent

        echo "Starting up the Docker image"
        docker-compose up -d 
    fi
    docker-compose logs
}

############################################################
# Updaters                                                 #
############################################################
Update_Adapter(){
    echo "Updating MTConnect Adapter..."

    systemctl stop adapter
    cp -r ./adapter/. /etc/adapter/
    rm -rf /etc/adapter/SmartSaw_*.afg
    cp -r ./afg/$Afg_File /etc/adapter/
    chmod +x /etc/adapter/Adapter
    cp /etc/adapter/adapter.service /etc/systemd/system/

    systemctl daemon-reload
    systemctl start adapter
    systemctl status adapter

    echo "MTConnect Adapter Up and Running"
    echo ""
}

Update_Agent(){
    echo "Updating MTConnect Agent..."

    systemctl stop agent
    cp -r ./agent/. /etc/mtconnect/agent/
    sed -i '1 i\Devices = ../devices/'$Device_File /etc/mtconnect/agent/agent.cfg
    sed -i '1 i\Devices = /etc/mtconnect/data/devices/'$Device_File /etc/mtconnect/agent/dockerAgent.cfg
    rm -rf /etc/mtconnect/devices/SmartSaw_*.xml
    cp -r ./devices/$Device_File /etc/mtconnect/devices/
    sed -i "11 i\        <Device id=\"saw\" uuid=\"HEMSaw_$Serial_Number\" name=\"Saw\">" /etc/mtconnect/devices/$Device_File
    cp -r ./schema/. /etc/mtconnect/schema/
    cp -r ./styles/. /etc/mtconnect/styles/
    cp -r ./ruby/. /etc/mtconnect/ruby/
    chown -R mtconnect:mtconnect /etc/mtconnect
    
    tar -xf agent_dist/mtcagent_dist.tar.gz -C agent_dist/
    cp agent_dist/mtcagent_dist/bin/* /usr/bin
    cp agent_dist/mtcagent_dist/lib/* /usr/lib
    rm -rf agent_dist/mtcagent_dist/
    chmod +x /usr/bin/mtcagent

    cp /etc/mtconnect/agent/agent.service /etc/systemd/system/

    systemctl daemon-reload
    systemctl start agent
    systemctl status agent

    echo "MTConnect Agent Up and Running"
    echo ""
}

Update_Mosquitto(){
    if service_exists docker && test -f /etc/mosquitto/passwd; then
        echo "Updating Mosquitto files..."
        cp ./mqtt/config/mosquitto.conf /etc/mosquitto/conf.d/
        cp ./mqtt/data/acl /etc/mosquitto/acl
        chmod 0700 /etc/mosquitto/acl

        docker run -d --pull=always --restart=unless-stopped \
            --name mosquitto \
            -p 1883:1883/tcp \
            -v /etc/mosquitto/conf.d/mosquitto.conf:/mosquitto/config/mosquitto.conf \
            -v /etc/mosquitto/acl:/mosquitto/data/acl \
            -v /etc/mosquitto/passwd:/mosquitto/data/passwd \
            eclipse-mosquitto:latest

        echo "Mosquitto Updated and Running"
    else
        echo "Installing the mosquitto service..."
        apt update
        apt install -y docker-compose
        apt clean

        echo "Adding mtconnect user to access control list"
        touch /etc/mosquitto/passwd
        mosquitto_passwd -b /etc/mosquitto/passwd mtconnect mtconnect
        chmod 0700 /etc/mosquitto/passwd
        cp ./mqtt/data/acl /etc/mosquitto/acl
        chmod 0700 /etc/mosquitto/acl

        cp ./mqtt/config/mosquitto.conf /etc/mosquitto/conf.d/

        # docker pull eclipse-mosquitto:latest
        docker run -d --pull=always --restart=unless-stopped \
            --name mosquitto \
            -p 1883:1883/tcp \
            -v /etc/mosquitto/conf.d/mosquitto.conf:/mosquitto/config/mosquitto.conf \
            -v /etc/mosquitto/acl:/mosquitto/data/acl \
            -v /etc/mosquitto/passwd:/mosquitto/data/passwd \
            eclipse-mosquitto:latest

        echo "Mosquitto MQTT Broker Up and Running"
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
Device_File="SmartSaw_DC_HA.xml"
Serial_Number="SmartSaw"
run_update_adapter=false
run_update_agent=false
run_update_mosquitto=false
run_Docker=false

############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options
while getopts ":a:d:u:DHAMh" option; do
    case ${option} in
        h) # display Help
            Help
            exit;;
        D) # use a docker image for mqtt and Agent
            run_Docker=true;;
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
        M) # Update Mosquitto
            run_update_mosquitto=true;;
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

echo "Printing the options..."
echo "Update Adapter set to run = "$run_update_adapter
echo "Update MTConnect Agent set to run = "$run_update_agent
echo "Update Mosquitto Broker set to run = "$run_update_mosquitto
echo "Run Docker = "$run_Docker
if $run_update_adapter; then
    echo "AFG file = "$Afg_File
fi
if $run_update_agent; then
    echo "MTConnect Agent file = "$Device_File
    echo "MTConnect UUID = HEMSaw_"$Serial_Number
fi
if $run_update_mosquitto; then
    echo "Config file = mosquitto.conf"
fi

echo ""
if service_exists docker; then
    echo "Shutting down any old Docker containers"
    docker-compose down || docker stop mosquitto && docker rm mosquitto
fi

echo ""
if $run_update_adapter; then
    Update_Adapter
fi
if $run_update_agent; then
    Update_Agent
fi
if $run_update_mosquitto; then
    Update_Mosquitto
fi

if $run_Docker; then
    RunAsDocker
fi
