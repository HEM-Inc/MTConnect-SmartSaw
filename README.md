# MTConnect Smart Saw

This is the release repo for all released devices and afg information to implement on the machine IPC.
This is a Repo for the released MTConnect agent and device file for the SmartSaw platform

## Getting started

To get the agent working on the IPC for the first time the github repoistory needs to be cloned. 
``` bash 
git clone --recurse-submodules --progress --depth 1 https://github.com/HEM-Inc/MTConnect_SmartSaw_DC.git mtconnect
```

After cloning the repository for the first time run the install script. This will locate the files into the correct locations and enable the systemctl service. Note if the agent is already created abd is an existing service then running this script can cause a lock file issue. 
``` bash
bash agent_install.sh
```

IF the agent has already be loaded then use the update script to update the files and restart the service. 
``` bash
bash agent_update.sh
```
