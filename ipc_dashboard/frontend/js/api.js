const API_BASE = "";

// LOGIN API
async function apiLogin(user_uid, password) {
    const response = await fetch(`${API_BASE}/api/auth/login`, {
        method: "POST",
        headers: {
            "Content-Type": "application/json"
        },
        credentials: "include", // 🔥 IMPORTANT (for cookies)
        body: JSON.stringify({
            user_uid: user_uid,
            password: password
        })
    });

    return response.json();
}

// VALIDATE SESSION
async function apiValidateSession() {
    const response = await fetch(`${API_BASE}/api/auth/me`, {
        method: "GET",
        credentials: "include"
    });

    return response.json();
}
