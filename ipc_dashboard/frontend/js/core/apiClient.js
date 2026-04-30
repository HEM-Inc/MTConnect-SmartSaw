import { API_BASE } from "../../utils.js";
import { showToast } from "./toast.js";

export async function apiRequest(url, options = {}) {
  try {
    const res = await fetch(`${API_BASE}${url}`, {
      credentials: "include",
      headers: {
        "Content-Type": "application/json",
        ...(options.headers || {}),
      },
      ...options,
    });

    // -------------------------------
    // HANDLE 401
    // -------------------------------
    if (res.status === 401) {
      showToast("Session expired. Please login again.", "error");

      localStorage.clear();
      sessionStorage.clear();

      setTimeout(() => {
        window.location.replace("/index.html");
      }, 1200);

      throw new Error("Unauthorized");
    }

    const data = await res.json().catch(() => null);

    // HTTP error
    if (!res.ok) {
      throw new Error(
        data?.detail?.[0]?.msg ||
          data?.message ||
          data?.data ||
          "Request failed",
      );
    }

    // Backend business failure
    if (data?.status?.toLowerCase() === "failed") {
      throw new Error(data?.data || data?.message || "Operation failed");
    }

    return data;
  } catch (err) {
    console.error("API ERROR:", err.message);
    throw err;
  }
}

export function handleApiError(err) {
  showToast(err?.message || err?.data || "Unknown error", "error");
}
