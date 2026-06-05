import socket
import time, sys
import json
import os
import logging

_FASTAPI_DIR = os.path.dirname(os.path.abspath(__file__))
_COMMON_DIR  = os.path.join(_FASTAPI_DIR, "../common")
_CONFIG_DIR  = os.path.join(_FASTAPI_DIR, "../config")

sys.path.insert(0, _FASTAPI_DIR)
sys.path.insert(1, _COMMON_DIR)
sys.path.insert(2, _CONFIG_DIR)

# ── Windows UTF-8 fix (must be before any logger import) ─────────────────────
if sys.platform == "win32":
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")

from backend_logger import *
from fastapi_backend import *
from fastapi_userauth import *
from fastapi_certdownload import *
from fastapi_ipcupgrade import *
from fastapi_ipcstatus import *
from fastapi_filemanager import *
from fastapi_ipcinstall import *
from fastapi_ipcclean import *
from fastapi_ipclogs import *

if __name__ == "__main__":
    init_logger(module_name="IPCDashboard", folder_name="ipc", log_level=logging.INFO)
    log_info("Starting IPC Dashboard Server")
    log_info("Platform: {}".format(sys.platform))

    fastapi_fe = IpcBackendFastApi(
        be_config_file=os.path.join(_CONFIG_DIR, "backend_ipc_config.json")
    )

    if fastapi_fe is None:
        log_error("FastAPI server creation failed")
        sys.exit()

    status, sts_msg = fastapi_fe.init_backend()
    if status != True:
        log_error("FastAPI backend init failed")
        sys.exit()

    status, sts_msg = fastapi_fe.init_fastapi()
    if status != True:
        log_error("FastAPI init failed")
        sys.exit()

    #fastapi_fe.register_spa_fallback()

    log_info("Server ready at http://localhost:8000")
    fastapi_fe.start()
