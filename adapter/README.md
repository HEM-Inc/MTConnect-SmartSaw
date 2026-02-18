# HEMsaw MTConnect Adapter

The HEMsaw Adapter interfaces with the saw’s control system (PLC) and exposes a standard SHDR stream for the MTConnect Agent to consume. It runs as a Docker container and is configured via AFG files and a JSON-based alarm definition.

- Protocols: SHDR 2.0 to Agent, PLC comms (per AFG)
- Default port: 7878/tcp
- Container image: hemsaw/smartsaw-adapter:latest
- MTConnect version: 2.3+ (as configured in AFG)

## Folder Structure

This folder contains configuration templates and data for the adapter. At runtime, these are installed to /etc/adapter on the host and bind-mounted into the container.

/adapter
├── config/                  AFG configuration files (example variants for different machines)
│   ├── SmartSaw_DC_HA.afg
│   ├── SmartSaw_DC_HM.afg
│   ├── SmartSaw_DC_SA.afg
│   ├── SmartSaw_DC_SM.afg
│   └── SmartSaw_VT_HA.afg
└── data/                    JSON alarm/condition definitions
    └── SmartSaw_alarms.json

Runtime host paths used by Docker:
- /etc/adapter/config → /adapter/config
- /etc/adapter/data → /adapter/data
- /etc/adapter/log → /adapter/log

## How It Fits In

- The MTConnect Agent connects to the adapter on port 7878. In the provided agent.cfg:
  - Host = mtc_adapter
  - Port = 7878
- Docker Compose service name: mtc_adapter
- The adapter is expected to be reachable from the agent container via the Docker network.

## Quick Start

1) Choose an AFG for your saw model
   - Examples provided in adapter/config:
     - SmartSaw_DC_HA.afg, SmartSaw_DC_HM.afg, SmartSaw_DC_SA.afg, SmartSaw_DC_SM.afg, SmartSaw_VT_HA.afg

2) Install or upgrade using scripts at repo root
   - ssInstall.sh or ssUpgrade.sh
   - Use flags to pick files (see repo README):
     - -a File_Name (AFG)
     - -j File_Name (Alarm JSON)
   - The chosen files persist via env.sh
   - Docker compose will launch mtc_adapter and mtc_agent
   - Agent consumes SHDR from the adapter

3) Verify connectivity
   - Check logs: docker compose logs mtc_adapter
   - Verify port open: nc -vz localhost 7878 (host) or from agent container to mtc_adapter:7878

## Docker Compose Reference

The adapter service in docker-compose.yml mounts config/data/log and exposes port 7878:

services:
  mtc_adapter:
    container_name: mtc_adapter
    image: hemsaw/smartsaw-adapter:latest
    user: adapter
    volumes:
      - "/etc/adapter/config/:/adapter/config/"
      - "/etc/adapter/data/:/adapter/data/"
      - "/etc/adapter/log/:/adapter/log/"
    ports:
      - "7878:7878/tcp"
    restart: unless-stopped

## Configuring the Adapter (AFG)

AFG files define both network parameters and the data items/commands published via SHDR. Common top-level keys include:

- plc_host: IP of the saw PLC (example default: 10.0.0.2)
- server_host: Adapter bind address (typically 0.0.0.0)
- server_port: SHDR port (default 7878)
- cmd_adapter_version: true (exposes adapter version)
- cmd_mtconnect_version: "2.3"
- cmd_shdr_version: "2.0"

Pick the AFG variant that matches your model. If you need a custom setup, copy an existing AFG and adjust:
- PLC IP
- Any model-specific data items and command definitions
- Optional features as supported by your machine

Apply it using ssInstall.sh/ssUpgrade.sh with -a or by setting the default in env.sh.

## Alarms and Conditions (JSON)

- Path: /etc/adapter/data/SmartSaw_alarms.json
- Purpose: Drives generic condition functions for alarms/notifications
- Customize to define your site-/model-specific alarm mapping and severities, then deploy with -j or via env.sh defaults

See the bundled JSON for structure and examples.

## Logging

- Container logs: JSON-file driver with rotation (10 MB, 3 files)
- Adapter logs directory: /etc/adapter/log (bind-mounted as /adapter/log)
- Repair utility: Use ssClean.sh -L to sanitize logs with NULL or control characters

## Networking and Ports

- SHDR: 7878/tcp (adapter)
- The agent is preconfigured to connect to the adapter at mtc_adapter:7878 via Docker networking
- Ensure firewalls allow access if you test from the host or another machine

## Operational Notes

- The adapter streams SHDR for the agent to consume; example SHDR (generic):
  2025-01-01T12:00:00.000000Z|avail|AVAILABLE
  2025-01-01T12:00:00.000000Z|power|ON
- Ensure the PLC IP (plc_host) is reachable from the adapter container’s network
- The adapter is updated via the same ssInstall/ssUpgrade workflows as the rest of the stack

## Troubleshooting

- No data in Agent
  - Verify mtc_adapter is running: docker compose ps
  - Check adapter logs: docker compose logs mtc_adapter
  - Confirm agent.cfg has Host=mtc_adapter, Port=7878
- Connection refused on 7878
  - Verify the service has started and port is exposed
  - From agent container: test TCP connection to mtc_adapter:7878
- PLC-related errors
  - Confirm plc_host in the selected AFG is correct
  - Check network path and firewall between adapter container and PLC
- Alarm issues
  - Validate SmartSaw_alarms.json syntax
  - Confirm the file is mounted to /adapter/data in the container

## Supported Variants

- DC Series: HA, HM, SA, SM
- VT Series: HA
- If unsure which AFG to start with, consult HEMsaw support or your machine’s documentation.

## See Also

- ../README.md for full system overview and script usage
- ../agent/config/agent.cfg to verify Agent → Adapter connection details
- ChangeLog.md for recent changes (port, paths, and behavior)

## License

See the repository LICENSE file for details.
