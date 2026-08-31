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
    echo "  sudo ./dashService.sh -I [version]"
    echo "  sudo ./dashService.sh -U [version]"
    echo "  sudo ./dashService.sh -S"
    echo "  sudo ./dashService.sh -T"
    echo "  sudo ./dashService.sh -R"
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
    echo "  sudo ./dashService.sh -I"
    echo "  sudo ./dashService.sh -I v1.1.10"
    echo "  sudo ./dashService.sh -U"
}


############################################################
# Root check
############################################################

if [[ "$(id -u)" -ne 0 ]]; then
    echo "ERROR: Please run using sudo."
    exit 1
fi

#Validate IPC Dashboard service user
check_service_user() {
	
    local service_user=$1
    local service_group=$2

    if ! id "$service_user" &>/dev/null; then
        echo "ERROR: Required service account '$service_user' does not exist."
        echo "Create it first, then re-run this script:"
        echo "  sudo useradd --system --no-create-home --shell /usr/sbin/nologin $service_user"
        return 1
    fi

    if ! getent group "$service_group" &>/dev/null; then
        echo "ERROR: Required service group '$service_group' does not exist."
        return 1
    fi

    return 0
}

############################################################
# Configure service-user traversal permission
#
# The application is located under:
#
#   /home/<owner>/MTConnect-SmartSaw
#
# The service runs as a different user.
#
# Give the service user only execute/traverse permission
# on the parent directory.
############################################################

set_service_user_access() {

    local service_user="$1"
    local parent_dir

    parent_dir="$(dirname "$SMARTSAW_DIR")"

    if [[ ! -d "$parent_dir" ]]; then
        echo "ERROR: Parent directory not found:"
        echo "  $parent_dir"
        return 1
    fi

    # setfacl is provided by the acl package.
    if ! command -v setfacl &>/dev/null; then

        echo "setfacl not found. Installing acl package..."

        if ! apt-get update; then
            echo "ERROR: Failed to update package lists."
            return 1
        fi

        if ! apt-get install -y acl; then
            echo "ERROR: Failed to install acl package."
            return 1
        fi
    fi

    echo "Configuring traversal permission for ${service_user}..."
    echo "Directory: ${parent_dir}"

    if ! setfacl -m "u:${service_user}:--x" "$parent_dir"; then
        echo "ERROR: Failed to configure ACL on ${parent_dir}."
        return 1
    fi

    echo "Traversal permission configured successfully."

    return 0
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
# Give service user ownership of application files, excluding .git.
############################################################

set_ipc_ownership() {

    local service_user="$1"
    local service_group="$2"
    local application_dir="$3"

    if [[ ! -d "$application_dir" ]]; then
        echo "ERROR: Application directory not found:"
        echo "  $application_dir"
        return 1
    fi

    echo "Setting application ownership..."

    if ! find "$application_dir" \
        -mindepth 1 \
        -path "$application_dir/.git" -prune -o \
        -exec chown "${service_user}:${service_group}" {} +; then

        echo "ERROR: Failed to set application ownership."
        return 1
    fi

    echo "Application ownership configured successfully."

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
    local install_script
    local upgrade_script
    local clean_script

    if [[ -z "$service_user" ]]; then
        echo "ERROR: Service user is empty."
        return 1
    fi

    systemctl_path="$(command -v systemctl)"

    if [[ -z "$systemctl_path" ]]; then
        echo "ERROR: systemctl not found."
        return 1
    fi

    install_script="${SMARTSAW_DIR}/ssInstall.sh"
    upgrade_script="${SMARTSAW_DIR}/ssUpgrade.sh"
    clean_script="${SMARTSAW_DIR}/ssClean.sh"

    if [[ ! -f "$install_script" ]]; then
        echo "ERROR: Install script not found: ${install_script}"
        return 1
    fi

    if [[ ! -f "$upgrade_script" ]]; then
        echo "ERROR: Upgrade script not found: ${upgrade_script}"
        return 1
    fi

    if [[ ! -f "$clean_script" ]]; then
        echo "ERROR: Clean script not found: ${clean_script}"
        return 1
    fi
    echo "Configuring service permissions for ${service_user}..."

    cat > "$SUDOERS_FILE" <<EOF
# IPC Dashboard backend may restart only its own service.
${service_user} ALL=(root) NOPASSWD: ${systemctl_path} restart ${SERVICE_NAME}.service

# IPC Dashboard backend may run the SmartSaw install script.
${service_user} ALL=(root) NOPASSWD: /usr/bin/bash ${install_script} *

# IPC Dashboard backend may run the SmartSaw upgrade script.
${service_user} ALL=(root) NOPASSWD: /usr/bin/bash ${upgrade_script} *

# IPC Dashboard backend may run the SmartSaw clean script.
${service_user} ALL=(root) NOPASSWD: /usr/bin/bash ${clean_script} *
EOF

    chmod 440 "$SUDOERS_FILE"

    if ! visudo -cf "$SUDOERS_FILE"; then
        echo "ERROR: Invalid sudoers configuration."
        rm -f "$SUDOERS_FILE"
        return 1
    fi

    echo "Service permissions configured successfully."
}

setup_docker_access() {

    local service_user="$1"

    if [[ -z "$service_user" ]]; then
        echo "ERROR: Service user is empty."
        return 1
    fi

    if ! getent group docker &>/dev/null; then
        echo "Docker group does not exist."
        echo "Skipping Docker group configuration."
        return 0
    fi

    if id -nG "$service_user" | grep -qw docker; then
        echo "${service_user} is already in the docker group."
    else
        echo "Adding ${service_user} to docker group..."

        if ! usermod -aG docker "$service_user"; then
            echo "ERROR: Failed to add ${service_user} to docker group."
            return 1
        fi

        echo "Docker group added to ${service_user}."
    fi

    # Verify Docker access immediately using the docker group.
    if sg docker -c "docker ps >/dev/null 2>&1"; then
        echo "Docker usable inside script without sudo."
    else
        echo "ERROR: Docker is not accessible through the docker group."
        return 1
    fi

    return 0
}


############################################################
# Download Binary
############################################################

download_binary() {

    local version="${1:-latest}"
    local bin_dir="$2"
    local ipc_binary="$3"
    local release_url
    local release_json
    local download_url
    local expected_digest
    local actual_digest
    local temp_binary

    # Require jq - install if not present
    if ! command -v jq &> /dev/null; then
        echo "jq not found, installing jq..."
        apt update --fix-missing && apt install -y jq --fix-missing
        apt clean
        if ! command -v jq &> /dev/null; then
            echo "ERROR: Failed to install jq."
            echo "Please install it manually: apt install jq on Ubuntu"
            return 1
        fi
    fi

    mkdir -p "$bin_dir"

    if [[ "$version" != "latest" ]]; then
        release_url="https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/releases/tags/${version}"
    else
        release_url="https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/releases/latest"
    fi

    if ! release_json="$(curl -fsSL "$release_url")"; then
        echo "ERROR: Release '${version}' does not exist."
        return 1
    fi

    download_url="$(echo "$release_json" | jq -r '.assets[] | select(.name == "ipc-dashboard") | .browser_download_url')"
    expected_digest="$(echo "$release_json" | jq -r '.assets[] | select(.name == "ipc-dashboard") | .digest')"

    if [[ -z "$download_url" ]]; then
        echo "ERROR: No 'ipc-dashboard' asset found for release '${version}'."
        return 1
    fi

    echo
    echo "Downloading IPC Dashboard ${version}..."
    echo "$download_url"
    echo

    # Download first to a temporary file.
    # Existing binary remains untouched if download or verification fails.
    temp_binary="$(mktemp "${bin_dir}/.ipc-dashboard.XXXXXX")"

    if ! curl -fL -o "$temp_binary" "$download_url"; then
        echo "ERROR: Failed to download binary."
        rm -f "$temp_binary"
        return 1
    fi

    if [[ -n "$expected_digest" && "$expected_digest" != "null" ]]; then
        actual_digest="sha256:$(sha256sum "$temp_binary" | awk '{print $1}')"

        if [[ "$actual_digest" != "$expected_digest" ]]; then
            echo "ERROR: Downloaded binary failed checksum verification."
            echo "  Expected: $expected_digest"
            echo "  Actual:   $actual_digest"
            rm -f "$temp_binary"
            return 1
        fi

        echo "Checksum verified."
    else
        echo "WARNING: No checksum published for this release; skipping verification."
    fi

    chmod +x "$temp_binary"

    # Replace the binary only after a successful, verified download.
    if ! mv -f "$temp_binary" "$ipc_binary"; then
        echo "ERROR: Failed to replace IPC Dashboard binary."
        rm -f "$temp_binary"
        return 1
    fi

    echo
    echo "IPC Dashboard ${version} installed successfully."
    echo "Binary: $ipc_binary"

    return 0
}


############################################################
# Install/Update service
############################################################

install_service() {

    local version="$1"

    local service_user="hemsaw"
    local service_group="hemsaw"

    local ipc_dir="${SMARTSAW_DIR}/ipc_dashboard"
    local bin_dir="${ipc_dir}/bin"
    local ipc_binary="${bin_dir}/ipc-dashboard"
    local local_service_path="${ipc_dir}/services/${SERVICE_FILE}"
    local resolved_service

    # Validate service account
    if ! check_service_user "$service_user" "$service_group"; then
        return 1
    fi

    # Give service user traversal permission
    if ! set_service_user_access "$service_user"; then
        return 1
    fi

    echo "IPC Dashboard service user: ${service_user}"
    echo "IPC Dashboard service group: ${service_group}"

    # Download binary
    if ! download_binary "$version" "$bin_dir" "$ipc_binary"; then
        echo "ERROR: IPC Dashboard binary download failed."
        return 1
    fi

    if [[ ! -x "$ipc_binary" ]]; then
        echo "ERROR: Binary missing or not executable:"
        echo "  $ipc_binary"
        return 1
    fi

    # Set ownership
    # Allows the Python backend to write/update the binary.
    if ! set_ipc_ownership "$service_user" "$service_group" "$SMARTSAW_DIR"; then
        return 1
    fi

    # Configure backend restart permission
    if ! setup_restart_permission "$service_user"; then
        return 1
    fi
    
    # Configure Docker access for the actual service user.
    if ! setup_docker_access "$service_user"; then
        return 1
    fi

    # Install/update systemd service
    if [[ ! -f "$local_service_path" ]]; then
        echo "ERROR: Service template not found:"
        echo "  $local_service_path"
        return 1
    fi

    resolved_service="$(mktemp "/tmp/${SERVICE_FILE}.XXXXXX")"

    if ! sed \
        -e "s|IPC_SERVICE_USER|${service_user}|g" \
	-e "s|IPC_SERVICE_GROUP|${service_group}|g" \
	-e "s|IPCDB_WORKING_DIR|${ipc_dir}|g" \
	-e "s|IPC_BINARY|${ipc_binary}|g" \
	"$local_service_path" \
	> "$resolved_service"; then

        echo "ERROR: Failed to generate systemd service file."
        rm -f "$resolved_service"
        return 1
    fi

    if files_differ "$resolved_service" "${SYSTEMD_PATH}/${SERVICE_FILE}"; then

        echo "Installing systemd service..."

        if ! cp "$resolved_service" "${SYSTEMD_PATH}/${SERVICE_FILE}"; then
            echo "ERROR: Failed to install systemd service."
            rm -f "$resolved_service"
            return 1
        fi

        chmod 644 "${SYSTEMD_PATH}/${SERVICE_FILE}"

        if ! systemctl daemon-reload; then
            echo "ERROR: Failed to reload systemd configuration."
            rm -f "$resolved_service"
            return 1
        fi

    else

        echo "Service file already up to date."

    fi

    rm -f "$resolved_service"

    # Enable service
    if ! systemctl is-enabled --quiet "$SERVICE_NAME"; then

        echo "Enabling service..."

        if ! systemctl enable "$SERVICE_NAME"; then
            echo "ERROR: Failed to enable service."
            return 1
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
