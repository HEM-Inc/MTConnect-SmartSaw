#!/bin/bash

SERVICE_NAME="ipc-dashboard"
SERVICE_FILE="ipc-dashboard.service"
SYSTEMD_PATH="/etc/systemd/system"
LOCAL_SERVICE_PATH="./$SERVICE_FILE"

############################################################
# Help
############################################################
Help() {
    echo "IPC Dashboard Service Manager"
    echo
    echo "Syntax: ipc_service.sh [-I|-S|-T|-R|-U|-h]"
    echo
    echo "options:"
    echo "-I    Install/Update service file and reload systemd"
    echo "-S    Start service"
    echo "-T    Stop service"
    echo "-R    Restart service"
    echo "-U    Full update (install/update + restart)"
    echo "-h    Help"
    echo
}

############################################################
# Root check
############################################################
if [[ $(id -u) -ne 0 ]]; then
    echo "Please run as sudo"
    exit 1
fi

############################################################
# Utilities
############################################################
service_exists() {
    systemctl list-units --full -all | grep -Fq "$SERVICE_NAME.service"
}

files_differ() {
    local src="$1"
    local dest="$2"

    if [ ! -f "$dest" ]; then
        return 0
    fi

    if cmp -s "$src" "$dest"; then
        return 1
    else
        return 0
    fi
}

install_service() {
    echo "Checking systemd service file..."

    if files_differ "$LOCAL_SERVICE_PATH" "$SYSTEMD_PATH/$SERVICE_FILE"; then
        echo "Updating service file..."
        cp "$LOCAL_SERVICE_PATH" "$SYSTEMD_PATH/"
        chmod 644 "$SYSTEMD_PATH/$SERVICE_FILE"

        echo "Reloading systemd..."
        systemctl daemon-reload
    else
        echo "Service file already up to date"
    fi

    if ! systemctl is-enabled --quiet $SERVICE_NAME; then
        echo "Enabling service..."
        systemctl enable $SERVICE_NAME
    fi
}

start_service() {
    echo "Starting service..."
    systemctl start $SERVICE_NAME
}

stop_service() {
    echo "Stopping service..."
    systemctl stop $SERVICE_NAME
}

restart_service() {
    echo "Restarting service..."
    systemctl restart $SERVICE_NAME
}

status_service() {
    echo ""
    echo "Service status:"
    systemctl status $SERVICE_NAME --no-pager
}

logs_service() {
    echo ""
    echo "Recent logs:"
    journalctl -u $SERVICE_NAME -n 20 --no-pager
}

############################################################
# Process options
############################################################
if [[ $# -eq 0 ]]; then
    Help
    exit 1
fi

while getopts ":IST RUh" option; do
    case ${option} in
        I)
            install_service
            ;;
        S)
            start_service
            ;;
        T)
            stop_service
            ;;
        R)
            restart_service
            ;;
        U)
            install_service
            restart_service
            ;;
        h)
            Help
            exit
            ;;
        \?)
            echo "Invalid option: -$OPTARG"
            Help
            exit 1
            ;;
    esac
done

status_service
logs_service
