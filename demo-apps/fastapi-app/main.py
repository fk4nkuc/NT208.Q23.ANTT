import asyncio
import logging
import random

from fastapi import FastAPI, HTTPException, Request, Response
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s %(levelname)s %(name)s trace_id=%(trace_id)s span_id=%(span_id)s %(message)s',
)

class TraceContextFilter(logging.Filter):
    def filter(self, record):
        span = trace.get_current_span()
        ctx = span.get_span_context()
        record.trace_id = format(ctx.trace_id, '032x') if ctx.is_valid else '0' * 32
        record.span_id = format(ctx.span_id, '016x') if ctx.is_valid else '0' * 16
        return True

logger = logging.getLogger("fastapi-demo")
logger.addFilter(TraceContextFilter())

_provider = TracerProvider()
_provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter()))
trace.set_tracer_provider(_provider)

app = FastAPI()
FastAPIInstrumentor.instrument_app(app)

REQUEST_COUNT = Counter('http_requests_total', 'Total HTTP requests', ['method', 'endpoint', 'status'])
REQUEST_DURATION = Histogram('http_request_duration_seconds', 'Request duration', ['method', 'endpoint'])

@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    start = asyncio.get_event_loop().time()
    response = await call_next(request)
    duration = asyncio.get_event_loop().time() - start
    REQUEST_COUNT.labels(request.method, request.url.path, response.status_code).inc()
    REQUEST_DURATION.labels(request.method, request.url.path).observe(duration)
    logger.info(
        "handled request",
        extra={"method": request.method, "path": request.url.path,
               "status": response.status_code, "duration_ms": round(duration * 1000, 2)}
    )
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
    await asyncio.sleep(delay)
    if random.random() < 0.1:
        logger.warning("simulated internal error triggered")
        raise HTTPException(status_code=500, detail="Internal server error")
    return {"data": "success", "delay_ms": round(delay * 1000, 2)}

@app.get("/api/slow")
async def slow():
    delay = random.uniform(0.5, 2.0)
    await asyncio.sleep(delay)
    logger.info("slow endpoint responded", extra={"delay_s": round(delay, 3)})
    return {"data": "slow", "delay_s": round(delay, 3)}

@app.get("/api/error")
async def force_error():
    logger.error("forced error endpoint called")
    raise HTTPException(status_code=500, detail="Forced error for testing")
