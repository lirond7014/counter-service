"""
Counter Service - Production-ready counter API with PostgreSQL persistence
Features:
- Counter persistence in PostgreSQL
- Structured JSON logging
- Prometheus metrics
- OpenTelemetry tracing
- Health checks
- Graceful shutdown
- CORS support for frontend
"""
from dotenv import load_dotenv

# Load .env file
load_dotenv()

import os
import json
import logging
import signal
import sys
from contextlib import asynccontextmanager
from datetime import datetime

import psycopg2
from psycopg2.pool import SimpleConnectionPool
from fastapi import FastAPI, HTTPException, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from opentelemetry import trace
from opentelemetry.exporter.jaeger.thrift import JaegerExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.psycopg2 import Psycopg2Instrumentor

# grab config from env, fall back to sensible defaults for local dev
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = int(os.getenv("DB_PORT", "5432"))
DB_NAME = os.getenv("DB_NAME", "counterdb")
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")
DB_SSLMODE = os.getenv("DB_SSLMODE", "require")

SERVICE_NAME = os.getenv("SERVICE_NAME", "counter-service")
SERVICE_VERSION = os.getenv("SERVICE_VERSION", "1.0.0")
ENVIRONMENT = os.getenv("ENVIRONMENT", "development")

JAEGER_ENABLED = os.getenv("JAEGER_ENABLED", "true").lower() == "true"
JAEGER_HOST = os.getenv("JAEGER_HOST", "localhost")
JAEGER_PORT = int(os.getenv("JAEGER_PORT", "6831"))

CORS_ORIGINS = os.getenv("CORS_ORIGINS", "*").split(",")


# log as JSON so tools like grafana/elk can parse it easily
class JSONFormatter(logging.Formatter):
    def format(self, record):
        log = {
            "timestamp": datetime.utcnow().isoformat(),
            "level": record.levelname,
            "message": record.getMessage(),
            "service": SERVICE_NAME,
            "env": ENVIRONMENT,
        }
        if record.exc_info:
            log["exception"] = self.formatException(record.exc_info)
        return json.dumps(log)


handler = logging.StreamHandler(sys.stdout)
handler.setFormatter(JSONFormatter())
logger = logging.getLogger()
logger.setLevel(os.getenv("LOG_LEVEL", "INFO"))
logger.addHandler(handler)


# simple connection pool - reuse connections instead of opening new ones each time
pool = None

def init_pool():
    global pool
    pool = SimpleConnectionPool(
    1, 5,
    host=DB_HOST,
    port=DB_PORT,
    database=DB_NAME,
    user=DB_USER,
    password=DB_PASSWORD,
    sslmode=DB_SSLMODE,
    connect_timeout=10,
)
    logger.info("db pool ready")

def get_conn():
    if not pool:
        raise RuntimeError("pool not initialized yet")
    return pool.getconn()

def release_conn(conn):
    if pool:
        pool.putconn(conn)


# db helpers
def init_table():
    conn = get_conn()
    try:
        cur = conn.cursor()
        cur.execute("""
            CREATE TABLE IF NOT EXISTS counter (
                id SERIAL PRIMARY KEY,
                value BIGINT NOT NULL DEFAULT 0,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        cur.execute("SELECT COUNT(*) FROM counter")
        if cur.fetchone()[0] == 0:
            cur.execute("INSERT INTO counter (value) VALUES (0)")
        conn.commit()
        logger.info("counter table ready")
    except psycopg2.Error as e:
        conn.rollback()
        logger.error(f"failed to init table: {e}")
        raise
    finally:
        release_conn(conn)

def get_value():
    conn = get_conn()
    try:
        cur = conn.cursor()
        cur.execute("SELECT value FROM counter WHERE id = 1")
        row = cur.fetchone()
        return row[0] if row else 0
    except psycopg2.Error as e:
        logger.error(f"failed to get counter: {e}")
        raise
    finally:
        release_conn(conn)

def increment():
    conn = get_conn()
    try:
        cur = conn.cursor()
        cur.execute("""
            UPDATE counter 
            SET value = value + 1, updated_at = CURRENT_TIMESTAMP 
            WHERE id = 1 
            RETURNING value
        """)
        row = cur.fetchone()
        conn.commit()
        new_val = row[0] if row else 0
        logger.info(f"counter is now {new_val}")
        return new_val
    except psycopg2.Error as e:
        conn.rollback()
        logger.error(f"failed to increment: {e}")
        raise
    finally:
        release_conn(conn)

def reset():
    conn = get_conn()
    try:
        cur = conn.cursor()
        cur.execute("""
            UPDATE counter 
            SET value = 0, updated_at = CURRENT_TIMESTAMP 
            WHERE id = 1
        """)
        conn.commit()
        logger.info("counter was reset")
        return 0
    except psycopg2.Error as e:
        conn.rollback()
        logger.error(f"failed to reset: {e}")
        raise
    finally:
        release_conn(conn)


# tracing - sends spans to jaeger so we can visualize request flows
def setup_tracing():
    if not JAEGER_ENABLED:
        logger.info("jaeger tracing is off")
        return
    try:
        exporter = JaegerExporter(agent_host_name=JAEGER_HOST, agent_port=JAEGER_PORT)
        trace.set_tracer_provider(TracerProvider())
        trace.get_tracer_provider().add_span_processor(BatchSpanProcessor(exporter))
        logger.info("jaeger tracing enabled")
    except Exception as e:
        logger.warning(f"couldnt setup jaeger: {e}")


# prometheus metrics - scraped every 15s by prometheus
request_count = Counter("counter_service_requests_total", "total requests", ["method", "endpoint", "status"])
request_duration = Histogram("counter_service_request_duration_seconds", "request duration", ["method", "endpoint"])
increment_count = Counter("counter_service_increments_total", "total increments")
reset_count = Counter("counter_service_resets_total", "total resets")


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info(f"starting {SERVICE_NAME} v{SERVICE_VERSION}")
    init_pool()
    init_table()
    setup_tracing()

    yield

    # cleanup on shutdown
    logger.info("shutting down...")
    if pool:
        pool.closeall()


app = FastAPI(title=SERVICE_NAME, version=SERVICE_VERSION, lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

FastAPIInstrumentor.instrument_app(app)
Psycopg2Instrumentor().instrument()

# runs on every request - logs it and tracks duration
@app.middleware("http")
async def track_requests(request: Request, call_next):
    with request_duration.labels(method=request.method, endpoint=request.url.path).time():
        response = await call_next(request)
    request_count.labels(method=request.method, endpoint=request.url.path, status=response.status_code).inc()
    return response


@app.get("/")
async def get_counter():
    try:
        return {"counter": get_value(), "timestamp": datetime.utcnow().isoformat()}
    except Exception as e:
        logger.error(f"get counter failed: {e}")
        raise HTTPException(status_code=500, detail="couldnt get counter")


@app.post("/")
async def increment_counter():
    try:
        value = increment()
        increment_count.inc()
        return {"counter": value, "timestamp": datetime.utcnow().isoformat()}
    except Exception as e:
        logger.error(f"increment failed: {e}")
        raise HTTPException(status_code=500, detail="couldnt increment counter")


@app.post("/reset")
async def reset_counter():
    try:
        reset_count.inc()
        return {"counter": reset(), "timestamp": datetime.utcnow().isoformat()}
    except Exception as e:
        logger.error(f"reset failed: {e}")
        raise HTTPException(status_code=500, detail="couldnt reset counter")


# kubernetes calls this to check if the pod is alive
@app.get("/health")
async def health():
    try:
        get_value()
        return {"status": "healthy", "service": SERVICE_NAME, "version": SERVICE_VERSION}
    except Exception as e:
        logger.error(f"health check failed: {e}")
        raise HTTPException(status_code=503, detail="unhealthy")


# kubernetes calls this before sending traffic to the pod
@app.get("/readiness")
async def readiness():
    try:
        get_value()
        return {"ready": True}
    except Exception:
        raise HTTPException(status_code=503, detail="not ready yet")


@app.get("/metrics")
async def metrics():
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)


# handle kill signals from kubernetes gracefully
def handle_shutdown(signum, frame):
    logger.info(f"got signal {signum}, bye")
    sys.exit(0)

signal.signal(signal.SIGTERM, handle_shutdown)
signal.signal(signal.SIGINT, handle_shutdown)


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000, log_config=None)