# Exercise 03: Adding Grafana Visualization

## Objective
Add Grafana for visualizing metrics, traces, and logs from the adtech services.

## Prerequisites
- Completed Exercise 02 (OpenTelemetry instrumentation working)
- Basic understanding of Grafana concepts

## What We'll Add
1. **Grafana** - Main visualization platform
2. **Loki** - Log aggregation
3. **Promtail** - Log collection
4. **Dashboards** - Pre-configured visualizations
5. **Data Sources** - Connect to Prometheus, Tempo, and Loki

## Step 1: Add Grafana and Loki Services

Add the following services to your `docker-compose.yml`:

```yaml
  # Grafana for visualization
  grafana:
    image: grafana/grafana:latest
    ports:
      - "3002:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_ALLOW_SIGN_UP=false
    volumes:
      - grafana-storage:/var/lib/grafana
      - ./monitoring/grafana/provisioning:/etc/grafana/provisioning
      - ./monitoring/grafana/dashboards:/var/lib/grafana/dashboards
    networks:
      - adtech-network

  # Loki for log aggregation
  loki:
    image: grafana/loki:latest
    ports:
      - "3100:3100"
    command: -config.file=/etc/loki/local-config.yaml
    volumes:
      - ./monitoring/loki-config.yaml:/etc/loki/local-config.yaml
      - loki-data:/loki
    networks:
      - adtech-network

  # Promtail for log collection
  promtail:
    image: grafana/promtail:latest
    volumes:
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
      - ./monitoring/promtail-config.yml:/etc/promtail/config.yml
    command: -config.file=/etc/promtail/config.yml
    restart: unless-stopped
    networks:
      - adtech-network
```

Add the volumes:
```yaml
volumes:
  postgres-data:
  tempo-data:
  grafana-storage:
  loki-data:
```

## Step 2: Create Loki Configuration

Create `monitoring/loki-config.yaml`:

```yaml
auth_enabled: false

server:
  http_listen_port: 3100

ingester:
  lifecycler:
    address: 127.0.0.1
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
    final_sleep: 0s
  chunk_idle_period: 5m
  chunk_retain_period: 30s
  wal:
    dir: /loki/wal

schema_config:
  configs:
    - from: 2020-05-15
      store: boltdb
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

storage_config:
  boltdb:
    directory: /loki/index

  filesystem:
    directory: /loki/chunks

limits_config:
  reject_old_samples: true
  reject_old_samples_max_age: 168h
  allow_structured_metadata: false

table_manager:
  retention_deletes_enabled: false
  retention_period: 0s
```

## Step 3: Create Promtail Configuration

Create `monitoring/promtail-config.yml`:

```yaml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: docker
    static_configs:
      - targets:
          - localhost
        labels:
          job: docker
          __path__: /var/lib/docker/containers/*/*.log
    pipeline_stages:
      - json:
          expressions:
            stream: stream
            attrs: attrs
            tag: attrs.tag
            time: time
            level: attrs.level
            msg: log
      - labels:
          stream:
          tag:
          level:
      - timestamp:
          source: time
          format: RFC3339Nano
      - output:
          source: msg
```

## Step 4: Create Grafana Provisioning

Create the directory structure:
```bash
mkdir -p monitoring/grafana/provisioning/datasources
mkdir -p monitoring/grafana/provisioning/dashboards
mkdir -p monitoring/grafana/dashboards
```

### Create Data Sources Configuration

Create `monitoring/grafana/provisioning/datasources/prometheus.yml`:

```yaml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    
  - name: Tempo
    type: tempo
    access: proxy
    url: http://tempo:3200
    jsonData:
      httpMethod: GET
      serviceMap:
        datasourceUid: prometheus
      
  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    jsonData:
      maxLines: 1000
```

### Create Dashboard Configuration

Create `monitoring/grafana/provisioning/dashboards/dashboards.yml`:

```yaml
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
```

## Step 5: Create Sample Dashboards

### Create AdTech Overview Dashboard

Create `monitoring/grafana/dashboards/adtech-overview.json`:

```json
{
  "dashboard": {
    "id": null,
    "title": "AdTech Services Overview",
    "tags": ["adtech", "overview"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "Service Health",
        "type": "stat",
        "targets": [
          {
            "expr": "up",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "color": {
              "mode": "thresholds"
            },
            "thresholds": {
              "steps": [
                {"color": "red", "value": 0},
                {"color": "green", "value": 1}
              ]
            }
          }
        }
      },
      {
        "id": 2,
        "title": "Request Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(http_requests_total[5m])",
            "refId": "A"
          }
        ]
      },
      {
        "id": 3,
        "title": "Response Time",
        "type": "graph",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))",
            "refId": "A"
          }
        ]
      }
    ],
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "refresh": "5s"
  }
}
```

## Step 6: Update Prometheus Configuration

Update `monitoring/prometheus.yml` to include Loki:

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
      - targets: ['host.docker.internal:9464']
    metrics_path: '/metrics'
    scrape_interval: 5s

  # Promtail
  - job_name: 'promtail'
    static_configs:
      - targets: ['host.docker.internal:9080']
    metrics_path: '/metrics'
```

## Step 7: Restart Services

```bash
# Stop existing services
docker compose down

# Start with new configuration
docker compose up -d --build

# Check all services are running
docker compose ps
```

## Step 8: Test Grafana Setup

Create `test-grafana.sh`:

```bash
#!/bin/bash

echo "📊 Testing Grafana Setup..."
echo "============================"

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 20

# Test Grafana
echo "1. Testing Grafana..."
GRAFANA_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3002/api/health)
if [ "$GRAFANA_RESPONSE" = "200" ]; then
    echo "✅ Grafana is healthy (HTTP $GRAFANA_RESPONSE)"
else
    echo "❌ Grafana is not responding (HTTP $GRAFANA_RESPONSE)"
fi

# Test Loki
echo "2. Testing Loki..."
LOKI_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3100/ready)
if [ "$LOKI_RESPONSE" = "200" ]; then
    echo "✅ Loki is ready (HTTP $LOKI_RESPONSE)"
else
    echo "❌ Loki is not ready (HTTP $LOKI_RESPONSE)"
fi

# Test Promtail
echo "3. Testing Promtail..."
PROMTAIL_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9080/metrics)
if [ "$PROMTAIL_RESPONSE" = "200" ]; then
    echo "✅ Promtail is healthy (HTTP $PROMTAIL_RESPONSE)"
else
    echo "❌ Promtail is not responding (HTTP $PROMTAIL_RESPONSE)"
fi

# Generate some logs
echo "4. Generating logs..."
for i in {1..3}; do
    curl -s -X POST http://localhost:3001/bidding/calculate \
      -H "Content-Type: application/json" \
      -d "{\"ad_request_id\": \"log-test-$i\", \"user_id\": \"user-$i\"}" > /dev/null
    sleep 1
done

echo "✅ Generated test logs"

# Check if logs are in Loki
echo "5. Checking log collection..."
LOG_COUNT=$(curl -s "http://localhost:3100/loki/api/v1/labels" | grep -c "container_name" || echo "0")
if [ "$LOG_COUNT" -gt 0 ]; then
    echo "✅ Logs are being collected by Loki"
else
    echo "⚠️  No logs found in Loki (this might be normal for new setup)"
fi

echo "============================"
echo "🎉 Grafana testing complete!"

# Summary
echo ""
echo "📊 Summary:"
echo "Grafana: $([ "$GRAFANA_RESPONSE" = "200" ] && echo "✅" || echo "❌")"
echo "Loki: $([ "$LOKI_RESPONSE" = "200" ] && echo "✅" || echo "❌")"
echo "Promtail: $([ "$PROMTAIL_RESPONSE" = "200" ] && echo "✅" || echo "❌")"
echo "Log Collection: $([ "$LOG_COUNT" -gt 0 ] && echo "✅" || echo "❌")"

echo ""
echo "🌐 Access Points:"
echo "Grafana: http://localhost:3002 (admin/admin)"
echo "Loki: http://localhost:3100"
echo "Promtail: http://localhost:9080/metrics"
```

Make it executable and run:
```bash
chmod +x test-grafana.sh
./test-grafana.sh
```

## Step 9: Access Grafana

1. **Open Grafana**: http://localhost:3002
2. **Login**: admin / admin
3. **Navigate to Explore** to query:
   - **Prometheus**: Metrics queries
   - **Tempo**: Trace queries
   - **Loki**: Log queries

## Step 10: Create Custom Queries

### Prometheus Queries
```
# Request rate by service
rate(http_requests_total[5m])

# Error rate
rate(http_requests_total{status=~"5.."}[5m])

# Response time 95th percentile
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```

### Loki Queries
```
# All logs
{job="docker"}

# Error logs
{job="docker"} |= "error"

# Service-specific logs
{container_name="grafotel-bidding-service-1"}
```

### Tempo Queries
```
# Find traces by service
{service.name="bidding-service"}

# Find traces by operation
{operation="calculate_bid"}
```

## Expected Results

After completing this exercise, you should have:
- ✅ Grafana running with admin access
- ✅ Loki collecting logs from all services
- ✅ Promtail forwarding logs to Loki
- ✅ Data sources configured (Prometheus, Tempo, Loki)
- ✅ Basic dashboards available
- ✅ Ability to query metrics, traces, and logs

## Troubleshooting

1. **Check Grafana logs:**
   ```bash
   docker compose logs grafana
   ```

2. **Check Loki logs:**
   ```bash
   docker compose logs loki
   ```

3. **Check Promtail logs:**
   ```bash
   docker compose logs promtail
   ```

4. **Verify data sources in Grafana:**
   - Go to Configuration → Data Sources
   - Check if Prometheus, Tempo, and Loki are connected

## Next Steps

Once Grafana is working, proceed to Exercise 04 where we'll add Alertmanager for alerting.

## Cleanup

To stop all services:
```bash
docker compose down
```

To remove all data:
```bash
docker compose down -v
``` 