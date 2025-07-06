# Exercise 04: Adding Alertmanager and Alerting

## Objective
Add Alertmanager for handling alerts from Prometheus and configure alerting rules for the adtech services using both configuration files and Grafana's UI.

## Prerequisites
- Completed Exercise 03 (Grafana visualization working)
- Basic understanding of alerting concepts
- Access to Grafana UI at http://localhost:3002

## What We'll Add
1. **Alertmanager** - Alert routing and notification management
2. **Alerting Rules** - Prometheus rules for detecting issues
3. **Grafana Alerting** - UI-based alert configuration
4. **Notification Channels** - Webhook and Slack integration
5. **Alert Dashboard** - Grafana integration for alert management

## Step 1: Add Alertmanager Service

Add the following service to your `docker-compose.yml`:

```yaml
  # Alertmanager for alert handling
  alertmanager:
    image: prom/alertmanager:latest
    ports:
      - "9093:9093"
    volumes:
      - ./monitoring/alertmanager.yml:/etc/alertmanager/alertmanager.yml
      - alertmanager-data:/alertmanager
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
      - '--web.listen-address=:9093'
    restart: unless-stopped
    networks:
      - adtech-network
```

Add the volume:
```yaml
volumes:
  postgres-data:
  tempo-data:
  grafana-storage:
  loki-data:
  alertmanager-data:
```

## Step 2: Create Alertmanager Configuration

Create `monitoring/alertmanager.yml`:

```yaml
global:
  resolve_timeout: 5m
  slack_api_url: 'https://hooks.slack.com/services/YOUR_SLACK_WEBHOOK_URL'

route:
  group_by: ['alertname', 'service']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'web.hook'
  routes:
    - match:
        severity: critical
      receiver: 'web.hook'
      continue: true
    - match:
        severity: warning
      receiver: 'web.hook'

receivers:
  - name: 'web.hook'
    webhook_configs:
      - url: 'http://localhost:5001/'
        send_resolved: true
    slack_configs:
      - channel: '#alerts'
        title: '{{ template "slack.title" . }}'
        text: '{{ template "slack.text" . }}'
        send_resolved: true

templates:
  - '/etc/alertmanager/template/*.tmpl'

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'service']
```

## Step 3: Create Alerting Rules

Create `monitoring/alerting_rules.yml`:

```yaml
groups:
  - name: adtech-service-alerts
    rules:
      # Service Down Alerts
      - alert: ServiceDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Service {{ $labels.exported_job }} is down"
          description: "Service {{ $labels.exported_job }} has been down for more than 1 minute."

      # High Error Rate
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.1
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High error rate for {{ $labels.exported_job }}"
          description: "Error rate is {{ $value }} errors per second for {{ $labels.exported_job }}"

      # High Response Time
      - alert: HighResponseTime
        expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 2
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High response time for {{ $labels.exported_job }}"
          description: "95th percentile response time is {{ $value }}s for {{ $labels.exported_job }}"

      # Low Success Rate
      - alert: LowSuccessRate
        expr: rate(http_requests_total{status=~"2.."}[5m]) / rate(http_requests_total[5m]) < 0.95
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "Low success rate for {{ $labels.exported_job }}"
          description: "Success rate is {{ $value | humanizePercentage }} for {{ $labels.exported_job }}"

  - name: bidding-service-alerts
    rules:
      # Bidding Service Specific Alerts
      - alert: BiddingServiceHighLatency
        expr: histogram_quantile(0.95, rate(bidding_request_duration_seconds_bucket[5m])) > 1
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High bidding latency"
          description: "95th percentile bidding latency is {{ $value }}s"

      - alert: BiddingServiceLowSuccessRate
        expr: rate(bidding_success_total[5m]) / rate(bidding_requests_total[5m]) < 0.6
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "Low bidding success rate"
          description: "Bidding success rate is {{ $value | humanizePercentage }}"

  - name: infrastructure-alerts
    rules:
      # Memory Usage
      - alert: HighMemoryUsage
        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes > 0.9
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage"
          description: "Memory usage is {{ $value | humanizePercentage }}"

      # Disk Usage
      - alert: HighDiskUsage
        expr: (node_filesystem_size_bytes - node_filesystem_free_bytes) / node_filesystem_size_bytes > 0.9
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High disk usage"
          description: "Disk usage is {{ $value | humanizePercentage }}"

      # CPU Usage
      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage"
          description: "CPU usage is {{ $value }}%"
```

## Step 4: Update Prometheus Configuration

Update `monitoring/prometheus.yml` to include alerting:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "alerting_rules.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

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

## Step 5: Update Prometheus Service

Update the Prometheus service in `docker-compose.yml` to mount the alerting rules:

```yaml
  # Prometheus for metrics
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
      - ./monitoring/alerting_rules.yml:/etc/prometheus/alerting_rules.yml
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

## Step 6: Restart Services

```bash
# Stop existing services
docker compose down

# Start with new configuration
docker compose up -d --build

# Check all services are running
docker compose ps
```

## Step 7: Test Basic Alerting Setup

Create `test-alerting-basic.sh`:

```bash
#!/bin/bash

echo "🚨 Testing Basic Alerting Setup..."
echo "=================================="

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 20

# Test Alertmanager
echo "1. Testing Alertmanager..."
ALERTMANAGER_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9093/-/healthy)
if [ "$ALERTMANAGER_RESPONSE" = "200" ]; then
    echo "✅ Alertmanager is healthy (HTTP $ALERTMANAGER_RESPONSE)"
else
    echo "❌ Alertmanager is not responding (HTTP $ALERTMANAGER_RESPONSE)"
fi

# Test Prometheus alerting
echo "2. Testing Prometheus alerting..."
PROM_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9090/-/healthy)
if [ "$PROM_RESPONSE" = "200" ]; then
    echo "✅ Prometheus is healthy (HTTP $PROM_RESPONSE)"
else
    echo "❌ Prometheus is not responding (HTTP $PROM_RESPONSE)"
fi

# Check if alerting rules are loaded
echo "3. Checking alerting rules..."
RULES_COUNT=$(curl -s http://localhost:9090/api/v1/rules | grep -c "alerting" || echo "0")
if [ "$RULES_COUNT" -gt 0 ]; then
    echo "✅ Alerting rules are loaded ($RULES_COUNT rule groups found)"
else
    echo "❌ No alerting rules found"
fi

# Check Alertmanager configuration
echo "4. Checking Alertmanager configuration..."
CONFIG_RESPONSE=$(curl -s http://localhost:9093/api/v1/status | grep -c "config" || echo "0")
if [ "$CONFIG_RESPONSE" -gt 0 ]; then
    echo "✅ Alertmanager configuration is valid"
else
    echo "❌ Alertmanager configuration issue"
fi

echo "=================================="
echo "🎉 Basic alerting testing complete!"

echo ""
echo "🌐 Access Points:"
echo "Alertmanager: http://localhost:9093"
echo "Prometheus Alerts: http://localhost:9090/alerts"
echo "Grafana: http://localhost:3002"

echo ""
echo "📋 Next Steps:"
echo "1. Open Alertmanager: http://localhost:9093"
echo "2. Check Prometheus Alerts: http://localhost:9090/alerts"
echo "3. Configure Grafana alerting in the UI"
```

Make it executable and run:
```bash
chmod +x test-alerting-basic.sh
./test-alerting-basic.sh
```

## Step 8: Configure Grafana Alerting

### 8.1 Access Grafana Alerting
1. **Open Grafana**: http://localhost:3002
2. **Login**: admin / admin
3. **Go to Alerting**: Click the bell icon in the sidebar

### 8.2 Create Alert Rule in Grafana UI

1. **Click "New alert rule"**
2. **Configure the rule**:
   - **Name**: "High Error Rate"
   - **Description**: "Alert when error rate is too high"
   - **Data Source**: Prometheus
   - **Query**: `rate(http_requests_total{status=~"5.."}[5m]) > 0.1`
   - **Evaluation**: Every 1m for 2m
   - **Severity**: Warning

3. **Configure notifications**:
   - **Contact point**: Create a new one
   - **Type**: Webhook
   - **URL**: `http://localhost:5001/` (for testing)

4. **Save the rule**

### 8.3 Create More Alert Rules

1. **Service Down Alert**:
   - **Query**: `up == 0`
   - **Evaluation**: Every 30s for 1m
   - **Severity**: Critical

2. **High Response Time Alert**:
   - **Query**: `histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 2`
   - **Evaluation**: Every 1m for 2m
   - **Severity**: Warning

3. **Low Success Rate Alert**:
   - **Query**: `rate(http_requests_total{status=~"2.."}[5m]) / rate(http_requests_total[5m]) < 0.95`
   - **Evaluation**: Every 1m for 2m
   - **Severity**: Warning

### 8.4 Create Contact Points

1. **Go to Contact points**
2. **Add contact point**:
   - **Name**: "Webhook"
   - **Type**: Webhook
   - **URL**: `http://localhost:5001/`
   - **HTTP Method**: POST

3. **Add Slack contact point** (optional):
   - **Name**: "Slack"
   - **Type**: Slack
   - **Webhook URL**: Your Slack webhook URL

### 8.5 Create Notification Policies

1. **Go to Notification policies**
2. **Create policy**:
   - **Name**: "Default"
   - **Group by**: `['alertname', 'service']`
   - **Timing**: Group wait 10s, group interval 10s, repeat interval 1h
   - **Contact point**: Select your webhook

## Step 9: Test Alerting by Stopping a Service

### 9.1 Test Service Down Alert
```bash
# Stop the bidding service to trigger an alert
docker compose stop bidding-service

# Wait a few minutes for the alert to fire
sleep 120

# Check for alerts in Prometheus
curl -s http://localhost:9090/api/v1/alerts | jq '.data.alerts[] | select(.state == "firing")'

# Check for alerts in Grafana
# Go to http://localhost:3002/alerting and check the Alert Rules section

# Restart the service
docker compose start bidding-service
```

### 9.2 Test High Error Rate Alert
```bash
# Generate some errors (if your service has error endpoints)
for i in {1..10}; do
    curl -s http://localhost:3001/nonexistent-endpoint || true
    sleep 0.5
done
```

## Step 10: Create Alert Dashboard

### 10.1 Create Alert Overview Dashboard
1. **Go to Dashboards** → **New Dashboard**
2. **Add Alert Panel**:
   - **Title**: "Active Alerts"
   - **Data Source**: Prometheus
   - **Query**: `ALERTS{alertstate="firing"}`
   - **Visualization**: Table

3. **Add Alert Count Panel**:
   - **Title**: "Alert Count by Severity"
   - **Data Source**: Prometheus
   - **Query**: `count by (severity) (ALERTS{alertstate="firing"})`
   - **Visualization**: Stat

4. **Save Dashboard**:
   - **Name**: "Alert Overview"
   - **Tags**: "alerts", "monitoring"

## Step 11: Test Complete Alerting Setup

Create `test-alerting-complete.sh`:

```bash
#!/bin/bash

echo "🚨 Testing Complete Alerting Setup..."
echo "====================================="

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 20

# Test all services
echo "1. Testing all services..."
ALERTMANAGER_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9093/-/healthy)
PROM_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9090/-/healthy)
GRAFANA_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3002/api/health)

echo "   Alertmanager: $([ "$ALERTMANAGER_RESPONSE" = "200" ] && echo "✅" || echo "❌") (HTTP $ALERTMANAGER_RESPONSE)"
echo "   Prometheus: $([ "$PROM_RESPONSE" = "200" ] && echo "✅" || echo "❌") (HTTP $PROM_RESPONSE)"
echo "   Grafana: $([ "$GRAFANA_RESPONSE" = "200" ] && echo "✅" || echo "❌") (HTTP $GRAFANA_RESPONSE)"

# Check alerting rules
echo "2. Checking alerting rules..."
RULES_COUNT=$(curl -s http://localhost:9090/api/v1/rules | grep -c "alerting" || echo "0")
echo "   Prometheus Rules: $([ "$RULES_COUNT" -gt 0 ] && echo "✅" || echo "❌") ($RULES_COUNT rule groups)"

# Check for active alerts
echo "3. Checking for active alerts..."
ALERTS_COUNT=$(curl -s http://localhost:9090/api/v1/alerts | grep -c "firing" || echo "0")
echo "   Active Alerts: $([ "$ALERTS_COUNT" -ge 0 ] && echo "✅" || echo "❌") ($ALERTS_COUNT firing alerts)"

# Generate some traffic
echo "4. Generating traffic..."
for i in {1..5}; do
    curl -s -X POST http://localhost:3001/bidding/calculate \
      -H "Content-Type: application/json" \
      -d "{\"ad_request_id\": \"alert-test-$i\", \"user_id\": \"user-$i\"}" > /dev/null
    sleep 0.5
done

echo "✅ Generated test traffic"

echo "====================================="
echo "🎉 Complete alerting testing finished!"

# Final Summary
echo ""
echo "📊 FINAL SUMMARY:"
echo "=================="
echo "Alertmanager: $([ "$ALERTMANAGER_RESPONSE" = "200" ] && echo "✅" || echo "❌")"
echo "Prometheus: $([ "$PROM_RESPONSE" = "200" ] && echo "✅" || echo "❌")"
echo "Grafana: $([ "$GRAFANA_RESPONSE" = "200" ] && echo "✅" || echo "❌")"
echo "Alerting Rules: $([ "$RULES_COUNT" -gt 0 ] && echo "✅" || echo "❌")"
echo "Active Alerts: $([ "$ALERTS_COUNT" -ge 0 ] && echo "✅" || echo "❌")"

echo ""
echo "🌐 Access Points:"
echo "=================="
echo "Alertmanager: http://localhost:9093"
echo "Prometheus Alerts: http://localhost:9090/alerts"
echo "Grafana Alerting: http://localhost:3002/alerting"

echo ""
echo "📋 Usage Guide:"
echo "==============="
echo "1. Open Grafana Alerting: http://localhost:3002/alerting"
echo "2. Check Alertmanager: http://localhost:9093"
echo "3. View Prometheus Alerts: http://localhost:9090/alerts"
echo "4. Test alerts by stopping services"
echo "5. Configure notification channels"
```

Make it executable and run:
```bash
chmod +x test-alerting-complete.sh
./test-alerting-complete.sh
```

## Expected Results

After completing this exercise, you should have:
- ✅ Alertmanager running and accessible
- ✅ Prometheus configured with alerting rules
- ✅ Grafana alerting configured in the UI
- ✅ Alerting rules for service health, performance, and infrastructure
- ✅ Notification channels configured
- ✅ Ability to test alerts by stopping services
- ✅ Alert dashboard for monitoring

## Key Features Demonstrated

### 1. Dual Alerting Approach
- **Prometheus Alertmanager**: Traditional rule-based alerting
- **Grafana Alerting**: Modern UI-based alert configuration

### 2. Comprehensive Alert Rules
- Service health monitoring
- Performance threshold alerts
- Business metric alerts
- Infrastructure monitoring

### 3. Notification Management
- Multiple notification channels
- Alert grouping and deduplication
- Escalation policies

## Troubleshooting

1. **Check Alertmanager logs:**
   ```bash
   docker compose logs alertmanager
   ```

2. **Check Prometheus logs:**
   ```bash
   docker compose logs prometheus
   ```

3. **Verify alerting rules:**
   ```bash
   curl http://localhost:9090/api/v1/rules
   ```

4. **Check Alertmanager configuration:**
   ```bash
   curl http://localhost:9093/api/v1/status
   ```

## Next Steps

Once alerting is working, proceed to Exercise 05 where we'll create comprehensive dashboards and finalize the observability stack.

## Cleanup

To stop all services:
```bash
docker compose down
```

To remove all data:
```bash
docker compose down -v
``` 