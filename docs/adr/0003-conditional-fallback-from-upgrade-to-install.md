# ADR 0003: Remove Automatic Fallback from Upgrade to Install

## Status
Accepted

## Context
`ssUpgrade.sh` historically detected a missing `/etc/mtconnect/config/agent.cfg` and automatically delegated to `ssInstall.sh`. This caused two problems:

1. **Surprise full reinstall.** An operator running a Selective Upgrade (e.g., `-d` for Agent device file) could silently trigger an `ssInstall` that recreates all six components, runs Docker Compose, and re-initializes databases — losing the original selective intent.
2. **Narrow utility.** Operational feedback confirmed this fallback is only genuinely useful after a full `ssClean -A` has been run, when the operator expects to rebuild the entire system. In all other cases, a missing `agent.cfg` is a symptom of corruption or partial uninstallation and should not be auto-rectified by reinstalling everything.

## Decision
Remove the automatic fallback entirely. `ssUpgrade.sh` now treats a missing `agent.cfg` as a fatal error:

```
ERROR: System appears not to be installed (/etc/mtconnect/config/agent.cfg missing).
Run ssInstall.sh to install, then use ssUpgrade.sh for updates.
```

The IPC Dashboard (another team's code) does not require changes because it continues to invoke `ssUpgrade.sh` normally — the only difference is that an unexpected fallback now surfaces as an explicit error rather than silently launching a full install.

## Consequences
- **Positive:** Complete elimination of surprise reinstalls. Selective Upgrade intent is always respected.
- **Positive:** The `ssInstall.sh` command remains available after `ssClean -A` for explicit reinstallation.
- **Negative:** Operators who were habitually running `ssUpgrade` after a clean will now see an error and must switch to `ssInstall`. This is considered acceptable because the previous behavior was dangerous and unpredictable.
- **Implication:** A system with a populated `/etc/mongodb/data/db/` but missing `/etc/mtconnect/config/agent.cfg` is now treated as an error state instead of being auto-repaired.
