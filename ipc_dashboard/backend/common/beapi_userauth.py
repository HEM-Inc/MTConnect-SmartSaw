"""
beapi_userauth.py - User authentication and profile business logic
"""

import os, copy, bcrypt
from dotenv import load_dotenv
from backend_logger import *
from backend_config import *


class BackendUserAuthApi:

    def _hash_password(self, password: str) -> str:
        """Hash password using bcrypt"""
        password_bytes = password.encode('utf-8')
        salt = bcrypt.gensalt()
        hashed = bcrypt.hashpw(password_bytes, salt)
        return hashed.decode('utf-8')

    def _verify_password(self, plain_password: str, hashed_password: str) -> bool:
        """Verify password against hash"""
        try:
            password_bytes = plain_password.encode('utf-8')
            hashed_bytes = hashed_password.encode('utf-8')
            return bcrypt.checkpw(password_bytes, hashed_bytes)
        except Exception as e:
            log_error(f"Password verification error: {e}")
            return False

    def _get_user(self, user_uid: str) -> dict:
        """Get user credentials from .env"""
        load_dotenv(self.env_file)

        password_key = f"{user_uid.upper()}_PASSWORD"
        password_hash = os.getenv(password_key)

        if not password_hash:
            return None

        return {
            "user_uid": user_uid,
            "password_hash": password_hash,
        }

    def authenticate_user(self, username: str, password: str):
        """
        Authenticate user with bcrypt password verification

        Args:
            username: Username
            password: Password (plain text)

        Returns:
            Tuple of (success: bool, result: dict or error_message: str)
        """
        log_debug(f"Authenticating user: {username}")

        # Get user from .env
        user = self._get_user(username)

        if not user:
            log_warning(f"Login attempt for non-existent user: {username}")
            return False, "Invalid username or password"

        # Verify password
        if not self._verify_password(password, user["password_hash"]):
            log_warning(f"Invalid password for user: {username}")
            return False, "Invalid username or password"

        # Return user info (without password hash)
        result = {
            "user_uid": user["user_uid"],
        }

        log_info(f"User {username} authenticated successfully")
        return True, result

    '''
    def validate_user_login(self, user_uid: str, password: str):
        """
        Validates credentials against environment variables.
        Returns (True, profile_record) or (False, error_msg)

        ENV vars:
            ADMIN_USERNAME, ADMIN_PASSWORD  -> role = admin
            USER_USERNAME,  USER_PASSWORD   -> role = user
        """
        log_debug("Backend validate user login for {}".format(user_uid))

        admin_user = os.getenv("ADMIN_USERNAME", "admin")
        admin_pass = os.getenv("ADMIN_PASSWORD", "admin123")
        user_user  = os.getenv("USER_USERNAME",  "certuser")
        user_pass  = os.getenv("USER_PASSWORD",  "cert123")

        status, sts_msg = self.get_ipc_timezone()
        if status != True:
            log_error("Backend validate user login, get ipc timezone failed")
            return False, sts_msg

        if user_uid == admin_user and password == admin_pass:
            log_info("Admin login successful: {}".format(user_uid))
            return True, {
                "user_uid": user_uid,
                "role":     "admin",
                "name":     "Administrator",
                "timezone" : sts_msg,
            }

        if user_uid == user_user and password == user_pass:
            log_info("User login successful: {}".format(user_uid))
            return True, {
                "user_uid": user_uid,
                "role":     "user",
                "name":     "Certificate User",
                "timezone" : sts_msg
            }

        log_warning("Failed login attempt for: {}".format(user_uid))
        return False, "Invalid login or password"
    '''
    def validate_user_login(self, user_uid: str, password: str):
        log_debug(f"Backend validate user login for {user_uid}")

        # Get timezone first
        status, sts_msg = self.get_ipc_timezone()
        if status != True:
            log_error("Backend validate user login, get ipc timezone failed")
            return False, sts_msg

        # Authenticate using bcrypt-based method
        auth_status, auth_result = self.authenticate_user(user_uid, password)

        if not auth_status:
            log_warning(f"Failed login attempt for: {user_uid}")
            return False, auth_result

        # Assign role based on username
        admin_user = os.getenv("ADMIN_USERNAME", "admin")
        user_user  = os.getenv("USER_USERNAME", "certuser")

        role = "user"
        name = "User"

        if user_uid == admin_user:
            role = "admin"
            name = "Administrator"
        elif user_uid == user_user:
            role = "user"
            name = "Certificate User"

        # Final response
        return True, {
            "user_uid": user_uid,
            "role": role,
            "name": name,
            "timezone": sts_msg
        }
    def get_user_profile_info(self, user_uid: str):
        """
        Returns basic profile info for the /me endpoint.
        Extend this when DB-backed profiles are added.
        """
        log_debug("Backend get user profile info for {}".format(user_uid))

        admin_user = os.getenv("ADMIN_USERNAME", "admin")
        user_user  = os.getenv("USER_USERNAME",  "certuser")

        if user_uid == admin_user:
            return True, {
                "user_uid": user_uid,
                "role":     "admin",
                "name":     "Administrator",
            }

        if user_uid == user_user:
            return True, {
                "user_uid": user_uid,
                "role":     "user",
                "name":     "Certificate User",
            }

        log_error("User profile not found for {}".format(user_uid))
        return False, "User profile not found"

    def get_timezone_filter(self):
        log_debug("BE Api Get timezones")

        fields_filter = {
            "Africa/Cairo": "Africa/Cairo",
            "Africa/Johannesburg": "Africa/Johannesburg",
            "Africa/Lagos": "Africa/Lagos",
            "Africa/Nairobi": "Africa/Nairobi",
            "America/Argentina/Buenos_Aires": "America/Argentina/Buenos_Aires",
            "America/Argentina/Cordoba": "America/Argentina/Cordoba",
            "America/Mexico_City": "America/Mexico_City",
            "America/Sao_Paulo": "America/Sao_Paulo",
            "US/Alaska (America/Anchorage)": "America/Anchorage",
            "US/Pacific (America/Los_Angeles)": "America/Los_Angeles",
            "US/Mountain (America/Denver)": "America/Denver",
            "US/Central (America/Chicago)": "America/Chicago",
            "US/Eastern (America/New_York)": "America/New_York",
            "Asia/Amman": "Asia/Amman",
            "Asia/Baghdad": "Asia/Baghdad",
            "Asia/Bangkok": "Asia/Bangkok",
            "Asia/Beirut": "Asia/Beirut",
            "Asia/China": "Asia/China",
            "Asia/Dubai": "Asia/Dubai",
            "Asia/Hong_Kong": "Asia/Hong_Kong",
            "Asia/Jakarta": "Asia/Jakarta",
            "Asia/Kolkata": "Asia/Kolkata",
            "Asia/Kuala_Lumpur": "Asia/Kuala_Lumpur",
            "Asia/Manila": "Asia/Manila",
            "Asia/Singapore": "Asia/Singapore",
            "Asia/Tokyo": "Asia/Tokyo",
            "Australia/Sydney": "Australia/Sydney",
            "Europe/Amsterdam": "Europe/Amsterdam",
            "Europe/Berlin": "Europe/Berlin",
            "Europe/Brussels": "Europe/Brussels",
            "Europe/Lisbon": "Europe/Lisbon",
            "Europe/London": "Europe/London",
            "Europe/Madrid": "Europe/Madrid",
            "Europe/Paris": "Europe/Paris",
            "Europe/Rome": "Europe/Rome",
            "Europe/Stockholm": "Europe/Stockholm",
            "Europe/Vienna": "Europe/Vienna",
            "Pacific/Auckland": "Pacific/Auckland",
            "Pacific/Fiji": "Pacific/Fiji",
            "Pacific/Tarawa": "Pacific/Tarawa",
            "Pacific/Tongatapu": "Pacific/Tongatapu",
        }

        return True, fields_filter

    def get_ipc_timezone(self):
        log_debug("Backend get ipc timezone")

        config = copy.deepcopy(self.config.backend_json_config)

        timezone = config['timezone']

        if string_none_or_empty(timezone):
            log_error("Backend get ipc timezone empty")
            return False, "Timezone empty"

        return True, timezone

    def update_ipc_timezone(self, timezone: str):
        log_debug(f"Updating timezone to: {timezone}")

        if not timezone or not isinstance(timezone, str):
            log_error("Invalid timezone value provided")
            return False, "Invalid timezone value"

        status, timezones = self.get_timezone_filter()

        if timezone not in timezones.values():
            log_error(f"Timezone '{timezone}' not supported")
            return False, f"Invalid timezone '{timezone}'"

        config_file = self.config.config_file_path

        try:
            with open(config_file, "r") as f:
                config_data = json.load(f)
        except Exception as e:
            log_error(f"Failed to read config file: {e}")
            return False, f"Failed to read config file: {e}"

        old_timezone = config_data.get("timezone", "UTC")

        if old_timezone == timezone:
            log_info("Timezone unchanged")
            return True, timezone

        config_data["timezone"] = timezone

        temp_file = config_file + ".tmp"

        try:
            with open(temp_file, "w") as f:
                json.dump(config_data, f, indent=4)

            os.replace(temp_file, config_file)  # atomic replace
        except Exception as e:
            log_error(f"Failed to write config file: {e}")
            return False, f"Failed to write config file: {e}"

        # ── Update in-memory config ────────────────────────────────
        self.config.backend_json_config["timezone"] = timezone

        log_info(f"Timezone updated: {old_timezone} → {timezone}")

        return True, "Success"

