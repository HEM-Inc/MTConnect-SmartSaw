const safeText = (value) => {
  if (value === null || value === undefined) return "";
  return String(value);
};

// Escape HTML
const escHtml = (str) => {
  return safeText(str)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
};

const renderConfig = (content) => {
  content = safeText(content).replace(/\n+$/, ""); // ← strip trailing newline

  return content
    .split("\n")
    .map((line) => {
      const trimmed = line.trim();

      if (!trimmed) return `<div class="editor-line">&nbsp;</div>`;

      if (
        trimmed.startsWith("#") ||
        trimmed.startsWith(";") ||
        trimmed.startsWith("//")
      ) {
        return `<div class="editor-line"><span class="e-comment">${escHtml(line)}</span></div>`;
      }

      if (trimmed.endsWith("{")) {
        return `<div class="editor-line"><span class="e-section">${escHtml(line)}</span></div>`;
      }

      if (trimmed.startsWith("[") && trimmed.endsWith("]")) {
        return `<div class="editor-line"><span class="e-section">${escHtml(line)}</span></div>`;
      }

      const eq = line.indexOf("=");

      if (eq !== -1) {
        const key = line.substring(0, eq + 1);
        const val = line.substring(eq + 1);
        // ← no leading newline in the template literal
        return `<div class="editor-line"><span class="e-key">${escHtml(key)}</span><span class="e-str">${escHtml(val)}</span></div>`;
      }

      return `<div class="editor-line">${escHtml(line)}</div>`;
    })
    .join("");
};

const renderJSON = (content) => {
  content = safeText(content);
  try {
    const pretty = JSON.stringify(JSON.parse(content), null, 2);
    return renderPlain(pretty);
  } catch {
    return renderPlain(content);
  }
};

const renderCode = (content) => {
  content = safeText(content).replace(/\n+$/, "");
  return content
    .split("\n")
    .map((line) => {
      const trimmed = line.trim();

      if (trimmed.startsWith("//") || trimmed.startsWith("#")) {
        return `<div class="editor-line"><span class="e-comment">${escHtml(line)}</span></div>`;
      }

      return `<div class="editor-line">${escHtml(line)}</div>`;
    })
    .join("");
};

const renderPlain = (content) => {
  content = safeText(content).replace(/\n+$/, "");
  return content
    .split("\n")
    .map(
      (line) => `<div class="editor-line">${escHtml(line) || "&nbsp;"}</div>`,
    )
    .join("");
};

// MAIN
export const renderFormattedContent = (content, type = "") => {
  type = safeText(type).toLowerCase().trim();

  switch (type) {
    case "cfg":
    case "conf":
    case "ini":
    case "afg":
      return renderConfig(content);

    case "json":
      return renderJSON(content);

    case "js":
    case "ts":
    case "py":
    case "rb":
    case "sh":
      return renderCode(content);

    default:
      return renderPlain(content);
  }
};
