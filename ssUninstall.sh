#!/bin/sh

############################################################
# Help                                                     #
############################################################
Help(){
    # Display Help
    echo "This function updates the systemd files for the HEMsaw Adapter and the Agent."
    echo "Any associated device files for MTConnect and Adapter files are updated as per this repo."
    echo
    echo "Syntax: ssUninstall.sh [-H|-A|-M|-D|-h]"
    echo "options:"
    echo "-H                Uninstall the HEMsaw adapter application"
    echo "-A                Uninstall the MTConnect Agent application"
    echo "-M                Uninstall the Mosquitto broker application"
    echo "-D                Uninstall Docker"
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

    if user_exists mtconnect; then
        userdel -f -r mtconnect
    fi
    
    rm -rf /var/log/mtconnect
    rm -rf /etc/mtconnect/
    rm -rf /etc/systemd/system/agent.service
    systemctl daemon-reload
    echo "<<Done>>"
    echo ""
}
Uninstall_Mosquitto(){
    echo "Uninstalling Mosquitto files..."
    apt purge mosquitto mosquitto-clients
    apt autoremove
    rm -rf /etc/mosquitto
    systemctl daemon-reload
    echo "<<Done>>"
    echo ""
}
Uninstall_Docker(){
    echo "Shutting down any old Docker containers"
    docker-compose down

    echo "Uninstalling MTConnect Adapter..."
    docker system prune --all --force --volumes

    apt purge docker-compose docker
    apt autoremove
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
run_uninstall_mosquitto=false
run_uninstall_docker=false

############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options
while getopts ":HAMDh" option; do
    case ${option} in
        h) # display Help
            Help
            exit;;
        H) # uninstall the Adapter
            run_uninstall_adapter=true;;
        A) # uninstall the Agent
            run_uninstall_agent=true;;
        M) # uninstall Mosquitto
            run_uninstall_mosquitto=true;;
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

user_exists() {
    local n=$1
    if id -u "$n.user" &>/dev/null; then
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
echo "uninstall Adapter set to run = "$run_uninstall_adapter
echo "uninstall MTConnect Agent set to run = "$run_uninstall_agent
echo "uninstall Mosquitto Broker set to run = "$run_uninstall_mosquitto
echo "uninstall Docker set to run = "$run_uninstall_docker

echo ""
if $run_uninstall_adapter; then
    Uninstall_Adapter
fi
if $run_uninstall_agent; then
    Uninstall_Agent
fi
if $run_uninstall_mosquitto; then
    Uninstall_Mosquitto
fi
if $run_uninstall_docker; then
    Uninstall_Docker
fi

apt clean

echo ""
