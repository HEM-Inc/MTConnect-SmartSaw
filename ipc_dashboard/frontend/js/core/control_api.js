import { API_BASE } from "../../utils.js";
import { apiRequest } from "./apiClient.js";
import { showToast } from "./toast.js";

// FILE TREE API
export async function getWorkspace() {
  const json = await apiRequest("/api/files-structure", {
    method: "GET",
  });

  return {
    project: {
      type: "folder",
      children: json.data,
    },
  };
}

// FILE CONTENT API
export async function getFileContent(path) {
  return await apiRequest(
    `/api/files-content?path=${encodeURIComponent(path)}`,
    {
      method: "GET",
    },
  );
}

export function acquireFileLock(file_path) {
  return apiRequest("/api/file-edit", {
    method: "POST",
    body: JSON.stringify(file_path),
  });
}

export async function saveFile(path, content) {
  return apiRequest("/api/file-save", {
    method: "POST",
    body: JSON.stringify({
      path: path,
      content: content,
    }),
  });
}

export async function discardFile(file_path) {
  return await apiRequest("/api/file-discard", {
    method: "POST",
    body: JSON.stringify(file_path),
  });
}

export function fileHeartbeat(file_path) {
  return apiRequest("/api/file-heartbeat", {
    method: "POST",
    body: JSON.stringify(file_path),
  });
}

export async function uploadFile(dir_path, file) {
  const fd = new FormData();
  fd.append("dir_path", dir_path);
  fd.append("file", file);

  const res = await fetch(`${API_BASE}/api/file-upload`, {
    method: "POST",
    credentials: "include",
    body: fd,
  });

  if (res.status === 401) {
    showToast("Session expired", "error");
    window.location.href = "/login.html";
    return;
  }

  return await res.json();
}

export async function startUpdate(command, components, sudo_password) {
  const params = {
    command,
    components,
    sudo_password,
  };

  const res = await fetch(`${API_BASE}/api/update-start`, {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(params),
  });

  if (res.status === 401) {
    showToast("Session expired", "error");
    window.location.href = "/login.html";
    return;
  }

  const contentType = res.headers.get("content-type") || "";

  // If backend returned JSON = failure
  if (contentType.includes("application/json")) {
    const json = await res.json();

    if (json.status === "Failed") {
      throw new Error(json.data || json.message || "Update failed");
    }

    throw new Error("Unexpected JSON response");
  }

  // If stream response
  return res;
}

export async function startInstall(command, components, sudo_password) {
  const params = {
    command,
    components,
    sudo_password,
  };

  const res = await fetch(`${API_BASE}/api/install`, {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(params),
  });

  const contentType = res.headers.get("content-type") || "";

  // If backend returned JSON = failure
  if (contentType.includes("application/json")) {
    const json = await res.json();

    if (json.status === "Failed") {
      throw new Error(json.data || json.message || "Update failed");
    }

    throw new Error("Unexpected JSON response");
  }

  return res;
}
