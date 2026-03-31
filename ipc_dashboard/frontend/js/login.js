const API_BASE = "";

// Toggle password visibility
document.getElementById("togglePassword").addEventListener("click", () => {
    const passwordInput = document.getElementById("password");
    passwordInput.type = passwordInput.type === "password" ? "text" : "password";
});


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

// Handle login
document.getElementById("loginForm").addEventListener("submit", async (e) => {
    e.preventDefault();

    const username = document.getElementById("username").value;
    const password = document.getElementById("password").value;
    const errorMsg = document.getElementById("errorMsg");

    errorMsg.innerText = "";

    try {
        const response = await fetch(`${API_BASE}/api/auth/login`, {
            method: "POST",
            headers: {
                "Content-Type": "application/json"
            },
            credentials: "include",
            body: JSON.stringify({
                user_uid: username,
                password: password
            })
        });
        // console.log("response data is ", response.data.data);

        const data = await response.json();

        if (data.status === "Success") {
            // console.log("Login Success:", data);

            // Optional: store user info
            localStorage.setItem("user", JSON.stringify(data.data));

            sessionStorage.setItem("loginSuccess", data.message || "Login successful");

            // Redirect to dashboard
            // showToast(data.message || "Login successful", "success");
            
            window.location.href = "/html/dashboard.html";
            
        } else {
            errorMsg.innerText = data.message || "Login failed";
            showToast(data.message || "Failed to login", "error");
        }

    } catch (error) {
        console.error(error);
        errorMsg.innerText = "Server error. Try again.";
        showToast("Server error. Try again.", "error");
    }
});