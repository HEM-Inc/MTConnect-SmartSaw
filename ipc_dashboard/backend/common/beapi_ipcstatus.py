import docker
import threading
import time
import hashlib
import json
from dateutil.relativedelta import relativedelta
from datetime import datetime, timezone

from backend_ssemanager import *
from backend_logger import *
from backend_utils import *


class BackendIpcStatus:
    def __init__(self):
        # Docker init
        try:
            self.client = docker.from_env()
            self.client.ping()
            self.available = True
            log_info("Docker connected successfully")
        except Exception as e:
            self.client = None
            self.available = False
            log_error(f"Docker init failed: {e}")

        # SSE
        self.sse_manager = SSEStreamManager(max_connections=50)

        # Cache
        self.cached_data = []
        self.cached_hash = None
        self.cache_lock = threading.Lock()

        # Worker
        self.worker_running = False
        self.worker_thread = None
        self.worker_lock = threading.Lock()

        # Connections
        self.active_connections = 0
        self.connection_lock = threading.Lock()

        # Timing
        self.last_stats_time = 0
        self.stats_interval = 6
        self.status_interval = 2

        # Stats cache
        self.previous_stats = {}

    
    # TIME FORMAT
    def format_relative_time(self, iso_time):
        if not iso_time:
            return None

        try:
            if "." in iso_time:
                main, rest = iso_time.split(".", 1)
                frac = rest.rstrip("Z")[:6]
                iso_time = f"{main}.{frac}+00:00"
            else:
                iso_time = iso_time.replace("Z", "+00:00")

            dt = datetime.fromisoformat(iso_time)
            now = datetime.now(timezone.utc)
            diff = relativedelta(now, dt)

            if diff.years:
                return f"{diff.years} year{'s' if diff.years > 1 else ''} ago"
            if diff.months:
                return f"{diff.months} month{'s' if diff.months > 1 else ''} ago"
            if diff.days:
                return f"{diff.days} day{'s' if diff.days > 1 else ''} ago"
            if diff.hours:
                return f"{diff.hours} hour{'s' if diff.hours > 1 else ''} ago"
            if diff.minutes:
                return f"{diff.minutes} minute{'s' if diff.minutes > 1 else ''} ago"

            return f"{diff.seconds} second{'s' if diff.seconds > 1 else ''} ago"

        except Exception as e:
            log_error(f"format_relative_time failed: {iso_time} -> {e}")
            return None

    
    # CONTAINER LIST
    def get_container_list(self):

        compose_name  = get_parent_directory_name(levels = 3).lower()

        if not self.client:
            log_error("get_container_list: docker client not available")
            return []

        try:
            containers = self.client.containers.list(all=True)
        except Exception as e:
            log_error(f"get_container_list failed: {e}")
            return []

        result = []

        for c in containers:
            try:
                c.reload()

                attrs = c.attrs
                labels = attrs.get("Config", {}).get("Labels", {})

                compose_project = labels.get("com.docker.compose.project")
                compose_service = labels.get("com.docker.compose.service")
                if compose_project != compose_name:
                    continue

                state = attrs.get("State", {})
                config = attrs.get("Config", {})
                network = attrs.get("NetworkSettings", {})

                state_status = state.get("Status", "unknown")
                started_at = state.get("StartedAt")
                finished_at = state.get("FinishedAt")
                created_at = attrs.get("Created")

                if state_status == "running":
                    uptime = self.format_relative_time(started_at)
                    status_text = f"Up {uptime.replace(' ago','')}" if uptime else "Up"

                elif state_status == "exited":
                    exited = self.format_relative_time(finished_at)
                    status_text = f"Exited ({state.get('ExitCode','')}) {exited}"

                elif state_status == "restarting":
                    status_text = "Restarting"
                elif state_status == "paused":
                    status_text = "Paused"
                elif state_status == "dead":
                    status_text = "Dead"
                elif state_status == "created":
                    status_text = "Created"
                else:
                    status_text = state_status.capitalize()

                ports = set()
                for container_port, bindings in network.get("Ports", {}).items():
                    if bindings:
                        for b in bindings:
                            ports.add(f"{b.get('HostPort')}->{container_port}")
                    else:
                        ports.add(container_port)

                try:
                    image_name = c.image.tags[0] if c.image.tags else c.image.short_id
                except Exception:
                    image_name = config.get("Image", "unknown")

                result.append({
                    "id": c.short_id,
                    "name": c.name,
                    "image": image_name,
                    "status": status_text,
                    "state": state_status,
                    "command": " ".join(config.get("Cmd") or []),
                    "created": self.format_relative_time(created_at),
                    "health": state.get("Health", {}).get("Status"),
                    "ports": sorted(ports),
                    "cpu": 0.0,
                    "memory": 0.0,
                })

            except Exception as e:
                log_error(f"container skip {c.short_id}: {e}")
                continue

        return result

    
    # CPU
    def calculate_cpu(self, stats):
        try:
            cpu_stats = stats.get("cpu_stats", {})
            precpu_stats = stats.get("precpu_stats", {})

            cpu_usage = cpu_stats.get("cpu_usage", {}).get("total_usage", 0)
            precpu_usage = precpu_stats.get("cpu_usage", {}).get("total_usage", 0)

            system_cpu = cpu_stats.get("system_cpu_usage", 0)
            precpu_system = precpu_stats.get("system_cpu_usage", 0)

            cpu_delta = cpu_usage - precpu_usage
            system_delta = system_cpu - precpu_system

            online_cpus = cpu_stats.get("online_cpus") or 1

            if system_delta > 0 and cpu_delta > 0:

                # true docker ratio
                raw_percent = (cpu_delta / system_delta) * online_cpus * 100.0

                ui_percent = min(raw_percent, 100.0)

                return round(ui_percent, 2)

            return 0.0

        except Exception as e:
            log_error(f"calculate_cpu error: {e}")
            return 0.0
    
    # MEMORY
    def calculate_memory(self, stats):
        try:
            mem = stats.get("memory_stats", {})
            usage = mem.get("usage", 0)
            cache = mem.get("stats", {}).get("cache", 0)

            real_usage = max(usage - cache, 0)
            limit = mem.get("limit", 0)

            if not limit:
                return 0.0

            return round((real_usage / limit) * 100, 2)

        except Exception as e:
            log_error(f"calculate_memory error: {e}")
            return 0.0

    
    # STATS
    def get_stats(self, container_id):
        try:
            c = self.client.containers.get(container_id)
            stats = c.stats(stream=False)

            cpu = self.calculate_cpu(stats)
            mem = self.calculate_memory(stats)

            self.previous_stats[container_id] = {"cpu": cpu, "memory": mem}
            return cpu, mem

        except docker.errors.NotFound:
            log_error(f"get_stats: container not found {container_id}")
            self.previous_stats.pop(container_id, None)
            return 0.0, 0.0

        except Exception as e:
            log_error(f"get_stats error {container_id}: {e}")
            prev = self.previous_stats.get(container_id, {})
            return prev.get("cpu", 0.0), prev.get("memory", 0.0)

    
    # COLLECT
    def collect(self):
        containers = self.get_container_list()

        now = time.time()
        collect_stats = (now - self.last_stats_time) >= self.stats_interval

        for c in containers:
            if c["state"] == "running":
                if collect_stats:
                    cpu, mem = self.get_stats(c["id"])
                else:
                    prev = self.previous_stats.get(c["id"], {})
                    cpu = prev.get("cpu", 0.0)
                    mem = prev.get("memory", 0.0)
            else:
                cpu, mem = 0.0, 0.0

            c["cpu"] = cpu
            c["memory"] = mem

        if collect_stats:
            self.last_stats_time = now

        return containers

    # HASH
    def hash_data(self, data):
        try:
            return hashlib.md5(json.dumps(data, sort_keys=True).encode()).hexdigest()
        except Exception as e:
            log_error(f"hash_data error: {e}")
            return None

    
    # WORKER
    def worker(self):
        log_info("Docker worker started")

        while self.worker_running:
            try:
                data = self.collect()
                new_hash = self.hash_data(data)

                with self.cache_lock:
                    if new_hash != self.cached_hash:
                        self.cached_data = data
                        self.cached_hash = new_hash

                        if self.sse_manager.has_clients():
                            self.sse_manager.broadcast({
                                "type": "docker_update",
                                "data": data,
                                "ts": time.time()
                            })

                time.sleep(self.status_interval)

            except Exception as e:
                log_error(f"worker error: {e}")
                time.sleep(2)

        log_info("Docker worker stopped")

    
    # START / STOP
    def start_worker(self):
        with self.worker_lock:
            if not self.worker_running:
                self.worker_running = True
                self.worker_thread = threading.Thread(target=self.worker, daemon=True)
                self.worker_thread.start()

    def stop_worker(self):
        with self.worker_lock:
            self.worker_running = False

    
    # SSE CONNECT
    def connect(self):
        buf, success, _ = self.sse_manager.add_client()
        if not success:
            log_error("connect failed")
            return False, (None, False)

        with self.connection_lock:
            self.active_connections += 1
            if self.active_connections == 1:
                self.start_worker()

        data, _ = self.get_cached_data()

        if not data:
            data = self.collect()
            with self.cache_lock:
                self.cached_data = data
                self.cached_hash = self.hash_data(data)

        self.sse_manager.send_to_client(buf, {
            "type": "docker_update",
            "data": data,
            "ts": time.time()
        })

        return True, (buf, True)

    def disconnect(self, params):
        buf = params.get("client_buffer")

        self.sse_manager.remove_client(buf)

        with self.connection_lock:
            self.active_connections -= 1
            if self.active_connections <= 0:
                self.active_connections = 0
                self.stop_worker()

        return True, "Success"

    
    # STATUS
    def get_status(self):
        if not self.worker_running:
            self.start_worker()

        return True, {
            "available": self.available,
            "connections": self.active_connections,
            "worker_running": self.worker_running
        }

    
    def get_containers(self):
        data, _ = self.get_cached_data()

        if not data:
            log_error("cache empty, collecting fresh data")
            data = self.collect()
            with self.cache_lock:
                self.cached_data = data
                self.cached_hash = self.hash_data(data)

        return True, data

    def get_cached_data(self):
        with self.cache_lock:
            return self.cached_data.copy(), self.cached_hash
