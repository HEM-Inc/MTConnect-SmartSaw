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

The IPC Dashboard is a Python FastAPI application that runs as a **host-level systemd service**, not inside Docker. It communicates with the host Docker daemon and systemd to manage the MTConnect SmartSaw stack.

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

### Backend Modules

| Module | Purpose |
|---|---|
| `backend_main.py` | Common backend entry point and bootstrap |
| `fastapi_main.py` | FastAPI server initialization and startup |
| `backend_api.py` | Core API business logic abstraction |
| `backend_config.py` | Configuration management (`backend_ipc_config.json`) |
| `backend_logger.py` | Structured logging with file rotation |
| `backend_sessionmgr.py` | HTTP session creation and validation |
| `backend_ssemanager.py` | Server-Sent Events (SSE) for live status |
| `beapi_ipcstatus.py` | Docker container status queries |
| `beapi_ipcupgrade.py` | Script execution (ssInstall, ssUpgrade, ssClean) |
| `beapi_userauth.py` | Authentication and user profile management |
| `beapi_certdownload.py` | MQTT TLS certificate download helpers |
| `fastapi_*.py` | FastAPI route registration for each API area |

### Frontend Pages

| Page | Path | Purpose |
|---|---|---|
| Login | `index.html` | Username/password authentication |
| Dashboard | `html/dashboard.html` | Real-time container status view |
| Control | `html/control.html` | System control panel (install, upgrade, clean) |
| Status | `html/control/status.html` | Detailed container listing |
| Config | `html/control/updateConfig.html` | Configuration update interface |
| Security | `html/security.html` | Certificate and TLS management |
| Device | `html/device.html` | Device info view |

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
- Python 3.10+
- `uv` package manager (preferred) or `pip`
- Docker and Docker Compose V2 installed

### Manual Install

```bash
cd /path/to/MTConnect-SmartSaw/ipc_dashboard
sudo bash ipc_service.sh -U
```

This will:
1. Detect the `uv` binary (PATH, pip module, or pipx)
2. Resolve the backend working directory (`ipc_dashboard/backend/fastapi`)
3. Generate and install `ipc-dashboard.service` to `/etc/systemd/system/`
4. Start the service

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
cd /path/to/MTConnect-SmartSaw/ipc_dashboard

# Install / update service file and reload systemd
sudo bash ipc_service.sh -I

# Start
sudo bash ipc_service.sh -S

# Stop
sudo bash ipc_service.sh -T

# Restart
sudo bash ipc_service.sh -R

# Full update (install + restart)
sudo bash ipc_service.sh -U

# Display help
sudo bash ipc_service.sh -h
```

### systemd Unit File

The generated service (`/etc/systemd/system/ipc-dashboard.service`) runs:
- **User/Group**: `hemsaw` (created if missing)
- **Working Directory**: `ipc_dashboard/backend/fastapi`
- **ExecStart**: `uv run fastapi_main.py`
- **Restart**: Always, with 5-second backoff
- **Logs**: Written to journald (`journalctl -u ipc-dashboard -f`)

---

## Configuration

### Backend Configuration

`backend/config/backend_ipc_config.json`:

```json
{
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
      "ca_file": "",
      "cert_file": "",
      "key_file": ""
    }
  },
  "certs": {
    "ca_cert_path": "/etc/mqtt/certs/ca.crt"
  }
}
```

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

## License

See the repository LICENSE file for details.
