# Exercise 04: Adding Alertmanager and Alerting

## Objective
Add Alertmanager for handling alerts from Prometheus and configure alerting rules for the adtech services.

## Prerequisites
- Completed Exercise 03 (Grafana visualization working)
- Basic understanding of alerting concepts

## What We'll Add
1. **Alertmanager** - Alert routing and notification management
2. **Alerting Rules** - Prometheus rules for detecting issues
3. **Notification Channels** - Webhook and Slack integration
4. **Alert Dashboard** - Grafana integration for alert management

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

## Step 6: Add Alertmanager to Grafana Data Sources

Update `monitoring/grafana/provisioning/datasources/prometheus.yml`:

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

  - name: Alertmanager
    type: alertmanager
    access: proxy
    url: http://alertmanager:9093
    jsonData:
      implementation: prometheus
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

## Step 8: Test Alerting Setup

Create `test-alerting.sh`:

```bash
#!/bin/bash

echo "🚨 Testing Alerting Setup..."
echo "============================"

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

# Generate some traffic to potentially trigger alerts
echo "5. Generating traffic for alert testing..."
for i in {1..10}; do
    curl -s -X POST http://localhost:3001/bidding/calculate \
      -H "Content-Type: application/json" \
      -d "{\"ad_request_id\": \"alert-test-$i\", \"user_id\": \"user-$i\"}" > /dev/null
    sleep 0.5
done

echo "✅ Generated test traffic"

# Check for active alerts
echo "6. Checking for active alerts..."
ALERTS_COUNT=$(curl -s http://localhost:9090/api/v1/alerts | grep -c "firing" || echo "0")
if [ "$ALERTS_COUNT" -gt 0 ]; then
    echo "⚠️  Active alerts found ($ALERTS_COUNT firing alerts)"
else
    echo "✅ No active alerts (this is good for a healthy system)"
fi

echo "============================"
echo "🎉 Alerting testing complete!"

# Summary
echo ""
echo "📊 Summary:"
echo "Alertmanager: $([ "$ALERTMANAGER_RESPONSE" = "200" ] && echo "✅" || echo "❌")"
echo "Prometheus: $([ "$PROM_RESPONSE" = "200" ] && echo "✅" || echo "❌")"
echo "Alerting Rules: $([ "$RULES_COUNT" -gt 0 ] && echo "✅" || echo "❌")"
echo "Alertmanager Config: $([ "$CONFIG_RESPONSE" -gt 0 ] && echo "✅" || echo "❌")"
echo "Active Alerts: $([ "$ALERTS_COUNT" -gt 0 ] && echo "⚠️" || echo "✅")"

echo ""
echo "🌐 Access Points:"
echo "Alertmanager: http://localhost:9093"
echo "Prometheus Alerts: http://localhost:9090/alerts"
echo "Grafana Alerting: http://localhost:3002/alerting"

echo ""
echo "📋 Next Steps:"
echo "1. Open Alertmanager: http://localhost:9093"
echo "2. Check Prometheus Alerts: http://localhost:9090/alerts"
echo "3. Configure Slack webhook in alertmanager.yml"
echo "4. Test alerting by stopping a service"
```

Make it executable and run:
```bash
chmod +x test-alerting.sh
./test-alerting.sh
```

## Step 9: Test Alerting by Stopping a Service

To test the alerting system, you can stop one of the services:

```bash
# Stop the bidding service to trigger an alert
docker compose stop bidding-service

# Wait a few minutes for the alert to fire
sleep 120

# Check for alerts
curl -s http://localhost:9090/api/v1/alerts | jq '.data.alerts[] | select(.state == "firing")'

# Restart the service
docker compose start bidding-service
```

## Step 10: Configure Slack Notifications (Optional)

To enable Slack notifications:

1. **Create a Slack App** and get a webhook URL
2. **Update `monitoring/alertmanager.yml`**:
   ```yaml
   global:
     slack_api_url: 'https://hooks.slack.com/services/YOUR_ACTUAL_WEBHOOK_URL'
   ```
3. **Restart Alertmanager**:
   ```bash
   docker compose restart alertmanager
   ```

## Expected Results

After completing this exercise, you should have:
- ✅ Alertmanager running and accessible
- ✅ Prometheus configured with alerting rules
- ✅ Alerting rules for service health, performance, and infrastructure
- ✅ Grafana integration for alert management
- ✅ Webhook and Slack notification capabilities
- ✅ Ability to test alerts by stopping services

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