/* ─────────────────────────────────────────
   clean.js  |  prefix: uip-
   API: POST /api/clean  (SSE stream)
   SSE event data shape: { type: string, message: string }
───────────────────────────────────────── */
import { showToast } from "../../core/toast.js";

export function uipInit() {
  // ── DOM references ──
  const optContainer = document.getElementById("uipOptCards");
  const consoleBody = document.getElementById("uipConsoleBody");
  const cmdInput = document.getElementById("uipCmdInput");
  const btnSubmitLhs = document.getElementById("uipBtnSubmitLhs");
  const btnClearLhs = document.getElementById("uipBtnClearLhs");
  const containerWrap = document.getElementById("uipContainerWrap");
  const containerInput = document.getElementById("uipContainerName");

  // Guard clause
  if (!optContainer || !consoleBody || !btnSubmitLhs) {
    console.error("[uip] Critical elements missing from DOM.");
    return;
  }

  // ── State ──
  let selected = new Set();
  let activeReader = null;

  // ── API endpoint ──
  const API_ENDPOINT = "/api/clean";

  // ── Flag → API component builder ──
  const FLAG_MAP = {
    "-A": () => ({ name: "all", clean: true }),
    "-H": () => ({ name: "adapter", clean: true }),
    "-a": () => ({ name: "agent", clean: true }),
    "-M": () => ({ name: "mqtt", clean: true }),
    "-O": () => ({ name: "ods", clean: true }),
    "-C": () => ({ name: "devctl", clean: true }),
    "-S": () => ({ name: "mongodb", clean: true }),
    "-d": () => ({ name: "all", disable: true }),
    "-D": () => ({ name: "docker", clean: true }),
    "-L": (cn) => ({ name: "container", container_name: cn }),
  };

  // ── Map SSE event type → CSS class ──
  function uipTypeToClass(type) {
    if (!type) return "uip-t-step";
    const t = type.toLowerCase();
    if (t === "success" || t === "done" || t === "complete")
      return "uip-t-success";
    if (t === "error" || t === "fail" || t === "failed") return "uip-t-error";
    if (t === "warning" || t === "warn") return "uip-t-warn";
    return "uip-t-step";
  }

  // ── Console helpers ──
  function uipRemoveCursor() {
    consoleBody.querySelectorAll(".uip-cursor").forEach((el) => el.remove());
  }

  function uipAddLine(typeClass, html) {
    uipRemoveCursor();
    const span = document.createElement("span");
    span.className = "uip-t-line " + typeClass;
    span.innerHTML = html;
    consoleBody.appendChild(span);
    consoleBody.scrollTop = consoleBody.scrollHeight;
  }

  function uipAddCursorLine() {
    const span = document.createElement("span");
    span.className = "uip-t-line uip-t-ready";
    span.innerHTML = '<span class="uip-cursor"></span>';
    consoleBody.appendChild(span);
    consoleBody.scrollTop = consoleBody.scrollHeight;
  }

  function uipAddBlank() {
    uipAddLine("uip-t-dim", "&nbsp;");
  }

  function uipSetBusy(busy) {
    btnSubmitLhs.disabled = busy;
    btnSubmitLhs.style.opacity = busy ? "0.5" : "1";
  }

  // ── Bind console header buttons (called after any innerHTML restore) ──
  function uipBindConsoleButtons() {
    const btnClear = document.getElementById("uipBtnClearConsole");
    const btnCopy = document.getElementById("uipBtnCopyConsole");

    if (btnClear) {
      btnClear.addEventListener("click", function () {
        consoleBody.innerHTML = "";
        uipAddLine("uip-t-ready", "Console cleared.");
        uipAddCursorLine();
      });
    }

    if (btnCopy) {
      btnCopy.addEventListener("click", function () {
        const lines = Array.from(consoleBody.querySelectorAll(".uip-t-line"))
          .map((line) => line.innerText)
          .join("\n")
          .trim();

        if (!lines) {
          showToast("Console is empty", "warn");
          return;
        }

        navigator.clipboard
          .writeText(lines)
          .then(() => {
            const orig = btnCopy.innerHTML;
            btnCopy.innerHTML =
              '<i class="ti ti-check" style="font-size:12px"></i> Copied!';
            btnCopy.style.color = "#4ade80";
            setTimeout(() => {
              btnCopy.innerHTML = orig;
              btnCopy.style.color = "";
            }, 2000);
          })
          .catch((err) => {
            console.error("Failed to copy:", err);
            uipAddLine("uip-t-error", "✗ Failed to copy to clipboard.");
          });
      });
    }
  }

  // Bind on initial load
  uipBindConsoleButtons();

  // ── Build API payload ──
  function uipBuildPayload(flags, pwd) {
    const containerName = containerInput ? containerInput.value.trim() : "";
    const components = flags
      .map((flag) => (FLAG_MAP[flag] ? FLAG_MAP[flag](containerName) : null))
      .filter(Boolean);

    return {
      command: "clean",
      components,
      sudo_password: pwd || null,
    };
  }

  // ── Validate before submit ──
  function uipValidate(flags) {
    if (flags.indexOf("-L") !== -1) {
      const cn = containerInput ? containerInput.value.trim() : "";
      if (!cn) {
        uipAddLine(
          "uip-t-warn",
          "⚠ Container name is required for Log Repair (-L).",
        );
        uipAddCursorLine();
        return false;
      }
    }
    return true;
  }

  // ── SSE execution ──
  async function uipExecute(flags, pwd, clearSelectedOptions) {
    const payload = uipBuildPayload(flags, pwd);

    const cmdParts = flags.map((f) => {
      if (f === "-L") {
        const cn = containerInput ? containerInput.value.trim() : "";
        return "-L " + cn;
      }
      return f;
    });
    //uipAddLine("uip-t-prompt", "$ sudo bash ssClean.sh " + cmdParts.join(" "));
    //uipAddBlank();

    uipSetBusy(true);

    try {
      const response = await fetch(API_ENDPOINT, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "text/event-stream",
        },
        body: JSON.stringify(payload),
      });

      if (response.status === 401) {
        localStorage.clear();
        window.location.href = "/index.html";
        return null;
      }

      const contentType = response.headers.get("content-type") || "";

      if (contentType.includes("application/json")) {
        const json = await response.json();
        if (json.status === "Failed") {
          const detail = json.data || json.message || "Operation failed";
          //uipAddLine("uip-t-error", "✗ " + detail);
          showToast(detail, "error");
          return;
        }
        // Unexpected JSON success shape — treat as error
        throw new Error(json.message || "Unexpected response");
      }

      if (!response.ok) {
        const errText = await response.text();
        throw new Error("HTTP " + response.status + " — " + errText);
      }

      //uipAddBlank();
      uipAddLine(
        "uip-t-prompt",
        "$ sudo bash ssClean.sh " + cmdParts.join(" "),
      );

      clearSelectedOptions();
      restoreEditorPanel();

      const reader = response.body.getReader();
      const decoder = new TextDecoder("utf-8");
      activeReader = reader;
      let buffer = "";

      while (true) {
        const { value, done } = await reader.read();

        if (done) {
          uipAddBlank();
          uipAddCursorLine();
          break;
        }

        buffer += decoder.decode(value, { stream: true });

        const lines = buffer.split("\n");
        buffer = lines.pop();

        for (let i = 0; i < lines.length; i++) {
          const trimmed = lines[i].trim();
          if (!trimmed || trimmed.startsWith(":")) continue;

          if (trimmed.startsWith("data:")) {
            const raw = trimmed.slice(5).trim();

            if (raw === "[DONE]") {
              uipAddBlank();
              uipAddCursorLine();
              uipSetBusy(false);
              activeReader = null;
              return;
            }

            try {
              const parsed = JSON.parse(raw);
              const type = parsed.type || "";
              const message = parsed.message || raw;
              const cssClass = uipTypeToClass(type);
              uipAddLine(cssClass, message);
            } catch (_) {
              uipAddLine("uip-t-step", "› " + raw);
            }
          }
        }
      }
    } catch (err) {
      if (err.name === "AbortError") {
        showToast("Stream Cancelled", "info");
        //uipAddLine("uip-t-warn", "⚠ Stream cancelled.");
      } else {
        //uipAddLine("uip-t-error", "✗ Request failed: " + err.message);
        showToast(err.message || "Request Failed", "error");
        console.error("[uip] SSE error:", err);
      }
      //uipAddBlank();
      //uipAddCursorLine();
    } finally {
      uipSetBusy(false);
      activeReader = null;
    }
  }

  // ── Password prompt (saves & restores console panel) ──
  let previousHeaderHTML = "";
  let previousEditorHTML = "";
  //let previousFooterHTML = "";

  function restoreEditorPanel() {
    const panel = document.querySelector(".uip-panel-root .uip-rhs");
    const header = panel.querySelector(".uip-console-header");
    const body = panel.querySelector(".uip-console-body");
    //const footer = panel.querySelector(".uip-console-input-row");

    header.innerHTML = previousHeaderHTML;
    body.innerHTML = previousEditorHTML;
    //footer.innerHTML = previousFooterHTML;

    // Re-bind Clear and Copy — innerHTML wipes event listeners
    uipBindConsoleButtons();
  }

  function showPasswordPrompt() {
    const panel = document.querySelector(".uip-panel-root .uip-rhs");
    const header = panel.querySelector(".uip-console-header");
    const body = panel.querySelector(".uip-console-body");
    //const footer = panel.querySelector(".uip-console-input-row");

    previousHeaderHTML = header.innerHTML;
    previousEditorHTML = body.innerHTML;
    //previousFooterHTML = footer.innerHTML;

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
          Submit
        </button>
        <button class="btn-discard" id="uipBtnCancelSudo">Cancel</button>
      </div>
    `;

    // FIX: use addEventListener, not inline onclick — restoreEditorPanel is
    // closure-scoped and not reachable from a global onclick string.
    //footer.innerHTML = `<button class="btn-discard" id="uipBtnCancelSudo">Cancel</button>`;
    document
      .getElementById("uipBtnCancelSudo")
      .addEventListener("click", () => {
        restoreEditorPanel();
        clearSelectedOptions();
      });

    document
      .getElementById("btnSubmitSudo")
      .addEventListener("click", async () => {
        const pwd = document.getElementById("sudoPassword").value.trim();
        if (!pwd) {
          showToast("Enter password", "error");
          return;
        }
        //restoreEditorPanel();
        await uipHandleSubmit(pwd);
      });
  }

  function clearSelectedOptions() {
    selected.clear();
    document
      .querySelectorAll(".uip-opt-card")
      .forEach((c) => c.classList.remove("uip-selected"));
    if (containerWrap) containerWrap.classList.remove("uip-visible");
    if (containerInput) containerInput.value = "";
  }

  // ── Handle submit ──
  function uipHandleSubmit(pwd) {
    if (selected.size === 0) {
      showToast("Please select at least one option", "warning");
      //uipAddLine("uip-t-warn", "⚠ Please select at least one option.");
      //uipAddCursorLine();
      return;
    }

    const flags = Array.from(selected);
    if (!uipValidate(flags)) return;

    uipExecute(flags, pwd, clearSelectedOptions);
  }

  // ── Card selection (event delegation) ──
  optContainer.addEventListener("click", function (e) {
    if (e.target.closest(".uip-container-input-wrap")) return;

    const card = e.target.closest(".uip-opt-card");
    if (!card) return;

    const flag = card.getAttribute("data-flag");

    if (selected.has(flag)) {
      selected.delete(flag);
      card.classList.remove("uip-selected");
    } else {
      selected.add(flag);
      card.classList.add("uip-selected");
    }

    if (flag === "-L" && containerWrap) {
      if (selected.has("-L")) {
        containerWrap.classList.add("uip-visible");
        if (containerInput) containerInput.focus();
      } else {
        containerWrap.classList.remove("uip-visible");
        if (containerInput) containerInput.value = "";
      }
    }
  });

  if (containerWrap) {
    containerWrap.addEventListener("click", (e) => e.stopPropagation());
  }

  // ── Button bindings ──
  btnSubmitLhs.addEventListener("click", showPasswordPrompt);

  btnClearLhs.addEventListener("click", function () {
    selected.clear();
    document
      .querySelectorAll(".uip-opt-card")
      .forEach((c) => c.classList.remove("uip-selected"));
    if (containerWrap) containerWrap.classList.remove("uip-visible");
    if (containerInput) containerInput.value = "";
    consoleBody.innerHTML = "";
    //uipAddLine("uip-t-ready", "Console cleared.");
    uipAddCursorLine();
  });

  // ── Terminal keyboard input ──
  if (cmdInput) {
    cmdInput.addEventListener("keydown", function (e) {
      if (e.key !== "Enter") return;
      const val = cmdInput.value.trim();
      cmdInput.value = "";
      if (!val) return;

      const known = [
        "-A",
        "-H",
        "-a",
        "-M",
        "-O",
        "-C",
        "-S",
        "-d",
        "-D",
        "-L",
      ];
      const parts = val.split(/\s+/);
      const found = parts.filter((p) => known.indexOf(p) !== -1);

      if (!found.length) {
        uipAddLine("uip-t-error", "✗ Unrecognized command.");
        uipAddCursorLine();
        return;
      }

      if (found.indexOf("-L") !== -1) {
        const lIdx = parts.indexOf("-L");
        const cn = parts[lIdx + 1] || "";
        if (!cn) {
          uipAddLine(
            "uip-t-warn",
            "⚠ Usage: ./uninstall.sh -L &lt;container_name&gt;",
          );
          uipAddCursorLine();
          return;
        }
        if (containerInput) containerInput.value = cn;
      }

      const prevSelected = selected;
      selected = new Set(found);
      uipExecute(found).finally(() => {
        selected = prevSelected;
        if (containerInput) containerInput.value = "";
      });
    });
  }
} // end uipInit
