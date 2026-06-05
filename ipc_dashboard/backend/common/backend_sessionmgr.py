"""
backend_sessionmgr.py - Session manager matching project standard pattern
"""

import copy
import threading
import secrets
import os
from datetime import datetime, timedelta
from backend_logger import *
from backend_utils import *


_DEFAULT_SESSION_TIMEOUT = timedelta(hours=1)


class SessionManager:
    _instance = None

    def __new__(cls, *args, **kwargs):
        if not cls._instance:
            log_debug("New Instance of SessionManager getting created")
            cls._instance = super(SessionManager, cls).__new__(cls, *args, **kwargs)
        return cls._instance

    def __init__(self):
        log_debug("SessionManager constructor")
        if not hasattr(self, "initialized"):
            log_debug("SessionManager constructor initializing")
            self.initialized      = True
            self.data_lock        = threading.Lock()
            self.session_map      = {}
            self.session_timeout  = _DEFAULT_SESSION_TIMEOUT

    # -- Create session -------------------------------------------------------
    def create_user_session(self, user_uid: str, uprof_record: dict):
        log_debug("Create user session for {}".format(user_uid))

        session_uid     = secrets.token_urlsafe(16)
        expiry_datetime = datetime.utcnow() + self.session_timeout

        session_info = {
            "user_uid":        user_uid,
            "session_uid":     session_uid,
            "expiry_datetime": expiry_datetime,
            "uprof_record":    copy.deepcopy(uprof_record),
        }

        with self.data_lock:
            self.session_map[session_uid] = copy.deepcopy(session_info)

        log_info("Session created for {} session_uid={}".format(user_uid, session_uid))
        return True, session_info

    # -- Validate session -----------------------------------------------------
    def validate_session(self, session_uid: str):
        log_debug("Validate session for session_uid={}".format(session_uid))

        if string_none_or_empty(session_uid):
            log_error("Validate session session_uid not given")
            return False, "session_uid not given"

        with self.data_lock:
            session_info = self.session_map.get(session_uid)

        if not session_info:
            log_warning("Validate session session not found")
            return False, "Session not found"

        expiry_time = session_info["expiry_datetime"]
        if datetime.utcnow() > expiry_time:
            self.delete_user_session(session_uid)
            log_warning("Validate session session expired for {}".format(
                session_info["user_uid"]))
            return False, "Session expired"

        # Extend session on each valid access
        with self.data_lock:
            if session_uid in self.session_map:
                self.session_map[session_uid]["expiry_datetime"] = (
                    datetime.utcnow() + self.session_timeout
                )

        payload = {
            "user_uid": session_info["user_uid"],
            "role":     session_info["uprof_record"].get("role", ""),
            "name":     session_info["uprof_record"].get("name", ""),
        }

        log_debug("Validate session successful for {}".format(session_info["user_uid"]))
        return True, payload

    # -- Delete session -------------------------------------------------------
    def delete_user_session(self, session_uid: str):
        log_debug("Delete user session session_uid={}".format(session_uid))
        with self.data_lock:
            self.session_map.pop(session_uid, None)
        log_info("Session deleted session_uid={}".format(session_uid))

    def delete_user_session_by_user_uid(self, user_uid: str):
        log_debug("Delete all sessions for user_uid={}".format(user_uid))
        with self.data_lock:
            to_delete = [
                sid for sid, info in self.session_map.items()
                if info.get("user_uid") == user_uid
            ]
            for sid in to_delete:
                del self.session_map[sid]
        log_info("Deleted {} sessions for {}".format(len(to_delete), user_uid))

    # -- Get session info -----------------------------------------------------
    def get_session_info(self, session_uid: str):
        log_debug("Get session info for session_uid={}".format(session_uid))
        with self.data_lock:
            session_info = self.session_map.get(session_uid)
        if not session_info:
            return False, "Session not found"
        return True, copy.deepcopy(session_info)

    def get_session_timeout_interval(self):
        return self.session_timeout.total_seconds()

    # -- Cleanup --------------------------------------------------------------
    def cleanup(self):
        log_debug("SessionManager cleanup")
        with self.data_lock:
            self.session_map.clear()
