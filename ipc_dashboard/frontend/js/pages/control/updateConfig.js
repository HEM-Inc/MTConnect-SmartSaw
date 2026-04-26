import {
  getWorkspace,
  getFileContent,
  acquireFileLock,
  saveFile,
  discardFile,
  fileHeartbeat,
  uploadFile,
  startUpdate,
} from "../../core/control_api.js";
import { handleApiError } from "../../core/apiClient.js";
import { showToast } from "../../core/toast.js";
import { renderFormattedContent } from "./fileFormatter.js";

// ── State ──
let currentFile     = null;
let currentContent  = "";
let workspaceData   = null;
let isEditMode      = false;
let currentPath     = null;
let heartbeatTimer  = null;

// ── Render file content into editor ──
function renderContent(filename, content, fileType = "") {
  currentFile    = filename;
  currentContent = content;
  isEditMode     = false;

  const bcParent = document.getElementById("bcParent");
  const bcFile   = document.getElementById("bcFile");
  const status   = document.getElementById("editorStatus");
  const editor   = document.getElementById("editorContent");
  const editBtn  = document.getElementById("btnEditToggle");

  if (!editor) return;

  if (bcParent && workspaceData) {
    const folders = workspaceData.project.children;
    const parent  = Object.keys(folders).find((f) =>
      Object.keys(folders[f].children || {}).includes(filename),
    );
    bcParent.textContent = parent || filename.split(".")[0].toUpperCase();
  }

  if (bcFile)  bcFile.textContent = filename;
  if (status) {
    status.textContent = "● unsaved";
    status.className   = "editor-status-badge";
  }
  if (editBtn) {
    editBtn.innerHTML = `
      <span class="material-symbols-outlined icon">edit</span>
      <span>Edit</span>
    `;
    editBtn.classList.remove("active");
  }

  editor.contentEditable = "false";
  editor.innerHTML       = renderFormattedContent(content, fileType);
  editor.oninput         = null;
}

function cleanMessage(evt) {
  const msg = evt?.message;
  return typeof msg === "string" ? msg.trim() : "";
}

// ── Toggle edit mode ──
async function handleEditToggle() {
  if (!currentPath) {
    showToast("Select file first", "error");
    return;
  }

  const editor = document.getElementById("editorContent");
  const btn    = document.getElementById("btnEditToggle");

  try {
    if (!isEditMode) {
      await acquireFileLock(currentPath);

      isEditMode             = true;
      editor.contentEditable = "true";
      editor.focus();

      btn.innerHTML = `
        <span class="material-symbols-outlined icon">visibility</span>
        <span>View</span>
      `;
      btn.classList.add("active");

      editor.oninput = () => { currentContent = editor.innerText; };

      heartbeatTimer = setInterval(() => fileHeartbeat(currentPath), 10000);

      showToast("Edit mode enabled", "success");
    } else {
      editor.contentEditable = "false";
      editor.oninput         = null;
      isEditMode             = false;

      btn.innerHTML = `
        <span class="material-symbols-outlined icon">edit</span>
        <span>Edit</span>
      `;
      btn.classList.remove("active");

      clearInterval(heartbeatTimer);
      heartbeatTimer = null;

      showToast("View mode enabled", "success");
    }
  } catch (err) {
    handleApiError(err);
  }
}

async function renderFileFromAPI(path) {
  const res = await getFileContent(path);
  const filename = path.split("/").pop();
  renderContent(
    filename,
    res?.data?.content ?? "",
    res?.data?.file_type ?? filename.split(".").pop(),
  );
}

// ── Tree expand/collapse ──
function toggleSection(treeId, arrowId) {
  const tree  = document.getElementById(treeId);
  const arrow = document.getElementById(arrowId);
  if (!tree || !arrow) return;
  const hide = tree.style.display !== "none";
  tree.style.display = hide ? "none" : "block";
  arrow.classList.toggle("collapsed", hide);
}

// ── Save ──
async function handleSave() {
  if (!currentFile) return;

  const s = document.getElementById("editorStatus");

  try {
    currentContent = document.getElementById("editorContent").innerText;

    await saveFile(currentPath, currentContent);

    clearInterval(heartbeatTimer);
    heartbeatTimer = null;
    isEditMode     = false;

    const editor           = document.getElementById("editorContent");
    editor.contentEditable = "false";
    editor.oninput         = null;

    if (s) {
      s.textContent = "✓ saved";
      s.classList.add("saved");
    }

    showToast("File saved successfully", "success");
    await renderFileFromAPI(currentPath);

    setTimeout(() => {
      if (s) {
        s.textContent = "● unsaved";
        s.classList.remove("saved");
      }
    }, 2500);
  } catch {
    showToast("Save failed", "error");
  }
}

// ── Discard ──
async function handleDiscard() {
  try {
    if (!currentPath) return;

    await discardFile(currentPath);

    clearInterval(heartbeatTimer);
    heartbeatTimer = null;
    isEditMode     = false;

    renderFileFromAPI(currentPath);
    showToast("Changes discarded", "success");
  } catch (err) {
    handleApiError(err);
  }
}

// ── Render file tree (left panel) ──
function renderTree(data, parentEl, parentPath = "") {
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
      children.className    = "tree-files";
      children.style.display = "none";

      header.onclick = () => {
        const hidden = children.style.display === "none";
        children.style.display = hidden ? "block" : "none";
        header.querySelector(".tree-arrow").classList.toggle("collapsed", !hidden);
      };

      folder.appendChild(header);
      folder.appendChild(children);
      parentEl.appendChild(folder);

      renderTree(node.children || {}, children, fullPath);
    }

    if (node.type === "file") {
      const file = document.createElement("div");
      file.className  = "file-item";
      file.textContent = name;

      file.onclick = (e) => {
        e.stopPropagation();
        document.querySelectorAll(".file-item").forEach((f) => f.classList.remove("active"));
        file.classList.add("active");
        currentPath = fullPath;
        restoreEditorPanel();
        renderFileFromAPI(fullPath);
      };

      parentEl.appendChild(file);
    }
  });
}

function loadWorkspace(data) {
  workspaceData = data;
  const root    = document.getElementById("compTree");
  root.innerHTML = "";
  renderTree(data.project.children, root);
}

const UPDATE_ITEMS = [
  { label: "Update all components",              flag: "-A", type: "nofiles" },
  { label: "Update afg file name",               flag: "-a", type: "files",  sourcePath: "adapter/config" },
  { label: "Update JSON file name",              flag: "-j", type: "files",  sourcePath: "adapter/data" },
  { label: "Update MTConnect agent file name",   flag: "-d", type: "files",  sourcePath: "agent/config/devices" },
  { label: "Update device control config file",  flag: "-c", type: "files",  sourcePath: "devctl/config" },
  { label: "Update serial number",               flag: "-u", type: "input",  placeholder: "Enter serial number" },
  { label: "MQTT using bridge configuration",    flag: "-b", type: "nofiles" },
  { label: "Docker Compose Version",             flag: "-v", type: "input",  placeholder: "Enter 1 or 2" },
];

function handleSingleFileSelect(e) {
  const selected = e.target;
  const block    = selected.closest(".update-block");
  if (!block) return;

  if (selected.checked) {
    block.querySelectorAll(".file-chk").forEach((chk) => {
      if (chk !== selected) chk.checked = false;
    });
  }

  updateRestartHint();
}

function renderUpdateFiles(children, parent, path = "") {
  Object.entries(children).forEach(([name, node]) => {
    const fullPath = path ? `${path}/${name}` : name;

    if (node.type === "file") {
      const row = document.createElement("label");
      row.className = "update-file-row";
      row.innerHTML = `
        <input type="checkbox" class="file-chk" value="${fullPath}">
        <span>${name}</span>
      `;
      row.querySelector(".file-chk").onchange = handleSingleFileSelect;
      parent.appendChild(row);
    }

    if (node.type === "folder") {
      const wrap = document.createElement("div");
      wrap.className = "update-sub-folder";

      const head = document.createElement("div");
      head.className   = "update-sub-head";
      head.innerHTML   = `▶ ${name}`;

      const sub = document.createElement("div");
      sub.className = "update-sub-body";

      head.onclick = () => {
        const open     = sub.classList.toggle("open");
        head.innerHTML = `${open ? "▼" : "▶"} ${name}`;
      };

      renderUpdateFiles(node.children || {}, sub, fullPath);
      wrap.appendChild(head);
      wrap.appendChild(sub);
      parent.appendChild(wrap);
    }
  });
}

function getNodeByPath(root, path) {
  const parts = path.split("/");
  let node    = root;

  for (const part of parts) {
    if (!node.children || !node.children[part]) return null;
    node = node.children[part];
  }

  return node;
}

function buildUpdateList(data) {
  const list = document.getElementById("updateList");
  list.innerHTML = "";

  UPDATE_ITEMS.forEach((item) => {
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
        ${chkHtml}
        <div>
          <div class="update-title">${item.label}</div>
          <div class="update-flag">${item.flag}</div>
        </div>
      </div>
      <div class="update-arrow">${item.type === "files" ? "▶" : ""}</div>
    `;

    wrap.appendChild(row);

    if (item.type === "input") {
      const input       = document.createElement("input");
      input.className   = "update-inline-input";
      input.placeholder = item.placeholder;
      input.oninput     = updateRestartHint;
      wrap.appendChild(input);
    }

    if (item.type === "files") {
      const panel    = document.createElement("div");
      panel.className = "update-files-panel";

      const folder = getNodeByPath(data.project, item.sourcePath);
      if (folder) renderUpdateFiles(folder.children || {}, panel, item.sourcePath);

      row.onclick = () => {
        const open = panel.classList.toggle("open");
        row.querySelector(".update-arrow").textContent = open ? "▼" : "▶";
      };

      wrap.appendChild(panel);
    }

    list.appendChild(wrap);
  });

  document.querySelectorAll(".app-chk").forEach((chk) => {
    chk.onchange = updateRestartHint;
  });

  updateRestartHint();
}

function updateRestartHint() {
  const appChecked   = [...document.querySelectorAll(".app-chk")].some((c) => c.checked);
  const fileChecked  = [...document.querySelectorAll(".file-chk")].some((c) => c.checked);
  const inputFilled  = [...document.querySelectorAll(".update-inline-input")].some((i) => i.value.trim() !== "");
  const hasSelection = appChecked || fileChecked || inputFilled;

  const hint = document.getElementById("restartHint");
  const btn  = document.getElementById("btnRestart");

  hint.textContent = hasSelection
    ? "Ready to update selected components"
    : "Restart system only";

  btn.disabled = false;
}

function buildUpdatePayload() {
  const components = [];

  if (document.querySelector(`.app-chk[data-flag="-A"]`)?.checked) {
    components.push({ name: "all" });
  }

  if (document.querySelector(`.app-chk[data-flag="-b"]`)?.checked) {
    components.push({ name: "mqtt", bridge: true });
  }

  document.querySelectorAll(".update-block").forEach((block, index) => {
    const checked = block.querySelector(".file-chk:checked");
    if (!checked) return;

    const fileName = checked.value.split("/").pop();
    const item     = UPDATE_ITEMS[index];

    if (item.flag === "-a") {
      components.push({ name: "adapter", config_file: fileName });
    }

    if (item.flag === "-j") {
      const existing = components.find((x) => x.name === "adapter");
      if (existing) existing.data_file = fileName;
      else components.push({ name: "adapter", data_file: fileName });
    }

    if (item.flag === "-d") {
      components.push({ name: "agent", config_file: fileName });
    }

    if (item.flag === "-c") {
      components.push({ name: "devctl", config_file: fileName });
    }
  });

  document.querySelectorAll(".update-inline-input").forEach((input, i) => {
    const val  = input.value.trim();
    if (!val) return;

    const item = UPDATE_ITEMS[i];

    if (item.flag === "-u") components.push({ name: "serial_number", serial_number: val });
    if (item.flag === "-v") components.push({ name: "docker", version: val });
  });

  return components;
}

// ── Password prompt ──
let previousHeaderHTML = "";
let previousEditorHTML = "";
let previousFooterHTML = "";

function showPasswordPrompt(components) {
  const panel  = document.querySelector(".content-grid .panel:nth-child(2)");
  const header = panel.querySelector(".panel-header");
  const body   = panel.querySelector(".panel-body");
  const footer = panel.querySelector(".panel-footer");

  previousHeaderHTML = header.innerHTML;
  previousEditorHTML = body.innerHTML;
  previousFooterHTML = footer.innerHTML;

  header.innerHTML = `
    <div class="live-header">🔐 Sudo Authentication Required</div>
  `;

  body.innerHTML = `
    <div class="password-box">
      <div class="password-label">Enter sudo password to continue</div>
      <input
        type="password"
        id="sudoPassword"
        class="password-input"
        placeholder="Enter sudo password"
      />
      <button id="btnSubmitSudo" class="btn-save">
        Submit &amp; Start Update
      </button>
    </div>
  `;

  footer.innerHTML = `
    <button class="btn-discard" onclick="restoreEditorPanel()">Cancel</button>
  `;

  document.getElementById("btnSubmitSudo").onclick = async () => {
    const pwd = document.getElementById("sudoPassword").value.trim();
    if (!pwd) {
      showToast("Enter password", "error");
      return;
    }
    await startUpdateProcess(components, pwd);
  };
}

// ── CSS classes for console line types ──
const TYPE_CLASS = {
  output  : "console-line",
  error   : "console-line console-line--error",
  complete: "console-line console-line--complete",
  start   : "console-line console-line--info",
  info    : "console-line console-line--info",
};

// ── Core SSE streaming ──
async function startUpdateProcess(components, password) {
  try {
    const response = await startUpdate("update", components, password);

    if (!response.ok && !response.body) {
      let errMsg = `Server error ${response.status}`;
      try {
        const json = await response.json();
        errMsg = json?.detail ?? json?.message ?? errMsg;
      } catch (_) {}
      showToast(errMsg, "error");
      return;
    }

    showLiveConsole(true);

    const reader = response.body.getReader();
    const decoder = new TextDecoder();
    let partial = "";

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      partial += decoder.decode(value, { stream: true });
      const events = partial.split("\n\n");
      partial = events.pop();

      for (const event of events) {
        for (const line of event.split("\n")) {
          if (!line.startsWith("data:")) continue;

          const raw = line.slice(5).trim();

          if (!raw || raw === "[DONE]") continue;

          let evt;
          try {
            evt = JSON.parse(raw);
          } catch (_) {
            // ❌ DO NOT PRINT RAW ANYTHING
            continue;
          }

          // ✅ ONLY PRINT MESSAGE
          const message = cleanMessage(evt);
          if (message) {
            appendConsoleLine(message, "output");
          }

          // COMPLETE EVENT
          if (evt.type === "complete") {
            markConsoleFinished(evt.status === "success");

            if (evt.status === "success") {
              showToast("Update completed successfully", "success");
            } else {
              showToast(evt.message || "Update failed", "error");
            }

            return;
          }

          // ERROR EVENT
          if (evt.type === "error") {
            showToast(evt.message || "Error occurred", "error");
          }
        }
      }
    }

    markConsoleFinished(true);

  } catch (err) {
    showToast(err.message || "Connection failed", "error");

    const box = document.getElementById("liveConsole");
    if (box) appendConsoleLine(`Connection error: ${err.message}`, "error");

    document.getElementById("sudoPassword")?.focus();
  }
}

// ── Helpers ──

function markConsoleFinished(success = true) {
  const footer = document.querySelector(
    ".content-grid .panel:nth-child(2) .panel-footer",
  );
  if (footer) {
    footer.innerHTML = `
      <button class="btn-save" onclick="restoreEditorPanel()">
        Close Console
      </button>
    `;
  }

  // Remove the pulsing dot from the header
  const dot = document.querySelector(".pulse-dot");
  if (dot) dot.remove();

  if (!success) {
    appendConsoleLine("✖ Update finished with errors.", "error");
  } else {
    appendConsoleLine("✔ Update completed successfully.", "complete");
  }
}

async function handleRestart() {
  const components = buildUpdatePayload();
  showPasswordPrompt(components);
}

// ── Expose globals for HTML inline onclick ──
window.handleSave         = handleSave;
window.handleDiscard      = handleDiscard;
window.handleRestart      = handleRestart;
window.handleEditToggle   = handleEditToggle;
window.toggleSection      = toggleSection;
window.restoreEditorPanel = restoreEditorPanel;

export async function initUpdateConfig() {
  const data = await getWorkspace();

  loadWorkspace(data);
  buildUpdateList(data);

  currentFile    = null;
  currentContent = "";
  isEditMode     = false;

  const editor   = document.getElementById("editorContent");
  const bcFile   = document.getElementById("bcFile");
  const bcParent = document.getElementById("bcParent");

  if (editor)   editor.innerHTML    = `<div class="editor-placeholder">Select a file to view its contents</div>`;
  if (bcFile)   bcFile.textContent  = "—";
  if (bcParent) bcParent.textContent = "—";

  updateRestartHint();
  showLiveConsole(false);
  appendConsoleLine("System console ready...", "info");
}

function showLiveConsole(isRunning = false) {
  const panel  = document.querySelector(".content-grid .panel:nth-child(2)");
  const header = panel.querySelector(".panel-header");
  const body   = panel.querySelector(".panel-body");
  const footer = panel.querySelector(".panel-footer");

  previousHeaderHTML = header.innerHTML;
  previousEditorHTML = body.innerHTML;
  previousFooterHTML = footer.innerHTML;

  header.innerHTML = `
    <div class="live-header">
      <span>⚡ Live Update Console</span>
      ${isRunning ? `<span class="pulse-dot"></span>` : ""}
    </div>
  `;

  body.innerHTML = `<div id="liveConsole" class="live-console"></div>`;

  footer.innerHTML = isRunning
    ? `<button class="btn-save" disabled>Running...</button>`
    : `<button class="btn-save" disabled>Ready</button>`;
}

function restoreEditorPanel() {
  const panel = document.querySelector(".content-grid .panel:nth-child(2)");

  panel.querySelector(".panel-header").innerHTML = `
    <div class="editor-breadcrumb">
      <span class="breadcrumb-parent" id="bcParent">—</span>
      <span>›</span>
      <span class="breadcrumb-file" id="bcFile">—</span>
    </div>
    <div style="display:flex;gap:8px;align-items:center">
      <button id="btnEditToggle" class="btn-edit-toggle" onclick="handleEditToggle()">
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
    <button class="btn-discard" onclick="handleDiscard()">Discard</button>
    <button class="btn-save" onclick="handleSave()">Save Changes</button>
  `;
}

function appendConsoleLine(text, type = "output") {
  const box = document.getElementById("liveConsole");
  if (!box) return;

  const row       = document.createElement("div");
  row.className   = TYPE_CLASS[type] ?? "console-line";
  row.textContent = text;

  box.appendChild(row);
  box.scrollTop = box.scrollHeight;
}

// ── Upload modal ──
let selectedUploadPath = "";

function openUploadModal() {
  document.getElementById("uploadModal").classList.remove("hidden");

  const tree = document.getElementById("uploadTree");
  tree.innerHTML = "";
  renderUploadTree(workspaceData.project.children, tree);
}

function closeUploadModal() {
  document.getElementById("uploadModal").classList.add("hidden");
  selectedUploadPath = "";
  document.getElementById("filePickerArea").style.display = "none";
}

function renderUploadTree(data, parent, path = "") {
  Object.entries(data).forEach(([name, node]) => {
    const fullPath = path ? `${path}/${name}` : name;

    if (node.type === "folder") {
      const wrap = document.createElement("div");

      const row       = document.createElement("div");
      row.className   = "upload-folder";
      row.innerHTML   = `
        <span class="upload-arrow">▶</span>
        <span class="material-symbols-outlined">folder</span>
        <span>${name}</span>
      `;

      const children       = document.createElement("div");
      children.className   = "upload-children";

      row.onclick = (e) => {
        e.stopPropagation();
        selectedUploadPath = fullPath;
        document.querySelectorAll(".upload-folder").forEach((x) => x.classList.remove("active"));
        row.classList.add("active");
        children.classList.toggle("open");
        row.querySelector(".upload-arrow").classList.toggle("open");
        document.getElementById("filePickerArea").style.display = "block";
      };

      wrap.appendChild(row);
      wrap.appendChild(children);
      parent.appendChild(wrap);

      renderUploadTree(node.children || {}, children, fullPath);
    }
  });
}

async function submitUpload() {
  const input = document.getElementById("uploadInput");

  if (!selectedUploadPath) {
    showToast("Select folder first", "error");
    return;
  }

  if (!input.files.length) {
    showToast("Choose file first", "error");
    return;
  }

  try {
    await uploadFile(selectedUploadPath, input.files[0]);
    showToast("Upload success", "success");
    closeUploadModal();
    const data = await getWorkspace();
    loadWorkspace(data);
  } catch (err) {
    showToast("Upload failed", "error");
  }
}

window.openUploadModal  = openUploadModal;
window.closeUploadModal = closeUploadModal;
window.submitUpload     = submitUpload;
