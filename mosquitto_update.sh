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
while getopts ":c:h" option; do
    case ${option} in
        h) # display Help
            Help
            exit;;
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

systemctl stop mosquitto
systemctl start mosquitto
systemctl status mosquitto

echo "Mosquitto Updated and Running"