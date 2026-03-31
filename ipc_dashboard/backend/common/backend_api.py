"""
backend_api.py - Core BackendApi class (business logic layer)
"""

import os
import copy
from dotenv import load_dotenv, set_key
from backend_utils import *
from backend_config import *
from backend_logger import *
from beapi_certdownload import *
from beapi_userauth import * 


class BackendApi(BackendCertDownloadApi,
                 BackendUserAuthApi,
                 BackendConfig
                 ):

    _instance = None

    def __new__(cls, *args, **kwargs):
        if not cls._instance:
            log_debug("New Instance of Backend API getting created")
            cls._instance = super(BackendApi, cls).__new__(cls, *args, **kwargs)
        return cls._instance

    def __init__(self):
        log_debug("Backend API constructor")
        if not hasattr(self, 'initialized'):
            log_debug("Backend API constructor initializing")
            self.initialized      = True
            self.config           = None
            self.config_init_done = False
            self.env_file         = None

    def cleanup(self):
        log_debug("Backend Api cleanup")

    def config_initialised(self):
        return self.config_init_done

    def get_fastapi_config(self):
        if self.config_init_done == False:
            return False, "Config not inited"
        return self.config.get_fastapi_config()

    def config_load_and_init(self, be_config_file="../config/backend_ipc_config.json"):
        log_debug("Backend config init in progress")
        config = BackendConfig()
        status, sts_msg = config.config_load_and_init(be_config_file=be_config_file)
        if status != True:
            log_msg = "Backend config load and init failed"
            log_error(log_msg)
            return False, log_msg
        self.config           = config
        self.config_init_done = True

        # Initialize .env file for user credentials
        self._init_env_file()

        log_debug("Backend Config read and initialization done")
        return True, "Config load and init Successful"

    def _init_env_file(self):
        """Initialize .env file path"""

        # Go from ipc_config/backend/common → ipc_config
        base_dir = os.path.abspath(
            os.path.join(os.path.dirname(__file__), "..", "..")
        )

        # सीधे ipc_config/.env
        self.env_file = os.path.join(base_dir, ".env")

        log_info(f"User credentials file: {self.env_file}")

        # Load if exists
        if os.path.isfile(self.env_file):
            load_dotenv(self.env_file)
            log_info("Loaded existing user credentials")
        else:
            log_info(".env file not found, will be created")

        # Initialize users
        self._initialize_default_users()

    def _initialize_default_users(self):
        """Create default admin and user accounts if they don't exist"""
        log_info("Checking for default user accounts...")

        # Check and create admin
        if not self._user_exists("admin"):
            log_info("Creating default admin account...")
            self._create_user(
                user_uid="admin",
                password="admin123",
            )
        else:
            log_info("Admin account exists")

        # Check and create user
        if not self._user_exists("user"):
            log_info("Creating default user account...")
            self._create_user(
                user_uid="user",
                password="user123",
            )
        else:
            log_info("User account exists")

        log_info("User initialization complete")

    def _user_exists(self, user_uid: str) -> bool:
        """Check if user exists in .env"""
        #load_dotenv(self.env_file)
        password_key = f"{user_uid.upper()}_PASSWORD"
        return os.getenv(password_key) is not None

    def _create_user(self, user_uid: str, password: str):
        """Create user in .env file with hashed password"""

        if not os.path.isfile(self.env_file):
            with open(self.env_file, 'w') as f:
                f.write("# IPC Dashboard User Credentials\n")
                f.write("# Passwords are bcrypt hashed\n\n")

        password_hash = self._hash_password(password)

        # Store both username + password
        set_key(self.env_file, f"{user_uid.upper()}_USERNAME", user_uid)
        set_key(self.env_file, f"{user_uid.upper()}_PASSWORD", password_hash)

        log_info(f"User created: {user_uid}")
