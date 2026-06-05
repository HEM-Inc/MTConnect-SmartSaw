import os
import time
import docker
import threading
import queue
import subprocess

from backend_logger import *


_TAIL_LINES = 100
_HEARTBEAT_INTERVAL = 15


class BackendIpcLogs:

    def __init__(self):

        # DOCKER INIT
        try:
            self.client = docker.from_env()
            self.client.ping()
            self.available = True
            log_info("Docker connected successfully")

        except Exception as e:
            self.client = None
            self.available = False
            log_error(f"Docker init failed: {e}")

        # SSE CLIENTS
        self.clients = set()
        self.client_lock = threading.Lock()

        # STREAM STATE
        self.logs_running = False
        self.logs_container = None
        self.worker_thread = None
        self.stream_lock = threading.Lock()

        # HEARTBEAT
        self._hb_stop = threading.Event()
        self._hb_thread = threading.Thread(
            target=self._heartbeat_loop,
            daemon=True,
            name="log-heartbeat"
        )
        self._hb_thread.start()

    # HEARTBEAT
    def _heartbeat_loop(self):
        while not self._hb_stop.wait(timeout=_HEARTBEAT_INTERVAL):
            self.broadcast({"type": "heartbeat"})

    # CLIENT CONNECT
    def connect(self):
        q = queue.Queue(maxsize=2000)
        with self.client_lock:
            self.clients.add(q)
        return True, q

    # CLIENT DISCONNECT
    def disconnect(self, client_queue):
        with self.client_lock:
            self.clients.discard(client_queue)
        return True

    # BROADCAST
    def broadcast(self, msg):
        with self.client_lock:
            for q in list(self.clients):
                try:
                    q.put_nowait(msg)
                except queue.Full:
                    pass

    # SEND LOG
    def _send_log(self, container_name, message):
        self.broadcast({
            "type": "log",
            "container": container_name,
            "message": message
        })

    # SELECT CONTAINER
    def select_container(self, container_name):

        if not self.available:
            return False

        with self.stream_lock:

            self.stop_stream()

            self.logs_running = True
            self.logs_container = container_name

            self.worker_thread = threading.Thread(
                target=self._worker,
                args=(container_name,),
                daemon=True
            )
            self.worker_thread.start()

        return True

    # STOP LOGS
    def stop_logs(self):
        with self.stream_lock:
            self.stop_stream()
        return True

    # STOP STREAM
    def stop_stream(self):

        if not self.logs_running:
            return

        self.logs_running = False
        self.logs_container = None

        worker = self.worker_thread

        if (
            worker and
            worker.is_alive() and
            worker != threading.current_thread()
        ):
            worker.join(timeout=3)

        self.worker_thread = None

    # DOCKER LOGS
    def docker_logs(self, container_name):

        container = self.client.containers.get(container_name)

        stream = container.logs(
            stream=True,
            follow=True,
            tail=_TAIL_LINES,
            timestamps=True
        )

        for line in stream:

            if not self.logs_running:
                break

            if self.logs_container != container_name:
                break

            msg = line.decode(errors="ignore").rstrip()

            if msg:
                self._send_log(container_name, msg)

    # COMPOSE LOGS (compose_dir moved locally)
    def compose_logs(self, requested_name, service_name):

        compose_dir = os.path.abspath(
            os.path.join(os.path.dirname(__file__), "../../../")
        )

        process = subprocess.Popen(
            [
                "docker", "compose", "logs",
                "-f",
                "--tail", str(_TAIL_LINES),
                service_name
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
            cwd=compose_dir
        )

        try:

            if not process.stdout:
                return

            for line in process.stdout:

                if not self.logs_running:
                    break

                if self.logs_container != requested_name:
                    break

                msg = line.rstrip()

                if msg:
                    self._send_log(requested_name, msg)

        finally:
            try:
                process.kill()
                process.wait(timeout=3)
            except Exception:
                pass

    # WORKER
    def _worker(self, container_name):

        log_info(f"Log worker started: {container_name}")

        compose_map = {
            "agent": "mtc_agent",
            "adapter": "mtc_adapter",
            "mqtt": "mosquitto",
        }

        _RETRY_DELAY = 3
        _MAX_RETRIES = 10
        consecutive = 0

        while self.logs_running and self.logs_container == container_name:

            try:

                if container_name in compose_map:
                    self.compose_logs(
                        requested_name=container_name,
                        service_name=compose_map[container_name]
                    )
                else:
                    self.docker_logs(container_name)

                consecutive = 0

            except docker.errors.NotFound:
                self._send_log(container_name, "[container removed — stream closed]")
                break

            except docker.errors.APIError as e:

                consecutive += 1
                self._send_log(container_name, f"[docker api error: {e}]")

                if consecutive >= _MAX_RETRIES:
                    self._send_log(container_name, "[too many errors — stream closed]")
                    break

                self._wait_retry(container_name, _RETRY_DELAY)

            except Exception as e:

                consecutive += 1
                self._send_log(container_name, f"[error: {e}]")

                if consecutive >= _MAX_RETRIES:
                    self._send_log(container_name, "[too many errors — stream closed]")
                    break

                self._wait_retry(container_name, _RETRY_DELAY)

        log_info(f"Log worker stopped: {container_name}")

    # RETRY WAIT
    def _wait_retry(self, container_name, delay):

        deadline = time.monotonic() + delay

        while time.monotonic() < deadline:

            if not self.logs_running:
                return

            if self.logs_container != container_name:
                return

            time.sleep(0.25)
