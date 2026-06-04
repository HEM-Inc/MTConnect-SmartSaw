import { apiValidateSession, confirmLogout } from "../core/auth.js";
import { showToast } from "../core/toast.js";
import {
  openTimezoneModal,
  closeTimezoneModal,
  submitTimezone,
} from "../pages/timezone.js";

async function loadComponent(id, file) {
  const res = await fetch(file);
  const html = await res.text();
  document.getElementById(id).innerHTML = html;
}

function initLogout() {
  document.addEventListener("click", (e) => {
    const sidebarLogout = e.target.closest(".logout-btn");
    const topbarLogout = e.target.closest(".dropdown-item.logout");
    const yesBtn = e.target.closest(".logout-yes");
    const noBtn = e.target.closest(".logout-no");

    // OPEN MODAL (from sidebar or topbar)
    if (sidebarLogout || topbarLogout) {
      document.getElementById("logoutModal")?.classList.add("show");
    }

    // CONFIRM
    if (yesBtn) {
      confirmLogout();
    }

    // CLOSE
    if (noBtn) {
      document.getElementById("logoutModal")?.classList.remove("show");
    }
  });
}

export const loadLayout = async (activeTab) => {
  await loadComponent("sidebarContainer", "/html/components/sidebar.html");
  await loadComponent("topbarContainer", "/html/components/topbar.html");
  await loadComponent(
    "logoutModalContainer",
    "/html/components/logoutModal.html",
  );
  await loadComponent(
    "timezoneModalContainer",
    "/html/components/timezoneModal.html",
  );

  const sidebar = document.querySelector(".sidebar");
  const toggleBtn = document.getElementById("toggleSidebar");
  const icon = document.getElementById("toggleIcon");
  const mobileBtn = document.getElementById("mobileMenuBtn");
  const overlay = document.getElementById("sidebarOverlay");

  if (mobileBtn) {
    mobileBtn.addEventListener("click", () => {
      sidebar.classList.add("mobile-open");
      overlay?.classList.add("show");
    });
  }

  if (overlay) {
    overlay.addEventListener("click", () => {
      sidebar.classList.remove("mobile-open");
      overlay.classList.remove("show");
    });
  }

  const closeBtn = document.getElementById("mobileCloseBtn");

  if (closeBtn) {
    closeBtn.addEventListener("click", () => {
      sidebar.classList.remove("mobile-open");
      overlay?.classList.remove("show");
    });
  }

  initTopbar();

  initLogout();

  if (activeTab) {
    const el = document.getElementById(activeTab);
    if (el) el.classList.add("active");
  }

  if (toggleBtn) {
    toggleBtn.addEventListener("click", () => {
      sidebar.classList.toggle("collapsed");
      icon.innerHTML = sidebar.classList.contains("collapsed") ? ">" : "<";
    });
  }

  try {
    const data = await apiValidateSession();
    console.log("Session valid:", data);
  } catch (err) {
    console.error("Validate session error:", err);
    showToast("Session expired please login again", "error");
  }
};

export const convertToUserTimezone = (dateStr, timezone) => {
  try {
    return moment(dateStr).tz(timezone).format("MMM D, YYYY, hh:mm:ss A");
  } catch (err) {
    console.error("Moment timezone error:", err);
    return dateStr;
  }
};

function initTopbar() {
  const profile = document.getElementById("profileMenu");
  const dropdown = document.getElementById("profileDropdown");

  if (!profile || !dropdown) return;

  profile.addEventListener("click", (e) => {
    dropdown.classList.toggle("show");
  });

  // close when clicking outside
  document.addEventListener("click", (e) => {
    if (!profile.contains(e.target)) {
      dropdown.classList.remove("show");
    }
  });
}

export function loadUpdateTimezoneBtn() {
  document
    .querySelectorAll(".update-timezone-btn")
    .forEach((btn) => btn.addEventListener("click", openTimezoneModal));

  const closeTimezoneBtn = document.getElementById("closeTimezoneModalBtn");

  const submitTimezoneBtn = document.getElementById("btnSubmitTimezone");

  if (closeTimezoneBtn) {
    closeTimezoneBtn.addEventListener("click", closeTimezoneModal);
  }

  if (submitTimezoneBtn) {
    submitTimezoneBtn.addEventListener("click", submitTimezone);
  }
}
