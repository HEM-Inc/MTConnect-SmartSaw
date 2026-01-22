# Fail2ban Configuration

This directory contains a curated `jail.local` and a bootstrap script to install and configure Fail2ban on a target Linux system.

Contents:
- `jail.local` — The Fail2ban configuration you want deployed to target systems.

Supported platforms:
- Debian/Ubuntu (apt)

Note: Run these on the target Linux host (with sudo privileges).

## Quick Start (recommended)

1) Copy this folder to the target machine (or clone the repo there).

2) Run the bootstrap script:
   - Make it executable:
     chmod +x root-os/fail2ban/bootstrap-fail2ban.sh
   - Run it (will sudo if needed):
     root-os/fail2ban/bootstrap-fail2ban.sh

What it does:
- Installs Fail2ban if not present.
- Backs up `/etc/fail2ban/jail.local` to a timestamped `.bak` file if it exists.
- Copies this folder’s `jail.local` to `/etc/fail2ban/jail.local`.
- Ensures correct permissions.
- Enables and (re)starts Fail2ban.
- Shows Fail2ban status and the `sshd` jail (if enabled).

## Manual Install/Update

If you prefer to install/configure manually:

1) Install Fail2ban:
- Debian/Ubuntu:
  sudo apt-get update && sudo apt-get install -y fail2ban
- RHEL/CentOS/Alma/Rocky:
  sudo dnf install -y fail2ban
  # or: sudo yum install -y fail2ban
- Fedora:
  sudo dnf install -y fail2ban
- openSUSE/SLES:
  sudo zypper install -y fail2ban
- Arch/Manjaro:
  sudo pacman -Syu --noconfirm fail2ban

2) Copy configuration:
sudo mkdir -p /etc/fail2ban
sudo cp root-os/fail2ban/jail.local /etc/fail2ban/jail.local
sudo chown root:root /etc/fail2ban/jail.local
sudo chmod 0644 /etc/fail2ban/jail.local

3) Enable and start:
sudo systemctl enable --now fail2ban
sudo systemctl restart fail2ban

4) Verify:
- Overall status:
  sudo fail2ban-client status
- Specific jail (e.g., sshd):
  sudo fail2ban-client status sshd

## Customization

Edit `root-os/fail2ban/jail.local` in this repo to suit your environment, then re-run the bootstrap script to deploy updates. Common options:

- Global defaults:
  - `bantime` — how long an IP is banned.
  - `findtime` — time window to count failures.
  - `maxretry` — number of failures before a ban.
- Jails:
  - `[sshd]` should typically be enabled on servers with SSH open to the internet.

Example fragment (for reference):
```/dev/null/fail2ban-example.conf#L1-50
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
port    = ssh
logpath = %(sshd_log)s
backend = systemd
