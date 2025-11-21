import random
import time
from locust import HttpUser, task, between, LoadTestShape, events

class VibeZUser(HttpUser):
    # Think time variance: users wait between 1 and 5 seconds between tasks
    wait_time = between(1, 5)

    @task(10)
    def index(self):
        """Standard page load"""
        self.client.get("/", name="Home")

    @task(5)
    def view_room(self):
        """Simulate viewing a room (common action)"""
        # Assuming a 'general' room exists or similar
        self.client.get("/api/rooms/general", name="View Room")

    @task(2)
    def auth_callback_smoke(self):
        """
        Smoke test for auth callback endpoint.
        This endpoint was identified as never being hit.
        """
        # Using dummy params to ensure the endpoint code is exercised
        self.client.get("/auth/callback?code=smoke_test_code&state=smoke_test_state", name="/auth/callback")

    @task(3)
    def websocket_fallback_simulation(self):
        """
        Simulate WebSocket fallback logic.
        If a user loses signal (WS disconnects), they might fall back to HTTP polling.
        This task simulates that HTTP load.
        """
        # Hitting the message history endpoint as a proxy for "polling" for new messages
        with self.client.get("/api/messages?roomId=general&limit=20", catch_response=True, name="WS Fallback (HTTP Poll)") as response:
            # We accept 401/403 here since we aren't doing full auth login in this load test script yet,
            # but we want to ensure the server handles the load.
            if response.status_code in [200, 401, 403]:
                response.success()
            else:
                response.failure(f"Unexpected status: {response.status_code}")

    @task(1)
    def chaos_monkey(self):
        """
        Simulate chaos: network latency and packet drops.
        This makes the user behave like they are on a flaky connection.
        """
        action = random.choice(["latency", "drop", "normal"])
        
        if action == "latency":
            # Simulate high latency on the client side before making a request
            time.sleep(random.uniform(0.5, 2.0))
            self.client.get("/api/health", name="Chaos: Latency")
        elif action == "drop":
            # Simulate packet drop / timeout
            try:
                # extremely short timeout to force a failure/drop simulation
                self.client.get("/api/health", timeout=0.001, name="Chaos: Packet Drop")
            except:
                # We expect this to fail, it's part of the simulation
                pass 
        else:
            self.client.get("/api/health", name="Chaos: Normal")

class WaveShape(LoadTestShape):
    """
    Custom Load Shape to spike traffic in waves.
    Start gentle, then flood.
    """
    
    # Define the stages of the test
    stages = [
        {"duration": 60,  "users": 100,  "spawn_rate": 10},   # Stage 1: Gentle start (1 min)
        {"duration": 120, "users": 500,  "spawn_rate": 20},   # Stage 2: Ramp up (2 mins)
        {"duration": 180, "users": 1000, "spawn_rate": 50},   # Stage 3: Heavy load (3 mins)
        {"duration": 240, "users": 2000, "spawn_rate": 100},  # Stage 4: FLOOD (4 mins) - Peak 2000 users
        {"duration": 300, "users": 500,  "spawn_rate": 50},   # Stage 5: Cool down (5 mins)
    ]

    def tick(self):
        run_time = self.get_run_time()

        for stage in self.stages:
            if run_time < stage["duration"]:
                tick_data = (stage["users"], stage["spawn_rate"])
                return tick_data

        return None
