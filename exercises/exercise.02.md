# Exercise 02: Adding OpenTelemetry Instrumentation

## Objective
Add OpenTelemetry instrumentation to collect traces, metrics, and logs from the adtech services.

## Prerequisites
- Completed Exercise 01 (all services running)
- Basic understanding of observability concepts

## What We'll Add
1. **OpenTelemetry Collector** - Central telemetry collection
2. **Tempo** - Distributed tracing backend
3. **Prometheus** - Metrics collection
4. **Instrumentation** - Add telemetry to all services

## Step 1: Update Docker Compose

Add the following services to your `docker-compose.yml`:

```yaml
  # OpenTelemetry Collector
  otel-collector:
    image: otel/opentelemetry-collector-contrib:latest
    ports:
      - "4317:4317"   # OTLP gRPC
      - "4318:4318"   # OTLP HTTP
      - "9464:9464"   # Prometheus metrics
    volumes:
      - ./monitoring/otel-collector-config.yml:/etc/otelcol/config.yml
    command: ["--config", "/etc/otelcol/config.yml"]
    restart: unless-stopped
    networks:
      - adtech-network

  # Tempo for distributed tracing
  tempo:
    image: grafana/tempo:latest
    command: [ "-config.file=/etc/tempo.yaml" ]
    volumes:
      - ./monitoring/tempo.yaml:/etc/tempo.yaml
      - tempo-data:/var/tempo
    ports:
      - "3200:3200"   # tempo
      - "4327:4317"   # otlp grpc
      - "4328:4318"   # otlp http
    networks:
      - adtech-network

  # Prometheus for metrics
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=200h'
      - '--web.enable-lifecycle'
    networks:
      - adtech-network
```

Add the volume:
```yaml
volumes:
  postgres-data:
  tempo-data:
```

## Step 2: Create OpenTelemetry Collector Configuration

Create `monitoring/otel-collector-config.yml`:

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318
  prometheus:
    config:
      scrape_configs:
        - job_name: 'ad-service'
          scrape_interval: 10s
          static_configs:
            - targets: ['ad-service:8080']
          metrics_path: '/metrics'
        - job_name: 'analytics-service'
          scrape_interval: 10s
          static_configs:
            - targets: ['analytics-service:3000']
          metrics_path: '/metrics'
        - job_name: 'bidding-service'
          scrape_interval: 10s
          static_configs:
            - targets: ['bidding-service:3001']
          metrics_path: '/metrics'

processors:
  batch:
    timeout: 1s
    send_batch_size: 1024
  attributes:
    actions:
      - key: db.statement
        action: delete
      - key: db.system
        action: delete

exporters:
  otlp/tempo:
    endpoint: tempo:4327
    tls:
      insecure: true
  prometheus:
    endpoint: "0.0.0.0:9464"
    const_labels:
      label1: value1
    send_timestamps: true
    metric_expiration: 180m
    enable_open_metrics: true
  debug:

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch, attributes]
      exporters: [otlp/tempo, debug]
    metrics:
      receivers: [otlp, prometheus]
      processors: [batch]
      exporters: [prometheus]
    logs:
      receivers: [otlp]
      processors: [batch, attributes]
      exporters: [debug] 
```

## Step 3: Create Tempo Configuration

Create `monitoring/tempo.yaml`:

```yaml
server:
  http_listen_port: 3200

distributor:
  receivers:
    otlp:
      protocols:
        grpc:
        http:

ingester:
  max_block_bytes: 1_000_000
  max_block_duration: 5m

compactor:
  compaction:
    compaction_window: 1h
    max_block_bytes: 100_000_000
    block_retention: 1h
    compacted_block_retention: 10m

storage:
  trace:
    backend: local
    wal:
      path: /var/tempo/wal
    local:
      path: /var/tempo/blocks

metrics_generator:
  registry:
    external_labels:
      source: tempo
      cluster: docker-compose
  storage:
    path: /var/tempo/generator/wal
    remote_write:
      - url: http://prometheus:9090/api/v1/write
        send_exemplars: true
```

## Step 4: Create Prometheus Configuration

Create `monitoring/prometheus.yml`:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  # Prometheus itself
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # OpenTelemetry Collector (aggregates all service metrics)
  - job_name: 'otel-collector'
    static_configs:
      - targets: ['otel-collector:9464']
    metrics_path: '/metrics'
    scrape_interval: 5s
```

## Step 5: Update Service Environment Variables

Update your services in `docker-compose.yml` to include OpenTelemetry configuration:

### Ad Service
```yaml
  ad-service:
    # ... existing config ...
    environment:
      - OTEL_EXPORTER_OTLP_ENDPOINT=otel-collector:4317
      - OTEL_SERVICE_NAME=ad-service
      - OTEL_TRACES_SAMPLER=always_on
      - OTEL_METRICS_EXPORTER=otlp
      - OTEL_LOGS_EXPORTER=otlp
      - ANALYTICS_SERVICE_URL=http://analytics-service:3000
      - BIDDING_SERVICE_URL=http://bidding-service:3001
```

### Analytics Service
```yaml
  analytics-service:
    # ... existing config ...
    environment:
      - RAILS_ENV=development
      - DATABASE_HOST=postgres
      - DATABASE_PORT=5432
      - DATABASE_USERNAME=postgres
      - DATABASE_PASSWORD=password
      - OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318
      - OTEL_LOG_LEVEL=DEBUG
      - OTEL_TRACES_SAMPLER=always_on
      - OTEL_TRACES_SAMPLER_ARG=1.0
      - OTEL_METRICS_EXPORTER=otlp
      - OTEL_LOGS_EXPORTER=otlp
      - AD_SERVICE_URL=http://ad-service:8080
      - BINDING=0.0.0.0
      - PORT=3000
      - RAILS_SERVE_STATIC_FILES=true
      - RAILS_LOG_TO_STDOUT=true
```

### Bidding Service
```yaml
  bidding-service:
    # ... existing config ...
    environment:
      - OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318/v1/traces
      - OTEL_SERVICE_NAME=bidding-service
      - OTEL_TRACES_SAMPLER=always_on
      - OTEL_METRICS_EXPORTER=otlp
      - OTEL_LOGS_EXPORTER=otlp
      - ANALYTICS_SERVICE_URL=http://analytics-service:3000
```

## Step 6: Restart Services

```bash
# Stop existing services
docker compose down

# Start with new configuration
docker compose up -d --build

# Check all services are running
docker compose ps
```

## Step 7: Test Telemetry Collection

Create `test-telemetry.sh`:

```bash
#!/bin/bash

echo "🔍 Testing OpenTelemetry Collection..."
echo "====================================="

# Wait for services to be ready
sleep 15

# Test OpenTelemetry Collector
echo "1. Testing OpenTelemetry Collector..."
OTEL_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9464/metrics)
if [ "$OTEL_RESPONSE" = "200" ]; then
    echo "✅ OpenTelemetry Collector is healthy (HTTP $OTEL_RESPONSE)"
else
    echo "❌ OpenTelemetry Collector is not responding (HTTP $OTEL_RESPONSE)"
fi

# Test Tempo
echo "2. Testing Tempo..."
TEMPO_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3200/ready)
if [ "$TEMPO_RESPONSE" = "200" ]; then
    echo "✅ Tempo is ready (HTTP $TEMPO_RESPONSE)"
else
    echo "❌ Tempo is not ready (HTTP $TEMPO_RESPONSE)"
fi

# Test Prometheus
echo "3. Testing Prometheus..."
PROM_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9090/-/healthy)
if [ "$PROM_RESPONSE" = "200" ]; then
    echo "✅ Prometheus is healthy (HTTP $PROM_RESPONSE)"
else
    echo "❌ Prometheus is not responding (HTTP $PROM_RESPONSE)"
fi

# Generate some traffic to create traces
echo "4. Generating traffic for traces..."
for i in {1..5}; do
    curl -s -X POST http://localhost:3001/bidding/calculate \
      -H "Content-Type: application/json" \
      -d "{\"ad_request_id\": \"test-$i\", \"user_id\": \"user-$i\"}" > /dev/null
    sleep 1
done

echo "✅ Generated test traffic"

# Check if metrics are being collected
echo "5. Checking metrics collection..."
METRICS_COUNT=$(curl -s http://localhost:9464/metrics | grep -c "bidding_requests_total" || echo "0")
if [ "$METRICS_COUNT" -gt 0 ]; then
    echo "✅ Metrics are being collected ($METRICS_COUNT bidding metrics found)"
else
    echo "❌ No metrics found"
fi

echo "====================================="
echo "🎉 Telemetry testing complete!"
```

Make it executable and run:
```bash
chmod +x test-telemetry.sh
./test-telemetry.sh
```

## Step 8: Verify Data Collection

### Check Prometheus Targets
Visit http://localhost:9090/targets to see if all services are being scraped.

### Check Tempo
Visit http://localhost:3200 to see the Tempo UI and check for traces.

### Check OpenTelemetry Collector Metrics
Visit http://localhost:9464/metrics to see collector metrics.

## Expected Results

After completing this exercise, you should have:
- ✅ OpenTelemetry Collector running and collecting telemetry
- ✅ Tempo receiving and storing traces
- ✅ Prometheus collecting metrics from all services
- ✅ Services instrumented with OpenTelemetry
- ✅ Traces flowing between services

## Troubleshooting

1. **Check collector logs:**
   ```bash
   docker compose logs otel-collector
   ```

2. **Check service logs for telemetry errors:**
   ```bash
   docker compose logs ad-service
   docker compose logs analytics-service
   docker compose logs bidding-service
   ```

3. **Verify network connectivity:**
   ```bash
   docker compose exec otel-collector ping tempo
   docker compose exec otel-collector ping prometheus
   ```

## Next Steps

Once telemetry collection is working, proceed to Exercise 03 where we'll add Grafana for visualization.

## Cleanup

To stop all services:
```bash
docker compose down
```

To remove all data:
```bash
docker compose down -v
``` 
