import os
import time
import mimetypes
import threading

from datetime import datetime, timedelta, timezone

from backend_logger import *
from backend_utils import *


class BackendFileManager:

    def __init__(self):

        self.lock = threading.Lock()

        # path -> {user, expires_at}
        self.file_locks = {}

        self.lock_timeout = 300

        threading.Thread(
            target=self.cleanup_expired_locks,
            daemon=True
        ).start()

    # ------------------------------------------------------------------
    # File-lock management
    # ------------------------------------------------------------------

    def acquire_lock(self, path, user):
        if string_none_or_empty(path):
            return False, "Path not provided"
        if string_none_or_empty(user):
            return False, "User not provided"

        with self.lock:
            lock = self.file_locks.get(path)

            if lock and datetime.utcnow() > lock["expires_at"]:
                self.file_locks.pop(path)
                lock = None

            if not lock:
                self.file_locks[path] = {
                    "user"      : user,
                    "expires_at": datetime.utcnow() + timedelta(seconds=self.lock_timeout)
                }
                return True, None

            if lock["user"] == user:
                lock["expires_at"] = datetime.utcnow() + timedelta(seconds=self.lock_timeout)
                return True, None

            return False, f"Locked by {lock['user']}"

    def release_lock(self, path, user):
        if string_none_or_empty(path):
            return False, "Path not provided"
        if string_none_or_empty(user):
            return False, "User not provided"

        with self.lock:
            lock = self.file_locks.get(path)
            if lock and lock["user"] == user:
                self.file_locks.pop(path)
                return True
            return False

    def acquire_file_lock(self, params):
        if not isinstance(params, dict):
            return False, "Invalid params instance"

        path, err = self.resolve_path(params.get("path"))
        if err:
            return False, err

        success, msg = self.acquire_lock(path, params.get("user"))
        if not success:
            return False, msg
        return True, "Lock acquired"

    def refresh_lock(self, params):
        if not isinstance(params, dict):
            return False, "Invalid params instance"

        path, err = self.resolve_path(params.get("path"))
        if err:
            return False, err

        user = params.get("user")

        with self.lock:
            lock = self.file_locks.get(path)
            if not lock:
                return False, "No lock found"
            if lock["user"] != user:
                return False, "Not your lock"
            lock["expires_at"] = datetime.utcnow() + timedelta(seconds=self.lock_timeout)

        return True, "Lock refreshed"

    def get_lock_status(self, params):
        if not isinstance(params, dict):
            return False, "Invalid params instance"

        path, err = self.resolve_path(params.get("path"))
        if err:
            return False, err

        with self.lock:
            lock = self.file_locks.get(path)
            if not lock or datetime.utcnow() > lock["expires_at"]:
                return True, {"locked": False}
            return True, {"locked": True, "user": lock["user"]}

    def release_file(self, params):
        if not isinstance(params, dict):
            return False, "Invalid params instance"

        path, err = self.resolve_path(params.get("path"))
        if err:
            return False, err

        if self.release_lock(path, params.get("user")):
            return True, "Lock released"
        return False, "Not lock owner"

    def cleanup_expired_locks(self):
        while True:
            time.sleep(30)
            with self.lock:
                expired = [
                    p for p, l in self.file_locks.items()
                    if datetime.utcnow() > l["expires_at"]
                ]
                for p in expired:
                    self.file_locks.pop(p)

    # ------------------------------------------------------------------
    # Path resolution
    # ------------------------------------------------------------------

    def resolve_path(self, relative_path):
        if string_none_or_empty(relative_path):
            return False, "relative path not provided"

        root_path = os.path.abspath("../../../")
        parts     = relative_path.strip("/").split("/", 1)
        comp      = parts[0]
        sub       = parts[1] if len(parts) > 1 else ""

        component_base = os.path.join(root_path, comp)

        if not os.path.isdir(component_base):
            return None, "Invalid component"

        full = os.path.normpath(os.path.join(component_base, sub))

        if not full.startswith(component_base):
            return None, "Invalid path traversal"

        return full, None

    # ------------------------------------------------------------------
    # File structure / content / save / upload
    # ------------------------------------------------------------------

    def get_file_structure(self, params=None):
        if params is not None and not isinstance(params, list):
            return False, "Invalid params instance"

        try:
            valid_components = ["adapter", "agent", "devctl", "mongodb", "mqtt", "ods"]

            if params is not None:
                components = []
                for param in params:
                    comp = param.lower()
                    if comp not in valid_components:
                        log_error(f"get_file_structure: invalid component '{comp}'")
                        continue
                    if comp not in components:
                        components.append(comp)
            else:
                components = valid_components

            BASE_PATH           = "../../../"
            IGNORE              = {".git", "__pycache__"}
            ALLOWED_ROOT_FOLDERS = {"config", "data"}

            def build(path, is_root=False):
                tree = {}
                try:
                    entries = os.listdir(path)
                except PermissionError:
                    return tree

                for entry in entries:
                    if entry in IGNORE:
                        continue
                    if is_root and entry not in ALLOWED_ROOT_FOLDERS:
                        continue

                    full_path = os.path.join(path, entry)

                    if os.path.isdir(full_path):
                        tree[entry] = {
                            "type"    : "folder",
                            "children": build(full_path, False)
                        }
                    else:
                        tree[entry] = {"type": "file"}

                return tree

            result = {}
            for comp in components:
                base_path = os.path.normpath(os.path.join(BASE_PATH, comp))
                result[comp] = {
                    "type"    : "folder",
                    "children": build(base_path, is_root=True) if os.path.exists(base_path) else {}
                }

            return True, result

        except Exception as e:
            log_error(f"get_file_structure error: {e}")
            return False, str(e)

    def get_file_content(self, file_path):
        if string_none_or_empty(file_path):
            return False, "file path not provided"

        try:
            path, err = self.resolve_path(file_path)
            if err:
                return False, err

            if not os.path.isfile(path):
                return False, "File not found"

            with open(path, "r", encoding="utf-8") as f:
                content = f.read()

            stat = os.stat(path)

            mime_type, _ = mimetypes.guess_type(path)
            if mime_type:
                file_type = mime_type.split("/")[-1]
            else:
                file_type = os.path.splitext(path)[1].lstrip(".").lower() or "text"

            last_modified = datetime.fromtimestamp(
                stat.st_mtime, tz=timezone.utc
            ).isoformat()

            return True, {
                "file_name"    : os.path.basename(path),
                "content"      : content,
                "size"         : stat.st_size,
                "last_modified": last_modified,
                "file_type"    : file_type
            }

        except Exception as e:
            log_error(f"get_file_content error: {e}")
            return False, str(e)

    def save_file(self, params):
        if not isinstance(params, dict):
            return False, "Invalid params instance"

        try:
            path, err = self.resolve_path(params.get("path"))
            if err:
                return False, err

            user    = params.get("user")
            content = params.get("content")

            with self.lock:
                lock = self.file_locks.get(path)
                if not lock or lock["user"] != user:
                    return False, "File not locked by you"

            with open(path, "w", encoding="utf-8") as f:
                f.write(content)

            self.release_lock(path, user)
            return True, "File Saved"

        except Exception as e:
            return False, str(e)

    def upload_file(self, params):
        if not isinstance(params, dict):
            return False, "Invalid params instance"

        try:
            rel_dir  = params.get("dir_path")
            filename = params.get("filename")
            content  = params.get("content")

            dir_path, err = self.resolve_path(rel_dir)
            if err:
                return False, err

            if not os.path.isdir(dir_path):
                return False, "Directory not found"

            safe_name = os.path.basename(filename)
            full_path = os.path.normpath(os.path.join(dir_path, safe_name))
            if not full_path.startswith(os.path.normpath(dir_path)):
                return False, "Invalid filename"

            if os.path.exists(full_path):
                return False, "File already exists"

            mode = "wb" if isinstance(content, bytes) else "w"
            with open(full_path, mode) as f:
                f.write(content)

            return True, "File uploaded"

        except Exception as e:
            log_error(f"upload_file error: {e}")
            return False, str(e)
