# Counter Service

A production-ready counter service with PostgreSQL persistence, built with FastAPI (Python backend) and React (frontend).

## Features

### Core Functionality
- ✅ GET `/` - Get current counter value
- ✅ POST `/` - Increment counter
- ✅ POST `/reset` - Reset counter to 0

### Production Ready
- ✅ PostgreSQL persistence
- ✅ Structured JSON logging
- ✅ Prometheus metrics (`GET /metrics`)
- ✅ OpenTelemetry tracing (Jaeger compatible)
- ✅ Health checks (`GET /health`, `GET /readiness`)
- ✅ Graceful shutdown handling

### Cloud Native
- ✅ Kubernetes-ready (YAML manifests + Kustomize)
- ✅ RBAC policies (least privilege)
- ✅ External Secrets integration (AWS Secrets Manager)
- ✅ Non-root containers
- ✅ Read-only root filesystem
- ✅ Resource limits and requests
- ✅ Pod disruption handling
- ✅ Liveness & readiness probes

### Frontend
- ✅ Modern React UI
- ✅ Real-time counter updates
- ✅ Error handling
- ✅ Responsive design

## Quick Start

### Local Development

```bash
# Start all services
docker-compose up

# Access:
# - Frontend: http://localhost:3000
# - Backend API: http://localhost:8000
# - Prometheus: http://localhost:9090
# - Grafana: http://localhost:3001