#!/bin/bash

SERVICE_NAME="ipc-dashboard"
SERVICE_FILE="ipc-dashboard.service"
SYSTEMD_PATH="/etc/systemd/system"

SMARTSAW_DIR="$(cd "$(dirname "$0")" && pwd)"
LOCAL_SERVICE_PATH="${SMARTSAW_DIR}/ipc_dashboard/services/$SERVICE_FILE"

GITHUB_OWNER="HEM-Inc"
GITHUB_REPO="MTConnect-SmartSaw"

############################################################
# Help
############################################################
Help() {
    echo "IPC Dashboard Service Manager"
    echo
    echo "Syntax:"
    echo "  sudo ./ipc_service.sh -I [version]"
    echo "  sudo ./ipc_service.sh -U [version]"
    echo "  sudo ./ipc_service.sh -S"
    echo "  sudo ./ipc_service.sh -T"
    echo "  sudo ./ipc_service.sh -R"
    echo
    echo "Options:"
    echo "  -I    Install/Update service and download binary"
    echo "  -S    Start service"
    echo "  -T    Stop service"
    echo "  -R    Restart service"
    echo "  -U    Install/Update + Restart"
    echo "  -h    Help"
    echo
    echo "Examples:"
    echo "  sudo ./ipc_service.sh -I"
    echo "  sudo ./ipc_service.sh -I v1.0.2"
    echo
}

############################################################
# Root check
############################################################
if [[ $(id -u) -ne 0 ]]; then
    echo "Please run using sudo."
    exit 1
fi

############################################################
# Utility
############################################################

files_differ() {

    local src="$1"
    local dst="$2"

    if [ ! -f "$dst" ]; then
        return 0
    fi

    if cmp -s "$src" "$dst"; then
        return 1
    fi

    return 0
}

############################################################
# Download Binary
############################################################

download_binary() {

    IPC_DIR="${SMARTSAW_DIR}/ipc_dashboard"
    BIN_DIR="${IPC_DIR}/bin"
    IPC_BINARY="${BIN_DIR}/ipc-dashboard"

    mkdir -p "$BIN_DIR"

    VERSION="${1:-latest}"

    #
    # Validate the requested version if it is not "latest"
    #
    if [[ "$VERSION" != "latest" ]]; then
        RELEASE_URL="https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/releases/tags/${VERSION}"

        if ! curl -fsSL "$RELEASE_URL" > /dev/null; then
            echo "ERROR: Release '${VERSION}' does not exist."
            exit 1
        fi

        DOWNLOAD_URL="https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}/releases/download/${VERSION}/ipc-dashboard"
    else
        DOWNLOAD_URL="https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}/releases/latest/download/ipc-dashboard"
    fi

    echo
    echo "Downloading IPC Dashboard ${VERSION}..."
    echo "$DOWNLOAD_URL"
    echo

    if ! curl -fL -o "$IPC_BINARY" "$DOWNLOAD_URL"; then
        echo "ERROR: Failed to download binary."
        exit 1
    fi

    chmod +x "$IPC_BINARY"

    echo
    echo "IPC Dashboard ${VERSION} installed successfully."
    echo "Binary: $IPC_BINARY"
}

############################################################
# Install service
############################################################

install_service() {

    VERSION="$1"

    IPC_DIR="${SMARTSAW_DIR}/ipc_dashboard"
    BIN_DIR="${IPC_DIR}/bin"
    IPC_BINARY="${BIN_DIR}/ipc-dashboard"

    download_binary "$VERSION"

    if [ ! -x "$IPC_BINARY" ]; then
        echo "Binary missing:"
        echo "$IPC_BINARY"
        exit 1
    fi

    if [ ! -f "$LOCAL_SERVICE_PATH" ]; then
        echo "ERROR: Service template not found:"
	echo " $LOCAL_SERVICE_PATH"
	exit 1
    fi

    RESOLVED_SERVICE="/tmp/${SERVICE_FILE}.resolved"

    sed \
        -e "s|IPCDB_WORKING_DIR|${IPC_DIR}|g" \
        -e "s|IPC_BINARY|${IPC_BINARY}|g" \
        "$LOCAL_SERVICE_PATH" \
> "$RESOLVED_SERVICE"

    if files_differ "$RESOLVED_SERVICE" "$SYSTEMD_PATH/$SERVICE_FILE"; then

        echo "Installing systemd service..."

        cp "$RESOLVED_SERVICE" "$SYSTEMD_PATH/$SERVICE_FILE"

        chmod 644 "$SYSTEMD_PATH/$SERVICE_FILE"

        systemctl daemon-reload

    else

        echo "Service file already up to date."

    fi

    if ! systemctl is-enabled --quiet "$SERVICE_NAME"; then

        echo "Enabling service..."

        systemctl enable "$SERVICE_NAME"

    fi

    ############################################################
    # Docker sudo/group handling
    ############################################################

    if [ -n "$SUDO_USER" ]; then

        if ! id -nG "$SUDO_USER" | grep -qw docker; then

            echo "Adding $SUDO_USER to docker group..."

            usermod -aG docker "$SUDO_USER"

            echo "Docker group added."

            # Immediate usability inside script
            sg docker -c "docker ps >/dev/null 2>&1" && \
                echo "Docker usable inside script without sudo."

        else

            echo "User already in docker group."

        fi

    fi
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
    echo "Service Status: "

    systemctl status "$SERVICE_NAME" --no-pager
}

logs_service() {

    echo
    echo "Recent Logs: "

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
        install_service "$VERSION"
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
        install_service "$VERSION"
        restart_service
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
