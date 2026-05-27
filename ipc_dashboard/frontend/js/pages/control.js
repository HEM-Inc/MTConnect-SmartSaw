import { loadLayout } from "../../js/core/layout.js";
import { loadUserInfo } from "../core/login.js";
import {
  openTimezoneModal,
  closeTimezoneModal,
  submitTimezone,
} from "./timezone.js";
import { startUpdate } from "../core/control_api.js";
import { startInstall } from "../core/control_api.js";
import { showToast } from "../../js/core/toast.js";

const TAB_BASE = "./control/";

const TAB_MAP = {
  updateConfig: "updateConfig.html",
  status: "status.html",
  setup: "setup.html",
  clean: "clean.html",
  logs: "logs.html",
  //env: "env.html",
};

window.activeStreams = window.activeStreams || {};

// TAB SWITCHING
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
    window.currentStopSSE = module.stopSSE;
  }

  if (tabName === "logs") {
    const module = await import("/js/pages/control/logs.js");
    module.initLogs();
    window.currentStopSSE = module.closeStream;
  }

  if (tabName === "setup") {
    const module = await import("/js/pages/control/setup.js");
    module.initSetup();
  }

  if (tabName === "clean") {
    const module = await import("/js/pages/control/clean.js");
    module.uipInit();
  }
}

async function switchTab(tabName, btn) {
  document
    .querySelectorAll(".page-tab")
    .forEach((t) => t.classList.remove("active"));
  btn.classList.add("active");
  moveIndicator(btn);

  try {
    const res = await fetch(TAB_BASE + TAB_MAP[tabName]);
    if (!res.ok) throw new Error(res.status);
    document.getElementById("content").innerHTML = await res.text();
    loadTabScript(tabName);
  } catch (err) {
    console.error(err);
    document.getElementById("content").innerHTML =
      `<div style="padding:20px;color:red;">Failed to load ${tabName}</div>`;
  }
}

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
    await loadTabScript(firstTab);
  } catch (err) {
    console.error(err);
  }
}

function moveIndicator(el) {
  const indicator = document.querySelector(".tab-indicator");
  const parent = document.querySelector(".tab-track");
  const rect = el.getBoundingClientRect();
  const parentRect = parent.getBoundingClientRect();
  indicator.style.width = rect.width + "px";
  indicator.style.left = rect.left - parentRect.left + "px";
}

document.addEventListener("DOMContentLoaded", async () => {
  try {
    // Show loader
    document.getElementById("pageLoader")?.classList.remove("hidden");

    await loadLayout("controlTab");
    await loadUserInfo();
    await loadDefaultTab();

    // Timezone modal functions
    window.openTimezoneModal = openTimezoneModal;
    window.closeTimezoneModal = closeTimezoneModal;
    window.submitTimezone = submitTimezone;

    // Hide loader
    document.getElementById("pageLoader")?.classList.add("hidden");

    // Show app
    document.getElementById("appContainer")?.classList.remove("hidden");

    document.body.classList.add("app-ready");
  } catch (err) {
    console.error("Page load failed:", err);

    document.getElementById("pageLoader")?.classList.add("hidden");

    showToast("Failed to load page", "error");
  }
});

window.switchTab = switchTab;

// SHARED PANEL HELPERS
let _savedPanelState = { header: "", body: "", footer: "" };

function _getEditorPanel() {
  return document.querySelector(".content-grid .panel:nth-child(2)") ?? null;
}

export function showLiveConsole(tab, isRunning = false) {
  const panel = _getEditorPanel();
  if (!panel) return;

  let sessionId = window.activeStreams?.[tab]?.sessionId;

  if (!sessionId) {
    sessionId = Math.random().toString(36).slice(2);
  }

  panel.dataset.consoleTab = tab;
  panel.dataset.consoleSession = sessionId;

  _savedPanelState = {
    header: panel.querySelector(".panel-header").innerHTML,
    body: panel.querySelector(".panel-body").innerHTML,
    footer: panel.querySelector(".panel-footer").innerHTML,
  };

  panel.querySelector(".panel-header").innerHTML = `
    <div class="live-header">
      <span>⚡ Live Update Console</span>
      ${isRunning ? `<span class="pulse-dot"></span>` : ""}
    </div>
  `;

  panel.querySelector(".panel-body").innerHTML = `
    <div 
      id="liveConsole"
      class="live-console"
      data-session="${sessionId}"
      data-tab="${tab}">
    </div>
  `;

  panel.querySelector(".panel-footer").innerHTML = isRunning
    ? `<button class="btn-save" disabled>Running...</button>`
    : `<button class="btn-save" disabled>Ready</button>`;

  return sessionId;
}
export function restoreEditorPanel(handlers = {}) {
  const panel = _getEditorPanel();
  if (!panel) return;

  panel.querySelector(".panel-header").innerHTML = `
    <div class="editor-breadcrumb">
      <span class="breadcrumb-parent" id="bcParent">—</span>
      <span>›</span>
      <span class="breadcrumb-file" id="bcFile">—</span>
    </div>
    <div style="display:flex;gap:8px;align-items:center">
      <button id="btnEditToggle" class="btn-edit-toggle">
        <span class="material-symbols-outlined icon">edit</span>
        <span>Edit</span>
      </button>
      <span class="editor-status-badge" id="editorStatus">● unsaved</span>
    </div>
  `;
  panel.querySelector(".panel-body").innerHTML = `
    <div class="editor-content" id="editorContent">
      <div class="editor-placeholder">Select a file to view its contents</div>
    </div>
  `;
  panel.querySelector(".panel-footer").innerHTML = `
  <button class="btn-discard hidden" id="btnDiscard">Discard</button>
  <button class="btn-save hidden" id="btnSave">Save Changes</button>
`;

  // Bind provided handlers — tabs pass only what they implement
  if (handlers.onEditToggle)
    document
      .getElementById("btnEditToggle")
      .addEventListener("click", handlers.onEditToggle);
  if (handlers.onSave)
    document
      .getElementById("btnSave")
      .addEventListener("click", handlers.onSave);
  if (handlers.onDiscard)
    document
      .getElementById("btnDiscard")
      .addEventListener("click", handlers.onDiscard);
}

export function appendConsoleLine(tab, text) {
  const box = document.getElementById("liveConsole");

  if (!box) return;

  if (box.dataset.tab !== tab) return;

  const row = document.createElement("div");
  row.className = "console-line";
  row.textContent = text;

  box.appendChild(row);
  box.scrollTop = box.scrollHeight;
}

export function updateRestartHint() {
  const appChecked = [...document.querySelectorAll(".app-chk")].some(
    (c) => c.checked,
  );
  const fileChecked = [...document.querySelectorAll(".file-chk")].some(
    (c) => c.checked,
  );
  const inputFilled = [
    ...document.querySelectorAll(".update-inline-input"),
  ].some((i) => i.value.trim() !== "");
  const hasSelection = appChecked || fileChecked || inputFilled;

  const hint = document.getElementById("restartHint");
  const btn = document.getElementById("btnRestart");
  if (hint)
    hint.textContent = hasSelection
      ? "Ready to update selected components"
      : "";
  if (btn) btn.disabled = false;
}

// SHARED RESTART / STREAMING FLOW
export function showPasswordPrompt(
  components,
  tab,
  command,
  doneLabel = "✔ Completed.",
) {
  const panel = _getEditorPanel();
  if (!panel) return;

  panel.querySelector(".panel-header").innerHTML = `
    <div class="live-header">🔐 Sudo Authentication Required</div>
  `;
  panel.querySelector(".panel-body").innerHTML = `
    <div class="password-box">
      <div class="password-label">Enter sudo password to continue</div>
      <input type="password" id="sudoPassword" class="password-input" placeholder="Enter sudo password" />
      <button id="btnSubmitSudo" class="btn-save">Submit &amp; Start</button>
    </div>
  `;
  panel.querySelector(".panel-footer").innerHTML = `
    <button class="btn-discard" id="btnCancelSudo">Cancel</button>
  `;

  document
    .getElementById("btnSubmitSudo")
    .addEventListener("click", async () => {
      const pwd = document.getElementById("sudoPassword").value.trim();
      if (!pwd) {
        // inline error — avoid importing showToast here to keep control.js api-free
        document.getElementById("sudoPassword").placeholder =
          "Password required!";
        return;
      }
      await _streamUpdate(components, tab, command, pwd, doneLabel);
    });

  document
    .getElementById("btnCancelSudo")
    .addEventListener("click", () => restoreEditorPanel());
}

function resetUpdateSelections() {
  // uncheck app checkboxes
  document.querySelectorAll(".app-chk").forEach((chk) => {
    chk.checked = false;
  });

  // uncheck file checkboxes
  document.querySelectorAll(".file-chk").forEach((chk) => {
    chk.checked = false;
  });

  // clear text inputs
  document.querySelectorAll(".update-inline-input").forEach((input) => {
    input.value = "";
  });

  // refresh restart hint
  updateRestartHint();
}

export function updateActionButtonState(tab, running) {
  let btn = null;

  if (tab === "updateConfig") {
    btn = document.getElementById("btnRestart");
  }

  if (tab === "setup") {
    btn = document.getElementById("btnRestart");
  }

  if (!btn) return;

  btn.disabled = running;

  if (running) {
    btn.classList.add("disabled");

    if (tab === "updateConfig") {
      btn.innerHTML = `
        <span class="material-symbols-outlined icon">sync</span>
        Updating...
      `;
    }

    if (tab === "setup") {
      btn.innerHTML = `
        <span class="material-symbols-outlined icon">sync</span>
        Installing...
      `;
    }
  } else {
    btn.classList.remove("disabled");

    if (tab === "updateConfig") {
      btn.innerHTML = `
        <span class="material-symbols-outlined icon">restart_alt</span>
        Restart System
      `;
    }

    if (tab === "setup") {
      btn.innerHTML = `
        <span class="material-symbols-outlined icon">restart_alt</span>
        Install
      `;
    }
  }
}

async function _streamUpdate(components, tab, command, password, doneLabel) {
  let mySession = null;

  try {
    let response;
    if (tab === "setup") {
      response = await startInstall(command, components, password);
    } else if (tab === "updateConfig") {
      response = await startUpdate(command, components, password);
    }

    mySession = showLiveConsole(tab, true);

    window.activeStreams[tab] = {
      sessionId: mySession,
      logs: [],
      running: true,
    };

    updateActionButtonState(tab, true);

    const reader = response.body.getReader();
    const decoder = new TextDecoder();
    let buffer = "";

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });
      const chunks = buffer.split("\n\n");
      buffer = chunks.pop();
      for (const chunk of chunks) {
        if (chunk.startsWith("data:")) {
          const raw = chunk.replace("data:", "").trim();
          if (raw) {
            if (window.activeStreams?.[tab]?.sessionId === mySession) {
              try {
                const parsed = JSON.parse(raw);
                const line = `> ${parsed.message || raw}`;

                window.activeStreams[tab].logs.push(line);

                if (window.activeStreams?.[tab]?.sessionId === mySession) {
                  appendConsoleLine(tab, line);
                }
              } catch {
                const line = `> ${raw}`;

                window.activeStreams[tab].logs.push(line);

                if (window.activeStreams?.[tab]?.sessionId === mySession) {
                  appendConsoleLine(tab, line);
                }
              }
            }
          }
        }
      }
    }

    window.activeStreams[tab].running = false;

    updateActionButtonState(tab, false);

    if (window.activeStreams?.[tab]?.sessionId === mySession) {
      appendConsoleLine(tab, doneLabel);
      resetUpdateSelections();
      const footer = _getEditorPanel()?.querySelector(".panel-footer");
      if (footer) {
        footer.innerHTML = `<button class="btn-save" id="btnCloseConsole">Close Console</button>`;
        document
          .getElementById("btnCloseConsole")
          .addEventListener("click", () => restoreEditorPanel());
      }
    }
  } catch (err) {
    console.error(err);

    updateActionButtonState(tab, false);

    if (window.activeStreams?.[tab]) {
      window.activeStreams[tab].running = false;
    }
    showToast(err.message || "Update failed", "error");

    // If console exists, append error there too
    if (window.activeStreams?.[tab]?.sessionId === mySession) {
      appendConsoleLine(tab, `✖ Error: ${err.message}`);
    }

    document.getElementById("sudoPassword")?.focus();
  }
}

export function restoreExistingConsole(tab) {
  const stream = window.activeStreams?.[tab];

  if (!stream) return false;

  showLiveConsole(tab, stream.running);

  const box = document.getElementById("liveConsole");

  if (!box) return false;

  stream.logs.forEach((line) => {
    const row = document.createElement("div");
    row.className = "console-line";
    row.textContent = line;
    box.appendChild(row);
  });

  box.scrollTop = box.scrollHeight;

  const footer = _getEditorPanel()?.querySelector(".panel-footer");

  if (footer && !stream.running) {
    footer.innerHTML = `
      <button class="btn-save" id="btnCloseConsole">
        Close Console
      </button>
    `;

    document.getElementById("btnCloseConsole").addEventListener("click", () => {
      delete window.activeStreams[tab];
      restoreEditorPanel();
    });
  }

  return true;
}

// SHARED FILE TREE
export function renderTree(data, parentEl, parentPath = "", onFileClick) {
  Object.entries(data).forEach(([name, node]) => {
    const fullPath = parentPath ? `${parentPath}/${name}` : name;

    if (node.type === "folder") {
      const folder = document.createElement("div");
      folder.className = "tree-node";

      const header = document.createElement("div");
      header.className = "tree-node-header";
      header.innerHTML = `
        <div class="tree-node-left">
          <span class="tree-node-label">${name}</span>
        </div>
        <svg class="tree-arrow collapsed" viewBox="0 0 24 24">
          <path d="M19 9l-7 7-7-7" stroke="currentColor" stroke-width="2"/>
        </svg>
      `;

      const children = document.createElement("div");
      children.className = "tree-files";
      children.style.display = "none";

      header.onclick = () => {
        const hidden = children.style.display === "none";
        children.style.display = hidden ? "block" : "none";
        header
          .querySelector(".tree-arrow")
          .classList.toggle("collapsed", !hidden);
      };

      folder.appendChild(header);
      folder.appendChild(children);
      parentEl.appendChild(folder);
      renderTree(node.children || {}, children, fullPath, onFileClick);
    }

    if (node.type === "file") {
      const file = document.createElement("div");
      file.className = "file-item";
      file.textContent = name;
      file.onclick = (e) => {
        e.stopPropagation();
        document
          .querySelectorAll(".file-item")
          .forEach((f) => f.classList.remove("active"));
        file.classList.add("active");
        if (typeof onFileClick === "function") onFileClick(fullPath);
      };
      parentEl.appendChild(file);
    }
  });
}

// SHARED UPDATE LIST HELPERS
export function getNodeByPath(root, path) {
  const parts = path.split("/");
  let node = root;
  for (const part of parts) {
    if (!node.children || !node.children[part]) return null;
    node = node.children[part];
  }
  return node;
}

export function renderUpdateFiles(children, parent, path = "", onFileChange) {
  Object.entries(children).forEach(([name, node]) => {
    const fullPath = path ? `${path}/${name}` : name;

    if (node.type === "file") {
      const row = document.createElement("label");
      row.className = "update-file-row";
      row.innerHTML = `<input type="checkbox" class="file-chk" value="${fullPath}"><span>${name}</span>`;
      row.querySelector(".file-chk").onchange = (e) => {
        const block = e.target.closest(".update-block");
        if (block && e.target.checked) {
          block.querySelectorAll(".file-chk").forEach((chk) => {
            if (chk !== e.target) chk.checked = false;
          });
        }
        if (typeof onFileChange === "function") onFileChange();
      };
      parent.appendChild(row);
    }

    if (node.type === "folder") {
      const wrap = document.createElement("div");
      wrap.className = "update-sub-folder";
      const head = document.createElement("div");
      head.className = "update-sub-head";
      head.innerHTML = `▶ ${name}`;
      const sub = document.createElement("div");
      sub.className = "update-sub-body";
      head.onclick = () => {
        const open = sub.classList.toggle("open");
        head.innerHTML = `${open ? "▼" : "▶"} ${name}`;
      };
      renderUpdateFiles(node.children || {}, sub, fullPath, onFileChange);
      wrap.appendChild(head);
      wrap.appendChild(sub);
      parent.appendChild(wrap);
    }
  });
}

export function buildUpdateList(data, items, onAnyChange) {
  const list = document.getElementById("updateList");
  if (!list) return;
  list.innerHTML = "";

  items.forEach((item) => {
    const wrap = document.createElement("div");
    wrap.className = "update-block";

    const row = document.createElement("div");
    row.className = "update-row";

    const chkHtml =
      item.type === "nofiles"
        ? `<input type="checkbox" class="app-chk" data-flag="${item.flag}">`
        : "";

    row.innerHTML = `
  <div class="update-left">
    <div class="update-inline-meta">
      <div class="update-flag">
        ${item.flag}
      </div>
      <div class="update-title">${item.label}</div>
${
  item.description
    ? `<div class="update-description">${item.description}</div>`
    : ""
}
    </div>
      ${chkHtml}

  </div>

  <div class="update-arrow">
    ${item.type === "files" ? "▶" : ""}
  </div>
`;
    wrap.appendChild(row);

    if (item.type === "input") {
      const input = document.createElement("input");
      input.className = "update-inline-input";
      input.placeholder = item.placeholder;
      input.oninput = onAnyChange;
      wrap.appendChild(input);
    }

    if (item.type === "files") {
      const panel = document.createElement("div");
      panel.className = "update-files-panel";
      const folder = getNodeByPath(data.project, item.sourcePath);
      if (folder)
        renderUpdateFiles(
          folder.children || {},
          panel,
          item.sourcePath,
          onAnyChange,
        );
      row.onclick = () => {
        const open = panel.classList.toggle("open");
        row.querySelector(".update-arrow").textContent = open ? "▼" : "▶";
      };
      wrap.appendChild(panel);
    }

    list.appendChild(wrap);
  });

  document.querySelectorAll(".app-chk").forEach((chk) => {
    chk.onchange = onAnyChange;
  });

  if (typeof onAnyChange === "function") onAnyChange();
}

export function getEditorText(editor) {
  return [...editor.querySelectorAll(".editor-line")]
    .map((line) => {
      // If line only contains a <br> or is truly empty, return empty string
      const clone = line.cloneNode(true);
      // Remove all <br> elements before reading text
      clone.querySelectorAll("br").forEach((br) => br.remove());
      let text = clone.innerText ?? clone.textContent ?? "";
      // Normalize non-breaking spaces
      text = text.replace(/\u00A0/g, " ");
      return text;
    })
    .join("\n")
    .replace(/\n+$/, ""); // strip trailing newlines
}

export function placeCursorAtEnd(lineEl) {
  const sel = window.getSelection();
  const range = document.createRange();
  const textNode = lineEl.childNodes[0];
  if (textNode && textNode.nodeType === Node.TEXT_NODE) {
    range.setStart(textNode, textNode.length);
  } else {
    range.setStart(lineEl, lineEl.childNodes.length);
  }
  range.collapse(true);
  sel.removeAllRanges();
  sel.addRange(range);
}

export function placeCursorAtOffset(lineEl, offset) {
  const sel = window.getSelection();
  const range = document.createRange();
  const textNode = lineEl.childNodes[0];
  if (textNode && textNode.nodeType === Node.TEXT_NODE) {
    range.setStart(textNode, Math.min(offset, textNode.length));
  } else {
    range.setStart(lineEl, 0);
  }
  range.collapse(true);
  sel.removeAllRanges();
  sel.addRange(range);
}
