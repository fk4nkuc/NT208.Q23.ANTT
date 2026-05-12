from fastapi import FastAPI, Response
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
import time
import random

app = FastAPI()

REQUEST_COUNT = Counter('http_requests_total', 'Total', ['method', 'endpoint', 'status'])
REQUEST_DURATION = Histogram('http_request_duration_seconds', 'Duration', ['method', 'endpoint'])

@app.middleware("http")
async def metrics_middleware(request, call_next):
    start = time.time()
    response = await call_next(request)
    duration = time.time() - start
    REQUEST_COUNT.labels(request.method, request.url.path, response.status_code).inc()
    REQUEST_DURATION.labels(request.method, request.url.path).observe(duration)
    return response

@app.get("/metrics")
async def metrics():
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)

@app.get("/health")
async def health():
    return {"status": "ok"}

@app.get("/api/data")
async def get_data():
    delay = random.uniform(0.01, 0.2)
    time.sleep(delay)
    if random.random() < 0.1:
        return {"error": "Internal error"}, 500
    return {"data": "success", "delay_ms": delay*1000}

@app.get("/api/slow")
async def slow():
    delay = random.uniform(0.5, 2.0)
    time.sleep(delay)
    return {"data": "slow", "delay_s": delay}