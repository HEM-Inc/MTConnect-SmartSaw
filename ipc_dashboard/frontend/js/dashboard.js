const API_BASE = "";

async function apiFetch(url, options = {}) {
    try {
        const response = await fetch(url, {
            credentials: "include",
            ...options
        });

        // 🚨 HANDLE SESSION EXPIRED
        if (response.status === 401) {
            console.warn("Session expired. Redirecting to login...");

            // Optional: clear local storage
            localStorage.clear();

            // Redirect to login page
            window.location.href = "/index.html";
            return null;
        }

        return response;

    } catch (error) {
        console.error("API Error:", error);
        throw error;
    }
}

document.addEventListener("DOMContentLoaded", () => {
    console.log("Dashboard loaded");

    const message = sessionStorage.getItem("loginSuccess");

    if (message) {
        showToast(message, "success");
        sessionStorage.removeItem("loginSuccess");
    }

    // Attach sidebar events AFTER DOM loads
    document.getElementById("securityTab").onclick = () => {
        switchTab("security");
    };

    document.getElementById("configTab").onclick = () => {
        switchTab("config");
    };

    // Default tab
    switchTab("security");

    // Load certificate info
    loadCertInfo();

    // Load user data
    const user = JSON.parse(localStorage.getItem("user"));

    if (user) {
        document.getElementById("userName").innerText =
            user.name || user.user_uid;

        // document.getElementById("userRole").innerText =
        //     user.role || "";

        // document.getElementById("userTimezone").innerText =
        //     user.timezone || "UTC";

        document.getElementById("userTimezoneText").innerText =
            user.timezone || "UTC";

        const role = (user.role || "").toLowerCase();

        if (role !== "admin") {
            // Hide Config & Device tabs
            document.getElementById("configTab").style.display = "none";
            document.getElementById("deviceTab").style.display = "none";
        }
    }

    const profile = document.getElementById("profileMenu");
    const dropdown = document.getElementById("profileDropdown");

    profile.addEventListener("click", (e) => {
        e.stopPropagation();
        dropdown.classList.toggle("show");
    });

    // Close when clicking outside
    document.addEventListener("click", () => {
        dropdown.classList.remove("show");
    });
});

const sidebar = document.querySelector(".sidebar");

// Collapse when mouse leaves
// sidebar.addEventListener("mouseleave", () => {
//     sidebar.classList.add("collapsed");
// });

// // Expand when mouse enters
// sidebar.addEventListener("mouseenter", () => {
//     sidebar.classList.remove("collapsed");
// });

// // Start collapsed (optional)
// window.addEventListener("load", () => {
//     sidebar.classList.add("collapsed");
// });


// document.addEventListener("DOMContentLoaded", () => {
//     const sidebar = document.querySelector(".sidebar");
//     const toggleBtn = document.getElementById("toggleSidebar");

//     // Default: OPEN (no collapsed class)

//     toggleBtn.addEventListener("click", () => {
//         sidebar.classList.toggle("collapsed");
//     });
// });

document.addEventListener("DOMContentLoaded", () => {
    const sidebar = document.querySelector(".sidebar");
    const toggleBtn = document.getElementById("toggleSidebar");
    const icon = document.getElementById("toggleIcon");

    toggleBtn.addEventListener("click", () => {
        sidebar.classList.toggle("collapsed");

        // Change icon based on state
        if (sidebar.classList.contains("collapsed")) {
            icon.innerHTML = ">";
        } else {
            icon.innerHTML = "<";
        }
    });
});

// Switch tabs
function switchTab(tab) {
    document.getElementById("securityPage").style.display =
        tab === "security" ? "block" : "none";

    document.getElementById("configPage").style.display =
        tab === "config" ? "block" : "none";

    document.getElementById("securityTab").classList.toggle("active", tab === "security");
    document.getElementById("configTab").classList.toggle("active", tab === "config");
}

// Load Certificate Info
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
            method: "GET"
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

// Render Card (SAFE VERSION)
// function renderCard(cert) {
//     const container = document.getElementById("certCardContainer");

//     const user = JSON.parse(localStorage.getItem("user"));
//     const userTimezone = user?.timezone || "UTC";

//     const formattedExpiry = convertToUserTimezone(cert.expiry_date, userTimezone);

//     container.innerHTML = `
//         <div class="card" id="certCard">
//             <h3>Certificate Authority</h3>
//             <h3>(Self Signed)</h3>
//             <p>Expiry Date:</p>
//             <strong>${formattedExpiry}</strong>
//             <button id="downloadBtn">Download ca.crt</button>
//         </div>
//     `;

//     // Safe event binding
//     document.getElementById("certCard").addEventListener("click", () => {
//         openModal(cert);
//     });

//     document.getElementById("downloadBtn").addEventListener("click", (e) => {
//         e.stopPropagation();
//         downloadCert();
//     });
// }

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

function formatDate(dateStr) {
    const date = new Date(dateStr);
    return date.toLocaleDateString();
}

// function convertToUserTimezone(dateStr, timezone) {
//     try {
//         const date = new Date(dateStr);

//         return date.toLocaleString("en-US", {
//             timeZone: timezone,
//             year: "numeric",
//             month: "short",
//             day: "numeric",
//             hour: "2-digit",
//             minute: "2-digit",
//             second: "2-digit"
//         });

//     } catch (err) {
//         console.error("Timezone conversion error:", err);
//         return dateStr;
//     }
// }


function convertToUserTimezone(dateStr, timezone) {
    try {
        return moment(dateStr)
            .tz(timezone)
            .format("MMM D, YYYY, hh:mm:ss A");

    } catch (err) {
        console.error("Moment timezone error:", err);
        return dateStr;
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
        .map(([key, value]) => 
            `<div class="issuer-row"><strong>${key}:</strong> ${value}</div>`
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

// Download Certificate
async function downloadCert() {
    try {
        const res = await fetch(`${API_BASE}/api/certs/ca`, {
            method: "GET",
            credentials: "include"
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
            credentials: "include"
        });

        const data = await res.json();

        const select = document.getElementById("timezoneSelect");
        select.innerHTML = "";

        const user = JSON.parse(localStorage.getItem("user"));

        const timezones = data.data || {};

        Object.entries(timezones).forEach(([label, value]) => {
            const option = document.createElement("option");

            option.value = value;   // actual value to send
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


// async function submitTimezone() {
//     const selectedTZ = document.getElementById("timezoneSelect").value;

//     try {
//         const res = await fetch(`${API_BASE}/api/timezone`, {
//             method: "POST",
//             headers: {
//                 "Content-Type": "application/json"
//             },
//             credentials: "include",
//             body: JSON.stringify(selectedTZ)
//         });

//         const data = await res.json();

//         console.log("response data is ", data)
//         console.log("res is  ", res)
//         console.log("is res ok ", res.ok)

//         if (res.ok) {
//             const user = JSON.parse(localStorage.getItem("user"));
//             user.timezone = selectedTZ;

//             localStorage.setItem("user", JSON.stringify(user));

//             document.getElementById("userTimezone").innerText = selectedTZ;

//             showToast(data.message || "Timezone updated successfully", "success");

//             closeTimezoneModal();
//         } else {
//             showToast(data.message || "Failed to update timezone", "Failed");
//         }

//     } catch (err) {
//         console.error(err);

//         showToast("Server error. Try again.", "error");
//     }
// }


async function submitTimezone() {
    const selectedTZ = document.getElementById("timezoneSelect").value;

    try {
        const res = await fetch(`${API_BASE}/api/timezone`, {
            method: "POST",
            headers: {
                "Content-Type": "application/json"
            },
            credentials: "include",
            body: JSON.stringify(selectedTZ)
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

function logout() {
    // document.getElementById("logoutModal").style.display = "block";
    document.getElementById("logoutModal").classList.add("show");
}

// Close popup
function closeLogoutModal() {
    // document.getElementById("logoutModal").style.display = "none";
    document.getElementById("logoutModal").classList.remove("show");
}

// Confirm logout
async function confirmLogout() {
    try {
        const res = await fetch(`${API_BASE}/api/auth/logout`, {
            method: "POST",
            credentials: "include"
        });

        console.log("Logout status:", res.status);

    } catch (err) {
        console.error("Logout error:", err);
    }

    // Clear frontend data
    localStorage.clear();

    // Redirect to login
    window.location.href = "/";
}