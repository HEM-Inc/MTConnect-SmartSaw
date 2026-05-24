import subprocess
import threading
import time
import os
import re
import mimetypes
from datetime import datetime, timedelta, timezone
from typing import List

from backend_ssemanager import *
from backend_logger import *
from backend_utils import *

_SAFE_FILENAME_RE = re.compile(r'^[A-Za-z0-9_.-]+$')
_SAFE_SERIAL_RE   = re.compile(r'^[A-Za-z0-9_-]+$')


class BackendIpcUpgrade:

    def _validate_safe_string(self, value: str, pattern, field_name: str):
        if not value:
            return True, None
        if not isinstance(value, str):
            return False, f"{field_name} must be a string"
        if not pattern.match(value):
            return False, f"Invalid characters in {field_name}"
        return True, None

    def __init__(self):
        self.process = None
        self.is_running = False
        self.lock = threading.Lock()

        self.sse_manager = SSEStreamManager()
        self.script_path = "../../../ssUpgrade.sh"

        # File locks
        self.file_locks  = {}   # path → {user, expires_at}
        self.lock_timeout = 300  # 5 mins

        self.clients = []

        # Cleanup thread
        threading.Thread(target=self.cleanup_expired_locks, daemon=True).start()

    
    # Validation / command builder
    def validate_command_inputs(self, command: str, components=None):
        if not command or command.lower() != "update":
            log_error("BeApi validate command inputs, invalid command")
            return False, "Invalid command"

        valid_names = {
            "all", "agent", "mqtt", "adapter",
            "devctl", "serial_number",
            "material_update", "reinit_jobs", "docker"
        }

        if components is not None:
            for comp in components:
                name = comp.get("name")

                if name not in valid_names:
                    return False, f"Invalid component: {name}"

                # Validate string fields to prevent shell injection
                for field, pattern, label in [
                    ("config_file", _SAFE_FILENAME_RE, "config_file"),
                    ("data_file", _SAFE_FILENAME_RE, "data_file"),
                    ("serial_number", _SAFE_SERIAL_RE, "serial_number"),
                    ("version", _SAFE_FILENAME_RE, "version"),
                ]:
                    val = comp.get(field)
                    if val:
                        ok, err = self._validate_safe_string(val, pattern, label)
                        if not ok:
                            return False, err

                if name == "agent" and not comp.get("config_file"):
                    return False, "agent requires config_file"

                if name == "adapter":
                    if not comp.get("config_file") and not comp.get("data_file"):
                        return False, "adapter requires config_file or data_file"

                if name == "devctl" and not comp.get("config_file"):
                    return False, "devctl requires config_file"

                if name == "serial_number" and not comp.get("serial_number"):
                    return False, "serial_number requires value"

                if name == "docker" and not comp.get("version"):
                    return False, "docker requires version"

        return True, None

    def build_command(self, components: List[Dict] = None):
        script_full_path = os.path.abspath(self.script_path)
        cmd = [
            "sudo", "-S",
            "stdbuf", "-oL", "-eL",
            "bash", script_full_path
        ]

        if components is not None:
            for comp in components:
                name = comp["name"]

                if name == "all":
                    cmd.append("-A")

                elif name == "agent":
                    cmd.extend(["-d", comp["config_file"]])

                elif name == "mqtt":
                    if comp.get("bridge"):
                        cmd.append("-b")

                elif name == "adapter":
                    if comp.get("config_file"):
                        cmd.extend(["-a", comp["config_file"]])
                    if comp.get("data_file"):
                        cmd.extend(["-j", comp["data_file"]])

                elif name == "devctl":
                    cmd.extend(["-c", comp["config_file"]])

                elif name == "serial_number":
                    cmd.extend(["-u", comp["serial_number"]])

                elif name == "material_update":
                    if comp.get("materials"):
                        cmd.append("-m")

                elif name == "reinit_jobs":
                    if comp.get("reinit"):
                        cmd.append("-i")

                elif name == "docker":
                    cmd.extend(["-v", comp["version"]])

        log_debug(f"Built command: {cmd}")
        return cmd

    # ------------------------------------------------------------------
    # Main update entry point
    # ------------------------------------------------------------------

    def start_update(self, command, components=None, sudo_password=None):
        """
        Returns (True, (buffer, finished)) on success.
        buffer   : list of dicts  {"type": "output"|"error"|"complete", ...}
        finished : dict           {"done": bool}

        The caller (FastAPI) drains buffer and watches finished["done"].
        """
        status, err = self.validate_command_inputs(command, components)
        if not status:
            return False, err

        script_full_path = os.path.abspath(self.script_path)
        script_dir       = os.path.dirname(script_full_path)

        # ---- validate sudo password BEFORE spawning the script ----
        try:
            validate = subprocess.run(
                ["sudo", "-S", "-k", "-v"],
                input=sudo_password + "\n",
                capture_output=True,
                text=True,
                timeout=10
            )
            if validate.returncode != 0:
                return False, "Authentication failed. Please enter the correct sudo password."
        except subprocess.TimeoutExpired:
            return False, "Password validation timed out."
        except Exception as e:
            return False, f"Password validation failed: {str(e)}"

        cmd    = self.build_command(components)
        buffer   = []                  # list of event dicts
        finished = {"done": False}     # set True when script exits

        def run_script():
            process = None
            try:
                process = subprocess.Popen(
                    cmd,
                    stdin=subprocess.PIPE,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,   # merge stderr so nothing is lost
                    text=True,
                    bufsize=1,                  # line-buffered
                    cwd=script_dir
                )

                # Write password then CLOSE stdin so sudo doesn't keep waiting
                if sudo_password:
                    try:
                        process.stdin.write(sudo_password + "\n")
                        process.stdin.flush()
                        process.stdin.close()
                    except OSError:
                        pass  # already closed — ignore

                # Stream every line as a structured dict
                for raw_line in process.stdout:
                    line = raw_line.rstrip("\n").rstrip("\r")
                    if line:
                        buffer.append({
                            "type"   : "output",
                            "message": line
                        })

                process.wait()
                return_code = process.returncode

                if return_code == 0:
                    buffer.append({
                        "type"   : "complete",
                        "status" : "success",
                        "message": "Update completed successfully"
                    })
                else:
                    buffer.append({
                        "type"   : "complete",
                        "status" : "error",
                        "message": f"Script exited with code {return_code}"
                    })

            except Exception as e:
                log_error(f"run_script exception: {e}")
                # Always push the error to the buffer so frontend sees it
                buffer.append({
                    "type"   : "error",
                    "message": str(e)
                })
                buffer.append({
                    "type"   : "complete",
                    "status" : "error",
                    "message": "Update failed due to an internal error"
                })

            finally:
                # Ensure stdout is closed even on unexpected paths
                if process:
                    try:
                        process.stdout.close()
                    except Exception:
                        pass
                # Mark done — the SSE stream generator will stop polling
                finished["done"] = True

        threading.Thread(target=run_script, daemon=True).start()
        return True, (buffer, finished)

    # ------------------------------------------------------------------

    def stop_update(self):
        with self.lock:
            if self.process:
                self.process.terminate()
                return True
        return False

    def remove_client(self, buffer):
        if buffer in self.clients:
            self.clients.remove(buffer)

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
