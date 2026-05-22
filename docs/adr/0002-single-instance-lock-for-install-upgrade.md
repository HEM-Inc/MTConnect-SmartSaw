# ADR 0002: Single-Instance Lock for Install and Upgrade

## Status
Accepted

## Context
The SmartSaw platform supports multiple entry points for triggering installs and upgrades:
- **SSH/CLI:** Operators run `ssInstall.sh` or `ssUpgrade.sh` directly.
- **IPC Dashboard:** Another team's Python backend (`beapi_ipcupgrade.py`) spawns `ssUpgrade.sh` via `subprocess.Popen`.

Both entry points target the same `/etc/*` configuration directories and `docker compose` state. If an upgrade is already running (e.g., pulling Docker images on a slow network) and an operator or dashboard widget triggers a second concurrent invocation, the two bash processes will race to write `/etc/adapter/config/`, `/etc/mtconnect/config/`, and so on. The result is undefined: partial configs, truncated files, or a hung Docker Compose state.

Additionally, `ssUpgrade.sh` contains a **Fallback** path: when it detects a missing `/etc/mtconnect/config/agent.cfg`, it delegates to `ssInstall.sh`. If a concurrent upgrade is already in progress when this fallback fires, the fallback must fail safely rather than join the race.

No locking mechanism existed.

## Decision
Both `ssInstall.sh` and `ssUpgrade.sh` shall acquire an **exclusive advisory file lock** (`flock`) on `/var/lock/HEMsaw-mtconnect.lock` before performing any filesystem or Docker operations.

- If another instance already holds the lock, the script emits an error (`Another install or upgrade is already in progress`) and exits immediately.
- When `ssUpgrade.sh` falls back to `ssInstall.sh`, the parent sets `HEMSAW_UPGRADE_LOCKED=1` (exported). `ssInstall.sh` detects this environment variable and skips its own `flock` call, relying on the parent process's open file descriptor, which remains held until the parent exits.
- The lock is automatically released by the kernel when the holding script's process terminates, so stale locks from crashes are impossible.

The IPC Dashboard requires no changes; the protection is entirely within the shell scripts.

## Consequences
- **Positive:** Eliminates undefined behavior from concurrent installs/upgrades whether triggered from CLI or dashboard.
- **Positive:** The fallback path respects the same guard — a second upgrade attempt cannot sneak in while the first is mid-fallback.
- **Neutral:** Stopping a long-running upgrade externally (e.g., via dashboard UI) still requires terminating the underlying child process tree; killing only the Python wrapper does not release the advisory lock held by the shell subprocess.
- **Implication:** `flock` from `util-linux` must be present on the target IPC. Debian/Ubuntu systems ship this by default. If `flock` were ever absent, the script would need a fallback, but this is considered out of scope for current target environments.
