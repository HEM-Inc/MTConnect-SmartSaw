import { API_BASE } from "../../utils.js";

export const apiFetch = async (url, options = {}) => {
  try {
    const response = await fetch(`${API_BASE}${url}`, {
      credentials: "include",
      ...options,
    });

    if (response.status === 401) {
      localStorage.clear();
      window.location.href = "/index.html";
      return null;
    }

    return response;
  } catch (error) {
    console.error("API Error:", error);
    throw error;
  }
};
