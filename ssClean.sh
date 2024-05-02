#!/bin/sh

############################################################
# Help                                                     #
############################################################
Help(){
    # Display Help
    echo "This function uninstalls HEMSaw MTConnect-SmartAdapter, ODS, MTconnect Agent and MQTT."
    echo "Any associated device files for MTConnect and Adapter files are deleted as per this repo."
    echo
    echo "Syntax: ssClean.sh [-H|-A|-M|-O|-S|-D|-h]"
    echo "options:"
    echo "-H                Uninstall the HEMsaw adapter application"
    echo "-A                Uninstall the MTConnect Agent application"
    echo "-M                Uninstall the MQTT Broker application"
    echo "-O                Uninstall the HEMsaw ods application"
    echo "-S                Uninstall the HEMSaw MongoDB application"
    echo "-D                Uninstall Docker"
    echo "-d                Disable mongod, ods, and agent daemons"
    echo "-h                Print this Help."
}

############################################################
# Uninstallers                                               #
############################################################
Uninstall_Adapter(){
    echo "Uninstalling MTConnect Adapter files and user..."

    if id -u adapter > /dev/null 2>&1; then
        userdel -f -r adapter
    fi

    rm -rf /etc/adapter/
    echo "<<Done>>"
    echo ""
}

Uninstall_Agent(){
    echo "Uninstalling MTConnect Agent files and user..."

    if id -u mtconnect > /dev/null 2>&1; then
        userdel -f -r mtconnect
    fi
    
    rm -rf /var/log/mtconnect
    rm -rf /etc/mtconnect/
    echo "<<Done>>"
    echo ""
}

Uninstall_MQTT(){
    echo "Uninstalling Mosquitto files..."
    rm -rf /etc/mosquitto
    rm -rf /etc/mqtt
    echo "<<Done>>"
    echo ""
}

Uninstall_ODS(){
    echo "Uninstalling ODS files and user..."

    if id -u ods > /dev/null 2>&1; then
        userdel -f -r ods
    fi

    rm -rf /etc/ods
    echo "<<Done>>"
    echo ""
}

Uninstall_Mongodb(){
    echo "Uninstalling Mongodb files..."
    rm -rf /etc/mongodb/
    echo "<<Done>>"
    echo ""
}

Uninstall_Docker(){
    echo "Shutting down any old Docker containers"
    docker-compose down

    echo "Uninstalling MTConnect Adapter..."
    docker system prune --all --force --volumes

    apt purge -y docker-compose docker
    apt autoremove -y
    echo "<<Done>>"
    echo ""
}

Uninstall_Daemon(){
    if systemctl is-active --quiet adapter || systemctl is-active --quiet ods || systemctl is-active --quiet mongod; then
        echo "Adapter, ODS and/or Mongodb is running as a systemd service, stopping the systemd services..."
        systemctl stop adapter
        systemctl stop ods
        systemctl stop mongod
    fi

    echo "Disabling the systemd services..."
    systemctl disable adapter
    systemctl disable ods
    systemctl disable mongod

    systemctl daemon-reload
    echo "<<Done>>"
    echo ""
}

############################################################
############################################################
# Main program                                             #
############################################################
############################################################

if [[ $(id -u) -ne 0 ]] ; then echo "Please run ssUninstall.sh as sudo" ; exit 1 ; fi

# Set default variables
run_uninstall_adapter=false
run_uninstall_agent=false
run_uninstall_mqtt=false
run_uninstall_ods=false
run_uninstall_mongodb=false
run_uninstall_docker=false
run_uninstall_daemon=false

############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options
while getopts ":HAMDhOSd" option; do
    case ${option} in
        h) # display Help
            Help
            exit;;
        H) # uninstall the Adapter
            run_uninstall_adapter=true;;
        A) # uninstall the Agent
            run_uninstall_agent=true;;
        M) # uninstall Mosquitto
            run_uninstall_mqtt=true;;
        O) # uninstall the ODS
            run_uninstall_ods=true;;
        S) # uninstall the mongodb
	    run_uninstall_mongodb=true;;
        D) # uninstall Docker
            run_uninstall_docker=true;;
        d) # uninstall daemon
            run_uninstall_daemon=true;;
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
echo "uninstall Adapter set to run = "$run_uninstall_adapter
echo "uninstall MTConnect Agent set to run = "$run_uninstall_agent
echo "uninstall MQTT Broker set to run = "$run_uninstall_mqtt
echo "uninstall ODS set to run = "$run_uninstall_ods
echo "uninstall Mongodb set to run="$run_uninstall_mongodb
echo "uninstall Docker set to run = "$run_uninstall_docker
echo "disable   Systemctl Daemons set to run = "$run_uninstall_daemon

echo ""
if $run_uninstall_adapter; then
    Uninstall_Adapter
fi
if $run_uninstall_agent; then
    Uninstall_Agent
fi
if $run_uninstall_mqtt; then
    Uninstall_MQTT
fi
if $run_uninstall_ods; then
    Uninstall_ODS
fi
if $run_uninstall_mongodb; then
    Uninstall_Mongodb
fi
if $run_uninstall_docker; then
    Uninstall_Docker
fi
if $run_uninstall_daemon; then
    Uninstall_Daemon
fi

echo "***** Cleaning Complete *****"
echo ""
