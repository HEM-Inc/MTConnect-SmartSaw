#!/bin/sh

############################################################
# Help                                                     #
############################################################
Help(){
    # Display Help
    echo "This function installs the systemd files for the mosquitto service."
    echo
    echo "Syntax: mosquitto_update [-h|-a|-c File_Name]"
    echo "options:"
    echo "-h             Print this Help."
    echo "-a             Re-add the ACL and restart with updated ACL"
    echo "-c File_Name   Declare the config file name; Defaults to - mosquitto.conf"
}

############################################################
# ACL                                                     #
############################################################
Update_ACL(){
    # Re-add the ACL and restart with updated ACL
    echo "Re-adding the access control list"
    # mosquitto_passwd -b /etc/mosquitto/passwd mtconnect mtconnect
    cp ./mqtt/acl /etc/mosquitto/acl
}

############################################################
############################################################
# Main program                                             #
############################################################
############################################################

if [[ $(id -u) -ne 0 ]] ; then echo "Please run mosquitto_update.sh as sudo" ; exit 1 ; fi

Config_File="mosquitto.conf"

############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options
while getopts ":c:ah" option; do
    case ${option} in
        h) # display Help
            Help
            exit;;
        a) # Re-add the ACL and restart with updated ACL
            Update_ACL
            ;;
        c) # Enter a Device file name
            Config_File=$OPTARG;;
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

echo "Printing the options..."
echo "Config file = "$Config_File

if service_exists mosquitto; then
    echo "Updating Mosquitto..."
    cp ./mqtt/$Config_File /etc/mosquitto/conf.d/

    systemctl stop mosquitto
    systemctl start mosquitto
    systemctl status mosquitto

    echo "Mosquitto Updated and Running"
else
    echo "Installing the mosquitto service..."
    # apt-add-repository ppa:mosquitto-dev/mosquitto-ppa
    apt update -y
    apt install mosquitto mosquitto-clients
    apt clean

    echo "Adding mtconnect user to access control list"
    touch /etc/mosquitto/passwd
    mosquitto_passwd -b /etc/mosquitto/passwd mtconnect mtconnect
    cp ./mqtt/acl /etc/mosquitto/acl

    cp ./mqtt/$Mqtt_Config_File /etc/mosquitto/conf.d/

    systemctl stop mosquitto
    systemctl start mosquitto
    systemctl status mosquitto

    echo "Mosquitto MQTT Broker Up and Running"
fi




