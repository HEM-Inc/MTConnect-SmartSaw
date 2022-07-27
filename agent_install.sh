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
    echo "Syntax: agent_install [-h|-a File_Name|-d File_Name]"
    echo "options:"
    echo "-h             Print this Help."
    echo "-a File_Name   Declare the afg file name; Defaults to - SmartSaw_DC.afg"
    echo "-d File_Name   Declare the MTConnect agent device file name; Defaults to - SmartSaw_DC.xml"
}

############################################################
############################################################
# Main program                                             #
############################################################
############################################################

if [[ $(id -u) -ne 0 ]] ; then echo "Please run agent_install.sh as sudo" ; exit 1 ; fi

# Set variables
Afg_File="SmartSaw_DC.afg"
Device_File="SmartSaw_DC.xml"

############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options
while getopts "h:a:d:" option; do
    case $option in
        h) # display Help
            Help
            exit;;
        a) # Enter an AFG file name
            Afg_File=$OPTARG;;
        d) # Enter a Device file name
            Device_File=$OPTARG;;
        \?) # Invalid option
            echo "Error: Invalid option chosen"
            Help
            exit;;
    esac
done

echo "Printing the Working Directory and options..."
echo "Present directory = " pwd
echo "AFG file = "$Afg_File
echo "MTConnect Agent file = "$Device_File
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
cp -r ./schema/. /etc/mtconnect/schema/
cp -r ./styles/. /etc/mtconnect/styles/
chown -R mtconnect:mtconnect /etc/mtconnect

cp /etc/mtconnect/agent/agent.service /etc/systemd/system/
systemctl enable agent
systemctl start agent
systemctl status agent

echo "MTConnect Agent Up and Running"
