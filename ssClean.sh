#!/bin/sh

############################################################
# Help                                                     #
############################################################
Help(){
    # Display Help
    echo "This function uninstalls HEMSaw MTConnect-SmartAdapter, ODS, MTconnect Agent and MQTT."
    echo "Any associated device files for MTConnect and Adapter files are deleted as per this repo."
    echo
    echo "Syntax: ssClean.sh [-A|-H|-a|-M|-O|-C|-S|-d|-D|-1|-L|-h]"
    echo "options:"
    echo "-A                    Uninstall ALL"
    echo "-H                    Uninstall the HEMsaw adapter application"
    echo "-a                    Uninstall the MTConnect Agent application"
    echo "-M                    Uninstall the MQTT Broker application"
    echo "-O                    Uninstall the HEMsaw ods application"
    echo "-C                    Uninstall the HEMsaw devctl application"
    echo "-S                    Uninstall the HEMSaw MongoDB application"
    echo "-d                    Disable mongod, ods, and agent daemons"
    echo "-D                    Uninstall Docker"
    echo "-1                    Use the docker V1 scripts for Ubuntu 22.04 and earlier base OS"
    echo "-L Container_Name     Log repair for any NULL or ^@ char"
    echo "-h                    Print this Help."
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

Uninstall_Devctl(){
    echo "Uninstalling Devctl files and user..."

    if id -u devctl > /dev/null 2>&1; then
        userdel -f -r devctl
    fi

    rm -rf /etc/devctl
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
    if $Use_Docker_Compose_v1; then
        echo "Shutting down any old Docker containers"
        docker-compose down

        echo "Uninstalling MTConnect Adapter..."
        docker system prune --all --force --volumes

        echo "run 'apt purge -y docker-compose-v2 docker.io' to fully uninstall docker"
    else
        echo "Shutting down any old Docker containers"
        docker compose down

        echo "Uninstalling MTConnect Adapter..."
        docker system prune --all --force --volumes

        echo "run 'apt purge -y docker-compose docker' to fully uninstall docker"
    fi
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

CleanLog(){
    # Get the log path for the specified container
    log_path=$(docker inspect --format='{{.LogPath}}' "$container_name")

    # Check if the log path was successfully retrieved
    if [ -z "$log_path" ]; then
        echo "Failed to retrieve log path for container $container_name"
        exit 1
    fi
    echo "Log path for container $container_name: $log_path"
    echo " "

    # Extract the file name and directory of the log file
    log_dir=$(dirname "$log_path")
    log_file=$(basename "$log_path")

    # Remove null characters from the log file and its rotated versions
    for logs in "$log_dir/$log_file"*;
    do
        if [ -e "$logs" ]; then
            sed -i 's/\x00//g' "$logs"
            echo " "
            echo "Null characters removed. Repair successful."
            echo "Repaired log file at $logs"
        fi
    done
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
run_uninstall_devctl=false
run_uninstall_mongodb=false
run_uninstall_docker=false
run_uninstall_daemon=false
Use_Docker_Compose_v1=false
clean_logs=false

############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options
while getopts ":L:HaAMDhOCSd1" option; do
    case ${option} in
        h) # display Help
            Help
            exit;;
        A) # uninstall all
            run_uninstall_adapter=true
            run_uninstall_agent=true
            run_uninstall_mqtt=true
            run_uninstall_ods=true
            run_uninstall_devctl=true
            run_uninstall_mongodb=true
            run_uninstall_docker=true;;
        H) # uninstall the Adapter
            run_uninstall_adapter=true;;
        a) # uninstall the Agent
            run_uninstall_agent=true;;
        M) # uninstall Mosquitto
            run_uninstall_mqtt=true;;
        O) # uninstall the ODS
            run_uninstall_ods=true;;
        C) # uninstall the Devctl
	        run_uninstall_devctl=true;;
        S) # uninstall the mongodb
            run_uninstall_mongodb=true;;
        D) # uninstall Docker
            run_uninstall_docker=true;;
        d) # uninstall daemon
            run_uninstall_daemon=true;;
        1) # Run the Docker Compose V1
            Use_Docker_Compose_v1=true;;
        L) # run the docker log clean;;
            container_name=$OPTARG
            clean_logs=true;;
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
echo ""

echo "uninstall Adapter = "$run_uninstall_adapter
echo "uninstall MTConnect Agent = "$run_uninstall_agent
echo "uninstall MQTT Broker = "$run_uninstall_mqtt
echo "uninstall ODS = "$run_uninstall_ods
echo "uninstall Devctl = "$run_uninstall_devctl
echo "uninstall Mongodb = "$run_uninstall_mongodb
echo "uninstall Docker = "$run_uninstall_docker
echo "disable Systemctl Daemons = "$run_uninstall_daemon
echo "Run Docker Compose V1 commands = " $Use_Docker_Compose_v1
echo "Clean the docker log for container (" $container_name ") = " $clean_logs

echo ""
if $clean_logs; then
    CleanLog
fi
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
if $run_uninstall_devctl; then
    Uninstall_Devctl
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
