#!/bin/sh

############################################################
# Help                                                     #
############################################################
Help(){
    # Display Help
    echo "This function updates the systemd files for the HEMsaw Adapter and the Agent."
    echo "Any associated device files for MTConnect and Adapter files are updated as per this repo."
    echo
    echo "Syntax: agent_update [-h|-a File_Name|-d File_Name]"
    echo "options:"
    echo "-h             Print this Help."
    echo "-a File_Name   Declare the afg file name; Defaults to - SmartSaw_DC_HA.afg"
    echo "-d File_Name   Declare the MTConnect agent device file name; Defaults to - SmartSaw_DC_HA.xml"
    echo "-s Serial_number   Declare the serial number for the uuid; Defaults to - SmartSaw"
}

############################################################
############################################################
# Main program                                             #
############################################################
############################################################

if [[ $(id -u) -ne 0 ]] ; then echo "Please run agent_update.sh as sudo" ; exit 1 ; fi

# Set default variables
Afg_File="SmartSaw_DC_HA.afg"
Device_File="SmartSaw_DC_HA.xml"
Serial_Number="SmartSaw"

############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options
while getopts ":a:d:s:h" option; do
    case ${option} in
        h) # display Help
            Help
            exit;;
        a) # Enter an AFG file name
            Afg_File=$OPTARG;;
        d) # Enter a Device file name
            Device_File=$OPTARG;;
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
echo "MTConnect UUID = HEMSaw_"$Serial_Number
echo ""

echo "Updating MTConnect Adapter..."

systemctl stop adapter
cp -r ./adapter/. /etc/adapter/
rm -rf /etc/adapter/SmartSaw_*.afg
cp -r ./afg/$Afg_File /etc/adapter/
chmod +x /etc/adapter/Adapter
cp /etc/adapter/adapter.service /etc/systemd/system/

systemctl daemon-reload
systemctl start adapter
systemctl status adapter

echo "MTConnect Adapter Up and Running"
echo ""

echo "Updating MTConnect Agent..."

systemctl stop agent
cp -r ./agent/. /etc/mtconnect/agent/
sed -i '1 i\Devices = ../devices/'$Device_File /etc/mtconnect/agent/agent.cfg
rm -rf /etc/mtconnect/devices/SmartSaw_*.xml
cp -r ./devices/$Device_File /etc/mtconnect/devices/
sed -i "11 i\        <Device id=\"saw\" uuid=\"HEMSaw_$Serial_Number\" name=\"Saw\">" /etc/mtconnect/devices/$Device_File
cp -r ./schema/. /etc/mtconnect/schema/
cp -r ./styles/. /etc/mtconnect/styles/
cp -r ./ruby/. /etc/mtconnect/ruby/
chown -R mtconnect:mtconnect /etc/mtconnect
cp agent/agent /usr/bin/
chmod +x /usr/bin/agent
cp /etc/mtconnect/agent/agent.service /etc/systemd/system/

systemctl daemon-reload
systemctl start agent
systemctl status agent

echo "MTConnect Agent Up and Running"
