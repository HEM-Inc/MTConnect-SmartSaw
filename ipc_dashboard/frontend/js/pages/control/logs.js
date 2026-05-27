/* ============================================================
   logs.js
   ============================================================
   Set CONFIG.useDummy = false and fill in real endpoints
   once the logs API is ready.
   ============================================================ */

const CONFIG = {
  // GET /api/containers
  // Response: { status, message, data: { data: { container_name: {...}, ... } } }
  containersEndpoint: "/api/files-structure",

  // Logs endpoint — swap to real URL when API is ready
  logsEndpoint: "/api/docker-logs",

  // Toggle dummy mode (set false when real logs API is ready)
  useDummy: false,

  // Auto-refresh interval ms (0 = disabled)
  pollInterval: 0,

  // Max lines kept in DOM
  maxLines: 5000,
};

/* ============================================================
   DUMMY DATA
============================================================ */

const DUMMY_CONTAINERS = [
  "adapter",
  "agent",
  "devctl",
  "mongodb",
  "mqtt",
  "ods",
];

const DUMMY_LOGS = {
  adapter: [
    "2024-05-01 10:00:00 [INFO]    Adapter service starting...",
    "2024-05-01 10:00:01 [INFO]    Loading config from /config/SmartSaw_VT_HA.afg",
    "2024-05-01 10:00:02 [INFO]    Config loaded successfully",
    "2024-05-01 10:00:03 [INFO]    Connecting to MQTT broker at localhost:1883",
    "2024-05-01 10:00:04 [SUCCESS] Connected to MQTT broker",
    "2024-05-01 10:00:05 [INFO]    Subscribing to device topics...",
    "2024-05-01 10:00:06 [DEBUG]   Topic registered: devices/SmartSaw_DC26A",
    "2024-05-01 10:00:07 [DEBUG]   Topic registered: devices/SmartSaw_DC22A",
    "2024-05-01 10:00:08 [WARN]    Device SmartSaw_DC_HM not responding",
    "2024-05-01 10:00:09 [INFO]    Adapter ready. Listening for events.",
  ],
  agent: [
    "2024-05-01 10:00:00 [INFO]    Agent service starting...",
    "2024-05-01 10:00:01 [INFO]    Reading agent.cfg",
    "2024-05-01 10:00:02 [DEBUG]   Loaded 19 device definitions from /config/devices/",
    "2024-05-01 10:00:03 [INFO]    Initialising Ruby runtime",
    "2024-05-01 10:00:04 [SUCCESS] Ruby runtime ready",
    "2024-05-01 10:00:05 [INFO]    Connecting to MongoDB at localhost:27017",
    "2024-05-01 10:00:06 [SUCCESS] MongoDB connection established",
    "2024-05-01 10:00:07 [INFO]    Agent polling started (interval: 5s)",
    "2024-05-01 10:00:12 [DEBUG]   Poll cycle #1 complete — 0 events",
    "2024-05-01 10:00:17 [DEBUG]   Poll cycle #2 complete — 3 events",
  ],
  devctl: [
    "2024-05-01 10:00:00 [INFO]    Devctl starting...",
    "2024-05-01 10:00:01 [INFO]    Parsing devctl_json_config.json",
    "2024-05-01 10:00:02 [SUCCESS] Config parsed OK",
    "2024-05-01 10:00:03 [INFO]    Registering control handlers...",
    "2024-05-01 10:00:04 [DEBUG]   Handler registered: start",
    "2024-05-01 10:00:05 [DEBUG]   Handler registered: stop",
    "2024-05-01 10:00:06 [DEBUG]   Handler registered: restart",
    "2024-05-01 10:00:07 [INFO]    Devctl ready.",
    '2024-05-01 10:01:00 [WARN]    Received unknown command: "reboot"',
    "2024-05-01 10:01:01 [ERROR]   Command execution failed: unsupported operation",
  ],
  mongodb: [
    "2024-05-01 10:00:00 [INFO]    mongod starting...",
    "2024-05-01 10:00:01 [INFO]    Loading config from /config/mongod.conf",
    "2024-05-01 10:00:02 [INFO]    WiredTiger cache size: 256 MB",
    "2024-05-01 10:00:03 [INFO]    Waiting for connections on port 27017",
    "2024-05-01 10:00:04 [SUCCESS] MongoDB ready",
    "2024-05-01 10:00:10 [INFO]    Connection accepted from 127.0.0.1",
    "2024-05-01 10:00:11 [DEBUG]   Running upload_materials.py",
    "2024-05-01 10:00:15 [SUCCESS] Materials uploaded from MaterialLibrary.csv",
    "2024-05-01 10:00:16 [DEBUG]   Running jobs_parts_init.py",
    "2024-05-01 10:00:18 [SUCCESS] Jobs & parts initialised",
  ],
  mqtt: [
    "2024-05-01 10:00:00 [INFO]    Mosquitto MQTT broker starting...",
    "2024-05-01 10:00:01 [INFO]    Loading mosquitto.conf",
    "2024-05-01 10:00:02 [INFO]    Loading bridge config from mosq_bridge.conf",
    "2024-05-01 10:00:03 [INFO]    ACL file loaded: /data/acl",
    "2024-05-01 10:00:04 [SUCCESS] Broker listening on port 1883",
    "2024-05-01 10:00:05 [SUCCESS] Broker listening on port 8883 (TLS)",
    "2024-05-01 10:00:10 [INFO]    Client connected: adapter-client",
    "2024-05-01 10:00:11 [INFO]    Client connected: agent-client",
    "2024-05-01 10:01:00 [DEBUG]   Message received on topic: devices/SmartSaw_DC26A",
    "2024-05-01 10:01:01 [DEBUG]   Message forwarded to bridge",
  ],
  ods: [
    "2024-05-01 10:00:00 [INFO]    ODS service starting...",
    "2024-05-01 10:00:01 [INFO]    Loading odscfg.yaml",
    "2024-05-01 10:00:02 [INFO]    Loading db_object_definitions.json",
    "2024-05-01 10:00:03 [DEBUG]   Registered 12 object definitions",
    "2024-05-01 10:00:04 [INFO]    Connecting to MongoDB at localhost:27017",
    "2024-05-01 10:00:05 [SUCCESS] Connected to MongoDB",
    "2024-05-01 10:00:06 [INFO]    ODS HTTP server listening on port 8080",
    "2024-05-01 10:00:30 [INFO]    GET /ods/objects — 200 OK",
    "2024-05-01 10:01:00 [WARN]    Slow query detected (320ms) on collection: jobs",
    "2024-05-01 10:01:01 [INFO]    Query optimisation hint applied",
  ],
};

/* ============================================================
   STATE
============================================================ */

const state = {
  containers: [],
  active: null,
  lines: [],
  sseSource: null,
};

/* ============================================================
   DOM HELPER
============================================================ */

const $ = (id) => document.getElementById(id);

let dom = {};

/* ============================================================
   API / DATA FETCHING
============================================================ */

async function fetchContainers() {
  if (CONFIG.useDummy) return DUMMY_CONTAINERS;

  const res = await fetch(CONFIG.containersEndpoint);

  if (res.status === 401) {
    localStorage.clear();
    window.location.href = "/index.html";
    return null;
  }

  if (!res.ok) throw new Error(`HTTP ${res.status} — ${res.statusText}`);

  const json = await res.json();

  if (
    json?.data &&
    typeof json.data === "object" &&
    !Array.isArray(json.data)
  ) {
    return Object.keys(json.data);
  }

  if (Array.isArray(json?.data)) return json.data;
  if (Array.isArray(json)) return json;

  throw new Error("Unexpected containers response shape");
}

function streamDummyLogs(name, onLine, onError) {
  const lines = DUMMY_LOGS[name] ?? [];
  let i = 0;
  let stopped = false;
  const tick = () => {
    if (stopped || i >= lines.length) return;
    onLine(lines[i++]);
    setTimeout(tick, 120);
  };
  setTimeout(tick, 0);
  return {
    close: () => {
      stopped = true;
    },
  };
}

function openLogStream(name, onLine, onError) {
  if (CONFIG.useDummy) return streamDummyLogs(name, onLine, onError);

  const url = new URL(CONFIG.logsEndpoint, window.location.origin);
  url.searchParams.append("container", name);
  const es = new EventSource(url.toString());

  es.onmessage = (e) => {
    // FIX: removed the stray `onLine(line)` call that was always firing
    // after the try/catch, causing every message to be printed twice
    // (once inside the if-block and once unconditionally below it).
    try {
      const parsed = JSON.parse(e.data);
      if (parsed.type === "log" && typeof parsed.message === "string") {
        onLine(parsed.message);
      }
    } catch (_) {
      // raw text — use as-is
      onLine(e.data);
    }
  };

  es.onerror = (e) => {
    if (e.target?.readyState === EventSource.CLOSED) {
      fetch(url.toString(), { credentials: "include" })
        .then((res) => {
          if (res.status === 401) {
            localStorage.clear();
            window.location.href = "/index.html";
          } else {
            onError(new Error("SSE connection error"));
          }
        })
        .catch(() => onError(new Error("SSE connection error")));
    } else {
      onError(new Error("SSE connection error"));
    }
    es.close();
  };

  return es;
}

/* ============================================================
   CONTAINERS
============================================================ */

async function loadContainers() {
  dom.containerList.innerHTML = `
    <div class="lv-state-msg lv-loading">
      <div class="lv-spinner"></div>
      <span>Loading containers…</span>
    </div>`;
  try {
    const names = await fetchContainers();
    if (!names) return; // 401 redirect happened
    state.containers = names;
    renderContainers(names);
  } catch (err) {
    dom.containerList.innerHTML = `
      <div class="lv-state-msg lv-error">
        Failed to load containers
        <small>${esc(err.message)}</small>
      </div>`;
    console.error("[logs] fetchContainers:", err);
  }
}

function renderContainers(names) {
  if (!names.length) {
    dom.containerList.innerHTML = `<div class="lv-state-msg">No running containers found.</div>`;
    return;
  }
  dom.containerList.innerHTML = "";
  names.forEach((name) => {
    const el = document.createElement("div");
    el.className = "lv-component-item";
    el.dataset.name = name;
    el.innerHTML = `
      <span class="lv-component-name">${esc(name)}</span>
      <span class="lv-component-arrow">›</span>`;
    el.addEventListener("click", () => onSelectContainer(name));
    dom.containerList.appendChild(el);
  });
}

function onSelectContainer(name) {
  document.querySelectorAll(".lv-component-item").forEach((el) => {
    el.classList.toggle("active", el.dataset.name === name);
  });
  state.active = name;
  closeStream();
  loadLogs(name);
}

/* ============================================================
   LOGS
============================================================ */

function loadLogs(name) {
  dom.consoleTitle.textContent = `Live Update Console — ${name}`;
  dom.logOutput.innerHTML = `<span class="lv-ready-line">Connecting to log stream for ${esc(name)}…</span>\n`;
  state.lines = [];

  state.sseSource = openLogStream(
    name,
    (raw) => {
      if (!raw || !raw.trim()) return;
      state.lines.push(raw);
      if (state.lines.length > CONFIG.maxLines) state.lines.shift();
      appendLogLine(raw);
    },
    (err) => {
      console.error("[logs] SSE error:", err);
      dom.logOutput.innerHTML += `<span class="lv-error">Stream error: ${esc(err.message)}</span>\n`;
    },
  );
}

function appendLogLine(raw) {
  const { cls, text } = classifyLine(raw);
  const span = document.createElement("span");
  span.className = `lv-log-line ${cls}`;
  span.textContent = text;
  dom.logOutput.appendChild(span);
  dom.logOutput.appendChild(document.createTextNode("\n"));
  dom.consoleBody.scrollTop = dom.consoleBody.scrollHeight;
}

function renderLogs(lines) {
  const display =
    lines.length > CONFIG.maxLines
      ? lines.slice(lines.length - CONFIG.maxLines)
      : lines;
  dom.logOutput.innerHTML = "";
  display.forEach((raw) => appendLogLine(raw));
}

function classifyLine(raw) {
  if (!raw || !raw.trim()) return { cls: "lv-default", text: raw || "" };
  const u = raw.toUpperCase();
  if (/\[ERROR\]|\bERROR\b/.test(u)) return { cls: "lv-error", text: raw };
  if (/\[WARN\]|\bWARN\b/.test(u)) return { cls: "lv-warn", text: raw };
  if (/\[INFO\]|\bINFO\b/.test(u)) return { cls: "lv-info", text: raw };
  if (/\[DEBUG\]|\bDEBUG\b/.test(u)) return { cls: "lv-debug", text: raw };
  if (/\[SUCCESS\]|\bSUCCESS\b/.test(u))
    return { cls: "lv-success", text: raw };
  return { cls: "lv-default", text: raw };
}

/* ============================================================
   UTILITIES
============================================================ */

function esc(str) {
  return String(str ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

function closeStream() {
  if (state.sseSource) {
    state.sseSource.close();
    state.sseSource = null;
  }
}

/* ============================================================
   INIT
============================================================ */

export function initLogs() {
  dom = {
    containerList: $("lvContainerList"),
    logOutput: $("lvLogOutput"),
    consoleTitle: $("lvConsoleTitle"),
    consoleBody: $("lvConsoleBody"),
    clearBtn: $("lvClearBtn"),
    copyBtn: $("lvCopyBtn"),
    chevron: $("lvChevron"),
  };

  if (!dom.containerList) {
    console.error(
      "[logs] DOM elements not found — check element IDs in logs.html",
    );
    return;
  }

  // ── Clear ──
  dom.clearBtn.addEventListener("click", () => {
    state.lines = [];
    dom.logOutput.innerHTML = `<span class="lv-ready-line">System console ready...</span>\n`;
    dom.consoleTitle.textContent = "Live Update Console";
    closeStream();
    state.active = null;
    // Deselect active container in sidebar
    document.querySelectorAll(".lv-component-item").forEach((el) => {
      el.classList.remove("active");
    });
  });

  // ── Copy ──
  dom.copyBtn.addEventListener("click", async () => {
    const text = state.lines.join("\n").trim();
    if (!text) {
      // Nothing to copy — briefly flash the button
      const orig = dom.copyBtn.textContent;
      dom.copyBtn.textContent = "Empty!";
      dom.copyBtn.style.color = "#f59e0b";
      setTimeout(() => {
        dom.copyBtn.textContent = orig;
        dom.copyBtn.style.color = "";
      }, 1500);
      return;
    }
    try {
      await navigator.clipboard.writeText(text);
      const orig = dom.copyBtn.innerHTML;
      dom.copyBtn.innerHTML = "✓ Copied!";
      dom.copyBtn.style.color = "#16a34a";
      setTimeout(() => {
        dom.copyBtn.innerHTML = orig;
        dom.copyBtn.style.color = "";
      }, 1500);
    } catch (_) {
      dom.copyBtn.textContent = "Failed";
      setTimeout(() => (dom.copyBtn.textContent = "Copy"), 1500);
    }
  });

  // ── Sidebar collapse toggle ──
  dom.chevron.parentElement.addEventListener("click", () => {
    const sidebar = dom.containerList.closest(".lv-sidebar");
    const isCollapsed = sidebar.classList.toggle("lv-sidebar--collapsed");
    dom.chevron.classList.toggle("collapsed", isCollapsed);
  });

  loadContainers();
}

export { closeStream };
