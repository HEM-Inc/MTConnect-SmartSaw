## MTConnect Container file structure

``` bash
/usr/bin
    |-- agent - the cppagent application

/mtconnect/config - Configuration files
    | - agent.cfg
    | - Devices.xml

/mtconnect/data
    |-- schemas - xsd files
    |-- styles - styles.xsl, styles.css, favicon.ico, etc

/home/agent - the users directory

/mtconnect/log - logging directory
```

### Notes:
- Note that the device name within the device.xml must be on line 11 so that the load can overwrite it correctly.
- See Below for headder needed:
``` xml
1  <?xml version="1.0" encoding="UTF-8"?>
2  <MTConnectDevices
3      xsi:schemaLocation="urn:mtconnect.org:MTConnectDevices:2.3 http://schemas.mtconnect.org/schemas/MTConnectDevices_2.3.xsd"
4      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
5      xmlns="urn:mtconnect.org:MTConnectDevices:2.3"
6      xmlns:m="urn:mtconnect.org:MTConnectDevices:2.3">
7
8      <Header bufferSize="8096" assetCount="8096" assetBufferSize="8096" version="2.4.0.0"
9          instanceId="1520711514" sender="HEMSaw" creationTime="2018-03-10T19:52:01Z" deviceModelChangeTime="2018-03-10T19:52:01Z"/>
10     <Devices>
11         <Device id="saw" uuid="HEMSaw_DC22A_SmartSaw" name="Saw">
...
xx         </Device>
xx     </Devices>
xx </MTConnectDevices>
```
