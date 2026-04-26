let eventSource = null;
let isStatusActive = false;

export function initStatus() {
  console.log("Status page loaded");

  isStatusActive = true;

  const page = document.getElementById("statusPage");
  if (page) {
    page.classList.remove("status-hidden");
    page.classList.add("status-ready");
  }

  startSSE();
}

function renderStatus(data) {
  const grid = document.getElementById("statusGrid");
  if (!grid) return;

  let running = 0,
    stopped = 0,
    error = 0;

  grid.innerHTML = data
    .map((item) => {
      if (item.state === "running") running++;
      else if (item.state === "exited") stopped++;
      else error++;

      return `
      <div class="status-card ${item.state}">

        <div class="card-header">
          <div>
            <div class="card-title">${item.name}</div>
            <div class="card-id">${item.id.substring(0, 8)}</div>
          </div>
          <span class="badge ${item.state}">${item.state}</span>
        </div>

        <div class="card-image">${item.image}</div>

        <div class="metric"><b>Status:</b> ${item.status}</div>
        <div class="metric"><b>Created:</b> ${item.created}</div>

        <div class="metric"><b>Ports:</b> ${item.ports.length ? item.ports.join(", ") : "-"}</div>

        <div class="metric">
          CPU (${item.cpu.toFixed(2)}%)
          <div class="progress">
            <div class="progress-bar cpu" style="width:${Math.min(item.cpu, 100)}%"></div>
          </div>
        </div>

        <div class="metric">
          Memory (${item.memory.toFixed(2)}%)
          <div class="progress">
            <div class="progress-bar memory" style="width:${Math.min(item.memory, 100)}%"></div>
          </div>
        </div>

      </div>
    `;
    })
    .join("");

  document.getElementById("runningCount").innerText = running;
  document.getElementById("stoppedCount").innerText = stopped;
  document.getElementById("errorCount").innerText = error;
  document.getElementById("uptime").innerText = data.length
    ? ((running / data.length) * 100).toFixed(1) + "%"
    : "0%";
}

function startSSE() {
  if (!isStatusActive) return;

  if (eventSource) {
    eventSource.close();
  }

  eventSource = new EventSource("/api/docker-stream?t=" + Date.now());

  eventSource.onmessage = (event) => {
    if (!isStatusActive) return;

    try {
      const payload = JSON.parse(event.data);

      //   console.log("SSE payload:", payload);

      if (payload.type === "connected") {
        return;
      }

      if (payload.type === "docker_update" && Array.isArray(payload.data)) {
        renderStatus(payload.data);
      }
    } catch (err) {
      console.error("SSE parse error:", err);
    }
  };

  eventSource.onerror = () => {
    console.warn("SSE disconnected");
  };
}

export function stopSSE() {
  isStatusActive = false;

  if (eventSource) {
    eventSource.close();
    eventSource = null;
    console.log("SSE stopped");
  }
}

window.addEventListener("beforeunload", stopSSE);

initStatus();

window.initStatus = initStatus;
window.stopSSE = stopSSE;
