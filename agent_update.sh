#!/bin/sh

sudo systemctl stop agent
sudo cp -r /home/hemsaw/mtconnect/agent/. /etc/mtconnect/agent/
sudo cp -r /home/hemsaw/mtconnect/devices/. /etc/mtconnect/devices/
sudo cp -r /home/hemsaw/mtconnect/schema/. /etc/mtconnect/schema/
sudo cp -r /home/hemsaw/mtconnect/styles/. /etc/mtconnect/styles/
sudo chown -R mtconnect:mtconnect /etc/mtconnect

sudo cp agent/agent /usr/bin/
sudo chmod +x /usr/bin/agent
sudo cp /etc/mtconnect/agent/agent.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl start agent
sudo systemctl status agent
