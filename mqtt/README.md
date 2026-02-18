# HEMsaw MQTT Broker (Mosquitto)

This folder contains configuration, ACLs, and TLS certificates for the MQTT broker used by the SmartSaw platform. The broker runs as a Docker container (image: hemsaw/mosquitto:latest) and can operate as:
- A local MQTT broker for the MTConnect Agent sink
- An optional TLS bridge to a remote broker (using mosq_bridge.conf)

Exposed ports (via docker-compose):
- 1883/tcp: MQTT (plain)
- 8883/tcp: MQTT over TLS (if configured)
- 9001/tcp: WebSockets (requires websockets-enabled build and listener config)

## Folder Structure

Repo layout:
- mqtt/config/
  - mosquitto.conf           (default local-broker config)
  - mosq_bridge.conf         (bridge-to-remote config with TLS)
- mqtt/data/
  - acl                      (ACL file used by mosquitto.conf)
  - acl_bridge               (ACL file example for bridge scenarios)
- mqtt/certs/
  - ca.crt, client.crt, client.key (client TLS materials for bridge)

Runtime host paths bound into the container (see docker-compose.yml):
- /etc/mqtt/config/mosquitto.conf → /mosquitto/config/mosquitto.conf
- /etc/mqtt/data/acl              → /mosquitto/data/acl
- /etc/mqtt/certs                 → /mosquitto/certs

Note:
- The configurations reference password_file /mosquitto/data/passwd. If you plan to enable username/password auth, ensure the password file exists in the container path (see “Security & Auth” below). You may choose to mount /etc/mqtt/data → /mosquitto/data to persist passwd alongside ACLs.

## How It Fits In

- The MTConnect Agent can publish Probe/Current/Sample/Asset streams to this broker using the Sinks.MqttService configuration.
- Within docker-compose, the agent connects to the broker using host: mosquitto and port: 1883 on the Docker network.
- Optionally, the local broker can bridge to a remote broker using TLS (see mosq_bridge.conf).

## Quick Start

1) Local broker (default)
   - Ensure /etc/mqtt/config/mosquitto.conf is mounted as /mosquitto/config/mosquitto.conf (the install scripts handle this).
   - Confirm ports 1883 and (optionally) 8883/9001 are exposed in docker-compose.yml.
   - Start services with the provided install/upgrade scripts.

2) Enable Agent MQTT sink
   - In agent/config/agent.cfg, Sinks.MqttService is preconfigured to use host=mosquitto, port=1883.
   - The agent publishes to topics:
     - mtconnect/probe/#
     - mtconnect/current/#
     - mtconnect/sample/#
     - mtconnect/asset/#

3) Optional: Bridge mode
   - Use ssUpgrade.sh -b to switch the broker configuration to mosq_bridge.conf (bridge mode).
   - Place TLS files (ca.crt, client.crt, client.key) into /etc/mqtt/certs on the host.

## mosquitto.conf (Local Broker)

Key points in mqtt/config/mosquitto.conf:
- allow_anonymous true
- password_file /mosquitto/data/passwd
- acl_file /mosquitto/data/acl
- listener 1883 0.0.0.0
- protocol mqtt

There are commented examples for setting up a bridge directly in this file. For production bridging, use mosq_bridge.conf instead and the ssUpgrade.sh -b workflow.

## mosq_bridge.conf (TLS Bridge to Remote)

Key points in mqtt/config/mosq_bridge.conf:
- allow_anonymous true (adjust per your security posture)
- password_file /mosquitto/data/passwd
- acl_file /mosquitto/data/acl
- TLS bridge connection:
  - connection bridge-1
  - address ssc.hemsaw.com:8883
  - bridge_insecure true
  - bridge_cafile /mosquitto/certs/ca.crt
  - bridge_certfile /mosquitto/certs/client.crt
  - bridge_keyfile /mosquitto/certs/client.key
- Topic mapping examples:
  - topic # out 1 mtconnect/ monitor/hemsaw/ok1/
  - topic # in  1 control/  control/hemsaw/ok1/
  - topic # out 1 monitor/   monitor/hemsaw/ok1/

Topic directive format (mosquitto):
- topic <pattern> <direction> <qos> [local_prefix] [remote_prefix]
- “out” sends topics from local → remote (e.g., local mtconnect/ → remote monitor/hemsaw/ok1/)
- “in” receives topics from remote → local (e.g., remote control/hemsaw/ok1/ → local control/)

Remote authentication:
- remote_username ssconnect-local-broker
- remote_password pwssconnect-local-broker

Adjust the remote address, prefixes, and credentials to match your deployment.

## Certificates (TLS)

For bridge mode to a remote TLS broker:
- Place CA and client materials into /etc/mqtt/certs on the host:
  - ca.crt
  - client.crt
  - client.key
- These are mounted as /mosquitto/certs inside the container.
- Ensure file permissions restrict private key access to trusted users only.

## Security & Auth

- Anonymous access:
  - By default, allow_anonymous true is set in both configs.
  - To restrict access, set allow_anonymous false and configure a password_file and/or ACLs.

- Username/Password:
  - Generate a password file (on host) with mosquitto_passwd:
    - mosquitto_passwd -c /etc/mqtt/data/passwd <username>
  - Mount it inside the container as /mosquitto/data/passwd (update docker-compose bind if needed).
  - Keep the acl_file path consistent (e.g., /etc/mqtt/data/acl mounted to /mosquitto/data/acl).

- ACLs:
  - Edit /etc/mqtt/data/acl to define topic-level permissions.
  - For bridge scenarios, you can maintain a separate ACL (e.g., acl_bridge), and point acl_file to it in your selected config.

- TLS on local listeners:
  - To run TLS on the local listener (8883), add TLS directives (cafile, certfile, keyfile) and a tls-enabled listener in mosquitto.conf.

- WebSockets:
  - 9001 is exposed in docker-compose, but a WebSockets listener must be configured in mosquitto.conf and the image must be built with websockets support.

## Testing

Local subscribe/publish (from host or inside a container with mosquitto-clients installed):
- Subscribe to all MTConnect topics:
  - mosquitto_sub -h localhost -p 1883 -t 'mtconnect/#' -v
- Publish a test message:
  - mosquitto_pub -h localhost -p 1883 -t 'mtconnect/test' -m 'hello'

Bridge verification:
- Use mosquitto_sub on the remote broker to confirm bridged messages arrive under the expected remote prefixes (e.g., monitor/hemsaw/ok1/…).

## Troubleshooting

- Broker not reachable
  - docker compose ps and docker compose logs mosquitto
  - Verify ports 1883/8883/9001 are open on the host firewall if accessing externally

- Agent not publishing
  - Confirm agent Sinks.MqttService points to mosquitto:1883
  - Check agent logs and topics

- Bridge not connecting
  - Confirm TLS cert/key material is valid and paths match mosq_bridge.conf
  - Validate remote address/port and credentials
  - Inspect mosquitto logs (log_type all is enabled in mosq_bridge.conf)

- Auth failures
  - Ensure allow_anonymous is set appropriately
  - Verify password_file format and mount path
  - Confirm ACLs permit the intended topics

## See Also

- ../agent/config/agent.cfg (MqttService sink settings)
- ../docker-compose.yml (mosquitto service volumes and ports)
- mqtt/config/mosquitto.conf (local broker)
- mqtt/config/mosq_bridge.conf (bridge config)

## License

See the repository LICENSE file for details.
