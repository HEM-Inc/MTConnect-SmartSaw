#!/bin/sh

echo "Printing the Working Directory..."
pwd
echo ""

echo "Installing MTConnect Adapter and setting it as a SystemCTL..."

sudo mkdir -p /etc/adapter/
sudo cp -r ./adapter/. /etc/adapter/
sudo cp -r ./afg/SmartSaw_DC.afg /etc/adapter/
sudo chmod +x /etc/adapter/Adapter

sudo cp /etc/adapter/adapter.service /etc/systemd/system/
sudo systemctl enable adapter
sudo systemctl start adapter
sudo systemctl status adapter

echo "MTConnect Adapter Up and Running"

echo "Installing MTConnect and setting it as a SystemCTL..."

sudo useradd -r -s /bin/false mtconnect
sudo mkdir /var/log/mtconnect
sudo chown mtconnect:mtconnect /var/log/mtconnect

sudo mkdir -p /etc/mtconnect/
sudo mkdir -p /etc/mtconnect/agent/
sudo mkdir -p /etc/mtconnect/devices/
sudo mkdir -p /etc/mtconnect/schema/
sudo mkdir -p /etc/mtconnect/styles/
sudo cp agent/agent /usr/bin/
sudo chmod +x /usr/bin/agent

sudo cp -r ./agent/. /etc/mtconnect/agent/
sudo cp -r ./devices/. /etc/mtconnect/devices/
sudo cp -r ./schema/. /etc/mtconnect/schema/
sudo cp -r ./styles/. /etc/mtconnect/styles/
sudo chown -R mtconnect:mtconnect /etc/mtconnect

sudo cp /etc/mtconnect/agent/agent.service /etc/systemd/system/
sudo systemctl enable agent
sudo systemctl start agent
sudo systemctl status agent

echo "MTConnect Agent Up and Running"
