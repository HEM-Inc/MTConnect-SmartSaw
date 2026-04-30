import { loadLayout } from "../../js/core/layout.js";
import { loadUserInfo } from "../core/login.js";

const TAB_BASE = "./control/";

const TAB_MAP = {
  updateConfig: "updateConfig.html",
  status: "status.html",
  setup: "setup.html",
  clean: "clean.html",
  logs: "logs.html",
  env: "env.html",
};

// ─────────────────────────────
// SWITCH TAB (CLICK)
// ─────────────────────────────

async function loadTabScript(tabName) {
  const oldScript = document.getElementById("dynamic-tab-script");
  if (oldScript) oldScript.remove();

  if (tabName === "updateConfig") {
    const module = await import("/js/pages/control/updateConfig.js");

    module.initUpdateConfig();
  }

  if (tabName === "status") {
    const module = await import("/js/pages/control/status.js");
    module.initStatus();

    // store stop function globally for cleanup
    window.currentStopSSE = module.stopSSE;
  }
}

async function switchTab(tabName, btn) {
  if (window.currentStopSSE) {
    window.currentStopSSE();
    window.currentStopSSE = null;
  }

  document.querySelectorAll(".page-tab").forEach((t) => {
    t.classList.remove("active");
  });

  btn.classList.add("active");
  moveIndicator(btn);

  const url = TAB_BASE + TAB_MAP[tabName];

  try {
    const res = await fetch(url);
    if (!res.ok) throw new Error(res.status);

    const html = await res.text();
    document.getElementById("content").innerHTML = html;

    // ✅ LOAD TAB-SPECIFIC JS
    loadTabScript(tabName);
  } catch (err) {
    console.error(err);
    document.getElementById("content").innerHTML =
      `<div style="padding:20px;color:red;">Failed to load ${tabName}</div>`;
  }
}

// ─────────────────────────────
// DEFAULT LOAD
// ─────────────────────────────
async function loadDefaultTab() {
  const firstTab = "updateConfig";

  const firstBtn = document.querySelector(`.page-tab[onclick*="${firstTab}"]`);

  document
    .querySelectorAll(".page-tab")
    .forEach((t) => t.classList.remove("active"));

  if (firstBtn) {
    firstBtn.classList.add("active");
    moveIndicator(firstBtn);
  }

  try {
    const res = await fetch(TAB_BASE + TAB_MAP[firstTab]);

    if (!res.ok) throw new Error(res.status);

    document.getElementById("content").innerHTML = await res.text();

    // IMPORTANT
    await loadTabScript(firstTab);
  } catch (err) {
    console.error(err);
  }
}

document.addEventListener("DOMContentLoaded", async () => {
  try {
    await loadLayout("controlTab");
    await loadUserInfo();
    await loadDefaultTab();

    document.body.classList.add("app-ready");
  } catch (err) {
    console.error("Page load failed:", err);
  }
});

window.switchTab = switchTab;

function moveIndicator(el) {
  const indicator = document.querySelector(".tab-indicator");
  const parent = document.querySelector(".tab-track");

  const rect = el.getBoundingClientRect();
  const parentRect = parent.getBoundingClientRect();

  indicator.style.width = rect.width + "px";
  indicator.style.left = rect.left - parentRect.left + "px";
}

// ─────────────────────────────
// GLOBAL EXPORTS (for HTML onclick)
// ─────────────────────────────
window.switchTab = switchTab;
