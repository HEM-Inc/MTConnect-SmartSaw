#!/bin/sh

############################################################
# Help                                                     #
############################################################
Help(){
    # Display Help
    echo "This function installs the systemd files for the HEMsaw Adapter and the Agent."
    echo "To securly set up the agent an mtconnect user and group is created. The agent"
    echo "is run using this mtconnect group so that it has lower permissions, while the"
    echo "adapter is run using the default permissions."
    echo
    echo "Syntax: agent_install [-h|-a File_Name|-d File_Name|-c File_Name|-s Serial_number]"
    echo "options:"
    echo "-h             Print this Help."
    echo "-a File_Name   Declare the afg file name; Defaults to - SmartSaw_DC_HA.afg"
    echo "-d File_Name   Declare the MTConnect agent device file name; Defaults to - SmartSaw_DC_HA.xml"
    echo "-c File_Name   Declare the config file name; Defaults to - mosquitto.conf"
    echo "-s Serial_number   Declare the serial number for the uuid; Defaults to - SmartSaw"
}

############################################################
############################################################
# Main program                                             #
############################################################
############################################################

if [[ $(id -u) -ne 0 ]] ; then echo "Please run agent_install.sh as sudo" ; exit 1 ; fi

if id "mtconnect" &>/dev/null; 
    then echo 'mtconnect user found, run bash agent_update.sh instead'; exit 1 
else
    echo 'User not found, continuing install...'
fi

# Set default variables
Afg_File="SmartSaw_DC_HA.afg"
Device_File="SmartSaw_DC_HA.xml"
Mqtt_Config_File="mosquitto.conf"
Serial_Number="SmartSaw"

############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options
while getopts ":a:d:c:s:h" option; do
    case ${option} in
        h) # display Help
            Help
            exit;;
        a) # Enter an AFG file name
            Afg_File=$OPTARG;;
        d) # Enter a Device file name
            Device_File=$OPTARG;;
        c) # Enter a Config file name
            Mqtt_Config_File=$OPTARG;;
        s) # Enter a serial number for the UUID
            Serial_Number=$OPTARG;;
        \?) # Invalid option
            Help
            exit;;
    esac
done


echo "Printing the Working Directory and options..."
echo "Present directory = " pwd
echo "AFG file = "$Afg_File
echo "MTConnect Agent file = "$Device_File
echo "Mosquitto Config file = "$Mqtt_Config_File
echo "MTConnect UUID = HEMSaw_"$Serial_Number
echo ""

echo "Installing MTConnect Adapter and setting it as a SystemCTL..."

mkdir -p /etc/adapter/
cp -r ./adapter/. /etc/adapter/
cp -r ./afg/$Afg_File /etc/adapter/
chmod +x /etc/adapter/Adapter

cp /etc/adapter/adapter.service /etc/systemd/system/
systemctl enable adapter
systemctl start adapter
systemctl status adapter

echo "MTConnect Adapter Up and Running"

echo "Installing MTConnect and setting it as a SystemCTL..."

useradd -r -s /bin/false mtconnect
mkdir /var/log/mtconnect
chown mtconnect:mtconnect /var/log/mtconnect

mkdir -p /etc/mtconnect/
mkdir -p /etc/mtconnect/agent/
mkdir -p /etc/mtconnect/devices/
mkdir -p /etc/mtconnect/schema/
mkdir -p /etc/mtconnect/styles/
cp agent/agent /usr/bin/
chmod +x /usr/bin/agent

cp -r ./agent/. /etc/mtconnect/agent/
sed -i '1 i\Devices = ../devices/'$Device_File /etc/mtconnect/agent/agent.cfg
cp -r ./devices/$Device_File /etc/mtconnect/devices/
sed -i "11 i\        <Device id=\"saw\" uuid=\"HEMSaw_$Serial_Number\" name=\"Saw\">" /etc/mtconnect/devices/$Device_File
cp -r ./schema/. /etc/mtconnect/schema/
cp -r ./styles/. /etc/mtconnect/styles/
cp -r ./ruby/. /etc/mtconnect/ruby/
chown -R mtconnect:mtconnect /etc/mtconnect

cp /etc/mtconnect/agent/agent.service /etc/systemd/system/
systemctl enable agent
systemctl start agent
systemctl status agent

echo "MTConnect Agent Up and Running"

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