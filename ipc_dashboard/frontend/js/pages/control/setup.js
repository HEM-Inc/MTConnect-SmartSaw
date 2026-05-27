import {
  getWorkspace,
  getFileContent,
  acquireFileLock,
  saveFile,
  discardFile,
  fileHeartbeat,
  uploadFile,
} from "../../core/control_api.js";
import { handleApiError } from "../../core/apiClient.js";
import { showToast } from "../../core/toast.js";
import { renderFormattedContent } from "./fileFormatter.js";
import {
  renderTree,
  updateRestartHint,
  buildUpdateList,
  showLiveConsole,
  appendConsoleLine,
  restoreEditorPanel,
  showPasswordPrompt,
  placeCursorAtOffset,
  getEditorText,
  placeCursorAtEnd,
  restoreExistingConsole,
  updateActionButtonState,
} from "../control.js";

// ── Module-local state ──
let currentFile = null;
let currentContent = "";
let workspaceData = null;
let isEditMode = false;
let currentPath = null;
let heartbeatTimer = null;
let selectedUploadPath = "";

// UPDATE ITEMS
const UPDATE_ITEMS = [
  {
    label: "AFG Configuration File",
    description: "Select the .afg configuration file",
    flag: "-a",
    type: "files",
    sourcePath: "adapter/config",
  },
  {
    label: "Alarm Configuration File",
    description: "Select the alarms JSON file.",
    flag: "-j",
    type: "files",
    sourcePath: "adapter/data",
  },
  {
    label: "MTConnect Device XML File",
    description: "Select the MTConnect device XML file",
    flag: "-d",
    type: "files",
    sourcePath: "agent/config/devices",
  },
  {
    label: "Device Control Config File",
    description: "Select the DevCtl JSON configuration file.",
    flag: "-c",
    type: "files",
    sourcePath: "devctl/config",
  },
  {
    label: "Machine Serial Number",
    description: "Configure serial number used for UUID generation",
    flag: "-u",
    type: "input",
    placeholder: "Enter serial number",
  },
  {
    label: "Enable MQTT Bridge Mode",
    description: "Install using MQTT bridge configuration",
    flag: "-b",
    type: "nofiles",
  },
  {
    label: "Use Standard MQTT Mode",
    description: "Install using standard MQTT broker configuration",
    flag: "-B",
    type: "nofiles",
  },
];

// FILE RENDERING
function renderContent(filename, content, fileType = "") {
  currentFile = filename;
  currentContent = content;
  isEditMode = false;

  const bcParent = document.getElementById("bcParent");
  const bcFile = document.getElementById("bcFile");
  const status = document.getElementById("editorStatus");
  const editor = document.getElementById("editorContent");
  const editBtn = document.getElementById("btnEditToggle");

  if (!editor) return;

  if (bcParent && workspaceData) {
    const folders = workspaceData.project.children;
    const parent = Object.keys(folders).find((f) =>
      Object.keys(folders[f].children || {}).includes(filename),
    );
    bcParent.textContent = parent || filename.split(".")[0].toUpperCase();
  }
  if (bcFile) bcFile.textContent = filename;
  if (status) {
    status.textContent = "● unsaved";
    status.className = "editor-status-badge";
  }
  if (editBtn) {
    editBtn.innerHTML = `<span class="material-symbols-outlined icon">edit</span><span>Edit</span>`;
    editBtn.classList.remove("active");
  }

  editor.contentEditable = "false";
  editor.innerHTML = renderFormattedContent(content, fileType);
  editor.oninput = null;
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

// EDIT / VIEW TOGGLE
async function handleEditToggle() {
  if (!currentPath) {
    showToast("Select file first", "error");
    return;
  }
  const saveBtn = document.getElementById("btnSave");
  const discardBtn = document.getElementById("btnDiscard");
  const editor = document.getElementById("editorContent");
  const btn = document.getElementById("btnEditToggle");

  try {
    if (!isEditMode) {
      await acquireFileLock(currentPath);
      isEditMode = true;
      saveBtn?.classList.remove("hidden");
      discardBtn?.classList.remove("hidden");
      editor.contentEditable = "true";
      // Add this in handleEditToggle, after editor.contentEditable = "true"
      editor._keydownHandler = (e) => {
        if (e.key === "Backspace") {
          const sel = window.getSelection();
          if (!sel.rangeCount) return;

          const range = sel.getRangeAt(0);
          // Only intercept if cursor is at the very start of a line
          if (range.collapsed && range.startOffset === 0) {
            const currentLine =
              range.startContainer.closest?.(".editor-line") ??
              range.startContainer.parentElement?.closest(".editor-line");

            if (!currentLine) return;
            const prevLine = currentLine.previousElementSibling;
            if (!prevLine) return; // already first line, nothing to do

            e.preventDefault();

            // Get text of both lines
            const prevClone = prevLine.cloneNode(true);
            prevClone.querySelectorAll("br").forEach((br) => br.remove());
            const prevText = prevClone.innerText.replace(/\u00A0/g, " ");

            const currClone = currentLine.cloneNode(true);
            currClone.querySelectorAll("br").forEach((br) => br.remove());
            const currText = currClone.innerText.replace(/\u00A0/g, " ");

            // Merge: put cursor at end of prevLine text
            if (currText === "") {
              // Current line is empty — just remove it
              currentLine.remove();
              // Place cursor at end of prevLine
              placeCursorAtEnd(prevLine);
            } else {
              // Merge curr into prev
              prevLine.innerText = prevText + currText;
              currentLine.remove();
              // Place cursor at the join point
              placeCursorAtOffset(prevLine, prevText.length);
            }

            currentContent = getEditorText(editor);
          }
        }
      };

      editor.addEventListener("keydown", editor._keydownHandler);
      // Store file type for re-rendering
      const fileType = currentPath?.split(".").pop() ?? "";

      // Intercept paste to normalize content
      editor._pasteHandler = (e) => {
        e.preventDefault();

        // Get plain text only
        const text = (e.clipboardData || window.clipboardData).getData(
          "text/plain",
        );

        // This inserts raw text without any HTML formatting
        document.execCommand("insertText", false, text);

        // After insert, sync currentContent and re-render
        currentContent = getEditorText(editor);
      };

      editor.addEventListener("paste", editor._pasteHandler);
      // Ensure at least one editor-line always exists
      editor._emptyGuard = new MutationObserver(() => {
        if (editor.innerHTML.trim() === "" || editor.childNodes.length === 0) {
          editor.innerHTML = '<div class="editor-line"><br/></div>';
          // Move caret to the line
          const sel = window.getSelection();
          const range = document.createRange();
          const line = editor.querySelector(".editor-line");
          range.setStart(line, 0);
          range.collapse(true);
          sel.removeAllRanges();
          sel.addRange(range);
        }
      });

      editor._emptyGuard.observe(editor, {
        childList: true,
        subtree: true,
        characterData: true,
      });
      editor.focus();
      btn.innerHTML = `<span class="material-symbols-outlined icon">visibility</span><span>View</span>`;
      btn.classList.add("active");
      editor.oninput = () => {
        currentContent = editor.innerText;
      };
      heartbeatTimer = setInterval(() => fileHeartbeat(currentPath), 10000);
      showToast("Edit mode enabled", "success");
    } else {
      editor.contentEditable = "false";
      if (editor._pasteHandler) {
        editor.removeEventListener("paste", editor._pasteHandler);
        editor._pasteHandler = null;
      }
      if (editor._emptyGuard) {
        editor._emptyGuard.disconnect();
        editor._emptyGuard = null;
      }
      if (editor._keydownHandler) {
        editor.removeEventListener("keydown", editor._keydownHandler);
        editor._keydownHandler = null;
      }
      editor.oninput = null;
      saveBtn?.classList.add("hidden");
      discardBtn?.classList.add("hidden");
      isEditMode = false;
      btn.innerHTML = `<span class="material-symbols-outlined icon">edit</span><span>Edit</span>`;
      btn.classList.remove("active");
      clearInterval(heartbeatTimer);
      heartbeatTimer = null;
      showToast("View mode enabled", "success");
    }
  } catch (err) {
    handleApiError(err);
  }
}

// SAVE / DISCARD
async function handleSave() {
  if (!currentFile) return;
  const s = document.getElementById("editorStatus");
  try {
    const editor = document.getElementById("editorContent");
    currentContent = getEditorText(editor);
    await saveFile(currentPath, currentContent);

    clearInterval(heartbeatTimer);
    heartbeatTimer = null;
    isEditMode = false;
    // Clean up edit-mode handlers
    if (editor._pasteHandler) {
      editor.removeEventListener("paste", editor._pasteHandler);
      editor._pasteHandler = null;
    }
    if (editor._emptyGuard) {
      editor._emptyGuard.disconnect();
      editor._emptyGuard = null;
    }
    if (editor._keydownHandler) {
      editor.removeEventListener("keydown", editor._keydownHandler);
      editor._keydownHandler = null;
    }

    editor.contentEditable = "false";
    // Store file type for re-rendering
    const fileType = currentPath?.split(".").pop() ?? "";

    // Intercept paste to normalize content
    editor._pasteHandler = (e) => {
      e.preventDefault();

      const text = (e.clipboardData || window.clipboardData)
        .getData("text/plain")
        .replace(/\r\n/g, "\n") // normalize Windows line endings
        .replace(/\r/g, "\n"); // normalize old Mac line endings

      const lines = text.split("\n");

      const sel = window.getSelection();
      if (!sel.rangeCount) return;

      const range = sel.getRangeAt(0);
      range.deleteContents();

      // Find which editor-line the cursor is in
      const anchorLine =
        range.startContainer.closest?.(".editor-line") ??
        range.startContainer.parentElement?.closest(".editor-line");

      if (!anchorLine) return;

      // Single-line paste — just insert text normally
      if (lines.length === 1) {
        const textNode = document.createTextNode(lines[0]);
        range.insertNode(textNode);
        range.setStartAfter(textNode);
        range.collapse(true);
        sel.removeAllRanges();
        sel.addRange(range);
        currentContent = getEditorText(editor);
        return;
      }

      // Multi-line paste
      // Get text after cursor in current line (to append to last pasted line)
      const afterRange = document.createRange();
      afterRange.setStart(range.startContainer, range.startOffset);
      afterRange.setEndAfter(anchorLine.lastChild ?? anchorLine);
      const afterText = afterRange.toString();
      afterRange.deleteContents();

      // Insert first line's text into current anchor line
      const firstNode = document.createTextNode(lines[0]);
      range.insertNode(firstNode);

      // Build new divs for lines[1..end]
      let lastLine = anchorLine;
      for (let i = 1; i < lines.length; i++) {
        const div = document.createElement("div");
        div.className = "editor-line";
        const lineText =
          i === lines.length - 1 ? lines[i] + afterText : lines[i];
        // Use &nbsp; for empty lines so the div has height
        div.innerText = lineText === "" ? "\u00A0" : lineText;
        lastLine.insertAdjacentElement("afterend", div);
        lastLine = div;
      }

      // Place cursor at end of last inserted line (before the afterText)
      const cursorOffset = lines[lines.length - 1].length;
      placeCursorAtOffset(lastLine, cursorOffset);

      currentContent = getEditorText(editor);
    };

    editor.addEventListener("paste", editor._pasteHandler);
    // Ensure at least one editor-line always exists
    editor._emptyGuard = new MutationObserver(() => {
      if (editor.innerHTML.trim() === "" || editor.childNodes.length === 0) {
        editor.innerHTML = '<div class="editor-line">\u200B</div>';
        // Move caret to the line
        const sel = window.getSelection();
        const range = document.createRange();
        const line = editor.querySelector(".editor-line");
        range.setStart(line, 0);
        range.collapse(true);
        sel.removeAllRanges();
        sel.addRange(range);
      }
    });

    editor._emptyGuard.observe(editor, {
      childList: true,
      subtree: true,
      characterData: true,
    });
    editor.oninput = null;
    const btn = document.getElementById("btnEditToggle");

    btn.innerHTML = `
  <span class="material-symbols-outlined icon">edit</span>
  <span>Edit</span>
`;

    btn.classList.remove("active");
    document.getElementById("btnSave")?.classList.add("hidden");
    document.getElementById("btnDiscard")?.classList.add("hidden");

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

async function handleDiscard() {
  try {
    if (!currentPath) return;

    await discardFile(currentPath);

    clearInterval(heartbeatTimer);
    heartbeatTimer = null;

    isEditMode = false;

    const editor = document.getElementById("editorContent");
    const btn = document.getElementById("btnEditToggle");

    editor.contentEditable = "false";
    // Clean up edit-mode handlers
    if (editor._pasteHandler) {
      editor.removeEventListener("paste", editor._pasteHandler);
      editor._pasteHandler = null;
    }
    if (editor._emptyGuard) {
      editor._emptyGuard.disconnect();
      editor._emptyGuard = null;
    }
    if (editor._keydownHandler) {
      editor.removeEventListener("keydown", editor._keydownHandler);
      editor._keydownHandler = null;
    }
    editor.oninput = null;

    document.getElementById("btnSave")?.classList.add("hidden");
    document.getElementById("btnDiscard")?.classList.add("hidden");

    btn.innerHTML = `
      <span class="material-symbols-outlined icon">edit</span>
      <span>Edit</span>
    `;
    btn.classList.remove("active");

    await renderFileFromAPI(currentPath);

    showToast("Changes discarded", "success");
  } catch (err) {
    handleApiError(err);
  }
}

// WORKSPACE / FILE TREE
function loadWorkspace(data) {
  workspaceData = data;
  const root = document.getElementById("compTree");
  root.innerHTML = "";
  renderTree(data.project.children, root, "", (fullPath) => {
    currentPath = fullPath;
    restoreEditorPanel({
      onEditToggle: handleEditToggle,
      onSave: handleSave,
      onDiscard: handleDiscard,
    });
    renderFileFromAPI(fullPath);
  });
}

function toggleSection(treeId, arrowId) {
  const tree = document.getElementById(treeId);
  const arrow = document.getElementById(arrowId);
  if (!tree || !arrow) return;
  const hide = tree.style.display !== "none";
  tree.style.display = hide ? "none" : "block";
  arrow.classList.toggle("collapsed", hide);
}

function buildUpdatePayload() {
  const components = [];

  if (document.querySelector(`.app-chk[data-flag="-b"]`)?.checked)
    components.push({ name: "mqtt", bridge: true });

  document.querySelectorAll(".update-block").forEach((block, index) => {
    const checked = block.querySelector(".file-chk:checked");
    if (!checked) return;
    const fileName = checked.value.split("/").pop();
    const item = UPDATE_ITEMS[index];
    if (item.flag === "-a")
      components.push({ name: "adapter", config_file: fileName });
    if (item.flag === "-j") {
      const existing = components.find((x) => x.name === "adapter");
      if (existing) existing.data_file = fileName;
      else components.push({ name: "adapter", data_file: fileName });
    }
    if (item.flag === "-d")
      components.push({ name: "agent", config_file: fileName });
    if (item.flag === "-c")
      components.push({ name: "devctl", config_file: fileName });
  });

  document.querySelectorAll(".update-inline-input").forEach((input, i) => {
    const val = input.value.trim();
    if (!val) return;
    const item = UPDATE_ITEMS[i];
    if (item.flag === "-u")
      components.push({ name: "serial_number", serial_number: val });
  });

  return components;
}

function handleInstall() {
  showPasswordPrompt(
    buildUpdatePayload(),
    "setup",
    "install",
    "✔ Install completed.",
  );
}

// UPLOAD MODAL
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
      const row = document.createElement("div");
      row.className = "upload-folder";
      row.innerHTML = `
        <span class="upload-arrow">▶</span>
        <span class="material-symbols-outlined">folder</span>
        <span>${name}</span>
      `;
      const children = document.createElement("div");
      children.className = "upload-children";
      row.onclick = (e) => {
        e.stopPropagation();
        selectedUploadPath = fullPath;
        document
          .querySelectorAll(".upload-folder")
          .forEach((x) => x.classList.remove("active"));
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
    const res = await uploadFile(selectedUploadPath, input.files[0]);
    if (res.status.toLowerCase() === "success") {
      showToast("Upload success", "success");
      closeUploadModal();
      loadWorkspace(await getWorkspace());
    } else {
      throw new Error(res.data || "Upload failed");
    }
  } catch (err) {
    showToast(`Upload failed: ${err.message}`, "error");
  }
}

// GLOBALS — only static onclick attrs in setup.html
window.handleInstall = handleInstall;
window.toggleSection = toggleSection;
window.openUploadModal = openUploadModal;
window.closeUploadModal = closeUploadModal;
window.submitUpload = submitUpload;

// INIT
export async function initSetup() {
  const data = await getWorkspace();
  loadWorkspace(data);
  buildUpdateList(data, UPDATE_ITEMS, updateRestartHint);

  const restored = restoreExistingConsole("setup");

  const stream = window.activeStreams?.["setup"];
  updateActionButtonState("setup", stream?.running === true);

  if (restored) {
    return;
  }

  currentFile = null;
  currentContent = "";
  isEditMode = false;
  currentPath = null;

  const editor = document.getElementById("editorContent");
  const bcFile = document.getElementById("bcFile");
  const bcParent = document.getElementById("bcParent");
  if (editor)
    editor.innerHTML = `<div class="editor-placeholder">Select a file to view its contents</div>`;
  if (bcFile) bcFile.textContent = "—";
  if (bcParent) bcParent.textContent = "—";

  updateRestartHint();
  showLiveConsole("setup", false);
  appendConsoleLine("setup", "System console ready...");
}
