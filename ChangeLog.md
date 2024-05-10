# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
For build level release notes see https://github.com/mtconnect/cppagent/

## [Unreleased]

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


## Types of changes
### `Added` for new features.
### `Changed` for changes in existing functionality.
### `Deprecated` for soon-to-be removed features.
### `Removed` for now removed features.
### `Fixed` for any bug fixes.
### `Security` in case of vulnerabilities.
