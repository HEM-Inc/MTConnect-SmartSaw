"""
beapi_ipcmanager.py  –  Unified manager for IPC update / install / clean.
"""

import threading
import time
from beapi_ipcupgrade import *
from beapi_ipcinstall import *
from beapi_ipcclean   import *


class BackendIpcManager:

    def __init__(self):
        log_debug("BackendIpcManager __init__")
        self._ipc_update  = None
        self._ipc_install = None
        self._ipc_clean   = None

    @property
    def ipc_update(self):
        if self._ipc_update is None:
            log_info("Lazy init: BackendIpcUpgrade")
            self._ipc_update = BackendIpcUpgrade()
        return self._ipc_update

    @property
    def ipc_install(self):
        if self._ipc_install is None:
            log_info("Lazy init: BackendIpcInstall")
            self._ipc_install = BackendIpcInstall()
        return self._ipc_install

    @property
    def ipc_clean(self):
        if self._ipc_clean is None:
            log_info("Lazy init: BackendIpcClean")
            self._ipc_clean = BackendIpcClean()
        return self._ipc_clean


    def try_set_running(self, op: str) -> tuple:
        self.config.get_ipc_script_running_lock()
        try:
            if self.ipc_script_running:
                return False, f"Cannot start {op}: another operation is already running"
            self.ipc_script_running = True
            return True, ""
        finally:
            self.config.give_ipc_script_running_lock()

    def clear_running(self):
        self.config.get_ipc_script_running_lock()
        self.ipc_script_running = False
        self.config.give_ipc_script_running_lock()

    def is_script_running(self) -> bool:
        self.config.get_ipc_script_running_lock()
        try:
            return self.ipc_script_running
        finally:
            self.config.give_ipc_script_running_lock()


    def watch_finished(self, finished: dict):
        def _watch():
            while not finished["done"]:
                time.sleep(0.1)
            self.clear_running()
            log_info("BackendIpcManager: script finished, ipc_script_running = False")

        threading.Thread(target=_watch, daemon=True).start()


    def start_update(self, **params):
        ok, err = self.try_set_running("update")
        if not ok:
            return False, err
        try:
            log_info("BackendIpcManager: starting update")
            status, result = self.ipc_update.start_update(
                **params
            )
            if not status:
                self.clear_running()
                return False, result
            buffer, finished = result
            self.watch_finished(finished)
            return True, (buffer, finished)
        except Exception as e:
            log_error(f"BackendIpcManager start_update exception: {e}")
            self.clear_running()
            return False, str(e)

    def start_install(self, **params) -> tuple:
        ok, err = self.try_set_running("install")
        if not ok:
            return False, err
        try:
            log_info("BackendIpcManager: starting install")
            status, result = self.ipc_install.start_install(
                **params
            )
            if not status:
                self.clear_running()
                return False, result
            buffer, finished = result
            self.watch_finished(finished)
            return True, (buffer, finished)
        except Exception as e:
            log_error(f"BackendIpcManager start_install exception: {e}")
            self.clear_running()
            return False, str(e)

    def start_clean(self, **params) -> tuple:
        ok, err = self.try_set_running("clean")
        if not ok:
            return False, err
        try:
            log_info("BackendIpcManager: starting clean")
            status, result = self.ipc_clean.start_clean(
                **params
            )
            if not status:
                self.clear_running()
                return False, result
            buffer, finished = result
            self.watch_finished(finished)
            return True, (buffer, finished)
        except Exception as e:
            log_error(f"BackendIpcManager start_clean exception: {e}")
            self.clear_running()
            return False, str(e)
