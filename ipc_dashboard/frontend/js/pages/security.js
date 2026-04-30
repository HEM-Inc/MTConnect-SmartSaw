import { loadLayout } from "../core/layout.js";
import { apiFetch } from "../core/api.js";
import { convertToUserTimezone } from "../core/layout.js";
import { loadUserInfo } from "../core/login.js";

document.addEventListener("DOMContentLoaded", async () => {
  await loadLayout("securityTab"); // 1. load UI first

  initSecurity(); // 2. then logic
});

async function initSecurity() {
  showLoginToast();
  loadUserInfo();
  await loadCertInfo();
}

function showLoginToast() {
  const message = sessionStorage.getItem("loginSuccess");
  if (message) {
    showToast(message, "success");
    sessionStorage.removeItem("loginSuccess");
  }
}

function renderCard(cert) {
  const container = document.getElementById("certCardContainer");

  const user = JSON.parse(localStorage.getItem("user"));
  const userTimezone = user?.timezone || "UTC";

  const formattedExpiry = convertToUserTimezone(cert.expiry_date, userTimezone);

  container.innerHTML = `
        <div class="card modern-card" id="certCard">

            <div class="card-header">
                <div class="card-icon">
                    <i class="fa-solid fa-shield-halved"></i>
                </div>
                <div>
                    <h3>Certificate Authority</h3>
                    <span class="badge">Self Signed</span>
                </div>
            </div>

            <div class="card-body">
                <p class="label">Expiry Date</p>
                <p class="expiry">${formattedExpiry}</p>
            </div>

            <div class="card-footer">
                <button id="downloadBtn">
                    <i class="fa-solid fa-download"></i>
                    Download
                </button>
            </div>

        </div>
    `;

  document.getElementById("certCard").addEventListener("click", () => {
    openModal(cert);
  });

  document.getElementById("downloadBtn").addEventListener("click", (e) => {
    e.stopPropagation();
    downloadCert();
  });
}

async function loadCertInfo() {
  try {
    console.log("Calling cert info API...");

    // a = b

    // const res = await fetch(`${API_BASE}/api/certs/info`, {
    //     method: "GET",
    //     credentials: "include"
    // });

    // console.log("Status:", res.status);

    // if (!res.ok) {
    //     console.error("API failed:", res.status);
    //     return;
    // }

    const response = await apiFetch("/api/certs/info", {
      method: "GET",
    });

    if (!response) return; // stop if redirected

    const data = await response.json();
    console.log("Response:", data);

    if (data.status === "Success") {
      renderCard(data.data);
    } else {
      alert("Failed: " + data.message);
    }
  } catch (err) {
    console.error("Error:", err);
  }
}

async function submitTimezone() {
  const selectedTZ = document.getElementById("timezoneSelect").value;

  try {
    const res = await fetch(`${API_BASE}/api/timezone`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      credentials: "include",
      body: JSON.stringify(selectedTZ),
    });

    const data = await res.json();

    // console.log("API response:", data);

    if (data.status === "Success") {
      const user = JSON.parse(localStorage.getItem("user"));
      user.timezone = selectedTZ;
      localStorage.setItem("user", JSON.stringify(user));

      document.getElementById("userTimezoneText").innerText = selectedTZ;

      await loadCertInfo();

      showToast(data.message || "Timezone updated successfully", "success");

      closeTimezoneModal();
    } else {
      showToast(data.message || "Failed to update timezone", "error");
    }
  } catch (err) {
    console.error(err);
    showToast("Server error. Try again.", "error");
  }
}

function openModal(data) {
  // document.getElementById("modal").style.display = "block";
  document.getElementById("modal").classList.add("show");

  const issuer = data.cert_details?.issuer || {};

  const user = JSON.parse(localStorage.getItem("user"));
  const userTimezone = user?.timezone || "UTC";

  console.log("data expirty date is ", data.expiry_date);

  const formattedExpiry = convertToUserTimezone(data.expiry_date, userTimezone);

  // const issuerHTML = Object.entries(issuer)
  //     .map(([key, value]) => `<div><strong>${key}:</strong> ${value}</div>`)
  //     .join("");

  const issuerHTML = Object.entries(issuer)
    .map(
      ([key, value]) =>
        `<div class="issuer-row"><strong>${key}:</strong> ${value}</div>`,
    )
    .join("");

  const status = data.is_expired
    ? `<span class="expired">Expired</span>`
    : `<span class="valid">Valid</span>`;

  document.getElementById("modalData").innerHTML = `
        <div class="modal-section">
            <h4>Issuer</h4>
            ${issuerHTML}
        </div>

        <div class="modal-section">
            <p><strong>Expiry Date:</strong> ${formattedExpiry}</p>
            <p><strong>Days Remaining:</strong> ${data.days_remaining}</p>
            <p><strong>Status:</strong> ${status}</p>
        </div>
    `;
}

function closeModal() {
  // document.getElementById("modal").style.display = "none";
  document.getElementById("modal").classList.remove("show");
}

window.closeModal = closeModal;

// Download Certificate
async function downloadCert() {
  try {
    const res = await fetch(`${API_BASE}/api/certs/ca`, {
      method: "GET",
      credentials: "include",
    });

    if (!res.ok) {
      alert("Download failed");
      return;
    }

    const blob = await res.blob();
    const url = window.URL.createObjectURL(blob);

    const a = document.createElement("a");
    a.href = url;
    a.download = "ca.crt";
    a.click();
  } catch (err) {
    console.error(err);
  }
}

async function openTimezoneModal() {
  // document.getElementById("timezoneModal").style.display = "block";

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

      option.value = value; // actual value to send
      option.textContent = label; // display text

      if (value === user.timezone) {
        option.selected = true;
      }

      select.appendChild(option);
    });
  } catch (err) {
    console.error("Timezone fetch error:", err);
  }
}

function closeTimezoneModal() {
  // document.getElementById("timezoneModal").style.display = "none";
  // document.getElementById("timezoneModal").style.display = "flex";
  document.getElementById("timezoneModal").classList.remove("show");
}

function showToast(message, type = "success") {
  const container = document.getElementById("toastContainer");

  const toast = document.createElement("div");
  toast.className = `toast ${type}`;
  toast.innerText = message;

  container.appendChild(toast);

  // Auto remove after 3 sec
  setTimeout(() => {
    toast.remove();
  }, 3000);
}
