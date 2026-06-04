import { showToast } from "../../core/toast.js";

let eventSource = null;
let isStatusActive = false;
let firstDataReceived = false;

function showLoader() {
  document.getElementById("statusLoader")?.classList.remove("hidden");
  document.getElementById("statusGrid").innerHTML = "";
}

function hideLoader() {
  document.getElementById("statusLoader")?.classList.add("hidden");
}

export function initStatus() {
  console.log("Status page loaded");

  isStatusActive = true;
  firstDataReceived = false;
  showLoader();
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

  if (!data || data.length === 0) {
    grid.innerHTML = `
      <div class="empty-state">
        <i class="fa-solid fa-cube"></i>
        <h3>No Containers Found</h3>
        <p>There are currently no Docker containers available.</p>
      </div>
    `;

    document.getElementById("runningCount").innerText = 0;
    document.getElementById("stoppedCount").innerText = 0;
    document.getElementById("errorCount").innerText = 0;
    document.getElementById("createdCount").innerText = 0;
    document.getElementById("uptime").innerText = "0%";

    return;
  }

  let running = 0,
    stopped = 0,
    error = 0,
    created = 0;

  grid.innerHTML = data
    .map((item) => {
      let stateClass = "error";

      if (item.state === "running") {
        running++;
        stateClass = "running";
      } else if (item.state === "exited") {
        stopped++;
        stateClass = "exited";
      } else if (item.state === "created") {
        created++;
        stateClass = "created";
      } else {
        error++;
        stateClass = "error";
      }

      return `
      <div class="status-card ${stateClass}">

        <div class="card-header">
          <div>
            <div class="card-title">${item.name}</div>
            <div class="card-id">${item.id.substring(0, 8)}</div>
          </div>

          <span class="badge ${stateClass}">
            ${item.state}
          </span>
        </div>

        <div class="card-image">${item.image}</div>

        <div class="metric"><b>Status:</b> ${item.status}</div>
        <div class="metric"><b>Created:</b> ${item.created}</div>

        <div class="metric">
          <b>Ports:</b>
          ${item.ports.length ? item.ports.join(", ") : "-"}
        </div>

        <div class="metric">
          CPU (${item.cpu.toFixed(2)}%)
          <div class="progress">
            <div
              class="progress-bar cpu"
               data-width="${Math.round(Math.min(item.cpu, 100))}">
            </div>
          </div>
        </div>

        <div class="metric">
          Memory (${item.memory.toFixed(2)}%)
          <div class="progress">
            <div class="progress-bar memory"
              data-width="${Math.round(Math.min(item.memory, 100))}">
            </div>
          </div>
        </div>

      </div>
    `;
    })
    .join("");

  grid.querySelectorAll(".progress-bar").forEach((bar) => {
    const width = Math.round(Math.min(Number(bar.dataset.width || 0), 100));

    bar.classList.add(`w-${width}`);
  });

  document.getElementById("runningCount").innerText = running;
  document.getElementById("stoppedCount").innerText = stopped;
  document.getElementById("errorCount").innerText = error;
  document.getElementById("createdCount").innerText = created;
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
        if (!firstDataReceived) {
          hideLoader();
          firstDataReceived = true;
        }
        renderStatus(payload.data);
      }
    } catch (err) {
      showToast(`Failed : ${err.message}`, "error");
      console.error("SSE parse error:", err);
    }
  };

  eventSource.onerror = () => {
    if (!firstDataReceived) {
      document
        .getElementById("statusLoader")
        .classList.remove("hidden").innerHTML = `
      <p>Failed to load container status</p>
    `;
    }
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
