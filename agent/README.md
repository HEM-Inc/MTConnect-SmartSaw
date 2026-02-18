# HEMsaw MTConnect Agent

The MTConnect Agent exposes the MTConnect HTTP interface for clients and consumes SHDR data from the HEMsaw Adapter. It runs as a Docker container and serves Probe, Current, Sample, and Asset endpoints.

- Default HTTP port: 5000/tcp
- Container image: hemsaw/mtconnect:latest
- MTConnect schema version: 2.4 (configurable)
- SHDR version (from adapters): 2.0

## Folder Structure

This folder provides configuration templates and resources for the agent. At runtime, files are installed to /etc/mtconnect on the host and bind-mounted into the container.

Repo:
- agent/config/
  - agent.cfg (primary agent configuration)
  - devices/ (device XML definitions for different models)
- agent/data/ruby/
  - module.rb, mqtt.rb (optional Ruby hooks, disabled by default)

Runtime host paths used by Docker:
- /etc/mtconnect/config → /mtconnect/config
- /etc/mtconnect/data/ruby → /mtconnect/data/ruby

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

## How It Fits In

- The Agent connects to the Adapter service (mtc_adapter) via SHDR on port 7878.
- The Agent exposes HTTP on port 5000 to deliver MTConnect data to clients.
- Docker Compose service name: mtc_agent
  - Volumes:
    - /etc/mtconnect/config:/mtconnect/config
    - /etc/mtconnect/data/ruby:/mtconnect/data/ruby
  - Port mapping: 5000:5000/tcp
  - Entrypoint: /usr/bin/mtcagent run /mtconnect/config/agent.cfg
  - Depends on: mosquitto (for MQTT sink), mtc_adapter

## Quick Start

1) Choose the correct Device XML
   - Device XML files are in agent/config/devices (e.g., SmartSaw_DC_HA.xml, SmartSaw_DC_SA.xml, WF series variants, etc.).
   - Requirement: The <Device ... name="..."> element must appear on line 11 of the XML so the install scripts can overwrite it correctly during deployment.

2) Place configuration on the host
   - Copy agent.cfg to /etc/mtconnect/config
   - Copy the chosen Device XML to /etc/mtconnect/config/devices
   - Optionally copy Ruby files (if you plan to enable them) to /etc/mtconnect/data/ruby

3) Install or upgrade using the root scripts
   - Use ssInstall.sh or ssUpgrade.sh
   - To set the default Device XML for this machine, pass -d File_Name or set it in env.sh

4) Start services (handled by install scripts)
   - Docker compose will launch mtc_agent and mtc_adapter
   - The Agent will connect to the Adapter at mtc_adapter:7878

5) Verify service
   - Probe:    curl http://localhost:5000/probe
   - Current:  curl http://localhost:5000/current
   - Sample:   curl http://localhost:5000/sample
   - Assets:   curl http://localhost:5000/assets

## Configuration Reference (agent.cfg)

Server and protocol:
- ServerIP = 0.0.0.0
- Port = 5000
- SchemaVersion = 2.4
- ShdrVersion = 2.0
- JsonVerson = 2.0

Core behavior:
- BufferSize = 17
- MaxAssets = 8096
- MonitorConfigFiles = yes (watch for config changes)
- Validation = no (schema validation off by default)
- IgnoreTimestamps = yes, UpcaseDataItemValue = yes, Pretty = yes
- VersionDeviceXml = yes, PreserveUUID = no, CreateUniqueIds = no

Security (optional):
- TlsOnly = no
- TLS certificate/keys can be configured via the commented fields (uncomment and set paths if enabling TLS)

Adapter connection:
- Adapters { Saw { Protocol = shdr, Host = mtc_adapter, Port = 7878, RealTime = no, AutoAvailable = yes, Manufacturer = HEMSaw, FilterDuplicates = yes } }

MQTT sink (optional, enabled by default in config):
- Sinks { MqttService { MqttHost = mosquitto, MqttPort = 1883, MqttUserName = mtconnect, MqttPassword = mtconnect, MqttClientId = mtc_agent } }
- Topics:
  - ProbeTopic = mtconnect/probe/#
  - CurrentTopic = mtconnect/current/#
  - SampleTopic = mtconnect/sample/#
  - AssetTopic = mtconnect/asset/#
- Publishing:
  - MqttCurrentInterval = 10000ms
  - MqttSampleInterval = 500ms
  - MqttSampleCount = 1000
  - MqttRetain = yes
  - MqttQOS = at_least_once

Static content and styles:
- Files { schemas { Path = /mtconnect/data/schemas, Location = /schemas/ }, styles { Path = /mtconnect/data/styles, Location = /styles/ }, Favicon { Path = /mtconnect/data/styles, Location = /styles/ } }
- DevicesStyle = /styles/styles.xsl, StreamsStyle = /styles/styles.xsl

Ruby integration (optional):
- Ruby { # module = /mtconnect/data/ruby/module.rb }
- To enable, uncomment the module line and provide the file via the /etc/mtconnect/data/ruby mount.

Logging:
- logger_config { logging_level = warn, output = cout }
- Container logs are captured by Docker’s json-file driver with rotation (10 MB, 3 files) as defined in docker-compose.yml.

## Device XML Guidance

- Place your device XML in /etc/mtconnect/config/devices.
- Ensure the <Device ... name="..."> tag is on line 11 of the file (required by the install/upgrade workflow).
- Match the device model variant to your saw (e.g., DC22/26/30, WF series, SCT variants).
- If you duplicate and customize an XML, preserve the header schema declarations consistent with your SchemaVersion.

## Networking and Ports

- Agent HTTP: 5000/tcp (host → container)
- Adapter SHDR: 7878/tcp (container-to-container via Docker network)
- MQTT broker (optional sink): mosquitto:1883 (Docker network)

## Operational Notes

- With Pretty = yes, browser requests to /current and /sample are human-readable.
- MonitorConfigFiles = yes allows the agent to detect configuration changes; some changes may still require a container restart.
- When MQTT sink is enabled, the agent publishes Probe/Current/Sample/Asset streams to the configured broker.

## Troubleshooting

- Agent not reachable
  - Check: docker compose ps and docker compose logs mtc_agent
  - Verify port mapping 5000:5000 and local firewall rules
- Empty streams (no data)
  - Confirm mtc_adapter is running and reachable (Host=mtc_adapter, Port=7878)
  - Check adapter logs and AFG configuration
- Device XML errors
  - Validate that the Device tag is on line 11
  - Ensure schema version matches agent.cfg SchemaVersion (e.g., 2.4)
- MQTT not receiving data
  - Verify mosquitto is running and reachable on 1883
  - Check MqttUserName/Password and topics
- Validation issues
  - Enable Validation = yes temporarily to diagnose schema problems (may impact performance)

## See Also

- ../adapter/README.md for adapter configuration and SHDR details
- ../README.md for the full system overview, install/upgrade scripts, and directory structure
- agent/config/agent.cfg (this agent’s configuration)
- agent/config/devices/ (Device XML templates)

## License

See the repository LICENSE file for details.
