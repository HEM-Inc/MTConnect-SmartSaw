# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
For build level release notes see https://github.com/mtconnect/cppagent/

---

## Types of changes

### `Added` for new features.

### `Changed` for changes in existing functionality.

### `Deprecated` for soon-to-be removed features.

### `Removed` for now removed features.

### `Fixed` for any bug fixes.

### `Security` in case of vulnerabilities.

---

## [Unreleased]



=======

# [Released]

##[4.2.0] - 2026/07/23 - emprarthanak

### Added

- Added IPC Dashboard service management script, service file and configs 

## [4.1.0] - 2026/06/19 - emnidhish

### Changed

- Added new topics to devctl configuration to support heartbeat feature.

## [4.0.0] - 2026/06/04 - max harris

### Added

- Added IPC Dashboard — a FastAPI-based web dashboard for local management of the SmartSaw IPC.
  - Real-time Docker container status via browser UI
  - Web-based control for install, upgrade, and clean operations
  - User authentication with role-based access control
  - Certificate download for MQTT TLS bridge setup
  - Server-Sent Events (SSE) for live status updates
  - Runs as a Docker container on port 8000
- Added `ipc_dashboard/` directory containing backend (FastAPI), frontend (HTML/JS/CSS), and service management (`ipc_service.sh`).
- Added IPC Dashboard Control page with full frontend implementation: setup, logs, clean, and updateConfig views.
- Added IPC Dashboard backend API modules: install (`beapi_ipcinstall`), clean (`beapi_ipcclean`), logs (`beapi_ipclogs`), file manager (`beapi_filemanager`), and IPC manager (`beapi_ipcmanager`).
- Added IPC Dashboard timezone modal and certificate download on the Security page.
- Added security headers to the IPC Dashboard FastAPI backend.
- Added CIP protocol support to SmartSaw adapter configs to match adapter 1.7.0, with backward-compatible Sysmac platform configuration.
- Added exclusive `flock` lock on `/var/lock/HEMsaw-mtconnect.lock` in `ssInstall.sh` and `ssUpgrade.sh` to prevent concurrent invocations from CLI or the IPC Dashboard.
- Added `SIGINT`/`SIGTERM` trap in `ssUpgrade.sh` to kill background update jobs before releasing the lock, preventing partial upgrades.
- Added container exclude support (`-x`) and persistent `Use_MQTT_Bridge` env variable for MQTT bridge preference across installs and upgrades.
- Added architecture decision records in `docs/adr/` (ADR-0001: preserve MongoDB data on install; ADR-0002: single-instance lock; ADR-0003: no conditional upgrade-to-install fallback) and domain glossary in `docs/CONTEXT.md`.

### Changed

- Bumped MTConnect schema from 2.5 to 2.7 in `agent.cfg` and all device XML config files.
- Changed schema namespace URLs from HTTPS to HTTP across all device config files.
- Migrated IPC Dashboard from a host-level systemd service to a Docker container.
- `ssUpgrade.sh` `-u` flag now triggers a full stack update; deprecated `-v` flag removed.
- Refactored `ssInstall.sh`, `ssUpgrade.sh`, and `ssClean.sh` to use shared `lib.sh` with centralized CLI argument validation and MQTT bridge detection logic.
- Replaced `rsync` with `rm + cp` in upgrade scripts for more predictable file replacement.
- Updated MQTT TLS certificates.

### Fixed

- `InstallMongodb()` now preserves `/etc/mongodb/data/db/` (production data) during upgrades and reinstalls, preventing accidental data loss.
- Removed automatic fallback from `ssUpgrade` to `ssInstall` when `agent.cfg` is missing, preventing surprise full reinstalls during selective upgrades.
- Fixed shell script path quoting in `ssInstall.sh` and `ssUpgrade.sh`.
- Fixed `cp` globbing to include hidden files (`cp -r dir/.` instead of `dir/*`) during upgrade.
- Fixed `update_agent_cfg` to handle a missing `Devices` line.
- Fixed `ssClean.sh` error message that referenced the wrong script name.

## [3.3.0] - 2026/01/08 - maxharris

### Added

- Added saw_maintenance_list to the Adapter AFG.
- Added saw_maintenance_list to the Agent XML.
- Added TLS support for MQTT bridge on 8883.

## [3.2.0] - 2025/10/15 - emkarthikb

### Added

- Added Devctl logging configuration via the configuration file.

## [3.1.2] - 2025/05/27 - Max Harris

### Added

- Added a check to auto-detect the docker-compose version and a way to force a specific version.

## [3.1.1] - 2025/05/02 - emkarthikb

### Fixed

- Fixed Devctl config file json syntax issue

## [3.1.0] - 2025/04/29 - emprarthanak

### Added

- logs folder added to devctl

## [3.0.0] - 2025/03/25 - Max Harris

### Changed

- Refactored the ssUpgrade.sh and ssInstall.sh scripts to nativly support the new docker-compose v2 commands by auto-detecting the docker-compose version.
- Refactored the ssUpgrade.sh script to run in parallel

### Deprecated

- Removed the -1 and -2 options in the ssUpgrade.sh, ssInstall.sh, and ssClean.sh scripts

## [2.3.3] - 2024/12/26 - Max Harris

### Fixed

- Removed the XML formatting that was created from Zed. This broke the Agent XML Parser.

## [2.3.2] - 2024/12/17 - Max Harris

### Added

- Model name added to agent device xml

## [2.3.1] - 2024/12/12 - Max Harris

### Fixed

- Corrected a mistake of what line is being updated on the sed for the devctl file

### Changed

- Updated Readme to add -c option

## [2.3.0] - 2024/12/11 - emprarthanak

### Added

- Jira ID - EP7US23TS4
  - Devctl(device control) container included within docker-compose.
  - 'devctl' directory containing configuration files.

### Changed

- Updated scripts to support docker-compose.
- Updated README.md file.

## [2.2.1] - 2024/10/09 - Max Harris

### Fixed

- Fixed the issue where it did not default the run_init_jp to false so init ran all the time.

## [2.2.0] - 2024/10/09 - Max Harris

### Added

- A way to init the jobs and parts DB on the upgrade, the install will auto clear the databases.

## [2.1.5] - 2024/10/08 - Max Harris

### Changed

- Modified the agent devices to have an a0 axis specification and extended the a0 axis dimension to the workenvelope.

## [2.1.4] - 2024/10/07 - Max Harris

### Added

- Check to see if the file names are there before running or exit with an error code.

## [2.1.3] - 2024/09/30 - Max Harris

### Changed

- Replace the device file device uuid line 11 insted of adding additional line which needed commenting out of the origional line.

## [2.1.2] - 2024/09/29 - Max Harris

### Added

- Added the ability to remember the last overwrite command (-a,-u,-d,-j) to the ssInstall and ssUpgrade bash files

## [2.1.1] - 2024/08/29 - Max Harris

### Changed

- Modified the bridge to set the uuid as the serial number declared in the env.sh or from the command line.

## [2.1.0] - 2024/08/21 - Max Harris

### Added

- Added a env.sh file for defining the default env

## [2.0.0] - 2024/08/09 - Max Harris

### Changed

- Removed the individual update tags infavor of a full update with an env file
- Updated the readme

### Added

- Created a Source env.sh file for setting the default file names for the unique install.

## [1.4.0] - 2024/06/18 - emsumithn

### Added

- Jira ID: EP4US8
  - added message event data items configurations to afg files
  - added message event data items definition to device files
  - saw_service_status, saw_switch_status

### Changed

- Updated alarm Json data file of adapter

## [1.3.6] - 2024/06/12 - Max Harris

### Added

- add Clean log to the ssClean.sh bash script as -L

## [1.3.5] - 2024/05/15 - emsumithn

### Changed

- Updated configurations for condition functions in afg files
  - x0_axis_condition, z0_axis_condition, c0_axis_condition
  - communication_condition, hyd_low_level_cond, end_of_bar_cond

## [1.3.4] - 2024/05/14 - emsumithn

### Added

- Added adapter log folder support in scripts and docker compose

### Changed

- Updated README file

### Fixed

- Fixed adapter data folder file updates in ssUpgrade

## [1.3.3] - 2024/05/13 - Max Harris

### Added

- Added compatibility for the docker compose v2 commands (needed for Ubuntu 24.04)

## [1.3.2] - 2024/05/13 - Max Harris

### Fixed

- Fixed the adapter data folder call from ssInstall and ssUpgrade
- Updated the afg and device files to 2.3

## [1.3.1] - 2024/05/10 - emAdithyaShenoy

### Changed

- Jira Id: EP4US7
  - renamed mongod.conf.orig to mongod.conf

### Fixed

- corrected mongodb script to take custom configuration file

## [1.3.0] - 2024/05/09 - emsumithn

### Added

- Jira ID : EP4US3
  - Alarm JSON file to support generic function for Condition

### Changed

- Updated script to handle Alarm JSON File

## [1.2.3] - 2024/05/09 - Max Harris

### Fixed

- Corrected the volume issue for mongodb

## [1.2.2] - 2024/05/02 - Max Harris

### Changed

- Changed the localhost to use host.docker.internal as an extrahost for directing the host ipaddress - @MaxHarris

### Fixed

- Fixed duplicate material entry

## [1.2.1] - 2024/05/01 - Max Harris

### Added

- Upload the mongodb default material to upgrade and install script
- ssClean script removes the daemons with the -d command

### Changed

- Changed the port 9800 to 7878 (mtconnect default adapter port)

## [1.2.0] - 2024/04/29 - emAdithyaShenoy

### Added

- Jira Id: EP4US7
  - MongoDB container included within docker-compose.
  - 'mongodb' directory containing configuration files.

### Changed

- Updated scripts to support docker-compose.
- Updated README file.

## [1.1.0] - 2024/04/05 - emprarthanak

### Added

- Jira Id: EP4US1
  - ODS container included within docker-compose.
  - 'ods' directory containing configuration files.

### Changed

- Adapter from systemd to docker container.
  - Added adapter container to docker-compose.
- Updated scripts to support docker-compose.
- Update the adapter (HA, SA, SM) afg(s) for commands - @MaxHarris

## [1.0.1] - 2023/12/18 - Max Harris

### Added

- SmartSaw_DC30M-SCT.xml to the device file list.

## [1.0.0] - 2023/12/05 - Max Harris

### Added

- This is the intial revisioned release of the code.
