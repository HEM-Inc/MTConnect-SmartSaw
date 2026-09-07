# ADR 0002: Single-instance lock for install, upgrade, and clean

## Status
Accepted

## Context
The SmartSaw platform has several entry points that mutate deployment state:
- SSH/CLI: operators run `ssInstall.sh`, `ssUpgrade.sh`, or `ssClean.sh` directly.
- IPC Dashboard: another team's Python backend spawns those same scripts via `subprocess`, behind the `/api/ipc/install`, `/api/ipc/upgrade`, and `/api/ipc/clean` endpoints.

All three scripts write the same `/etc/*` configuration directories and drive the same `docker compose` project. If an upgrade is already running (say, pulling images on a slow link) and an operator or a dashboard button starts a second run, the two bash processes race on `/etc/adapter/config/`, `/etc/mtconnect/config/`, and the rest. The outcome is undefined: partial configs, truncated files, a wedged Compose state, or in the case of a concurrent `ssClean.sh`, files deleted out from under a running install.

No locking mechanism existed.

## Decision
`ssInstall.sh`, `ssUpgrade.sh`, and `ssClean.sh` acquire an exclusive advisory file lock (`flock`) on `/var/lock/HEMsaw-mtconnect.lock` through the shared `acquire_upgrade_lock` helper in `lib.sh`.

- Each script calls `acquire_upgrade_lock <op>` after argument parsing and before its first mutation. Parsing first means `-h` and malformed arguments exit without touching the lock. "First mutation" is whichever comes first: an `apt` install, a `docker compose` call, a `systemctl` change, or a write under `/etc`. In `ssUpgrade.sh` that is the `docker-compose-v2` bootstrap; in `ssInstall.sh` it is the legacy-daemon teardown, which was moved below argument parsing so it too is covered.
- `ssClean.sh` takes the lock only when an uninstall is requested. `-L` log repair edits Docker log files and nothing else, so it stays outside the lock.
- If another instance holds the lock, the script prints `Another install, upgrade, or clean is already in progress`, followed by a `Holder:` line naming the operation, pid, and start time recorded by the current holder, then exits 1. The exit code and the first line are a stable contract for the dashboard backend to match on.
- The helper opens the lock file with `<>` (read-write, no truncate) so a blocked caller can read the holder line. The winner truncates and rewrites it after `flock` succeeds.
- `HEMSAW_UPGRADE_LOCKED=1` (exported) makes `acquire_upgrade_lock` a no-op. This covers any case where one locked script execs another; `ssUpgrade.sh` no longer delegates to `ssInstall.sh` on a missing `agent.cfg` (it now errors and tells the operator to run `ssInstall.sh`), but the guard stays as cheap insurance.
- The kernel releases the lock when the holding process exits, so a crash cannot leave a stale lock.

The IPC Dashboard needs no change *as long as* every state-changing action it performs goes through one of these three scripts. A dashboard feature that writes `/etc/*` or runs `docker compose` from inside the backend binary would bypass the lock and needs its own handling. That has not been verified against the released `ipc-dashboard` binary and should be.

## Consequences
- Concurrent install, upgrade, and clean runs from CLI or dashboard can no longer corrupt each other.
- A blocked caller now reports which operation holds the lock and since when, instead of a bare "in progress".
- Stopping a long run from the dashboard UI still requires killing the whole child process tree. Killing only the Python wrapper leaves the bash child holding the lock until it finishes or dies.
- `flock` from `util-linux` must be present on the IPC. Debian and Ubuntu ship it by default. `date -Is` is used for the holder timestamp with a plain `date` fallback.
- Anything the dashboard runs outside these scripts is still unprotected. Closing that gap depends on the dashboard team.
