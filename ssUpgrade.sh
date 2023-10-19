#!/bin/sh

############################################################
# Help                                                     #
############################################################
Help(){
    # Display Help
    echo "This function updates the systemd files for the HEMsaw Adapter and the Agent."
    echo "Any associated device files for MTConnect and Adapter files are updated as per this repo."
    echo
    echo "Syntax: ssUpgrade.sh [-H|-a File_Name|-A|-d File_Name|-u Serial_number|-M|-h]"
    echo "options:"
    echo "-H                Update the HEMsaw adapter application"
    echo "-a File_Name      Declare the afg file name; Defaults to - SmartSaw_DC_HA.afg"
    echo "-A                Update the MTConnect Agent application"
    echo "-d File_Name      Declare the MTConnect agent device file name; Defaults to - SmartSaw_DC_HA.xml"
    echo "-u Serial_number  Declare the serial number for the uuid; Defaults to - SmartSaw"
    echo "-M                Update the Mosquitto broker application"
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
    echo "Updating MTConnect Adapter..."

    systemctl stop adapter
    cp -r ./adapter/. /etc/adapter/
    rm -rf /etc/adapter/SmartSaw_*.afg
    cp -r ./afg/$Afg_File /etc/adapter/
    chmod +x /etc/adapter/Adapter
    cp -u /etc/adapter/adapter.service /etc/systemd/system/

    systemctl daemon-reload
    systemctl start adapter
    systemctl status adapter

    echo "MTConnect Adapter Up and Running"
    echo ""
}

Update_Agent(){
    if test -f ; then
        echo "Updating MTConnect Agent files..."
        cp -r ./agent/. /etc/mtconnect/agent/
        sed -i '1 i\Devices = /etc/mtconnect/data/devices/'$Device_File /etc/mtconnect/agent/agent.cfg
        rm -rf /etc/mtconnect/devices/SmartSaw_*.xml
        cp -r ./devices/$Device_File /etc/mtconnect/devices/
        sed -i "11 i\        <Device id=\"saw\" uuid=\"HEMSaw_$Serial_Number\" name=\"Saw\">" /etc/mtconnect/devices/$Device_File
        cp -r ./schema/. /etc/mtconnect/schema/
        cp -r ./styles/. /etc/mtconnect/styles/
        cp -r ./ruby/. /etc/mtconnect/ruby/
        chown -R mtconnect:mtconnect /etc/mtconnect
        echo ""
    else
        echo "Installing MTConnect Agent files..."

        if ! user_exists mtconnect; then
            useradd -r -s /bin/false mtconnect
            chown mtconnect:mtconnect /var/log/mtconnect
        fi

        mkdir -p /etc/mtconnect/
        mkdir -p /etc/mtconnect/agent/
        mkdir -p /etc/mtconnect/devices/
        mkdir -p /etc/mtconnect/schema/
        mkdir -p /etc/mtconnect/styles/

        cp -r ./agent/agent.cfg /etc/mtconnect/agent/
        sed -i '1 i\Devices = /etc/mtconnect/data/devices/'$Device_File /etc/mtconnect/agent/agent.cfg
        rm -rf /etc/mtconnect/devices/SmartSaw_*.xml
        cp -r ./devices/$Device_File /etc/mtconnect/devices/
        sed -i "11 i\        <Device id=\"saw\" uuid=\"HEMSaw_$Serial_Number\" name=\"Saw\">" /etc/mtconnect/devices/$Device_File
        cp -r ./schema/. /etc/mtconnect/schema/
        cp -r ./styles/. /etc/mtconnect/styles/
        cp -r ./ruby/. /etc/mtconnect/ruby/
        chown -R mtconnect:mtconnect /etc/mtconnect
        echo ""
}

Update_Mosquitto(){
    if test -f /etc/mosquitto/passwd; then
        echo "Updating Mosquitto files..."
        cp -u ./mqtt/data/passwd /etc/mosquitto
        chmod 0700 /etc/mosquitto/passwd
        cp -u ./mqtt/data/acl /etc/mosquitto
        chmod 0700 /etc/mosquitto/acl
        cp -u ./mqtt/config/mosquitto.conf /etc/mosquitto/conf.d/
    else
        echo "Updating Mosquitto files..."
        mkdir -p /etc/mosquitto/conf.d/
        cp -u ./mqtt/data/passwd /etc/mosquitto
        chmod 0700 /etc/mosquitto/passwd
        cp -u ./mqtt/data/acl /etc/mosquitto
        chmod 0700 /etc/mosquitto/acl
        cp -u ./mqtt/config/mosquitto.conf /etc/mosquitto/conf.d/
    fi
}

############################################################
############################################################
# Main program                                             #
############################################################
############################################################

if [[ $(id -u) -ne 0 ]] ; then echo "Please run ssUpgrade.sh as sudo" ; exit 1 ; fi

if ! user_exists mtconnect; 
    then echo 'mtconnect user not found, run bash ssInstall.sh instead'; exit 1 
else
    echo 'Mtconnect user found, continuing install...'
fi

# Set default variables
Afg_File="SmartSaw_DC_HA.afg"
Device_File="SmartSaw_DC_HA.xml"
Serial_Number="SmartSaw"
run_update_adapter=false
run_update_agent=false
run_update_mosquitto=false

############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options
while getopts ":a:d:u:HAMh" option; do
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

user_exists() {
    local n=$1
    if [[ id -u "$n.user" &>/dev/null ]]; then
        return 1
    else
        return 0
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
    docker-compose down
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

RunDocker

echo ""
echo "Check to verify containers are running:"
docker system prune -f
docker ps
