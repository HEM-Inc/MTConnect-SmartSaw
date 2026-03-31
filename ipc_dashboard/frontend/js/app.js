// LOGIN FUNCTION
async function login() {

    const user_uid = document.getElementById("user_uid").value;
    const password = document.getElementById("password").value;

    const result = await apiLogin(user_uid, password);

    if (result.status === "Success") {
        // ✅ Redirect to dashboard
        window.location.href = "/dashboard";
    } else {
        document.getElementById("error-msg").innerText = result.message;
    }
}

// AUTO SESSION CHECK (on page load)
window.onload = async function () {

    try {
        const result = await apiValidateSession();

        if (result.status === "Success") {
            // Already logged in → go to dashboard
            window.location.href = "/dashboard";
        }

    } catch (e) {
        console.log("No active session");
    }
};
