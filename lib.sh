#!/bin/bash

############################################################
# Shared library — sourced by ssInstall.sh and ssUpgrade.sh
############################################################

# Check if a systemd service exists.
service_exists() {
    local n=$1
    if [[ $(systemctl list-units --all -t service --full --no-legend "$n.service" | sed 's/^\s*//g' | cut -f1 -d' ') == $n.service ]]; then
        return 0
    else
        return 1
    fi
}


# Return 0 if src and dest files differ or dest does not exist.
files_differ() {
    local src="$1"
    local dest="$2"

    if [ ! -f "$dest" ]; then
        return 0  # Files differ if destination doesn't exist
    fi

    if cmp -s "$src" "$dest"; then
        return 1  # Files are identical
    else
        return 0  # Files differ
    fi
}


# Return 0 if src and dest directories differ or dest does not exist.
dir_needs_update() {
    local src="$1"
    local dest="$2"

    if [ ! -d "$dest" ]; then
        return 0  # Needs update if destination doesn't exist
    fi

    if diff -rq "$src" "$dest" > /dev/null 2>&1; then
        return 1  # Directories are identical
    else
        return 0  # Directories differ
    fi
}


# Create /etc/mongodb/venv and install Python deps if not already present.
ensure_venv() {
    if [ ! -f /etc/mongodb/venv/bin/python ]; then
        python3 -m venv /etc/mongodb/venv || { echo "ERROR: Failed to create venv at /etc/mongodb/venv"; return 1; }
        /etc/mongodb/venv/bin/pip install --quiet pymongo || { echo "ERROR: Failed to install pymongo"; return 1; }
    fi
}


# Set (or replace) "Devices = /mtconnect/config/<Device_File>" on line 1 of agent.cfg.
# Relies on global: Device_File
update_agent_cfg() {
    local CONFIG_FILE="/etc/mtconnect/config/agent.cfg"

    if [[ -z "$Device_File" ]]; then
        echo "ERROR: Device_File is not set. Aborting."
        return 1
    fi

    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "ERROR: Config file not found: $CONFIG_FILE"
        return 1
    fi

    awk -v dev="$Device_File" '
        NR==1 && /^Devices[[:space:]]*=/ { print "Devices = /mtconnect/config/" dev; next }
        NR==1 { print "Devices = /mtconnect/config/" dev; print; next }
        { print }
    ' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" || { echo "ERROR: awk processing failed. Original file unchanged."; rm -f "${CONFIG_FILE}.tmp"; return 1; }

    mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
}


# Inject (or replace) remote_clientid / local_clientid inside every
# connection block of mosquitto.conf.
# Relies on global: Serial_Number
update_remote_clientid() {
    local CONFIG_FILE="/etc/mqtt/config/mosquitto.conf"

    if [[ -z "$Serial_Number" ]]; then
        echo "ERROR: Serial_Number is not set. Aborting."
        return 1
    fi

    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "ERROR: Config file not found: $CONFIG_FILE"
        return 1
    fi

    echo "Updating remote_clientid and local_clientid in $CONFIG_FILE"

    awk -v serial="$Serial_Number" '

    # flush_block: called at end-of-block or EOF.
    # Only injects client IDs here if no address line was seen
    # (they would have been injected inline after address otherwise).
    function flush_block(    i) {
        if (!in_conn) return

        for (i = 0; i < block_len; i++) {
            print block_lines[i]

            # Inject after connection line if no address line in block
            if (!found_address && i == 0) {
                print "remote_clientid HEMSaw-" serial "-MQTT"
                print "local_clientid local.HEMSaw-" serial "-MQTT-" conn_name
            }
        }

        # Reset state
        block_len     = 0
        found_address = 0
        conn_name     = ""
        in_conn       = 0
    }

    # New connection block detected
    /^connection [^ ]/ {
        flush_block()

        in_conn       = 1
        found_address = 0
        block_len     = 0
        conn_name     = $2

        block_lines[block_len++] = $0
        next
    }

    # Inside a connection block
    in_conn {

        # Suppress existing remote_clientid / local_clientid anywhere
        # in the block — correct values are injected after address line
        if ($0 ~ /^[[:space:]]*(#[[:space:]]*)?remote_clientid([[:space:]]|$)/ ||
            $0 ~ /^[[:space:]]*(#[[:space:]]*)?local_clientid([[:space:]]|$)/) {
            next
        }

        # Address line found: buffer it, then immediately inject client IDs
        if ($0 ~ /^[[:space:]]*address[[:space:]]/) {
            found_address = 1
            block_lines[block_len++] = $0
            block_lines[block_len++] = "remote_clientid HEMSaw-" serial "-MQTT"
            block_lines[block_len++] = "local_clientid local.HEMSaw-" serial "-MQTT-" conn_name
            next
        }

        block_lines[block_len++] = $0
        next
    }

    # Lines outside any connection block — print as-is
    { print }

    END { flush_block() }

    ' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" || { echo "ERROR: awk processing failed. Original file unchanged."; rm -f "${CONFIG_FILE}.tmp"; return 1; }

    cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
    mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    echo "Updated mosquitto config file successfully."
}
