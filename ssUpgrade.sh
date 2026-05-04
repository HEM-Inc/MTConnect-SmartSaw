#!/bin/bash

SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/lib.sh" || { echo "ERROR: lib.sh not found at $SCRIPT_DIR/lib.sh"; exit 1; }

############################################################
# Help                                                     #
############################################################
Help(){
    # Display Help
    echo "This function updates HEMSaw MTConnect-SmartAdapter, ODS, Devctl, MTconnect Agent and MQTT."
    echo "Any associated device files for MTConnect and Adapter files are updated as per this repo."
    echo
    echo "Syntax: ssUpgrade.sh [-A|-a File_Name|-j File_Name|-d File_Name|-c File_Name|-u Serial_number|-b|-i|-m|-h]"
    echo "options:"
    echo "-A                Update the MTConnect Agent, HEMsaw adapter, ODS, MQTT, Devctl and Mongodb application"
    echo "-a File_Name      Declare the afg file name; Defaults to - SmartSaw_DC_HA.afg"
    echo "-j File_Name      Declare the JSON file name; Defaults to - SmartSaw_alarms.json"
    echo "-d File_Name      Declare the MTConnect agent device file name; Defaults to - SmartSaw_DC_HA.xml"
    echo "-c File_Name      Declare the Device control config file name; Defaults to - devctl_json_config.json"
    echo "-u Serial_number  Declare the serial number for the uuid; Defaults to - SmartSaw"
    echo "                  Triggers a full update so the serial number propagates to all configs"
    echo "-b                Update the MQTT broker to use the bridge configuration; runs - mosq_bridge.conf"
    echo "-i                ReInit the MongoDB parts and job databases"
    echo "-m                Update the MongoDB database with default materials"
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
# Function to install and run Docker
RunDocker(){
    if service_exists docker; then
        echo "Shutting down any old Docker containers"
        docker compose down

        echo "Pulling latest Docker images..."
        docker compose pull

        echo "Starting up the Docker containers..."
        docker compose up --remove-orphans -d
    fi

    # Display logs
    echo "Displaying container logs..."
    docker compose logs mtc_adapter mtc_agent mosquitto ods devctl
}


############################################################
# Updaters                                                 #
############################################################
# Function to update adapter files
Update_Adapter(){
    echo "Checking adapter files..."
    if [[ -d /etc/adapter/config/ ]]; then
        # Check if config file needs updating
        if files_differ "./adapter/config/$Afg_File" "/etc/adapter/config/$Afg_File"; then
            echo "Updating adapter config file..."
            cp -p "./adapter/config/$Afg_File" "/etc/adapter/config/"
        else
            echo "Adapter config file already up to date"
        fi

        # Check if JSON file needs updating
        if files_differ "./adapter/data/$Json_File" "/etc/adapter/data/$Json_File"; then
            echo "Updating adapter JSON file..."
            cp -p "./adapter/data/$Json_File" "/etc/adapter/data/"
        else
            echo "Adapter JSON file already up to date"
        fi

        # Remove any other AFG files so only the selected remains
        if [ -d /etc/adapter/config ]; then
            find /etc/adapter/config -maxdepth 1 -type f -name "*.afg" ! -name "$Afg_File" -exec rm -f {} +
        fi

        # Remove any other JSON files so only the selected remains
        if [ -d /etc/adapter/data ]; then
            find /etc/adapter/data -maxdepth 1 -type f -name "*.json" ! -name "$Json_File" -exec rm -f {} +
        fi

        # Clear logs - always do this
        rm -rf /etc/adapter/log/*
    else
        echo "Installing adapter files..."
        mkdir -p /etc/adapter/
        mkdir -p /etc/adapter/config/
        mkdir -p /etc/adapter/data/
        mkdir -p /etc/adapter/log
        cp -r ./adapter/config/$Afg_File /etc/adapter/config/
        cp -r ./adapter/data/$Json_File /etc/adapter/data/
    fi
    chown -R 1100:1100 /etc/adapter/
}

# Function to update MTConnect Agent files
Update_Agent(){
    echo "Checking MTConnect Agent files..."
    if [[ -f /etc/mtconnect/config/agent.cfg ]]; then
        # Check if agent.cfg needs updating
        if files_differ "./agent/config/agent.cfg" "/etc/mtconnect/config/agent.cfg"; then
            echo "Updating MTConnect Agent configuration..."
            cp -p ./agent/config/agent.cfg /etc/mtconnect/config/
            update_agent_cfg
        else
            echo "MTConnect Agent configuration already up to date"
        fi

        # Check if device file needs updating
        if files_differ "./agent/config/devices/$Device_File" "/etc/mtconnect/config/$Device_File"; then
            echo "Updating MTConnect device file..."
            cp -p ./agent/config/devices/$Device_File /etc/mtconnect/config/
            sed -i "s|<Device[[:space:]].*id=\"saw\".*|        <Device id=\"saw\" uuid=\"HEMSaw-$Serial_Number\" name=\"Saw\">|" /etc/mtconnect/config/"$Device_File"
        else
            echo "MTConnect device file already up to date"
        fi

        # Ensure only the selected device XML remains
        if [ -d /etc/mtconnect/config ]; then
            find /etc/mtconnect/config -maxdepth 1 -type f -name "*.xml" ! -name "$Device_File" -exec rm -f {} +
        fi

        # Check if ruby scripts need updating
        if dir_needs_update "./agent/data/ruby" "/etc/mtconnect/data/ruby"; then
            echo "Updating MTConnect ruby scripts..."
            rm -rf /etc/mtconnect/data/ruby
            mkdir -p /etc/mtconnect/data/ruby
            cp -r ./agent/data/ruby/. /etc/mtconnect/data/ruby/
        else
            echo "MTConnect ruby scripts already up to date"
        fi
    else
        echo "Installing MTConnect Agent files..."
        mkdir -p /etc/mtconnect/
        mkdir -p /etc/mtconnect/config/
        mkdir -p /etc/mtconnect/data/

        cp -p ./agent/config/agent.cfg /etc/mtconnect/config/
        update_agent_cfg
        cp -p ./agent/config/devices/$Device_File /etc/mtconnect/config/
        sed -i "s|<Device[[:space:]].*id=\"saw\".*|        <Device id=\"saw\" uuid=\"HEMSaw-$Serial_Number\" name=\"Saw\">|" /etc/mtconnect/config/"$Device_File"
        cp -r ./agent/data/ruby/. /etc/mtconnect/data/ruby/
    fi

    chown -R 1000:1000 /etc/mtconnect/
}


# Function to update MQTT Broker files
Update_MQTT_Broker(){
    if $run_update_mqtt_bridge; then
        if [[ -d /etc/mqtt/config/ ]]; then
            echo "Checking MQTT bridge files..."

            # Check if mosquitto.conf needs updating
            if files_differ "./mqtt/config/mosq_bridge.conf" "/etc/mqtt/config/mosquitto.conf"; then
                echo "Updating MQTT bridge configuration..."
                cp -p ./mqtt/config/mosq_bridge.conf /etc/mqtt/config/mosquitto.conf
                update_remote_clientid
            else
                echo "MQTT bridge configuration already up to date"
            fi

            # Check if ACL needs updating
            if files_differ "./mqtt/data/acl" "/etc/mqtt/data/acl"; then
                echo "Updating MQTT bridge ACL..."
                cp -r ./mqtt/data/acl /etc/mqtt/data/acl
                chmod 0700 /etc/mqtt/data/acl
            else
                echo "MQTT bridge ACL already up to date"
            fi

            # Check if certs need updating
            if dir_needs_update "./mqtt/certs" "/etc/mqtt/certs"; then
                echo "Updating MQTT certificates..."
                rm -rf /etc/mqtt/certs
                mkdir -p /etc/mqtt/certs
                cp -r ./mqtt/certs/. /etc/mqtt/certs/
            else
                echo "MQTT certificates already up to date"
            fi
        else
            echo "Installing MQTT bridge files"
            mkdir -p /etc/mqtt/config/
            mkdir -p /etc/mqtt/data/
            mkdir -p /etc/mqtt/certs/

            # Load the Broker UUID
            cp -p ./mqtt/config/mosq_bridge.conf /etc/mqtt/config/mosquitto.conf
            update_remote_clientid

            cp -r ./mqtt/data/acl /etc/mqtt/data/acl
            cp -r ./mqtt/certs/. /etc/mqtt/certs/
            chmod 0700 /etc/mqtt/data/acl
        fi
    else
        if [[ -d /etc/mqtt/config/ ]]; then
            echo "Checking MQTT files..."

            # Check if mosquitto.conf needs updating
            if files_differ "./mqtt/config/mosquitto.conf" "/etc/mqtt/config/mosquitto.conf"; then
                echo "Updating MQTT configuration..."
                cp -r ./mqtt/config/mosquitto.conf /etc/mqtt/config/
            else
                echo "MQTT configuration already up to date"
            fi

            # Check if ACL needs updating
            if files_differ "./mqtt/data/acl" "/etc/mqtt/data/acl"; then
                echo "Updating MQTT ACL..."
                cp -r ./mqtt/data/acl /etc/mqtt/data/
                chmod 0700 /etc/mqtt/data/acl
            else
                echo "MQTT ACL already up to date"
            fi
        else
            echo "Installing MQTT files..."
            mkdir -p /etc/mqtt/config/
            mkdir -p /etc/mqtt/data/
            cp -r ./mqtt/config/mosquitto.conf /etc/mqtt/config/
            cp -r ./mqtt/data/acl /etc/mqtt/data/
            chmod 0700 /etc/mqtt/data/acl
        fi
    fi
}

# Function to update ODS files
Update_ODS(){
    echo "Checking ODS files..."
    if [[ -d /etc/ods/config/ ]]; then
        # Check if ODS config needs updating
        if dir_needs_update "./ods/config" "/etc/ods/config"; then
            echo "Updating ODS configuration..."
            rm -rf /etc/ods/config
            mkdir -p /etc/ods/config
            cp -r ./ods/config/. /etc/ods/config/
        else
            echo "ODS configuration already up to date"
        fi
    else
        echo "Installing ODS files..."
        mkdir -p /etc/ods/config/
        cp -r ./ods/config/. /etc/ods/config
    fi
    chown -R 1200:1200 /etc/ods/
}

# Function to update Devctl files
Update_Devctl(){
    echo "Checking Devctl files..."
    if [[ -d /etc/devctl/config/ ]] && [[ -d /etc/devctl/logs/ ]]; then
        # Check if DevCTL config needs updating
        if files_differ "./devctl/config/$DevCTL_File" "/etc/devctl/config/devctl_json_config.json"; then
            echo "Updating Devctl configuration..."
            cp -p ./devctl/config/$DevCTL_File /etc/devctl/config/devctl_json_config.json
            sed -i "s|\"device_uid\"[[:space:]]*:.*|        \"device_uid\" : \"HEMSaw-$Serial_Number\",|" /etc/devctl/config/devctl_json_config.json
        else
            echo "Devctl configuration already up to date"
        fi
    else
        echo "Installing Devctl..."
        mkdir -p /etc/devctl/
        mkdir -p /etc/devctl/config/
        mkdir -p /etc/devctl/logs/
        cp -p ./devctl/config/$DevCTL_File /etc/devctl/config/devctl_json_config.json
        sed -i "s|\"device_uid\"[[:space:]]*:.*|        \"device_uid\" : \"HEMSaw-$Serial_Number\",|" /etc/devctl/config/devctl_json_config.json
    fi
    chown -R 1300:1300 /etc/devctl/
}

# Function to update MongoDB files
Update_Mongodb(){
    echo "Checking MongoDB files..."
    if [[ -d /etc/mongodb/config/ ]]; then
        # Check if MongoDB config needs updating
        if dir_needs_update "./mongodb/config" "/etc/mongodb/config"; then
            echo "Updating MongoDB configuration..."
            rm -rf /etc/mongodb/config
            mkdir -p /etc/mongodb/config
            cp -r ./mongodb/config/. /etc/mongodb/config/
        else
            echo "MongoDB configuration already up to date"
        fi

        # Check if MongoDB data needs updating
        if dir_needs_update "./mongodb/data" "/etc/mongodb/data"; then
            echo "Updating MongoDB data files..."
            rm -rf /etc/mongodb/data
            mkdir -p /etc/mongodb/data
            cp -r ./mongodb/data/. /etc/mongodb/data/
        else
            echo "MongoDB data files already up to date"
        fi
    else
        echo "Installing MongoDB files..."
        mkdir -p /etc/mongodb/
        mkdir -p /etc/mongodb/config/
        mkdir -p /etc/mongodb/data/
        mkdir -p /etc/mongodb/data/db
        cp -r ./mongodb/config/. /etc/mongodb/config/
        cp -r ./mongodb/data/. /etc/mongodb/data/
    fi
    chown -R 1000:1000 /etc/mongodb/
}

# Function to initialize jobs and parts
Init_Jobs_Parts(){
    echo "Reseting the Parts and Jobs..."
    ensure_venv || return 1
    /etc/mongodb/venv/bin/python /etc/mongodb/data/jobs_parts_init.py
}

# Function to update the materials to default stored in the csv
Update_Materials(){
    echo "Updating or reseting the materials to default..."
    ensure_venv || return 1
    /etc/mongodb/venv/bin/python /etc/mongodb/data/upload_materials.py
}

############################################################
############################################################
# Main program                                             #
############################################################
############################################################

if [[ $(id -u) -ne 0 ]] ; then echo "Please run ssUpgrade.sh as sudo" ; exit 1 ; fi

## Set default variables
# Source the env.sh file
if [[ -f "$SCRIPT_DIR/env.sh" ]]; then
    set -a
    source "$SCRIPT_DIR/env.sh"
    set +a
else
    echo "env.sh file not found. Using default values."
    Afg_File="SmartSaw_DC_HA.afg"
    Json_File="SmartSaw_alarms.json"
    Device_File="SmartSaw_DC_HA.xml"
    Serial_Number="SmartSaw"
    DevCTL_File="devctl_json_config.json"
fi

run_update_adapter=false
run_update_agent=false
run_update_mqtt_broker=false
run_update_mqtt_bridge=false
run_update_ods=false
run_update_devctl=false
run_update_mongodb=false
run_update_materials=false
run_init_jp=false
run_install=false
run_full_update=false

#####################################################
# Process the input options. Add options as needed. #
#####################################################

validate_args "$@" || { Help; exit 1; }

# Get the options
while getopts ":a:j:d:c:u:Ahbmi" option; do
    case ${option} in
        h) # display Help
            Help
            exit;;
        A) # Update All Containers
            run_full_update=true;;
        a) # Enter an AFG file name
            Afg_File=$OPTARG
            [[ -f "$SCRIPT_DIR/env.sh" ]] && sed -i "s|^export Afg_File=.*|export Afg_File=\"$Afg_File\"|" "$SCRIPT_DIR/env.sh";;
        j) # Enter JSON file name
            Json_File=$OPTARG;
            [[ -f "$SCRIPT_DIR/env.sh" ]] && sed -i "s|^export Json_File=.*|export Json_File=\"$Json_File\"|" "$SCRIPT_DIR/env.sh";;
        d) # Enter a Device file name
            Device_File=$OPTARG
            [[ -f "$SCRIPT_DIR/env.sh" ]] && sed -i "s|^export Device_File=.*|export Device_File=\"$Device_File\"|" "$SCRIPT_DIR/env.sh";;
        c) # Enter a Device file name
            DevCTL_File=$OPTARG
            [[ -f "$SCRIPT_DIR/env.sh" ]] && sed -i "s|^export DevCTL_File=.*|export DevCTL_File=\"$DevCTL_File\"|" "$SCRIPT_DIR/env.sh";;
        u) # Enter a serial number for the UUID
            Serial_Number=$OPTARG
            [[ -f "$SCRIPT_DIR/env.sh" ]] && sed -i "s|^export Serial_Number=.*|export Serial_Number=\"$Serial_Number\"|" "$SCRIPT_DIR/env.sh"
            # Serial changes must propagate to all configs; trigger a full update
            run_full_update=true;;
        m) # Update Mongodb materials
            run_update_materials=true;;
        i) # Init Mongodb jobs and parts
            run_init_jp=true;;
        b) # Enter MQTT Bridge file name
            run_update_mqtt_bridge=true
            if [[ -f "$SCRIPT_DIR/env.sh" ]]; then
                if grep -q "^export Use_MQTT_Bridge=" "$SCRIPT_DIR/env.sh"; then
                    sed -i "s|^export Use_MQTT_Bridge=.*|export Use_MQTT_Bridge=\"true\"|" "$SCRIPT_DIR/env.sh"
                else
                    echo 'export Use_MQTT_Bridge="true"' >> "$SCRIPT_DIR/env.sh"
                fi
            fi
            ;;
        \?) # Invalid option
            echo "ERROR[1] - Invalid option chosen: -$OPTARG"
            echo "Use -h for help and list of valid options"
            Help
            exit 1;;
    esac
done

# Check for any remaining unprocessed arguments that might be malformed options
shift $((OPTIND-1))
if [[ $# -gt 0 ]]; then
    for remaining_arg in "$@"; do
        if [[ "$remaining_arg" =~ ^[A-Za-z]$ ]]; then
            echo "ERROR[1] - Unrecognized argument '$remaining_arg'"
            echo "Did you mean to use '-$remaining_arg'?"
            echo "Check for spaces between dash and option letters"
            Help
            exit 1
        fi
    done
fi

# Expand a full-update request into individual component flags
if $run_full_update; then
    run_update_mqtt_broker=true
    run_update_adapter=true
    run_update_agent=true
    run_update_ods=true
    run_update_devctl=true
    run_update_mongodb=true
fi

# If doing a full update and bridge mode wasn't explicitly toggled,
# restore the persisted preference from env.sh.
if $run_full_update && [[ "${Use_MQTT_Bridge:-false}" == "true" ]]; then
    run_update_mqtt_bridge=true
fi

# Require Docker Compose v2 - install if not present
if ! docker compose version &> /dev/null; then
    echo "Docker Compose v2 not found, installing docker-compose-v2..."
    apt update --fix-missing && apt install -y docker-compose-v2 --fix-missing
    apt clean
    if ! docker compose version &> /dev/null; then
        echo "ERROR: Failed to install docker-compose-v2. Please install it manually: apt install docker-compose-v2"
        exit 1
    fi
fi

# check if install or upgrade
if [[ ! -f /etc/mtconnect/config/agent.cfg ]]; then
    echo 'MTConnect agent.cfg not found, running bash ssInstall.sh instead'; run_install=true
else
    echo 'MTConnect agent.cfg found, continuing upgrade...'
fi

echo ""

# check if systemd services are running
if systemctl is-active --quiet adapter || systemctl is-active --quiet ods || systemctl is-active --quiet mongod; then
    echo "Adapter, ODS and/or Mongodb is running as a systemd service, stopping the systemd services..."
    echo " -- Recommend running 'sudo bash ssClean.sh -d' to disable the daemons for future updates"
    systemctl stop adapter
    systemctl stop ods
    systemctl stop mongod
fi

###############################################
# Continue Main program                       #
###############################################

if $run_install; then
    echo "Running Install script..."
    bash "$SCRIPT_DIR/ssInstall.sh" -a "$Afg_File" -j "$Json_File" -d "$Device_File" -c "$DevCTL_File" -u "$Serial_Number" ${Use_MQTT_Bridge:+-b}
else
    echo "Printing the options..."
    echo "Update Adapter set to run = "$run_update_adapter
    echo "Update MTConnect Agent set to run = "$run_update_agent
    echo "Update MQTT Broker set to run = "$run_update_mqtt_broker
    echo "Update MQTT Bridge set to run = "$run_update_mqtt_bridge
    echo "Update ODS set to run = "$run_update_ods
    echo "Update Devctl set to run = "$run_update_devctl
    echo "Update Mongodb set to run = "$run_update_mongodb
    echo "Update Materials set to run = "$run_update_materials
    echo "Init Jobs and Parts set to run = "$run_init_jp
    echo "Docker Compose Version = 2"
    echo ""

    echo "Printing the settings..."
    echo "AFG file = "$Afg_File
    echo "JSON file = "$Json_File
    echo "MTConnect Agent file = "$Device_File
    echo "MTConnect UUID = HEMSaw-"$Serial_Number
    echo "Device Control file = "$DevCTL_File
    echo ""

    # check if files are correct
    if [[ ! -f ./agent/config/devices/$Device_File ]]; then
        echo 'ERROR[1] - MTConnect device file not found, check file name! Exiting install...'
        echo "Available MTConnect Device files..."
        ls agent/config/devices
        exit 1
    fi
    if [[ ! -f ./adapter/config/$Afg_File ]]; then
        echo 'ERROR[1] - Adapter config file not found, check file name! Exiting install...'
        echo "Available Adapter config files..."
        ls adapter/config
        exit 1
    fi
    if [[ ! -f ./adapter/data/$Json_File ]]; then
        echo 'ERROR[1] - Adapter alarm json file not found, check file name! Exiting install...'
        echo "Available Adapter alarm json files..."
        ls adapter/data
        exit 1
    fi
    if [[ ! -f ./devctl/config/$DevCTL_File ]]; then
        echo 'ERROR[1] - Device Control file not found, check file name! Exiting install...'
        echo "Available Device Control files..."
        ls devctl/config
        exit 1
    fi

    # Shutdown any old Docker containers before updating files
    if service_exists docker; then
        echo "Shutting down any old Docker containers"
        docker compose down
    fi
    echo ""

    # Run update functions in parallel
    declare -A PIDS=()
    if $run_update_adapter; then
        Update_Adapter &
        PIDS[adapter]=$!
    fi
    if $run_update_agent; then
        Update_Agent &
        PIDS[agent]=$!
    fi
    if $run_update_mqtt_broker || $run_update_mqtt_bridge; then
        Update_MQTT_Broker &
        PIDS[mqtt]=$!
    fi
    if $run_update_ods; then
        Update_ODS &
        PIDS[ods]=$!
    fi
    if $run_update_devctl; then
        Update_Devctl &
        PIDS[devctl]=$!
    fi
    if $run_update_mongodb; then
        Update_Mongodb &
        PIDS[mongodb]=$!
    fi

    # Wait for all background processes to complete
    failed=0
    for name in "${!PIDS[@]}"; do
        if ! wait "${PIDS[$name]}"; then
            echo "ERROR: $name update failed" >&2
            failed=1
        else
            echo "$name update completed"
        fi
    done
    (( failed )) && exit 1

    echo ""
    # Run Docker after all updates
    RunDocker

    echo ""
    # These operations are sequential as they depend on the running containers
    if $run_init_jp; then
        Init_Jobs_Parts
    fi
    if $run_update_materials; then
        Update_Materials
    fi
fi

echo ""
echo "Check to verify containers are running:"

# Smart pruning instead of aggressive pruning
# Only prune containers that haven't been used in the last 24 hours
# and always prune volumes that aren't being used by any containers
echo "Pruning unused Docker resources (older than 24h)..."
if docker system prune --filter "until=24h" --force > /dev/null; then
    echo "Container pruning completed successfully"
else
    echo "No containers to prune or pruning failed"
fi

# Always prune unused volumes
echo "Pruning unused Docker volumes..."
if docker volume prune --force > /dev/null; then
    echo "Volume pruning completed successfully"
else
    echo "No volumes to prune or pruning failed"
fi

docker ps
