#!/bin/sh

############################################################
# Help                                                     #
############################################################
Help(){
    # Display Help
    echo "This function installs the HEMSaw MTConnect-SmartAdapter, ODS, Devctl, MTconnect Agent and MQTT."
    echo
    echo "Syntax: ssInstall.sh [-h|-a File_Name|-j File_Name|-d File_Name|-c File_Name|-u Serial_number|-f]"
    echo "options:"
    echo "-a File_Name          Declare the afg file name; Defaults to - SmartSaw_DC_HA.afg"
    echo "-j File_Name          Declare the JSON file name; Defaults to - SmartSaw_alarms.json"
    echo "-d File_Name          Declare the MTConnect agent device file name; Defaults to - SmartSaw_DC_HA.xml"
    echo "-c File_Name          Declare the Device control config file name; Defaults to - devctl_json_config.json"
    echo "-u Serial_number      Declare the serial number for the uuid; Defaults to - SmartSaw"
    echo "-b                    Use the MQTT bridge configuration file name; Defaults to - mosq_bridge.conf"
    echo "-f                    Force install of the files"
    echo "-h                    Print this Help."
    echo "AFG files"
    ls adapter/config/
    echo ""
    echo "MTConnect Device files"
    ls agent/config/devices
    echo ""
}

############################################################
# Utilities                                                #
############################################################
# Function to check if a service exists
service_exists() {
    local n=$1
    if [[ $(systemctl list-units --all -t service --full --no-legend "$n.service" | sed 's/^\s*//g' | cut -f1 -d' ') == $n.service ]]; then
        return 0
    else
        return 1
    fi
}

############################################################
# Installers                                               #
############################################################

InstallAdapter(){
    echo "Installing MTConnect Adapter..."

    mkdir -p /etc/adapter/
    mkdir -p /etc/adapter/config/
    mkdir -p /etc/adapter/data/
    mkdir -p /etc/adapter/log/
    cp -p ./adapter/config/$Afg_File /etc/adapter/config/
    cp -p ./adapter/data/$Json_File /etc/adapter/data/
    chown -R 1100:1100 /etc/adapter/

    echo "MTConnect Adapter Up and Running"
}

InstallMTCAgent(){
    echo "Moving MTConnect Files..."
    mkdir -p /etc/mtconnect/
    mkdir -p /etc/mtconnect/config/
    mkdir -p /etc/mtconnect/data/

    cp -p ./agent/config/agent.cfg /etc/mtconnect/config/
    sed -i '1 i\Devices = /mtconnect/config/'$Device_File /etc/mtconnect/config/agent.cfg
    cp -p ./agent/config/devices/$Device_File /etc/mtconnect/config/
    sed -i "11 s|.*|        <Device id=\"saw\" uuid=\"HEMSaw-$Serial_Number\" name=\"Saw\">|" /etc/mtconnect/config/$Device_File
    cp -r ./agent/data/ruby/. /etc/mtconnect/data/ruby/

    chown -R 1000:1000 /etc/mtconnect/


    if $Use_MQTT_Bridge; then
        if [[ -d /etc/mqtt/config/ ]]; then
            echo "Updating MQTT bridge files"

            # Load the Broker UUID
            cp -p ./mqtt/config/mosq_bridge.conf /etc/mqtt/config/mosquitto.conf
            sed -i "27 i\remote_clientid HEMSaw-$Serial_Number" /etc/mqtt/config/mosquitto.conf

            cp -p ./mqtt/data/acl /etc/mqtt/data/acl
            cp -r ./mqtt/certs/. /etc/mqtt/certs/
            chmod 0700 /etc/mqtt/data/acl
        else
            echo "Installing MQTT bridge files"
            mkdir -p /etc/mqtt/config/
            mkdir -p /etc/mqtt/data/
            mkdir -p /etc/mqtt/certs/

            # Load the Broker UUID
            cp -p ./mqtt/config/mosq_bridge.conf /etc/mqtt/config/mosquitto.conf
            sed -i "27 i\remote_clientid HEMSaw-$Serial_Number" /etc/mqtt/config/mosquitto.conf

            cp -p ./mqtt/data/acl /etc/mqtt/data/acl
            cp -r ./mqtt/certs/. /etc/mqtt/certs/
            chmod 0700 /etc/mqtt/data/acl
        fi
    else
        if [[ -d /etc/mqtt/config/ ]]; then
            echo "Updating MQTT files..."
            cp -p ./mqtt/config/mosquitto.conf /etc/mqtt/config/
            cp -p ./mqtt/data/acl /etc/mqtt/data/
            chmod 0700 /etc/mqtt/data/acl
        else
            echo "Updating MQTT files..."
            mkdir -p /etc/mqtt/config/
            mkdir -p /etc/mqtt/data/
            cp -p ./mqtt/config/mosquitto.conf /etc/mqtt/config/
            cp -p ./mqtt/data/acl /etc/mqtt/data/
            chmod 0700 /etc/mqtt/data/acl
        fi
    fi
}

InstallODS(){
    echo "Installing ODS..."
    mkdir -p /etc/ods/
    mkdir -p /etc/ods/config/
    cp -r ./ods/config/* /etc/ods/config/
    chown -R 1200:1200 /etc/ods/
}

InstallDevctl(){
    echo "Installing Devctl..."
    mkdir -p /etc/devctl/
    mkdir -p /etc/devctl/config/
    mkdir -p /etc/devctl/logs/
    cp -r ./devctl/config/* /etc/devctl/config/
    sed -i "18 s|.*|        \"device_uid\" : \"HEMSaw-$Serial_Number\",|" /etc/devctl/config/devctl_json_config.json
    chown -R 1300:1300 /etc/devctl/
}

InstallMongodb(){
    echo "Installing Mongodb..."
    mkdir -p /etc/mongodb/
    mkdir -p /etc/mongodb/config/
    mkdir -p /etc/mongodb/data/
    mkdir -p /etc/mongodb/data/db
    cp -r ./mongodb/config/* /etc/mongodb/config/
    cp -r ./mongodb/data/* /etc/mongodb/data/
    chown -R 1000:1000 /etc/mongodb/

    if command -v pip3 &> /dev/null; then
        pip3 install pyaml --break-system-packages
        pip3 install pymongo --break-system-packages
    fi
}


############################################################
############################################################
# Main program                                             #
############################################################
############################################################

if [[ $(id -u) -ne 0 ]] ; then echo "Please run ssInstall.sh as sudo" ; exit 1 ; fi

if systemctl is-active --quiet adapter || systemctl is-active --quiet ods || systemctl is-active --quiet mongod; then
    echo "Adapter, ODS and/or Mongodb is running as a systemd service, stopping the systemd services.."
    systemctl stop adapter
    systemctl stop ods
    systemctl stop mongod
fi

## Set default variables
# Source the env.sh file
if [[ -f "./env.sh" ]]; then
    set -a
    source ./env.sh
    set +a
else
    echo "env.sh file not found. Using default values."
    Afg_File="SmartSaw_DC_HA.afg"
    Json_File="SmartSaw_alarms.json"
    Device_File="SmartSaw_DC_HA.xml"
    Serial_Number="SmartSaw"
    DevCTL_File="devctl_json_config.json"
fi

Use_MQTT_Bridge=false
force_install_files=false

# Process the input options. Add options as needed.
############################################################

# Validate arguments for common mistakes
for arg in "$@"; do
    if [[ "$arg" == "-" ]]; then
        echo "ERROR[1] - Invalid option format: standalone dash detected"
        echo "Did you use a space between dash and option letter?"
        echo "Correct format: -d (not - d)"
        Help
        exit 1
    fi
done

# Check for standalone letters that might be mistyped options
for arg in "$@"; do
    if [[ "$arg" =~ ^[A-Za-z]$ ]]; then
        echo "ERROR[1] - Standalone letter '$arg' detected"
        echo "Did you mean to use '-$arg' instead of '- $arg'?"
        echo "Options should have no space between the dash and letter"
        Help
        exit 1
    fi
done

# Get the options
while getopts ":a:j:d:c:u:bhf" option; do
    case ${option} in
        h) # display Help
            Help
            exit;;
        a) # Enter an AFG file name
            Afg_File=$OPTARG
            [[ -f env.sh ]] && sed -i "4 s|.*|export Afg_File=\"$Afg_File\"|" env.sh;;
        j) # Enter JSON file name
            Json_File=$OPTARG;
            [[ -f env.sh ]] && sed -i "5 s|.*|export Json_File=\"$Json_File\"|" env.sh;;
        d) # Enter a Device file name
            Device_File=$OPTARG
            [[ -f env.sh ]] && sed -i "6 s|.*|export Device_File=\"$Device_File\"|" env.sh;;
        c) # Enter a Device file name
            DevCTL_File=$OPTARG
            [[ -f env.sh ]] && sed -i "8 s|.*|export DevCTL_File=\"$DevCTL_File\"|" env.sh;;
        u) # Enter a serial number for the UUID
            Serial_Number=$OPTARG
            [[ -f env.sh ]] && sed -i "7 s|.*|export Serial_Number=\"$Serial_Number\"|" env.sh;;
        b) # Run MQTT Bridge
            Use_MQTT_Bridge=true;;
        f) # Force install files
            force_install_files=true;;
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

# Require Docker Compose v2 - install if not present
if ! docker compose version &> /dev/null; then
    echo "Docker Compose v2 not found, installing docker-compose-v2..."
    apt update --fix-missing && apt install -y docker-compose-v2 --fix-missing
    apt clean
    if ! docker compose version &> /dev/null; then
        echo "ERROR: Failed to install docker-compose-v2."
        echo "Please install it manually: apt install docker-compose-v2 on Ubuntu"
        exit 1
    fi
fi

###############################################
# Continue Main program                       #
###############################################

echo "Printing the Working Directory and options..."
echo "AFG file = "$Afg_File
echo "JSON file = "$Json_File
echo "MTConnect Agent file = "$Device_File
echo "MTConnect UUID = HEMSaw-"$Serial_Number
echo "Device Control file = "$DevCTL_File
echo "Docker Compose Version = 2"
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

if service_exists docker; then
    echo "Shutting down any old Docker containers"
    docker compose down
fi
echo ""

InstallAdapter
InstallMTCAgent
InstallODS
InstallDevctl
InstallMongodb
echo ""

echo "Starting up the Docker image"
docker compose up --remove-orphans -d
docker compose logs

echo ""
python3 /etc/mongodb/data/jobs_parts_init.py
python3 /etc/mongodb/data/upload_materials.py


echo ""
echo "Check to verify containers are running:"
docker ps
