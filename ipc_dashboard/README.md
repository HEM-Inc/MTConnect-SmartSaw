# IPC Dashboard

A FastAPI-based web management interface for the SmartSaw MTConnect IPC. The dashboard provides a browser-based alternative to running command-line scripts for managing Docker containers, viewing system status, and performing install/upgrade/clean operations.

**Status**: Optional (planned to become core in a future release)

---

## Table of Contents

- [Architecture](#architecture)
- [Features](#features)
- [Installation](#installation)
- [Service Management](#service-management)
- [Configuration](#configuration)
- [API Endpoints](#api-endpoints)
- [Ports and Exposed Services](#ports-and-exposed-services)

---

## Architecture

The IPC Dashboard is a Python FastAPI application that runs as a **host-level systemd service**, not inside Docker. It communicates with the host Docker daemon and systemd to manage the MTConnect SmartSaw stack. It is deployed here as a prebuilt binary; the sections below describe the runtime behavior of that binary.

```
User Browser
    |           https://localhost:8000/ (TLS optional)
    |           http://localhost:8000/ (plain)
    ▼
[ IPC Dashboard ]
   FastAPI Backend (Python)
   ├── Static File Serving (frontend/)
   ├── API Routes (/api/*)
   │   ├── /api/auth/*       User authentication
   │   ├── /api/ipc/status   Container status
   │   ├── /api/ipc/upgrade  Upgrade/install operations
   │   ├── /api/cert/*       Certificate management
   │   └── /api/timezones    Timezone selection
   └── SSE Manager           Server-Sent Events for live status
    |
    ├─ Docker Socket (read-only) → Container inspection
    ├─ systemd → Service control (ipc-dashboard.service)
    └─ /etc/ filesystem → Config viewing (read-only)
```

### Source Code and Releases

The dashboard's application code (FastAPI backend and frontend) is **not maintained in this repository**. The source lives in the [`HEM-Inc/ipc-dashboard-release`](https://github.com/HEM-Inc/ipc-dashboard-release) repository, which also publishes prebuilt `ipc-dashboard` binary releases. This repo ships only the deployment pieces:

| Item | Path | Purpose |
|---|---|---|
| Install script | `dashService.sh` (repo root) | Downloads the binary, verifies its checksum, and manages the systemd service |
| Service template | `services/ipc-dashboard.service` | systemd unit template resolved at install time |
| Dashboard config | `config/backend_ipc_config.json` | Configuration consumed by the binary at runtime |

Binary versions, release notes, and reporting for dashboard bugs live in the release repository.

---

## Features

- **Real-time Container Status**: View all Docker containers (names, states, uptime, image versions) without running `docker ps`
- **System Control**: Trigger `ssInstall.sh`, `ssUpgrade.sh`, or `ssClean.sh` operations from the browser
- **Configuration Updates**: Change AFG, device XML, alarm JSON, and other configs through the web UI
- **Certificate Management**: Download MQTT CA, client certificate, and client key for bridge setup
- **User Authentication**: Role-based access with session cookies (HTTPOnly, Secure, SameSite)
- **Live Updates**: Server-Sent Events stream real-time container state changes
- **Timezone Support**: Configurable timezone for timestamps displayed in the UI

---

## Installation

The dashboard is **optional** in the current release. It is not installed automatically by `ssInstall.sh`.

### Prerequisites

- Ubuntu 20.04+ (or compatible Linux distribution)
- `curl` (used by `dashService.sh` to fetch releases; `jq`, used to verify them, is installed automatically via `apt` if missing)
- Docker and Docker Compose V2 installed

The IPC Dashboard is distributed as a prebuilt binary — there is no local Python source, `pyproject.toml`, or virtual environment to manage in this repo. `dashService.sh` downloads it automatically from `HEM-Inc/ipc-dashboard-release` on GitHub. Available versions and release notes are published there.

### Manual Install

```bash
cd /path/to/MTConnect-SmartSaw
sudo ./dashService.sh -U
```

This will:
1. Determine the service user/group to run as
2. Download the latest (or requested) `ipc-dashboard` binary release and verify its checksum
3. Set ownership on `ipc_dashboard/bin/` so the backend can self-update
4. Configure a restricted, passwordless `sudo systemctl restart ipc-dashboard.service` rule for the backend
5. Generate and install `ipc-dashboard.service` to `/etc/systemd/system/`, then enable and start it

### Verify

```bash
sudo systemctl status ipc-dashboard
# or
curl http://localhost:8000/health
```

Then open a browser to `http://<ipc-ip>:8000/`.

---

## Service Management

```bash
cd /path/to/MTConnect-SmartSaw

# Install / update service file and reload systemd
sudo ./dashService.sh -I

# Start
sudo ./dashService.sh -S

# Stop
sudo ./dashService.sh -T

# Restart
sudo ./dashService.sh -R

# Full update (install + restart)
sudo ./dashService.sh -U

# Display help
sudo ./dashService.sh -h
```

### systemd Unit File

The generated service (`/etc/systemd/system/ipc-dashboard.service`) runs:
- **User/Group**: `hemsaw`
- **Working Directory**: `ipc_dashboard/`
- **ExecStart**: `ipc_dashboard/bin/ipc-dashboard` (the downloaded binary)
- **Restart**: Always, with 5-second backoff
- **Logs**: Written to journald (`journalctl -u ipc-dashboard -f`)

---

## Configuration

### Backend Configuration

`config/backend_ipc_config.json`:

```json
{
    "deployment_path": "~/MTConnect-SmartSaw",
    "binary_release_repository" : {
        "repo_name": "ipc-dashboard-release",
        "repo_owner": "HEM-Inc"
    },
    "name": "IPC Dashboard",
    "type": "fastapi",
    "timezone": "America/Chicago",
    "logger_config": {
        "logging_level": "INFO",
        "file_logging": "No"
    },
    "fastapi": {
        "enable": "Yes",
        "host": "0.0.0.0",
        "port": 8000,
        "domain_names": [],
        "security": {
            "enable": "No",
            "type": "ssl",
            "ca_file": "ipc_dashboard/certs/ca.crt",
            "cert_file": "ipc_dashboard/certs/server.crt",
            "key_file": "ipc_dashboard/certs/server.key"
        }
    },
    "certs": {
        "ca_cert_path": "/etc/mqtt/certs/ca.crt"
    }
}
```

`binary_release_repository` is metadata only — `dashService.sh` pulls `ipc-dashboard` binary releases from a hardcoded `GITHUB_OWNER`/`GITHUB_REPO` (`HEM-Inc`/`ipc-dashboard-release`) at the top of the script, not from this file.

### User Credentials

The dashboard creates a `.env` file on first startup to store user credentials. This file is created at `ipc_dashboard/.env` and stores `bcrypt` hashed passwords.

Passwords are managed via the dashboard UI (Security page). There is no command-line password reset utility.

### Certificate Paths

For TLS bridge certificate download, ensure the following files exist on the host:
- `/etc/mqtt/certs/ca.crt`
- `/etc/mqtt/certs/client.crt`
- `/etc/mqtt/certs/client.key`

These paths are read by the dashboard backend and exposed through the `/api/cert/*` endpoints.

---

## API Endpoints

### Authentication

| Method | Endpoint | Description |
|---|---|---|
| POST | `/api/auth/login` | Authenticate and receive session cookie |
| POST | `/api/auth/logout` | Invalidate session |
| GET | `/api/auth/me` | Get current user profile |

### IPC Status

| Method | Endpoint | Auth Required | Description |
|---|---|---|---|
| GET | `/api/ipc/status` | Yes | Docker container summary |
| GET | `/api/ipc/status/stream` | Yes | SSE stream of container events |
| GET | `/api/ipc/logs` | Yes | Fetch container logs |

### IPC Upgrade / Operations

| Method | Endpoint | Auth Required | Description |
|---|---|---|---|
| POST | `/api/ipc/upgrade` | Admin | Run `ssUpgrade.sh` with options |
| POST | `/api/ipc/install` | Admin | Run `ssInstall.sh` with options |
| POST | `/api/ipc/clean` | Admin | Run `ssClean.sh` with options |

### Certificates

| Method | Endpoint | Auth Required | Description |
|---|---|---|---|
| GET | `/api/cert/ca` | Yes | Download CA certificate |
| GET | `/api/cert/client` | Yes | Download client certificate |
| GET | `/api/cert/key` | Yes | Download client private key |

### Utilities

| Method | Endpoint | Auth Required | Description |
|---|---|---|---|
| GET | `/api/timezones` | Yes | List available timezones |
| GET | `/api/timezones/valid` | Yes | Filtered timezone list |

### Web UI

| Method | Endpoint | Description |
|---|---|---|
| GET | `/` | Login page |
| GET | `/html/*` | Static dashboard pages |
| GET | `/js/*`, `/css/*`, `/images/*` | Frontend assets |

---

## Ports and Exposed Services

| Port | Protocol | Component | Access |
|---|---|---|---|
| 8000 | HTTP | IPC Dashboard FastAPI | Browser / API clients |
| 5000 | HTTP | MTConnect Agent | External clients |
| 7878 | TCP | HEMsaw Adapter SHDR | Internal (Agent → Adapter) |
| 9625 | HTTP | ODS REST API | Internal |
| 1883 | MQTT | Mosquitto Broker | Internal / Bridge |
| 8883 | MQTT-TLS | Mosquitto Broker (TLS) | Internal / Bridge |
| 27017 | TCP | MongoDB | Localhost only |

---

## Troubleshooting

- **Dashboard not reachable**
  - Check: `sudo systemctl status ipc-dashboard`
  - Verify port 8000 is open and not blocked by firewall
  - Check journal: `sudo journalctl -u ipc-dashboard -n 100`

- **Authentication errors**
  - Clear the `.env` file in `ipc_dashboard/` and restart to re-initialize default users
  - Ensure browser cookies are enabled (session cookie is required)

- **Certificate download fails**
  - Confirm files exist at `/etc/mqtt/certs/ca.crt`, `client.crt`, `client.key`
  - Verify file permissions allow read access for the `hemsaw` user

- **Container status not updating**
  - Confirm the dashboard user has permission to read the Docker socket
  - Verify Docker is running: `sudo docker ps`

- **Dashboard bugs or missing features**
  - The application source is not in this repo — report issues in the `HEM-Inc/ipc-dashboard-release` repository

## License

See the repository LICENSE file for details.
