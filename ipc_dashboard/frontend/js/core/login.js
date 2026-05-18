import { API_BASE } from "../../utils.js";

/* --------------------------------------------------
   PAGE INIT
-------------------------------------------------- */
document.addEventListener("DOMContentLoaded", () => {
  initLoginPage();
});

/* --------------------------------------------------
   LOGIN PAGE ONLY
-------------------------------------------------- */

function initLoginPage() {
  const toggleBtn = document.getElementById("togglePassword");
  const loginForm = document.getElementById("loginForm");

  // If not login page, safely stop
  if (!toggleBtn || !loginForm) return;

  /* Toggle password */
  toggleBtn.addEventListener("click", () => {
    const passwordInput = document.getElementById("password");
    if (!passwordInput) return;

    const eyeIcon = toggleBtn.querySelector("i");

    if (passwordInput.type === "password") {
      passwordInput.type = "text";
      eyeIcon?.classList.remove("fa-eye");
      eyeIcon?.classList.add("fa-eye-slash");
    } else {
      passwordInput.type = "password";
      eyeIcon?.classList.remove("fa-eye-slash");
      eyeIcon?.classList.add("fa-eye");
    }
  });

  /* Handle login submit */
  loginForm.addEventListener("submit", async (e) => {
    e.preventDefault();

    const username = document.getElementById("username")?.value?.trim();
    const password = document.getElementById("password")?.value;
    const errorMsg = document.getElementById("errorMsg");

    if (errorMsg) errorMsg.innerText = "";

    try {
      const response = await fetch(`${API_BASE}/api/auth/login`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        credentials: "include",
        body: JSON.stringify({
          user_uid: username,
          password: password,
        }),
      });

      const data = await response.json();

      if (data.status === "Success") {
        localStorage.setItem("user", JSON.stringify(data.data));

        sessionStorage.setItem(
          "loginSuccess",
          data.message || "Login successful",
        );

        window.location.href = "/html/security.html";
      } else {
        if (errorMsg) {
          errorMsg.innerText = data.message || "Login failed";
        }

        showToast(data.message || "Failed to login", "error");
      }
    } catch (error) {
      console.error("Login Error:", error);

      if (errorMsg) {
        errorMsg.innerText = "Server error. Try again.";
      }

      showToast("Server error. Try again.", "error");
    }
  });
}

/* --------------------------------------------------
   TOAST
-------------------------------------------------- */
function showToast(message, type = "success") {
  const container = document.getElementById("toastContainer");

  if (!container) return;

  const toast = document.createElement("div");
  toast.className = `toast ${type}`;
  toast.innerText = message;

  container.appendChild(toast);

  setTimeout(() => {
    toast.remove();
  }, 3000);
}

/* --------------------------------------------------
   SHARED FUNCTION
-------------------------------------------------- */
export async function loadUserInfo() {
  const user = JSON.parse(localStorage.getItem("user"));

  if (!user) return;

  const userName = document.getElementById("userName");
  const timezone = document.getElementById("userTimezoneText");
  const controlTab = document.getElementById("controlTab");
  const deviceTab = document.getElementById("deviceTab");

  if (userName) {
    userName.innerText = user.name || user.user_uid;
  }

  if (timezone) {
    timezone.innerText = user.timezone || "UTC";
  }

  const role = (user.role || "").toLowerCase();

  if (role !== "admin") {
    if (controlTab) controlTab.style.display = "none";
    if (deviceTab) deviceTab.style.display = "none";
  }

  window.addEventListener("timezoneChanged", (e) => {
    if (timezone && e.detail?.timezone) {
      timezone.innerText = e.detail.timezone;
    }
  });
}
