import { API_BASE } from "../../utils.js";

export async function confirmLogout() {
  try {
    await fetch(`${API_BASE}/api/auth/logout`, {
      method: "POST",
      credentials: "include",
    });
  } catch (err) {
    console.error(err);
  }

  localStorage.clear();
  window.location.replace("/index.html");
}

// VALIDATE SESSION
export async function apiValidateSession() {
  const response = await fetch(`${API_BASE}/api/auth/me`, {
    method: "GET",
    credentials: "include",
  });

  if (!response.ok) {
    throw new Error("Unauthorized");
  }

  return await response.json();
}
