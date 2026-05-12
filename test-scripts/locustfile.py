from locust import HttpUser, task, between, events
import random
import time

class DemoUser(HttpUser):
    wait_time = between(0.5, 2)
    
    def on_start(self):
        """Initialize user session"""
        self.start_time = time.time()
    
    @task(3)
    def get_data(self):
        """Normal API call"""
        with self.client.get("/api/data", catch_response=True) as response:
            if response.status_code == 500:
                response.failure("Got 500 error")
            elif response.elapsed.total_seconds() > 1.0:
                response.failure(f"Slow response: {response.elapsed.total_seconds()}s")
    
    @task(1)
    def get_slow(self):
        """Slow endpoint to create bottlenecks"""
        self.client.get("/api/slow")
    
    @task(1)
    def get_health(self):
        """Health check"""
        self.client.get("/health")

@events.quitting.add_listener
def on_quit(environment, **kwargs):
    """Log summary when test ends"""
    stats = environment.runner.stats.total
    print("\n===== LOCUST TEST SUMMARY =====")
    print(f"Total requests: {stats.num_requests}")
    print(f"Failure rate: {stats.fail_ratio * 100:.2f}%")
    print(f"Average response time: {stats.avg_response_time:.2f}ms")
    print(f"P95: {stats.get_response_time_percentile(0.95):.2f}ms")
    print(f"P99: {stats.get_response_time_percentile(0.99):.2f}ms")