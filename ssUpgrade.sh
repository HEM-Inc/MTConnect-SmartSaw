#!/bin/sh

############################################################
# Help                                                     #
############################################################
Help(){
    # Display Help
    echo "This function updates the systemd files for the HEMsaw Adapter and the Agent."
    echo "Any associated device files for MTConnect and Adapter files are updated as per this repo."
    echo
    echo "Syntax: ssUpgrade [-H|-a File_Name|-A|-d File_Name|-u Serial_number|-M|-c File_Name|-h]"
    echo "options:"
    echo "-H                Update the HEMsaw adapter application"
    echo "-a File_Name      Declare the afg file name; Defaults to - SmartSaw_DC_HA.afg"
    echo "-A                Update the MTConnect Agent application"
    echo "-d File_Name      Declare the MTConnect agent device file name; Defaults to - SmartSaw_DC_HA.xml"
    echo "-u Serial_number  Declare the serial number for the uuid; Defaults to - SmartSaw"
    echo "-M                Update the mosquitto broker application"
    echo "-c File_Name      Declare the config file name; Defaults to - mosquitto.conf"
    echo "-h                Print this Help."
}

############################################################
# Updaters                                                 #
############################################################
Update_Adapter(){
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
}

Update_Agent(){
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
}

Update_Mosquitto(){
    if service_exists mosquitto; then
        echo "Updating Mosquitto files..."
        cp ./mqtt/$Config_File /etc/mosquitto/conf.d/
        cp ./mqtt/acl /etc/mosquitto/acl

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
}

############################################################
############################################################
# Main program                                             #
############################################################
############################################################

if [[ $(id -u) -ne 0 ]] ; then echo "Please run mosquitto_update.sh as sudo" ; exit 1 ; fi

# Set default variables
Afg_File="SmartSaw_DC_HA.afg"
Device_File="SmartSaw_DC_HA.xml"
Serial_Number="SmartSaw"
Config_File="mosquitto.conf"
run_update_adapter=false
run_update_agent=false
run_update_mosquitto=false

############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options
while getopts ":a:d:u:c:HAMh" option; do
    case ${option} in
        h) # display Help
            Help
            exit;;
        H) # Update the Adapter
            run_update_adapter = true;;
        a) # Enter an AFG file name
            Afg_File=$OPTARG;;
        A) # Update the Agent
            run_update_agent = true;;
        d) # Enter a Device file name
            Device_File=$OPTARG;;
        u) # Enter a serial number for the UUID
            Serial_Number=$OPTARG;;
        M) # Update Mosquitto
            run_update_mosquitto = true;;
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
echo "AFG file = "$Afg_File
echo "MTConnect Agent file = "$Device_File
echo "MTConnect UUID = HEMSaw_"$Serial_Number
echo "Config file = "$Config_File

if run_update_adapter; then
    Update_Adapter
elif run_update_agent; then
    Update_Agent
elif run_update_mosquitto; then
    Update_Mosquitto
fi



