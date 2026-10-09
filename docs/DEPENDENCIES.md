# MTConnect-SmartSaw Stack — Dependency Inventory (SBOM) & Security Notes

**Purpose:** Track every third-party dependency in this Docker stack for security monitoring ("birth certificate" for the stack). Update this file whenever a base image, pinned library, or compose image is changed.

**Generated:** 2026-09-14 from the `MTConnect-SmartSaw` compose file and the sibling HEM-Inc source repos that build each image. Versions reflect the manifests as checked out; verify deployed versions with `docker images` before triaging a specific CVE.

**Key for Risk:** HIGH = address now, WATCH = monitor or plan, OK = healthy.

---

## 1. At-a-Glance Risk Register

| # | Component | Dependency | Deployed as | Risk | Why |
|---|-----------|------------|-------------|------|-----|
| 1 | mongodb | **MongoDB Server 4.4** | `mongo:4.4` (Docker Hub) | HIGH | EOL since Feb 2024 — no security patches. Affected by MongoBleed (CVE-2025-14847, unauthenticated heap exposure, patched 8.0.17/7.0.29/6.0.29; 4.4 never patched). Repo's own `mongodb/Dockerfile` already builds a patched 8.0 image. |
| 2 | watchtower | **containrrr/watchtower** | `containrrr/watchtower` (latest) | HIGH | Upstream **archived (read-only) since Nov 2024**; actively maintained fork is `nickfedor/watchtower`. Runs with `docker.sock` = root-equivalent on the IPC host. |
| 3 | adapter (C++) | OpenSSL 3.0.13 (Conan pin) | compiled into `hemsaw/smartsaw-adapter` | WATCH | Pinned in `conanfile.py`; affected by 2025-2026 OpenSSL 3.0-line CVEs (incl. High-severity CVE-2025-15467, fixed 3.0.19; latest 3.0 patch is 3.0.22). Bump pin to 3.0.22. |
| 4 | ods (C++) | OpenSSL 3.0.13 (Conan pin) | compiled into `hemsaw/ods` | WATCH | Same pin as adapter — bump together. |
| 5 | agent (C++) | libxml2 2.11.7 (Conan pin) | compiled into `hemsaw/mtconnect` | WATCH | EOL-ish; 2.13.x is current branch (2.12.x LTS). CVE-2025-6021 fixes land in 2.13/2.12. Plan a pin bump. |
| 6 | adapter, ods, agent | Boost 1.82 | compiled into images | OK | Old (Aug 2023) but no known exploitable CVEs in used libs; bump opportunistically. |
| 7 | ssc fastapi | Playwright + Chromium (unpinned) | `python:3.11-slim` + `playwright install --with-deps chromium` | WATCH | Chromium is fetched at image build time (good) but unpinned; pin the Playwright version for a reproducible SBOM. |
| 8 | ssc fastapi | unpinned pip deps (35 entries) | `SSC/backend/fastapi` build | WATCH | No lockfile — every image build resolves fresh versions. Add a lock/hash-pinned set for the birth certificate to be exact. |
| 9 | devctl | unpinned pip deps (6 pkgs, `python:3.11-slim`) | `hemsaw/devctl` | WATCH | Same: unpinned; add pins/lock. |
| 10 | ipc-dashboard | gitpython pinned `<3.2.0` | host systemd service, not in Docker | OK | Pinned with upper bound, built as binary with Nuitka. |
| 11 | mosquitto | eclipse-mosquitto:openssl | `hemsaw/mosquitto:latest` | OK | Upstream images patched regularly; rebuilt image tracked here. |
| 12 | mongodb image | mongo 8.0 + OS patches + FCV binaries (5.0/6.0/7.0) | `hemsaw/mongodb` (built) | OK | The repo's approved 8.0 image with OS-level CVE patching. Use it in compose (see Finding #1). |

---

## 2. Stack Map (compose → source)

| Compose service | Container name | Image | Source repo (sibling) | Deps live in |
|---|---|---|---|---|
| adapter | `mtc_adapter` | `hemsaw/smartsaw-adapter:latest` | `MTConnect-SmartAdapter` | `Dockerfile`, `conanfile.py` |
| agent | `mtc_agent` | `hemsaw/mtconnect:latest` | `MTConnect-Agent` (of github.com/HEM-Inc/MTConnect) | `Dockerfile` |
| mqtt | `mtc_broker` | `hemsaw/mosquitto:latest` | `mosquitto` | `Dockerfile` (from `eclipse-mosquitto:openssl`) |
| ods | `ods` | `hemsaw/ods:latest` | `ODS` | `Dockerfile`, `conanfile adapter`, `conanfile.py` |
| devctl | `devctl` | `hemsaw/devctl:latest` | `SSC/devctl` (HEM-Inc/SmartSawConnect) | `SSC/devctl/Dockerfile` (pip, inline) |
| mongodb | `mongodb` | `mongo:4.4` (Docker Hub, **stale pin**) | `mongodb` (HEM-Inc) builds 8.0 | `mongodb/Dockerfile` |
| watchtower | `watchtower` | `containrrr/watchtower` | upstream (archived); fork `nicholas-fedor/watchtower` | Docker Hub image |
| — host systemd | `ipc-dashboard` | prebuilt binary (Nuitka) | `ipc-dashboard` (HEM-Inc) | `requirements.txt` |

Ports exposed on host: 7878 (adapter SHDR), 5000 (agent HTTP), 1883 + 8883 (MQTT plain/TLS), 9625 (ODS), 27017 (**loopback-only** — good), plus IPC dashboard on 8000 (host process).

---

## 3. Component Details

### 3.1 hemsaw/smartsaw-adapter (source: MTConnect-SmartAdapter)
C++ SHDR adapter. Build base `ubuntu:24.04` (Dockerfile_conan), Conan dependencies:
- boost/1.82.0 — Aug 2023 vintage; current line is 1.89. No known exploitable CVEs for the subset in use; upgrade opportunistically.
- openssl/3.0.13 — affected by 2025-2026 3.0-line CVEs: CVE-2025-15467 (High, CMS stack overflow, fixed 3.0.19), CVE-2026-31789/31790 (fixed 3.0.20), CVE-2026-34180 (fixed 3.0.21), CVE-2026-54874/63072/63074/63076/75803 (fixed 3.0.22). Bump pin to 3.0.22.
- rapidjson/cci.20230929 — header-only, no security updates expected.
- antlr4-cppruntime/4.13.1 — current for 4.13 line.
- cmake/3.28.1 (tool only, not shipped).

### 3.2 hemsaw/mtconnect (source: MTConnect-Agent)
C++ MTConnect agent (MTConnect schema 2.4, SHDR 2.0). Base `ubuntu:24.04` + PPA builds; compiled deps via repo's CMake/conan flow (boost, libxml2/2.11.7, openssl 3.0.x, pthread). libxml2 pin flagged (see risk table #5). Image tag is `:latest` — tag each release (e.g., `:1.6.0`) so a deployed CVE can be traced to source.

### 3.3 hemsaw/mosquitto (source: mosquitto)
Thin wrapper on `eclipse-mosquitto:openssl` upstream; adds passwd entries from build secrets. MQTT ports 1883 (plain) and 8883 (TLS) exposed on the host. Auth via `mosquitto_passwd`; rotate passwords on any image rebuild. Upstream `eclipse-mosquitto` receives regular security patches — rebuild/redeploy on advisory.

### 3.4 hemsaw/ods (source: ODS)
C++ Operational Data Store (MQTT→MongoDB bridge). Base `hemsaw/smartsaw_base:ubuntu_24.04_<arch>`; Conan deps:
- boost/1.82.0, openssl/3.0.13 (flagged; same as adapter), gtest/1.14.0 (test-only), rapidjson, yaml-cpp/0.8.0, mongo-cxx-driver/3.8.1, date/3.0.1, libxml2/2.11.7 (flagged), cmake/3.28.1 (tool).
- mongo-cxx-driver 3.8.1 is compatible with server 4.4→8.0; verify after MongoDB upgrade (see Finding #1).

### 3.5 hemsaw/devctl (source: SmartSawConnect /devctl)
Python 3.11-slim, inline pip install (unpinned): xmltodict, requests, pydantic, pymongo, paho-mqtt, python-dateutil. Add a pinned requirements set (see Finding #3).

### 3.6 mongodb
- **Deployed in this stack: `mongo:4.4` from Docker Hub — HIGH risk: EOL and unpatched (MongoBleed CVE-2025-14847).**
- The `mongodb` repo builds an approved image: `mongo:8.0` + OS patch step + copies `mongod` binaries from 5.0/6.0/7.0 for FCV step-upgrade. `MONGO_VERSION` ARG defaults to 8.0.
- Compose keeps 27017 loopback-only and the container is excluded from watchtower (correct — data-bearing service must not be auto-updated).
- Migration path: 4.4 → 5.0 → 6.0 → 7.0 → 8.0 using the bundled binaries (FCV step-through), or fresh 8.0 + `mongorestore` dump.
- mongo-cxx-driver/3.8.1 in ODS supports server 8.0; verify end-to-end after upgrade.

### 3.7 watchtower
`containrrr/watchtower:latest` — **upstream archived Nov 2024, unmaintained.** Maintained fork: `nickfedor/watchtower` (`nickfedor/watchtower` on Docker Hub). Runs with host `docker.sock` (root-equivalent); schedules 03:00 with cleanup/rolling-restart; enabled for app containers, disabled for mongodb. Swap to the fork image to keep receiving fixes (see Finding #2).

### 3.8 ipc-dashboard (host systemd service, not containerized)
Python/FastAPI host process deployed as a Nuitka binary from HEM-Inc/ipc-dashboard.
`requirements.txt` (repo of record for this component's deps):
- bcrypt>=5.0.0
- cryptography>=48.0.1
- fastapi>=0.135.2
- pydantic>=2.12.5
- python-dotenv>=1.2.2
- uvicorn>=0.42.0
- docker>=7.1.0
- python-multipart>=0.0.31
- python-dateutil>=2.9.0.post0
- gitpython>=3.1.50,<3.2.0
- nuitka==2.7.14
- APScheduler==3.11.2
All floors are recent (2024-2025 era). No lockfile — runtime env resolved by `uv`/pip at install. Consider a constraints file for exactness.

### 3.9 SSC FastAPI backend (related, shares MongoDB + saw environment)
Source: `SSC/backend/fastapi` (HEM-Inc/SmartSawConnect). Base `python:3.11-slim` + cairo/pango/weasyprint system libs, `playwright install --with-deps chromium` (unpinned), 35 unpinned pip packages (motor, pandas, pymongo, bcrypt, requests, starlette, uvicorn, xmltodict, fastapi, opencv-python-headless, nuitka, openpyxl, httpx, pyotp, qrcode, Pillow, email-validator, schedule, standard-imghdr, apscheduler, pint, pytz, orjson, weasyprint, jinja2, msal, playwright, mcp>=1.27.2,<2, xlrd, etc.).
Notable: `standard-imghdr` is a Python 3.13-compat shim (imghdr was removed from stdlib in 3.13) — safe on 3.11.

---

## 4. Findings / Actions

### Finding #1 (HIGH) — MongoDB 4.4 in compose is EOL and unpatched
`docker-compose.yml` line 113 pins `mongo:4.4`. Server 4.4 reached EOL Feb 2024 (no security fixes) and is affected by **CVE-2025-14847 ("MongoBleed")** — unauthenticated heap information disclosure via compressed protocol messages, disclosed Oct 2025, fixed in 8.0.17 / 7.0.29 / 6.0.29 (4.4 never gets a fix). Even with the loopback-only port binding, this is the stack's highest-risk item.
**Fix:** migrate to the HEM-Inc `mongodb` repo's approved 8.0 image (it even ships the 5.0/6.0/7.0 binaries for the FCV step-through), then update the compose `image:` pin. Until migrated, at minimum pull the latest 4.4.x image (4.4.29) to pick up OS-level fixes, though the DB engine itself remains unpatched.

### Finding #2 (HIGH) — Watchtower upstream is dead
`containrrr/watchtower` was archived (read-only) in Nov 2024. The stack's auto-updater is on the root Docker socket with 03:00 rolling restarts, so an unmaintained auto-updater is a real exposure (a future Docker API change could also break it or, worse, an abandoned image is a stale-CVE liability).
**Fix:** switch to the maintained fork `nickfedor/watchtower` (GitHub: nicholas-fedor/watchtower; same env/labels, docs at watchtower.nickfedor.com) and pin a version tag instead of `latest`.

### Finding #3 (WATCH) — Unpinned Python deps and `:latest` images
devctl and SSC backend install unpinned dependencies at build time; all five HEMsaw images are `:latest`. For a reliable birth certificate you want to know *exactly* what shipped.
**Fix:** add pinned/locked requirements (or `uv`/pip-tools lockfiles) for devctl and SSC backend; tag images per release (`hemsaw/ods:1.6.0`) alongside `:latest`; record `docker inspect` image digests per deployed release in this file (Section 5).

### Finding #4 (WATCH) — C++ library pins need bumps
Adapter/ODS: `openssl/3.0.13` → 3.0.22 (High-severity CVE-2025-15467 plus several 2026 CVEs; 3.0.22 is the newest 3.0-line patch). ODS: `libxml2/2.11.7` → 2.14.x (or 2.12/2.13 LTS) to close known 2.11-line CVEs. Boost 1.82 → 1.86+ opportunistically.
**Fix:** bump the two `conanfile.py` files together (shared pins), rebuild, and re-run Docker Scout on the images.

---

## 5. Deployment Record (fill per release)

Record the actual deployed state at each release so CVEs can be traced:

| Date | Stack version (ChangeLog) | Image digests (`docker images --digests`) | Mongo version | Notes |
|------|---------------------------|-------------------------------------------|---------------|-------|
| 2026-09-14 | (initial record) | _fill via `docker images --digests` on IPC host_ | 4.4 | mongo:4.4 pin flagged; watchtower upstream archived |

---

## 6. Keeping This Current

- After any dependency bump, update the relevant component section and the risk register.
- Rebuilds of `hemsaw/*` images: re-run Docker Scout (or `trivy image`) and note fixable CVEs in Section 5.
- `docker compose pull` + `watchtower` will silently move `:latest` tags — record digests at deployment, not just tags.
- Recheck EOL statuses quarterly: MongoDB (endoflife.date/mongodb), Ubuntu 24.04 (EOL 2029), Python 3.11 (EOL Oct 2027), Mosquitto, eclipse-mosquitto:openssl tag.
- Sources for component repos: github.com/HEM-Inc/{MTConnect-SmartAdapter, MTConnect (agent), mosquitto, ODS, mongodb, SmartSawConnect (devctl, SSC backend), ipc-dashboard}.