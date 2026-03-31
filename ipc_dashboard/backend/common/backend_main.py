import socket
import time, sys
import json
import os
import logging
from _thread import *

_COMMON_DIR = os.path.dirname(os.path.abspath(__file__))
_CONFIG_DIR = os.path.join(_COMMON_DIR, "../config")

sys.path.insert(0, _COMMON_DIR)
sys.path.insert(1, _CONFIG_DIR)

# -- Windows UTF-8 fix (before any imports that log) -------------------------
if sys.platform == "win32":
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")

from backend_utils import *
from backend_config import *
from backend_api import *
from backend_logger import *


class Backend:
    def __init__(self,
                 be_config_file="../config/backend_ipc_config.json",
                ):
        log_info("Backend init ...")
        self.be_config_file = be_config_file
        self.be_api         = None

    def cleanup(self):
        log_debug("Cleaning up backend ...")
        time.sleep(2)
        self.be_api = None

    def initialize(self):
        log_debug("Starting Backend ....")

        self.be_api = BackendApi()

        status, sts_msg = self.be_api.config_load_and_init(
            be_config_file=self.be_config_file,
        )
        if status != True:
            log_error("Backend config load and init Failed")
            return False, "Failed"

        log_info("Backend initialized successfully")
        return True, "Backend Inited"

    def start(self):
        log_debug("Starting backend main loop")
        try:
            while True:
                time.sleep(10)
        except KeyboardInterrupt:
            log_info("Backend shutting down ...")
            self.cleanup()

        return True, "Success"


if __name__ == "__main__":
    init_logger(
        module_name="Backend",
        folder_name="backend",
        log_level=logging.INFO
    )

    log_info("Starting Backend Server")
    log_info("Platform: {}".format(sys.platform))

    backend = Backend(
        be_config_file=os.path.join(_CONFIG_DIR, "backend_ipc_config.json")
    )

    status, sts_msg = backend.initialize()
    if status != True:
        log_error("Backend initialization failed: {}".format(sts_msg))
        sys.exit()

    status, sts_msg = backend.start()
    if status != True:
        log_error("Backend start failed: {}".format(sts_msg))
        sys.exit()