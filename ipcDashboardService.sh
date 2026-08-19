#!/bin/bash

set -o pipefail

SERVICE_NAME="ipc-dashboard"
SERVICE_FILE="${SERVICE_NAME}.service"
SYSTEMD_PATH="/etc/systemd/system"

SMARTSAW_DIR="$(cd "$(dirname "$0")" && pwd)"

GITHUB_OWNER="HEM-Inc"
GITHUB_REPO="ipc-dashboard-release"

# Allows the IPC Dashboard backend to restart only this service.
SUDOERS_FILE="/etc/sudoers.d/ipc-dashboard-update"


############################################################
# Help
############################################################

Help() {
    echo "IPC Dashboard Service Manager"
    echo
    echo "Syntax:"
    echo "  sudo ./ipcDashboardService.sh -I [version]"
    echo "  sudo ./ipcDashboardService.sh -U [version]"
    echo "  sudo ./ipcDashboardService.sh -S"
    echo "  sudo ./ipcDashboardService.sh -T"
    echo "  sudo ./ipcDashboardService.sh -R"
    echo
    echo "Options:"
    echo "  -I [version]  Install/update service and binary"
    echo "  -U [version]  Install/update and restart service"
    echo "  -S            Start service"
    echo "  -T            Stop service"
    echo "  -R            Restart service"
    echo "  -h            Show help"
    echo
    echo "Examples:"
    echo "  sudo ./ipcDashboardService.sh -I"
    echo "  sudo ./ipcDashboardService.sh -I v1.1.10"
    echo "  sudo ./ipcDashboardService.sh -U"
}


############################################################
# Root check
############################################################

if [[ "$(id -u)" -ne 0 ]]; then
    echo "ERROR: Please run using sudo."
    exit 1
fi


# Get IPC Dashboard service user
get_service_user() {

    local service_user
    local service_group

    # Use the user who executed sudo.
    if [[ -n "$SUDO_USER" && "$SUDO_USER" != "root" ]]; then
        service_user="$SUDO_USER"
        service_group="$(id -gn "$SUDO_USER")"
    else
        # Fall back to the owner of the SmartSaw directory.
        service_user="$(stat -c '%U' "$SMARTSAW_DIR")"
        service_group="$(stat -c '%G' "$SMARTSAW_DIR")"
    fi

    if [[ -z "$service_user" || "$service_user" == "root" ]]; then
        echo "ERROR: Could not determine IPC Dashboard service user."
        return 1
    fi

    echo "${service_user}:${service_group}"
}


############################################################
# Utility
############################################################

files_differ() {

    local src="$1"
    local dst="$2"

    # Destination does not exist.
    if [[ ! -f "$dst" ]]; then
        return 0
    fi

    # Files are identical.
    if cmp -s "$src" "$dst"; then
        return 1
    fi

    # Files are different.
    return 0
}


############################################################
# Set IPC Dashboard ownership
#
# Required so the FastAPI backend can download and replace
# the binary inside ipc_dashboard/bin.
############################################################

set_ipc_ownership() {

    local service_user="$1"
    local service_group="$2"

    IPC_DIR="${SMARTSAW_DIR}/ipc_dashboard"
    BIN_DIR="${IPC_DIR}/bin"

    if [[ ! -d "$BIN_DIR" ]]; then
        echo "ERROR: IPC Dashboard bin directory not found:"
        echo "  $BIN_DIR"
        return 1
    fi

    echo "Setting binary directory ownership..."

    if ! chown -R "${service_user}:${service_group}" "$BIN_DIR"; then
        echo "ERROR: Failed to set binary directory ownership."
        return 1
    fi

    echo "Binary directory ownership configured successfully."

    return 0
}


############################################################
# Configure restricted sudo permission
#
# Allows the backend user to run only:
#
#   sudo systemctl restart ipc-dashboard.service
#
# without requiring a password.
############################################################

setup_restart_permission() {

    local service_user="$1"
    local systemctl_path

    if [[ -z "$service_user" ]]; then
        echo "ERROR: Service user is empty."
        return 1
    fi

    systemctl_path="$(command -v systemctl)"

    if [[ -z "$systemctl_path" ]]; then
        echo "ERROR: systemctl not found."
        return 1
    fi

    echo "Configuring service restart permission for ${service_user}..."

    cat > "$SUDOERS_FILE" <<EOF
# IPC Dashboard backend may restart only its own service.
${service_user} ALL=(root) NOPASSWD: ${systemctl_path} restart ${SERVICE_NAME}.service
EOF

    chmod 440 "$SUDOERS_FILE"

    if ! visudo -cf "$SUDOERS_FILE"; then
        echo "ERROR: Invalid sudoers configuration."
        rm -f "$SUDOERS_FILE"
        return 1
    fi

    echo "Restricted restart permission configured successfully."
}


############################################################
# Download Binary
############################################################

download_binary() {

    IPC_DIR="${SMARTSAW_DIR}/ipc_dashboard"
    BIN_DIR="${IPC_DIR}/bin"
    IPC_BINARY="${BIN_DIR}/ipc-dashboard"

    local temp_binary="${IPC_BINARY}.download"
    mkdir -p "$BIN_DIR"

    local version="${1:-latest}"

    if [[ "$version" != "latest" ]]; then
        RELEASE_URL="https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/releases/tags/${version}"

        if ! curl -fsSL "$RELEASE_URL" > /dev/null; then
            echo "ERROR: Release '${version}' does not exist."
            return 1
        fi

        DOWNLOAD_URL="https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}/releases/download/${version}/ipc-dashboard"

    else

        DOWNLOAD_URL="https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}/releases/latest/download/ipc-dashboard"

    fi

    echo
    echo "Downloading IPC Dashboard ${version}..."
    echo "$DOWNLOAD_URL"
    echo

    # Download first to a temporary file.
    # Existing binary remains untouched if download fails.
    rm -f "$temp_binary"

    if ! curl -fL -o "$temp_binary" "$DOWNLOAD_URL"; then
        echo "ERROR: Failed to download binary."
        rm -f "$temp_binary"
        return 1
    fi

    chmod +x "$temp_binary"

    # Replace the binary only after a successful download.
    if ! mv -f "$temp_binary" "$IPC_BINARY"; then
        echo "ERROR: Failed to replace IPC Dashboard binary."
        rm -f "$temp_binary"
        return 1
    fi

    chmod +x "$IPC_BINARY"

    echo
    echo "IPC Dashboard ${version} installed successfully."
    echo "Binary: $IPC_BINARY"

    return 0
}


############################################################
# Install/Update service
############################################################

install_service() {

    local version="$1"
    local user_info
    local service_user
    local service_group
    RESOLVED_SERVICE="/tmp/${SERVICE_FILE}.resolved"

    IPC_DIR="${SMARTSAW_DIR}/ipc_dashboard"
    BIN_DIR="${IPC_DIR}/bin"
    IPC_BINARY="${BIN_DIR}/ipc-dashboard"
    LOCAL_SERVICE_PATH="${IPC_DIR}/services/${SERVICE_FILE}"

    # Determine service user
    user_info="$(get_service_user)"

    if [[ $? -ne 0 || -z "$user_info" ]]; then
        echo "ERROR: Failed to determine IPC Dashboard service user."
        return 1
    fi

    service_user="${user_info%%:*}"
    service_group="${user_info##*:}"

    echo "IPC Dashboard service user: ${service_user}"
    echo "IPC Dashboard service group: ${service_group}"

    # Download binary
    if ! download_binary "$version"; then
        echo "ERROR: IPC Dashboard binary download failed."
        return 1
    fi

    if [[ ! -x "$IPC_BINARY" ]]; then
        echo "ERROR: Binary missing or not executable:"
        echo "  $IPC_BINARY"
        return 1
    fi

    # Set ownership
    # Allows the Python backend to write/update the binary.
    if ! set_ipc_ownership "$service_user" "$service_group"; then
        return 1
    fi

    # Configure backend restart permission
    if ! setup_restart_permission "$service_user"; then
        return 1
    fi

    # Install/update systemd service
    if [[ ! -f "$LOCAL_SERVICE_PATH" ]]; then
        echo "ERROR: Service template not found:"
        echo "  $LOCAL_SERVICE_PATH"
        return 1
    fi

    if ! sed \
        -e "s|IPCDB_WORKING_DIR|${IPC_DIR}|g" \
        -e "s|IPC_BINARY|${IPC_BINARY}|g" \
        "$LOCAL_SERVICE_PATH" \
        > "$RESOLVED_SERVICE"; then

        echo "ERROR: Failed to generate systemd service file."
        rm -f "$RESOLVED_SERVICE"
        return 1
    fi

    if files_differ "$RESOLVED_SERVICE" "${SYSTEMD_PATH}/${SERVICE_FILE}"; then

        echo "Installing systemd service..."

        if ! cp "$RESOLVED_SERVICE" "${SYSTEMD_PATH}/${SERVICE_FILE}"; then
            echo "ERROR: Failed to install systemd service."
            rm -f "$RESOLVED_SERVICE"
            return 1
        fi

        chmod 644 "${SYSTEMD_PATH}/${SERVICE_FILE}"

	if ! systemctl daemon-reload; then
	    echo "ERROR: Failed to reload systemd configuration."
	    rm -f "$RESOLVED_SERVICE"
	    return 1
	fi

    else

        echo "Service file already up to date."

    fi

    rm -f "$RESOLVED_SERVICE"

    # Enable service
    if ! systemctl is-enabled --quiet "$SERVICE_NAME"; then

        echo "Enabling service..."

        if ! systemctl enable "$SERVICE_NAME"; then
            echo "ERROR: Failed to enable service."
            return 1
        fi

    fi

    # Docker sudo/group handling
    if [ -n "$SUDO_USER" ]; then

        if ! id -nG "$SUDO_USER" | grep -qw docker; then

            echo "Adding $SUDO_USER to docker group..."

            if ! usermod -aG docker "$SUDO_USER"; then
                echo "ERROR: Failed to add $SUDO_USER to docker group."
                return 1
            fi

            echo "Docker group added."

            # Immediate usability inside script
            sg docker -c "docker ps >/dev/null 2>&1" && \
                echo "Docker usable inside script without sudo."

        else

            echo "User already in docker group."
        fi
    fi

    echo
    echo "IPC Dashboard installation/update completed successfully."

    return 0
}


############################################################
# Service controls
############################################################

start_service() {
    echo "Starting service..."
    systemctl start "$SERVICE_NAME"
}

stop_service() {
    echo "Stopping service..."
    systemctl stop "$SERVICE_NAME"
}

restart_service() {
    echo "Restarting service..."
    systemctl restart "$SERVICE_NAME"
}

status_service() {
    echo
    echo "Service Status:"
    echo
    systemctl status "$SERVICE_NAME" --no-pager
}

logs_service() {
    echo
    echo "Recent Logs:"
    echo
    journalctl -u "$SERVICE_NAME" -n 20 --no-pager
}


############################################################
# Main
############################################################

if [[ $# -eq 0 ]]; then
    Help
    exit 1
fi

OPTION="$1"
VERSION="$2"

case "$OPTION" in

    -I)
        if ! install_service "$VERSION"; then
            exit 1
        fi
        ;;

    -S)
        start_service
        ;;

    -T)
        stop_service
        ;;

    -R)
        restart_service
        ;;

    -U)
        # Download/install first.
        # The running service remains untouched if installation fails.
        if ! install_service "$VERSION"; then
            echo "ERROR: Update failed. Existing service was not restarted."
            exit 1
        fi

        if ! restart_service; then
	    echo "ERROR: Failed to restart IPC Dashboard service."
	    exit 1
        fi
	;;

    -h)
        Help
        exit 0
        ;;

    *)
        echo "Invalid option."
        Help
        exit 1
        ;;
esac


status_service
logs_service
