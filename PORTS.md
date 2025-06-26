# Port Assignment Guide

This document outlines all port assignments for the Ad-Tech Microservices Training setup to avoid conflicts.

## Infrastructure Services (Docker)

| Service | Port | Purpose | Internal Port |
|---------|------|---------|---------------|
| Grafana | 3002 | Main observability interface | 3000 |
| Tempo UI | 3200 | Distributed tracing UI | 3200 |
| Tempo OTLP gRPC | 4327 | Trace ingestion (gRPC) | 4317 |
| Tempo OTLP HTTP | 4328 | Trace ingestion (HTTP) | 4318 |
| Loki | 3100 | Log aggregation | 3100 |
| Prometheus | 9090 | Metrics collection | 9090 |
| Alertmanager | 9093 | Alert management | 9093 |
| OpenTelemetry Collector gRPC | 4317 | Telemetry ingestion (gRPC) | 4317 |
| OpenTelemetry Collector HTTP | 4318 | Telemetry ingestion (HTTP) | 4318 |
| PostgreSQL | 5444 | Database | 5432 |
| Redis | 6380 | Caching | 6379 |

## Application Services

| Service | Port | Purpose |
|---------|------|---------|
| Ad Service (Go) | 8080 | Core ad management |
| Analytics Service (Rails) | 3000 | Analytics and reporting |
| Bidding Service (Node.js) | 3001 | Real-time bidding |

## Data Flow

```
Services → OpenTelemetry Collector (4317/4318) → Tempo (4327/4328) → Grafana
Services → Prometheus (9090) → Alertmanager (9093) → Grafana
Services → Loki (3100) → Grafana
```

## Service Configuration

### Ad Service (Go)
- Sends traces to: `localhost:4317` (gRPC)
- Sends metrics to: `localhost:4317` (gRPC)

### Bidding Service (Node.js)
- Sends traces to: `localhost:4318` (HTTP)
- Sends metrics to: `localhost:4318` (HTTP)

### Analytics Service (Rails)
- Sends traces to: `localhost:4317` (gRPC)
- Sends metrics to: `localhost:4317` (gRPC)

## Conflict Resolution

All ports have been carefully chosen to avoid conflicts:

1. **Tempo vs OpenTelemetry Collector**: Tempo uses 4327/4328, Collector uses 4317/4318
2. **PostgreSQL**: Uses 5444 instead of default 5432
3. **Redis**: Uses 6380 instead of default 6379
4. **Application Services**: Use standard ports 3000, 3001, 8080
5. **Infrastructure Services**: Use non-standard ports where needed

## Troubleshooting

If you encounter port conflicts:

1. Check if any services are already running on these ports
2. Use `netstat -an | grep :<port>` to check port usage
3. Stop conflicting services or modify port assignments in docker compose.yml
4. Update service configurations if port assignments change

## Environment Variables

You can override port assignments using environment variables:

```bash
# For services
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318/v1/traces
export DATABASE_PORT=5444
export REDIS_PORT=6380

# For Docker Compose
export COMPOSE_PROJECT_NAME=adtech-training
``` 