#!/bin/sh

############################################################
# Help                                                     #
############################################################
Help(){
    # Display Help
    echo "This function installs the systemd files for the mosquitto service."
    echo
    echo "Syntax: mosquitto_update [-h|-c File_Name]"
    echo "options:"
    echo "-h             Print this Help."
    echo "-c File_Name   Declare the config file name; Defaults to - mosquitto.conf"
    echo "-u             Upgrade the mosquitto program"
}

############################################################
# UpgradeBroker                                            #
############################################################
UpgradeBroker(){
    apt update
    apt upgrade mosquitto mosquitto-clients
    apt clean
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
while getopts ":u:c:h" option; do
    case ${option} in
        h) # display Help
            Help
            exit;;
        u) # Enter an AFG file name
            UpgradeBroker;;
        c) # Enter a Device file name
            Config_File=$OPTARG;;
        \?) # Invalid option
            Help
            exit;;
    esac
done

echo "Printing the Working Directory and options..."
echo "Config file = "$Config_File

cp ./mqtt/$Config_File /etc/mosquitto/conf.d/


service mosquitto stop && service mosquitto start && service mosquitto status