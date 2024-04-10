#!/bin/sh

############################################################
# Help                                                     #
############################################################
Help(){
    # Display Help
    echo "This function uninstalls HEMSaw MTConnect-SmartAdapter, ODS, MTconnect Agent and MQTT."
    echo "Any associated device files for MTConnect and Adapter files are deleted as per this repo."
    echo
    echo "Syntax: ssClean.sh [-H|-A|-M|-O|-D|-h]"
    echo "options:"
    echo "-H                Uninstall the HEMsaw adapter application"
    echo "-A                Uninstall the MTConnect Agent application"
    echo "-M                Uninstall the MQTT Broker application"
    echo "-O		        Uninstall the HEMsaw ods application"
    echo "-D                Uninstall Docker"
    echo "-h                Print this Help."
}

############################################################
# Uninstallers                                               #
############################################################
Uninstall_Adapter(){
    echo "Uninstalling MTConnect Adapter files..."

    if id -u adapter > /dev/null 2>&1; then
        userdel -f -r adapter
    fi

    rm -rf /etc/adapter/
    echo "<<Done>>"
    echo ""
}

Uninstall_Agent(){
    echo "Uninstalling MTConnect Agent files..."

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
    echo "Uninstalling ODS files..."

    if id -u ods > /dev/null 2>&1; then
        userdel -f -r ods
    fi

    rm -rf /etc/ods
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
run_uninstall_docker=false

############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options
while getopts ":HAMDhO" option; do
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
        D) # uninstall Docker
            run_uninstall_docker=true;;
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
echo "uninstall Docker set to run = "$run_uninstall_docker

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
if $run_uninstall_docker; then
    Uninstall_Docker
fi

echo ""
