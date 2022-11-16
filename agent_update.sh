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


############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options
while getopts ":a:d:h" option; do
    case ${option} in
        h) # display Help
            Help
            exit;;
        a) # Enter an AFG file name
            Afg_File=$OPTARG;;
        d) # Enter a Device file name
            Device_File=$OPTARG;;
        \?) # Invalid option
            Help
            exit;;
    esac
done

echo "Printing the Working Directory and options..."
echo "Present directory = " pwd
echo "AFG file = "$Afg_File
echo "MTConnect Agent file = "$Device_File
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
cp -r ./devices/$Device_File /etc/mtconnect/devices/
cp -r ./schema/. /etc/mtconnect/schema/
cp -r ./styles/. /etc/mtconnect/styles/
chown -R mtconnect:mtconnect /etc/mtconnect
cp agent/agent /usr/bin/
chmod +x /usr/bin/agent
cp /etc/mtconnect/agent/agent.service /etc/systemd/system/

systemctl daemon-reload
systemctl start agent
systemctl status agent

echo "MTConnect Agent Up and Running"
