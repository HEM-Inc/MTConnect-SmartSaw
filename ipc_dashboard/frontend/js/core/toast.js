export function showToast(message, type = "info", duration = 3000) {
  let container = document.getElementById("toastContainer");

  if (!container) {
    container = document.createElement("div");
    container.id = "toastContainer";
    container.className = "toast-container";
    document.body.appendChild(container);
  }

  const toast = document.createElement("div");
  toast.className = `toast ${type}`;
  toast.textContent = message;

  container.appendChild(toast);

  // auto remove
  setTimeout(() => {
    toast.classList.add("hide");

    setTimeout(() => toast.remove(), 300);
  }, duration);
}
