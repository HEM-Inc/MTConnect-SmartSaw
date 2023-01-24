#!/bin/sh

############################################################
# Help                                                     #
############################################################
Help(){
    # Display Help
    echo "This function installs the systemd files for the mosquitto service."
    echo
    echo "Syntax: mosquitto_install [-h|-c File_Name]"
    echo "options:"
    echo "-h             Print this Help."
    echo "-c File_Name   Declare the config file name; Defaults to - mosquitto.conf"
}

############################################################
############################################################
# Main program                                             #
############################################################
############################################################

if [[ $(id -u) -ne 0 ]] ; then echo "Please run mosquitto_install.sh as sudo" ; exit 1 ; fi

Config_File="mosquitto.conf"

############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options
while getopts ":d:h" option; do
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

echo "Adding the mosquitto service..."
# apt-add-repository ppa:mosquitto-dev/mosquitto-ppa
apt update
apt install mosquitto mosquitto-clients
apt clean

# add hemsaw to access control
touch /etc/mosquitto/passwd
sudo mosquitto_passwd -b /etc/mosquitto/passwd mtconnect mtconnect
cp ./mqtt/acl /etc/mosquitto/acl

echo "Printing the options..."
echo "Config file = "$Config_File

cp ./mqtt/$Config_File /etc/mosquitto/conf.d/

sudo service mosquitto stop && sudo service mosquitto start && sudo service mosquitto status