import subprocess
import threading
import time
import os
import mimetypes
import re

from datetime import datetime, timedelta, timezone
from typing import List, Dict

from backend_ssemanager import *
from backend_logger import *
from backend_utils import *

_SAFE_FILENAME_RE = re.compile(r'^[A-Za-z0-9_.-]+$')
_SAFE_SERIAL_RE   = re.compile(r'^[A-Za-z0-9_-]+$')

class BackendIpcInstall:

    def __init__(self):

        self.process = None
        self.sse_manager = SSEStreamManager()
        self.script_path = "../../../ssInstall.sh"
        self.install_running = False
        self.install_lock = threading.Lock()

    def validate_install_command_inputs(self,
                                        command: str,
                                        components=None):

        if not command or command.lower() != "install":
            log_error("BeApi validate install command inputs, invalid command")
            return False, "Invalid install command"

        valid_names = {
            "agent",
            "mqtt",
            "adapter",
            "devctl",
            "serial_number",
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
                ]:
                    val = comp.get(field)
                    if val:
                        ok, err = validate_safe_string(val, pattern, label)
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

        return True, "Success"

    def build_install_command(self,
                              components: List[Dict] = None):

        script_full_path = os.path.abspath(
            self.script_path
        )

        cmd = [
            "sudo",
            "-S",
            "stdbuf",
            "-oL",
            "-eL",
            "bash",
            script_full_path
        ]

        if components is not None:

            for comp in components:
                name = comp["name"]

                if name == "agent":
                    cmd.extend(["-d", comp["config_file"]])

                elif name == "mqtt":
                    if comp.get("bridge") == True:
                        cmd.append("-b")

                    elif comp.get("bridge") == False:
                        cmd.append("-B")

                elif name == "adapter":
                    if comp.get("config_file"):
                        cmd.extend(["-a", comp["config_file"]])

                    if comp.get("data_file"):
                        cmd.extend(["-j", comp["data_file"]])

                elif name == "devctl":
                    cmd.extend(["-c", comp["config_file"]])

                elif name == "serial_number":
                    cmd.extend(["-u", comp["serial_number"]])

        log_debug(f"Built command: {cmd}")

        return cmd

    def start_install(self,
                      command,
                      components=None,
                      sudo_password=None):

        with self.install_lock:

            if self.install_running:
                log_error("Install already running")
                return False, "Install already running"

            self.install_running = True

        try:
            status, err = self.validate_install_command_inputs(command, components)
            if status != True:
                log_error("Start install, validate install command input failed")
                with self.install_lock:
                    self.install_running = False
                return False, err

            script_full_path = os.path.abspath(self.script_path)

            script_dir = os.path.dirname(script_full_path)

            if not os.path.isfile(script_full_path):

                with self.install_lock:
                    self.install_running = False

                return False, "Install script not found"

            # VALIDATE SUDO PASSWORD
            try:

                validate = subprocess.run(
			["sudo", "-S", "-k", "-v"],
			input=sudo_password + "\n",
			capture_output=True,
			text=True,
			timeout=10
		    )

                if validate.returncode != 0:
                    with self.install_lock:
                        self.install_running = False
                    return False, "Authentication failed. Please enter the correct sudo password."

            except subprocess.TimeoutExpired:

                with self.install_lock:
                    self.install_running = False

                return False, "Password validation timed out."

            except Exception as e:

                with self.install_lock:
                    self.install_running = False

                return False, f"Password validation failed: {str(e)}"


            cmd = self.build_install_command(
                components
            )

            buffer = []

            finished = {
                "done": False
            }

            def run_script():

                process = None

                try:
                    process = subprocess.Popen(
                        cmd,
                        stdin=subprocess.PIPE,
                        stdout=subprocess.PIPE,
                        stderr=subprocess.STDOUT,
                        text=True,
                        bufsize=1,
                        cwd=script_dir
                    )

                    self.process = process

                    if sudo_password:

                        try:
                            process.stdin.write(
                                sudo_password + "\n"
                            )

                            process.stdin.flush()

                            process.stdin.close()

                        except OSError:
                            pass

                    for raw_line in process.stdout:

                        line = raw_line.rstrip("\n").rstrip("\r")

                        if line:

                            buffer.append({
                                "type": "output",
                                "message": line
                            })

                    process.wait()

                    return_code = process.returncode

                    if return_code == 0:

                        buffer.append({
                            "type": "complete",
                            "status": "success",
                            "message": (
                                "Install completed successfully"
                            )
                        })

                    else:

                        buffer.append({
                            "type": "complete",
                            "status": "error",
                            "message": (
                                f"Script exited with "
                                f"code {return_code}"
                            )
                        })

                except Exception as e:

                    log_error(
                        f"run_script exception: {e}"
                    )

                    buffer.append({
                        "type": "error",
                        "message": str(e)
                    })

                    buffer.append({
                        "type": "complete",
                        "status": "error",
                        "message": (
                            "Install failed due to "
                            "internal error"
                        )
                    })

                finally:

                    try:
                        if process and process.stdout:
                            process.stdout.close()

                    except Exception:
                        pass

                    self.process = None

                    with self.install_lock:
                        self.install_running = False

                    finished["done"] = True

            threading.Thread(
                target=run_script,
                daemon=True
            ).start()

            return True, (buffer, finished)

        except Exception as e:

            with self.install_lock:
                self.install_running = False

            log_error(
                f"start_install exception: {e}"
            )

            return False, str(e)

    def stop_install(self):

        with self.install_lock:

            if not self.install_running:
                return False, "No install running"

            try:

                if self.process:

                    self.process.terminate()

                    try:
                        self.process.wait(timeout=5)

                    except subprocess.TimeoutExpired:
                        self.process.kill()

                self.process = None

                self.install_running = False

                return True, "Install stopped"

            except Exception as e:

                log_error(
                    f"stop_install exception: {e}"
                )

                return False, str(e)
