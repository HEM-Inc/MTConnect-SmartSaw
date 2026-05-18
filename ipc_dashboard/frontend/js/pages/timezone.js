import { API_BASE } from "../../utils.js";
import { showToast } from "../core/toast.js";

export async function openTimezoneModal() {
  document.getElementById("timezoneModal").classList.add("show");

  try {
    const res = await fetch(`${API_BASE}/api/timezones`, {
      method: "GET",
      credentials: "include",
    });

    const data = await res.json();
    const select = document.getElementById("timezoneSelect");
    select.innerHTML = "";

    const user = JSON.parse(localStorage.getItem("user"));
    const timezones = data.data || {};

    Object.entries(timezones).forEach(([label, value]) => {
      const option = document.createElement("option");
      option.value = value;
      option.textContent = label;
      if (value === user.timezone) option.selected = true;
      select.appendChild(option);
    });

    window.addEventListener("timezoneChanged", () => {
      const updatedUser = JSON.parse(localStorage.getItem("user"));
      if (timezone && updatedUser?.timezone) {
        timezone.innerText = updatedUser.timezone;
      }
    });
  } catch (err) {
    console.error("Timezone fetch error:", err);
  }
}

export function closeTimezoneModal() {
  document.getElementById("timezoneModal").classList.remove("show");
}

export async function submitTimezone() {
  const selectedTZ = document.getElementById("timezoneSelect").value;

  try {
    const res = await fetch(`${API_BASE}/api/timezone`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      credentials: "include",
      body: JSON.stringify(selectedTZ),
    });

    const data = await res.json();

    if (data.status === "Success") {
      const user = JSON.parse(localStorage.getItem("user"));
      user.timezone = selectedTZ;
      localStorage.setItem("user", JSON.stringify(user));
      closeTimezoneModal();
      showToast(data.message || "Timezone updated successfully", "success");
      window.dispatchEvent(
        new CustomEvent("timezoneChanged", {
          detail: { timezone: selectedTZ },
        }),
      );
    } else {
      showToast(data.message || "Failed to update timezone", "error");
    }
  } catch (err) {
    console.error(err);
    showToast("Server error. Try again.", "error");
  }
}
