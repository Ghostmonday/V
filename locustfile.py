from locust import HttpUser, between, task
from locust_plugins.users import WebSocketUser
import json, time

class ApiUser(HttpUser):
    wait_time = between(5,10)
    @task(7)
    def get_user(self):
        self.client.get("/api/users/123")
    
    @task(3)
    def create_room(self):
        self.client.post("/api/rooms", json={"name":"swarm"})

class WSUser(WebSocketUser):
    host = "ws://localhost:8000"
    wait_time = between(5,10)
    
    def on_start(self):
        self.connect("/ws")
    
    @task(7)
    def join_room(self):
        self.send(json.dumps({"type":"join","room":"test"}))
    
    @task(3)
    def broadcast(self):
        self.send(json.dumps({"type":"broadcast","data":"voice-chunk"}))
