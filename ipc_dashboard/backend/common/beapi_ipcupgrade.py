import subprocess
import threading
import os
import re
from typing import List, Dict

from backend_ssemanager import *
from backend_logger import *
from backend_utils import *

_SAFE_FILENAME_RE = re.compile(r'^[A-Za-z0-9_.-]+$')
_SAFE_SERIAL_RE   = re.compile(r'^[A-Za-z0-9_-]+$')


class BackendIpcUpgrade:


    def __init__(self):

        self.process = None
        self.lock = threading.Lock()

        self.sse_manager = SSEStreamManager()
        self.script_path = "../../../ssUpgrade.sh"

    
    # Validation
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

                if name == "docker" and not comp.get("version"):
                    return False, "docker requires version"

        return True, None

    
    # Build command
    def build_command(self, components: List[Dict] = None):

        script_full_path = os.path.abspath(self.script_path)

        cmd = [
            "sudo", "-S",
            "stdbuf", "-oL", "-eL",
            "bash",
            script_full_path
        ]

        if components is not None:

            for comp in components:

                name = comp["name"]

                if name == "all":
                    cmd.append("-A")

                elif name == "agent":
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

    
    # Start update
    def start_update(self, command, components=None, sudo_password=None):

        status, err = self.validate_command_inputs(command, components)
        if not status:
            return False, err

        if not self.lock.acquire(blocking=False):
            return False, "Update already running"

        script_full_path = os.path.abspath(self.script_path)
        script_dir       = os.path.dirname(script_full_path)

        try:
            validate = subprocess.run(
                ["sudo", "-S", "-k", "-v"],
                input=sudo_password + "\n",
                capture_output=True,
                text=True,
                timeout=10
            )

            if validate.returncode != 0:
                self.lock.release()
                return False, "Authentication failed. Please enter the correct sudo password."

        except subprocess.TimeoutExpired:
            self.lock.release()
            return False, "Password validation timed out."

        except Exception as e:
            self.lock.release()
            return False, f"Password validation failed: {str(e)}"

        cmd = self.build_command(components)

        buffer = []
        finished = {"done": False}

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
                        process.stdin.write(sudo_password + "\n")
                        process.stdin.flush()
                        process.stdin.close()
                    except OSError:
                        pass

                for raw_line in process.stdout:
                    line = raw_line.rstrip("\n").rstrip("\r")

                    if line:
                        log_info(line)
                        buffer.append({
                            "type"   : "output",
                            "message": line
                        })

                process.wait()

                if process.returncode == 0:
                    buffer.append({
                        "type"   : "complete",
                        "status" : "success",
                        "message": "Update completed successfully"
                    })
                else:
                    buffer.append({
                        "type"   : "complete",
                        "status" : "error",
                        "message": f"Script exited with code {process.returncode}"
                    })

            except Exception as e:

                log_error(f"run_script exception: {e}")

                buffer.append({
                    "type"   : "error",
                    "message": str(e)
                })

                buffer.append({
                    "type"   : "complete",
                    "status" : "error",
                    "message": "Update failed due to internal error"
                })

            finally:

                try:
                    if process and process.stdout:
                        process.stdout.close()
                except Exception:
                    pass

                self.process = None
                finished["done"] = True

                try:
                    self.lock.release()
                except RuntimeError:
                    pass

        threading.Thread(target=run_script, daemon=True).start()

        return True, (buffer, finished)
