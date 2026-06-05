import subprocess
import threading
import os
from typing import List, Dict

from backend_ssemanager import *
from backend_logger import *
from backend_utils import *

class BackendIpcClean:

    def __init__(self):
        self.sse_manager = SSEStreamManager()
        self.script_path = "../../../ssClean.sh"
        self.lock = threading.Lock()

    def validate_clean_command_inputs(self, command: str, components=None):
        if not command or command.lower() != "clean":
            return False, "Invalid clean command"

        valid_names = {
            "all", "agent", "mqtt", "adapter", "devctl",
            "mongodb", "ods", "docker", "container"
        }

        if components:
            for comp in components:
                name = comp.get("name")

                if name not in valid_names:
                    return False, f"Invalid component: {name}"

                if name == "container" and not comp.get("container_name"):
                    return False, "Invalid container command"

        return True, "Success"

    def build_clean_command(self, components: List[Dict] = None):

        cmd = [
            "sudo", "-S",
            "stdbuf", "-oL", "-eL",
            "bash",
            os.path.abspath(self.script_path)
        ]

        if components:
            for comp in components:
                name = comp["name"]

                if name == "agent" and comp.get("clean"):
                    cmd.append("-a")

                elif name == "mqtt" and comp.get("clean"):
                    cmd.append("-M")

                elif name == "adapter" and comp.get("clean"):
                    cmd.append("-H")

                elif name == "devctl" and comp.get("clean"):
                    cmd.append("-C")

                elif name == "mongodb" and comp.get("clean"):
                    cmd.append("-S")

                elif name == "ods" and comp.get("clean"):
                    cmd.append("-O")

                elif name == "docker" and comp.get("clean"):
                    cmd.append("-D")

                elif name == "all":
                    if comp.get("clean"):
                        cmd.append("-A")
                    if comp.get("disable"):
                        cmd.append("-d")

                elif name == "container":
                    cmd.extend(["-L", comp["container_name"]])

        return cmd

    def start_clean(self, command, components=None, sudo_password=None):

        # 1. validate inputs
        status, err = self.validate_clean_command_inputs(command, components)
        if not status:
            return False, err

        # 2. LOCK (prevents parallel runs)
        if not self.lock.acquire(blocking=False):
            return False, "Clean already running"

        buffer = []
        finished = {"done": False}

        script_dir = os.path.dirname(os.path.abspath(self.script_path))

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

        cmd = self.build_clean_command(components)

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

                if sudo_password:
                    process.stdin.write(sudo_password + "\n")
                    process.stdin.flush()
                    process.stdin.close()

                for line in process.stdout:
                    line = line.strip()
                    if line:
                        buffer.append({
                            "type": "output",
                            "message": line
                        })

                process.wait()

                buffer.append({
                    "type": "complete",
                    "status": "success" if process.returncode == 0 else "error",
                    "message": "Clean completed"
                })

            except Exception as e:
                log_error(f"clean error: {e}")
                buffer.append({
                    "type": "error",
                    "message": str(e)
                })

            finally:
                finished["done"] = True
                self.lock.release()

        threading.Thread(target=run_script, daemon=True).start()

        return True, (buffer, finished)
