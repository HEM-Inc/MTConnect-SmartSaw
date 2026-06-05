import { loadLayout, loadUpdateTimezoneBtn } from "../core/layout.js";
import { apiFetch } from "../core/api.js";
import { convertToUserTimezone } from "../core/layout.js";
import { loadUserInfo } from "../core/login.js";
import { API_BASE } from "../../utils.js";
import { showToast } from "../core/toast.js";

document.addEventListener("DOMContentLoaded", async () => {
  try {
    await loadLayout("securityTab");

    // Close modal button
    document
      .getElementById("closeSecurityModalBtn")
      .addEventListener("click", closeModal);
    loadUpdateTimezoneBtn();

    await initSecurity();

    // Show app after everything loads
    document.getElementById("pageLoader").style.display = "none";

    document.getElementById("appContainer").classList.remove("hidden");
  } catch (err) {
    console.error("Page load error:", err);

    document.getElementById("pageLoader").style.display = "none";

    showToast("Failed to load page", "error");
  }
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

function renderEmptyCertificateState(message) {
  const container = document.getElementById("certCardContainer");

  container.innerHTML = `
    <div class="modern-card empty-cert-card">
      
      <div class="card-header">
        <div class="card-icon empty-icon">
          <i class="fa-solid fa-shield-halved"></i>
        </div>

        <div>
          <h3>No Certificate</h3>
          <span class="badge danger-badge">Self-signed Not Configured</span>
        </div>
      </div>

      <div class="card-body">
        <div class="label">Status</div>
        <div class="expiry error-text">
          Certificate not found
        </div>

        <p class="empty-message">
          ${message}
        </p>
      </div>

      <div class="card-footer">
        <button class="disabled-btn" disabled>
          <i class="fa-solid fa-download"></i>
          Download Unavailable
        </button>
      </div>

    </div>
  `;
}

async function loadCertInfo() {
  try {
    console.log("Calling cert info API...");

    const response = await apiFetch("/api/certs/info", {
      method: "GET",
    });

    if (!response) return;

    const data = await response.json();
    console.log("Response:", data);

    if (data.status === "Success" && data.data) {
      renderCard(data.data);
    } else {
      showToast(data.message || "Failed to load certificate info", "error");
      renderEmptyCertificateState(data.message || "Certificate not found");
    }
  } catch (err) {
    console.error("Error:", err);

    showToast("Failed to load certificate info", "error");
    renderEmptyCertificateState("Certificate not found");
  }
}

window.addEventListener("timezoneChanged", () => {
  loadCertInfo();
});

function openModal(data) {
  // document.getElementById("modal").style.display = "block";
  document.getElementById("modal").classList.add("show");

  const issuer = data.cert_details?.issuer || {};

  const user = JSON.parse(localStorage.getItem("user"));
  const userTimezone = user?.timezone || "UTC";

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

const btn = document.getElementById("modaldownloadBtn");

btn.addEventListener("click", downloadCert);

async function downloadCert() {
  try {
    const res = await fetch(`${API_BASE}/api/certs/ca`, {
      method: "GET",
      credentials: "include",
    });

    if (!res.ok) {
      showToast("Failed to download certificate", "error");
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
    showToast("Failed to download certificate", "error");
  }
}
