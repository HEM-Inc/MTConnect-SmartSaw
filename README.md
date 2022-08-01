# MTConnect Smart Saw

This is the release repo for all released devices and afg information to implement on the machine IPC.
This is a Repo for the released MTConnect agent and device file for the SmartSaw platform

## Getting started

To get the agent working on the IPC for the first time the github repoistory needs to be cloned. 
``` bash 
git clone --recurse-submodules --progress --depth 1 https://github.com/HEM-Inc/MTConnect_SmartSaw.git mtconnect
```

After cloning the repository for the first time run the install script. This will locate the files into the correct locations and enable the systemctl service. Note if the agent is already created abd is an existing service then running this script can cause a lock file issue. 
``` bash
bash agent_install.sh
```

IF the agent has already be loaded then use the update script to update the files and restart the service. 
``` bash
bash agent_update.sh
```

Help syntax for both the 'agent_install.sh' and 'agent_update.sh'.
``` bash
Syntax: agent_install [-h|-a File_Name|-d File_Name]
options:
-h             Print this Help.
-a File_Name   Declare the afg file name; Defaults to - SmartSaw_DC.afg
-d File_Name   Declare the MTConnect agent device file name; Defaults to - SmartSaw_DC.xml
```
