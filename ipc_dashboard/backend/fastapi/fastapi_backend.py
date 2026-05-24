import os
import sys
import time
import asyncio
import traceback
from concurrent.futures import ThreadPoolExecutor
from functools import partial

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
import uvicorn

# ── path setup so common/ is importable ──────────────────────────────────────
_FASTAPI_DIR = os.path.dirname(__file__)
_COMMON_DIR  = os.path.join(_FASTAPI_DIR, "../common")
sys.path.insert(0, _FASTAPI_DIR)
sys.path.insert(1, _COMMON_DIR)

from backend_utils import *
from backend_api import BackendApi
from backend_sessionmgr import SessionManager

# ── Single FastAPI app instance ───────────────────────────────────────────────
ipc_fast_api = FastAPI(title="IPC Dashboard API", version="1.0.0")


def get_be_fastapi_obj() -> "IpcBackendFastApi":
    return IpcBackendFastApi.get_instance()


class IpcBackendFastApi:
    _instance = None

    def __new__(cls, *args, **kwargs):
        if not cls._instance:
            log_debug("Creating IpcBackendFastApi instance")
            cls._instance = super().__new__(cls)
        return cls._instance

    def __init__(self, be_config_file: str = None):
        if not hasattr(self, "initialized"):
            self.initialized       = True
            self.api:  BackendApi  = None
            self.smgr: SessionManager = None
            self.fapi_config       = None
            self.be_init_done      = False
            self.fastapi_init_done = False
            self.async_worker_pool = None
            self._be_config_file   = be_config_file or os.path.join(
                _FASTAPI_DIR, "../config/backend_ipc_config.json"
            )

    @staticmethod
    def get_instance() -> "IpcBackendFastApi":
        return IpcBackendFastApi._instance

    # ── Async thread-pool helper ──────────────────────────────────────────────
    async def thread_pool_exec(self, function_name, params):
        befa = get_be_fastapi_obj()
        loop = asyncio.get_running_loop()
        try:
            partial_function = partial(function_name, **params)
            status, result = await loop.run_in_executor(
                                      self.async_worker_pool,
                                      partial_function)
            #log_debug("Status {} result: {}".format(status, result))
            return status, result
        except Exception as e:
            stack_trace = traceback.format_exc()

            log_error("Fast Api Thread pool exec Exception")
            log_error("Function: {}".format(function_name))
            log_error("Params  : {}".format(params))
            log_error("Exception is: {}".format(e))
            log_error("Stack trace is: {}".format(stack_trace))
            return False, "Thread pool Exception"

        return False, "Unknown Error"

    # ── Backend init ──────────────────────────────────────────────────────────
    def init_backend(self):
        if self.be_init_done:
            return True, "Already done"

        log_info("Initialising backend …")
        self.api  = BackendApi()
        self.smgr = SessionManager()

        status, msg = self.api.config_load_and_init(
            be_config_file=self._be_config_file
        )
        if not status:
            log_error(f"Backend config init failed: {msg}")
            return False, msg

        self.be_init_done = True
        log_info("Backend init successful")
        return True, "Backend init done"

    # ── FastAPI init ──────────────────────────────────────────────────────────
    def init_fastapi(self):
        if self.fastapi_init_done:
            return True, "Already done"

        log_info("Initialising FastAPI …")
        self.async_worker_pool = ThreadPoolExecutor(max_workers=8)

        status, cfg = self.api.get_fastapi_config()
        if not status:
            return False, "Could not read fastapi config"
        self.fapi_config = cfg

        origins = ["http://localhost:3000", "http://localhost:8000"]
        for d in cfg.get("domain_names", []):
            origins.append(d)

        ipc_fast_api.add_middleware(
            CORSMiddleware,
            allow_origins=origins,
            allow_credentials=True,
            allow_methods=["*"],
            allow_headers=["*"],
        )

        @ipc_fast_api.middleware("http")
        async def add_security_headers(request, call_next):
            response = await call_next(request)
            response.headers["X-Content-Type-Options"] = "nosniff"
            response.headers["X-Frame-Options"] = "DENY"
            response.headers["Content-Security-Policy"] = (
                "default-src 'self'; script-src 'self'; style-src 'self'; "
                "connect-src 'self'; img-src 'self'; font-src 'self';"
            )
            return response

        # ── Serve vanilla JS frontend ──────────────
        frontend_dir = os.path.join(_FASTAPI_DIR, "../../frontend")
        if os.path.isdir(frontend_dir):
            ipc_fast_api.mount(
                "/",
                StaticFiles(directory=frontend_dir, html=True),
                name="frontend"
            )
            log_info(f"Serving frontend")

            @ipc_fast_api.get("/", include_in_schema=False)
            async def root():
                return FileResponse(os.path.join(frontend_dir, "index.html"))
        else:
            log_warning(f"Frontend directory not found at {frontend_dir}")

        self.fastapi_init_done = True
        log_info("FastAPI init successful")
        return True, "FastAPI init done"

    # ── Start uvicorn ─────────────────────────────────────────────────────────
    def start(self):
        log_info("Starting uvicorn …")
        sec  = self.fapi_config.get("security", {"enable": "No"})
        host = self.fapi_config.get("host", "0.0.0.0")
        port = int(self.fapi_config.get("port", 8000))

        kwargs = dict(host=host, port=port, log_level="info")
        if sec.get("enable") == "Yes":
            kwargs["ssl_keyfile"]  = sec["key_file"]
            kwargs["ssl_certfile"] = sec["cert_file"]

        uvicorn.run(ipc_fast_api, **kwargs)
