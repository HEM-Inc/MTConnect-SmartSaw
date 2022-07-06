#!/bin/sh

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

sudo cp -r /home/hemsaw/mtconnect/agent/. /etc/mtconnect/agent/
sudo cp -r /home/hemsaw/mtconnect/devices/. /etc/mtconnect/devices/
sudo cp -r /home/hemsaw/mtconnect/schema/. /etc/mtconnect/schema/
sudo cp -r /home/hemsaw/mtconnect/styles/. /etc/mtconnect/styles/
sudo chown -R mtconnect:mtconnect /etc/mtconnect

sudo cp /etc/mtconnect/agent/agent.service /etc/systemd/system/
sudo systemctl enable agent
sudo systemctl start agent
sudo systemctl status agent
