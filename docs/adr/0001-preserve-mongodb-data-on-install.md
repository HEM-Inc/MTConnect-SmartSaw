# ADR 0001: Preserve MongoDB Data Directory During Install

## Status
Accepted

## Context
`ssInstall.sh` is used both for first-time installation and as a fallback path from `ssUpgrade.sh` when `ssUpgrade` detects that the MTConnect Agent configuration (`/etc/mtconnect/config/agent.cfg`) is missing. The `InstallMongodb()` function in `ssInstall.sh` contained:

```bash
rm -rf /etc/mongodb/config
rm -rf /etc/mongodb/data
```

The directory `/etc/mongodb/data/db/` is mounted into the MongoDB container as `/data/db/` and contains the actual production database files. When `ssUpgrade` fell back to `ssInstall` on a partially-installed system (for example, after `agent.cfg` was accidentally deleted or moved), `ssInstall` recreated `/etc/mongodb/data/db` as an empty directory, effectively wiping all production data.

This created a latent data-loss vector: any trigger that caused the fallback path to run (missing agent.cfg) would silently destroy the MongoDB database.

## Decision
`InstallMongodb()` in `ssInstall.sh` will **never** remove or alter the contents of `/etc/mongodb/data/db/`. Repo data files (Python scripts and CSVs under `/etc/mongodb/data/`, excluding `db/`) may be cleaned and re-copied, but the `db/` directory itself is treated as **Runtime State** and is off-limits to all install and upgrade operations.

ODB and Devctl config directories are confirmed to contain only static **Repository Files** and remain safe to `rm -rf` and replace.

**Update:** The automatic **Fallback** from `ssUpgrade.sh` to `ssInstall.sh` on missing `agent.cfg` has been identified as a source of accidental Full Upgrade behavior. Subsequent discussion (see ADR 0003‑Fallback) addresses whether this fallback should remain unconditional.

## Consequences
- **Positive:** The fallback path from `ssUpgrade` to `ssInstall` no longer risks accidental data loss.
- **Positive:** Re-running `ssInstall` on an already-configured system is safer.
- **Negative:** Stale repo data files (e.g., old `*.py` or `*.csv` scripts) may accumulate in `/etc/mongodb/data/` if they are removed from the repo but not cleaned up. We mitigated this by adding a targeted cleanup that deletes immediate children of `/etc/mongodb/data/` except `db/` before copying the new repo files.
- **Implication:** Any intentional MongoDB data reset must now be performed explicitly (e.g., via `ssClean.sh -S` or manual `rm -rf`) rather than happening as a side effect of install.
