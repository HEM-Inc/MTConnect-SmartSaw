import threading
from typing import List, Dict


class SSEStreamManager:
    def __init__(self, max_connections: int = 100):
        self.clients = []
        self.lock = threading.Lock()
        self.max_connections = max_connections

    def add_client(self):
        with self.lock:
            if len(self.clients) >= self.max_connections:
                return None, False, "Too many connections"

            client_buffer = []
            self.clients.append(client_buffer)
            return client_buffer, True, "Connected"

    def remove_client(self, client_buffer: List):
        with self.lock:
            if client_buffer in self.clients:
                self.clients.remove(client_buffer)

    def broadcast(self, message: Dict):
        with self.lock:
            for client in self.clients:
                client.append(message)

    def send_to_client(self, client_buffer: List, message: Dict):
        client_buffer.append(message)

    def has_clients(self):
        with self.lock:
            return len(self.clients) > 0

    def get_client_count(self):
        with self.lock:
            return len(self.clients)
