# Exercise 03: Adding Grafana Visualization with Trace Linking

## Objective
Add Grafana for visualizing metrics, traces, and logs from the adtech services, with special focus on trace linking functionality.

## Prerequisites
- Completed Exercise 02 (OpenTelemetry instrumentation working)
- Basic understanding of Grafana concepts

## What We'll Add
1. **Grafana** - Main visualization platform
2. **Loki** - Log aggregation with trace linking
3. **Promtail** - Log collection with trace ID extraction
4. **Dashboards** - Pre-configured visualizations with trace links
5. **Data Sources** - Connect to Prometheus, Tempo, and Loki
6. **Trace Linking** - Clickable trace IDs in logs

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

## Step 3: Create Promtail Configuration with Trace Extraction

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
      - json:
          expressions:
            level: level
            timestamp: timestamp
            caller: caller
            message: message
            user_id: user_id
            ad_type: ad_type
            ad_id: ad_id
            bid_amount: bid_amount
            duration_seconds: duration_seconds
            trace_id: trace_id
            span_id: span_id
          source: msg
      - labels:
          stream:
          tag:
          level:
          trace_id:
          span_id:
      - timestamp:
          source: timestamp
          format: RFC3339
      - template:
          source: '{{.message}} Trace: {{.trace_id}} Span: {{.span_id}}'
          template: '{{.message}} Trace: {{.trace_id}} Span: {{.span_id}}'
      - output:
          source: template
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
    uid: PBFA97CFB590B2093
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    jsonData:
      exemplarTraceIdDestinations:
        - datasourceUid: P214B5B846CF3925F
          name: trace_id
        - url: http://localhost:3200/trace/$${__value.raw}
          name: trace_id
          urlDisplayLabel: View in Tempo UI
    
  - name: Tempo
    type: tempo
    uid: P214B5B846CF3925F
    access: proxy
    url: http://tempo:3200
    jsonData:
      httpMethod: GET
      serviceMap:
        datasourceUid: PBFA97CFB590B2093
      
  - name: Loki
    type: loki
    uid: P8E80F9AEF21F6940
    access: proxy
    url: http://loki:3100
    jsonData:
      maxLines: 1000
      derivedFields:
        # Simple trace linking to Tempo UI
        - datasourceUid: P214B5B846CF3925F
          datasourceName: Tempo
          matcherRegex: "Trace: ([a-zA-Z0-9]+)"
          name: Trace
          url: "$${__value.raw}"

  - name: Alertmanager
    type: alertmanager
    uid: alertmanager
    access: proxy
    url: http://alertmanager:9093
    jsonData:
      implementation: prometheus
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

## Step 5: Restart Services

```bash
# Stop existing services
docker compose down

# Start with new configuration
docker compose up -d --build

# Check all services are running
docker compose ps
```

## Step 6: Test Basic Setup

Create `test-grafana-basic.sh`:

```bash
#!/bin/bash

echo "📊 Testing Basic Grafana Setup..."
echo "================================="

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

# Generate some logs with trace IDs
echo "4. Generating logs with trace IDs..."
for i in {1..5}; do
    curl -s -X POST http://localhost:3001/bidding/calculate \
      -H "Content-Type: application/json" \
      -d "{\"ad_request_id\": \"log-test-$i\", \"user_id\": \"user-$i\"}" > /dev/null
    sleep 1
done

echo "✅ Generated test logs"

echo "================================="
echo "🎉 Basic Grafana testing complete!"

echo ""
echo "🌐 Access Points:"
echo "Grafana: http://localhost:3002 (admin/admin)"
echo "Loki: http://localhost:3100"
echo "Promtail: http://localhost:9080/metrics"

echo ""
echo "📋 Next Steps:"
echo "1. Open Grafana: http://localhost:3002"
echo "2. Login with admin/admin"
echo "3. Go to Configuration → Data Sources to verify connections"
echo "4. Proceed to create dashboards in the UI"
```

Make it executable and run:
```bash
chmod +x test-grafana-basic.sh
./test-grafana-basic.sh
```

## Step 7: Create Dashboards in Grafana UI

### 7.1 Access Grafana
1. **Open Grafana**: http://localhost:3002
2. **Login**: admin / admin
3. **Verify Data Sources**: Go to Configuration → Data Sources
   - Prometheus should be configured
   - Tempo should be configured  
   - Loki should be configured

### 7.2 Create Service Overview Dashboard

1. **Go to Dashboards** → **New Dashboard**
2. **Add Panel** → **Add a new panel**
3. **Configure the first panel**:
   - **Title**: "Service Health"
   - **Data Source**: Prometheus
   - **Query**: `up`
   - **Visualization**: Stat
   - **Field**: Configure thresholds (0 = red, 1 = green)
   - **Mappings**: 0 → "Down", 1 → "Up"

4. **Add second panel**:
   - **Title**: "Request Rate"
   - **Data Source**: Prometheus
   - **Query**: `rate(http_requests_total[5m])`
   - **Visualization**: Time series
   - **Y-axis**: Unit = "reqps"

5. **Add third panel**:
   - **Title**: "Response Time (95th percentile)"
   - **Data Source**: Prometheus
   - **Query**: `histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))`
   - **Visualization**: Time series
   - **Y-axis**: Unit = "s"

6. **Add fourth panel**:
   - **Title**: "Error Rate"
   - **Data Source**: Prometheus
   - **Query**: `rate(http_requests_total{status=~"5.."}[5m])`
   - **Visualization**: Time series
   - **Y-axis**: Unit = "reqps"

7. **Save Dashboard**:
   - **Name**: "AdTech Services Overview"
   - **Tags**: adtech, overview
   - **Time Range**: Last 1 hour
   - **Refresh**: 5s

### 7.3 Create Logs Dashboard with Trace Links

1. **Create New Dashboard**
2. **Add Log Panel**:
   - **Title**: "Application Logs with Trace Links"
   - **Data Source**: Loki
   - **Query**: `{tag="grafotel-$service-1"} |= `` | json | line_format `{{.message}} Trace: {{.trace_id}} Span: {{.span_id}}``
   - **Visualization**: Logs
   - **Options**: Enable "Show time", "Show labels"

3. **Add Error Logs Panel**:
   - **Title**: "Error Logs"
   - **Data Source**: Loki
   - **Query**: `{tag="grafotel-$service-1"} |= "error" | json`
   - **Visualization**: Logs

4. **Add Trace Logs Panel**:
   - **Title**: "Logs with Trace IDs"
   - **Data Source**: Loki
   - **Query**: `{tag="grafotel-$service-1"} |= "trace_id" | json | line_format `{{.message}} Trace: {{.trace_id}} Span: {{.span_id}}``
   - **Visualization**: Logs

5. **Save Dashboard**:
   - **Name**: "Application Logs with Trace Links"
   - **Tags**: adtech, logs, traces

### 7.4 Test Trace Linking

1. **Generate traffic with trace IDs**:
   ```bash
   curl -X POST http://localhost:3001/bidding/calculate \
     -H "Content-Type: application/json" \
     -d '{"ad_request_id": "trace-test-123", "user_id": "user-456"}'
   ```

2. **Check the logs dashboard**:
   - Look for logs with "Trace:" in the message
   - The trace ID should appear as a clickable link
   - Click the link to open the trace in Tempo

## Step 8: Export Dashboards as JSON

### 8.1 Export Service Overview Dashboard
1. Open the "AdTech Services Overview" dashboard
2. Click the **Settings** icon (gear) in the top right
3. Click **JSON Model**
4. Copy the entire JSON content
5. Create file: `monitoring/grafana/dashboards/service-overview.json`
6. Paste the JSON content

### 8.2 Export Logs Dashboard
1. Open the "Application Logs with Trace Links" dashboard
2. Go to Settings → JSON Model
3. Copy the JSON content
4. Create file: `monitoring/grafana/dashboards/logs.json`
5. Paste the JSON content

## Step 9: Create Additional Dashboards

### 9.1 Create Bidding Service Dashboard

1. **Create New Dashboard** in Grafana UI
2. **Add panels for bidding metrics**:
   - Bidding request rate
   - Bidding success rate
   - Bidding latency
   - Bid amounts distribution

3. **Save and export** as `monitoring/grafana/dashboards/bidding-service.json`

### 9.2 Create Infrastructure Dashboard

1. **Create New Dashboard** in Grafana UI
2. **Add panels for infrastructure**:
   - CPU usage
   - Memory usage
   - Disk usage
   - Network traffic

3. **Save and export** as `monitoring/grafana/dashboards/infrastructure.json`

## Step 10: Test Complete Setup

Create `test-grafana-complete.sh`:

```bash
#!/bin/bash

echo "📊 Testing Complete Grafana Setup..."
echo "===================================="

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 20

# Test all services
echo "1. Testing all services..."
GRAFANA_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3002/api/health)
LOKI_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3100/ready)
PROMTAIL_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9080/metrics)
PROM_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9090/-/healthy)
TEMPO_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3200/ready)

echo "   Grafana: $([ "$GRAFANA_RESPONSE" = "200" ] && echo "✅" || echo "❌") (HTTP $GRAFANA_RESPONSE)"
echo "   Loki: $([ "$LOKI_RESPONSE" = "200" ] && echo "✅" || echo "❌") (HTTP $LOKI_RESPONSE)"
echo "   Promtail: $([ "$PROMTAIL_RESPONSE" = "200" ] && echo "✅" || echo "❌") (HTTP $PROMTAIL_RESPONSE)"
echo "   Prometheus: $([ "$PROM_RESPONSE" = "200" ] && echo "✅" || echo "❌") (HTTP $PROM_RESPONSE)"
echo "   Tempo: $([ "$TEMPO_RESPONSE" = "200" ] && echo "✅" || echo "❌") (HTTP $TEMPO_RESPONSE)"

# Generate comprehensive test traffic
echo "2. Generating test traffic..."
for i in {1..10}; do
    curl -s -X POST http://localhost:3001/bidding/calculate \
      -H "Content-Type: application/json" \
      -d "{\"ad_request_id\": \"complete-test-$i\", \"user_id\": \"user-$i\"}" > /dev/null
    sleep 0.5
done

echo "✅ Generated test traffic"

# Test data collection
echo "3. Testing data collection..."
METRICS_COUNT=$(curl -s http://localhost:9464/metrics | grep -c "bidding_requests_total" || echo "0")
LOG_COUNT=$(curl -s "http://localhost:3100/loki/api/v1/labels" | grep -c "container_name" || echo "0")

echo "   Metrics Collection: $([ "$METRICS_COUNT" -gt 0 ] && echo "✅" || echo "❌") ($METRICS_COUNT metrics found)"
echo "   Log Collection: $([ "$LOG_COUNT" -gt 0 ] && echo "✅" || echo "❌") (logs available)"

echo "===================================="
echo "🎉 Complete Grafana testing finished!"

# Final Summary
echo ""
echo "📊 FINAL SUMMARY:"
echo "=================="
echo "Grafana: $([ "$GRAFANA_RESPONSE" = "200" ] && echo "✅" || echo "❌")"
echo "Loki: $([ "$LOKI_RESPONSE" = "200" ] && echo "✅" || echo "❌")"
echo "Promtail: $([ "$PROMTAIL_RESPONSE" = "200" ] && echo "✅" || echo "❌")"
echo "Prometheus: $([ "$PROM_RESPONSE" = "200" ] && echo "✅" || echo "❌")"
echo "Tempo: $([ "$TEMPO_RESPONSE" = "200" ] && echo "✅" || echo "❌")"
echo "Data Collection: $([ "$METRICS_COUNT" -gt 0 ] && [ "$LOG_COUNT" -gt 0 ] && echo "✅" || echo "❌")"

echo ""
echo "🌐 Access Points:"
echo "=================="
echo "Grafana (Main UI): http://localhost:3002 (admin/admin)"
echo "Prometheus: http://localhost:9090"
echo "Tempo: http://localhost:3200"
echo "Loki: http://localhost:3100"

echo ""
echo "📋 Usage Guide:"
echo "==============="
echo "1. Open Grafana: http://localhost:3002"
echo "2. Go to Dashboards to see your created dashboards"
echo "3. Check the logs dashboard for trace links"
echo "4. Click on trace IDs to open traces in Tempo"
echo "5. Use Explore to query metrics, traces, and logs"
echo "6. Create additional dashboards as needed"
```

Make it executable and run:
```bash
chmod +x test-grafana-complete.sh
./test-grafana-complete.sh
```

## Expected Results

After completing this exercise, you should have:
- ✅ Grafana running with admin access
- ✅ Loki collecting logs from all services
- ✅ Promtail extracting trace IDs from logs
- ✅ Data sources configured (Prometheus, Tempo, Loki)
- ✅ Dashboards created in the UI
- ✅ Trace linking working in logs
- ✅ Ability to click trace IDs to open traces in Tempo

## Key Features Demonstrated

### 1. Trace Linking in Logs
- Logs show trace IDs in format: `message Trace: <trace_id> Span: <span_id>`
- Trace IDs are clickable links
- Links open the trace in Tempo UI

### 2. UI-First Dashboard Creation
- Create dashboards using Grafana's intuitive UI
- Export dashboards as JSON for version control
- Organize dashboards with tags and folders

### 3. Comprehensive Monitoring
- Service health monitoring
- Performance metrics
- Error tracking
- Log analysis with trace correlation

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

4. **Verify trace linking:**
   - Check that logs contain "Trace:" format
   - Verify derived fields configuration
   - Test clicking trace links

## Next Steps

Once Grafana is working with trace linking, proceed to Exercise 04 where we'll add Alertmanager for alerting.

## Cleanup

To stop all services:
```bash
docker compose down
```

To remove all data:
```bash
docker compose down -v
``` 