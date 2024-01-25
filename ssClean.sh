#!/bin/sh

############################################################
# Help                                                     #
############################################################
Help(){
    # Display Help
    echo "This function updates the systemd files for the HEMsaw Adapter and the Agent."
    echo "Any associated device files for MTConnect and Adapter files are updated as per this repo."
    echo
    echo "Syntax: ssClean.sh [-H|-A|-M|-D|-C|-h]"
    echo "options:"
    echo "-H                Uninstall the HEMsaw adapter application"
    echo "-A                Uninstall the MTConnect Agent application"
    echo "-M                Uninstall the MQTT Broker application"
    echo "-D                Uninstall Docker"
    echo "-C                Clean the system files"
    echo "-h                Print this Help."
}

############################################################
# Unstallers                                               #
############################################################
Uninstall_Adapter(){
    echo "Uninstalling MTConnect Adapter files..."
    systemctl stop adapter
    rm -rf /etc/adapter/
    rm -rf /etc/systemd/system/adapter.service
    systemctl daemon-reload
    echo "<<Done>>"
    echo ""
}
Uninstall_Agent(){
    echo "Uninstalling MTConnect Agent files..."
    systemctl stop agent

    if id -u mtconnect > /dev/null 2>&1; then
        userdel -f -r mtconnect
    fi
    
    rm -rf /var/log/mtconnect
    rm -rf /etc/mtconnect/
    rm -rf /etc/systemd/system/agent.service
    systemctl daemon-reload
    echo "<<Done>>"
    echo ""
}
Uninstall_MQTT(){
    echo "Uninstalling Mosquitto files..."
    apt purge -y mosquitto mosquitto-clients
    apt autoremove -y
    rm -rf /etc/mosquitto
    rm -rf /etc/mqtt
    systemctl daemon-reload
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
}
Clean_Files(){
    apt clean
    journalctl --vacuum-time=10d
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
run_uninstall_docker=false
run_clean=false

############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options
while getopts ":HAMDCh" option; do
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
        D) # uninstall Docker
            run_uninstall_docker=true;;
        C) # Clean Files
            run_clean=true;;
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
echo "uninstall Docker set to run = "$run_uninstall_docker
echo "clean System Files set to run = "$run_clean

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
if $run_uninstall_docker; then
    Uninstall_Docker
fi
if $run_clean; then
    Clean_Files
fi

echo ""
