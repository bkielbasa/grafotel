# Exercise 05: Complete Observability Stack

## Objective
Finalize the complete observability stack and create comprehensive dashboards for the adtech services.

## Prerequisites
- Completed Exercises 01-04
- All services running and healthy
- Basic understanding of the observability stack

## What We'll Accomplish
1. **Final Integration** - Ensure all components work together
2. **Comprehensive Dashboards** - Create detailed visualizations
3. **End-to-End Testing** - Test the complete observability pipeline
4. **Best Practices** - Implement monitoring best practices
5. **Documentation** - Create usage documentation

## Step 1: Verify Complete Stack

First, let's verify all services are running:

```bash
# Check all services
docker compose ps

# Expected output should show all services as "Up":
# - ad-service
# - analytics-service  
# - bidding-service
# - postgres
# - redis
# - otel-collector
# - tempo
# - prometheus
# - grafana
# - loki
# - promtail
# - alertmanager
```

## Step 2: Create Comprehensive Test Script

Create `test-complete-stack.sh`:

```bash
#!/bin/bash

echo "🔍 Testing Complete Observability Stack..."
echo "=========================================="

# Wait for all services to be ready
echo "⏳ Waiting for all services to start..."
sleep 30

# Test Application Services
echo "1. Testing Application Services..."
AD_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8180/health)
ANALYTICS_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/health)
BIDDING_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3001/health)

echo "   Ad Service: $([ "$AD_RESPONSE" = "200" ] && echo "✅" || echo "❌") (HTTP $AD_RESPONSE)"
echo "   Analytics Service: $([ "$ANALYTICS_RESPONSE" = "200" ] && echo "✅" || echo "❌") (HTTP $ANALYTICS_RESPONSE)"
echo "   Bidding Service: $([ "$BIDDING_RESPONSE" = "200" ] && echo "✅" || echo "❌") (HTTP $BIDDING_RESPONSE)"

# Test Observability Services
echo "2. Testing Observability Services..."
OTEL_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9464/metrics)
TEMPO_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3200/ready)
PROM_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9090/-/healthy)
GRAFANA_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3002/api/health)
LOKI_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3100/ready)
ALERTMANAGER_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9093/-/healthy)

echo "   OpenTelemetry Collector: $([ "$OTEL_RESPONSE" = "200" ] && echo "✅" || echo "❌") (HTTP $OTEL_RESPONSE)"
echo "   Tempo: $([ "$TEMPO_RESPONSE" = "200" ] && echo "✅" || echo "❌") (HTTP $TEMPO_RESPONSE)"
echo "   Prometheus: $([ "$PROM_RESPONSE" = "200" ] && echo "✅" || echo "❌") (HTTP $PROM_RESPONSE)"
echo "   Grafana: $([ "$GRAFANA_RESPONSE" = "200" ] && echo "✅" || echo "❌") (HTTP $GRAFANA_RESPONSE)"
echo "   Loki: $([ "$LOKI_RESPONSE" = "200" ] && echo "✅" || echo "❌") (HTTP $LOKI_RESPONSE)"
echo "   Alertmanager: $([ "$ALERTMANAGER_RESPONSE" = "200" ] && echo "✅" || echo "❌") (HTTP $ALERTMANAGER_RESPONSE)"

# Generate comprehensive test traffic
echo "3. Generating test traffic..."
for i in {1..20}; do
    echo "   Request $i/20..."
    curl -s -X POST http://localhost:3001/bidding/calculate \
      -H "Content-Type: application/json" \
      -d "{\"ad_request_id\": \"final-test-$i\", \"user_id\": \"user-$i\"}" > /dev/null
    
    # Also test analytics
    curl -s http://localhost:3000/analytics/user/user-$i > /dev/null
    
    sleep 0.3
done

echo "✅ Generated comprehensive test traffic"

# Test Data Collection
echo "4. Testing Data Collection..."

# Check metrics
METRICS_COUNT=$(curl -s http://localhost:9464/metrics | grep -c "bidding_requests_total" || echo "0")
echo "   Metrics Collection: $([ "$METRICS_COUNT" -gt 0 ] && echo "✅" || echo "❌") ($METRICS_COUNT metrics found)"

# Check traces
TRACE_COUNT=$(curl -s http://localhost:3200/api/search/tags | grep -c "service.name" || echo "0")
echo "   Trace Collection: $([ "$TRACE_COUNT" -gt 0 ] && echo "✅" || echo "❌") (traces available)"

# Check logs
LOG_COUNT=$(curl -s "http://localhost:3100/loki/api/v1/labels" | grep -c "container_name" || echo "0")
echo "   Log Collection: $([ "$LOG_COUNT" -gt 0 ] && echo "✅" || echo "❌") (logs available)"

# Check alerts
ALERTS_COUNT=$(curl -s http://localhost:9090/api/v1/alerts | grep -c "firing" || echo "0")
echo "   Alert System: $([ "$ALERTS_COUNT" -ge 0 ] && echo "✅" || echo "❌") ($ALERTS_COUNT active alerts)"

echo "=========================================="
echo "🎉 Complete stack testing finished!"

# Final Summary
echo ""
echo "📊 FINAL SUMMARY:"
echo "=================="
echo "Application Services: $([ "$AD_RESPONSE" = "200" ] && [ "$ANALYTICS_RESPONSE" = "200" ] && [ "$BIDDING_RESPONSE" = "200" ] && echo "✅" || echo "❌")"
echo "Observability Stack: $([ "$OTEL_RESPONSE" = "200" ] && [ "$TEMPO_RESPONSE" = "200" ] && [ "$PROM_RESPONSE" = "200" ] && [ "$GRAFANA_RESPONSE" = "200" ] && [ "$LOKI_RESPONSE" = "200" ] && [ "$ALERTMANAGER_RESPONSE" = "200" ] && echo "✅" || echo "❌")"
echo "Data Collection: $([ "$METRICS_COUNT" -gt 0 ] && [ "$TRACE_COUNT" -gt 0 ] && [ "$LOG_COUNT" -gt 0 ] && echo "✅" || echo "❌")"
echo "Alert System: $([ "$ALERTS_COUNT" -ge 0 ] && echo "✅" || echo "❌")"

echo ""
echo "🌐 Access Points:"
echo "=================="
echo "Grafana (Main UI): http://localhost:3002 (admin/admin)"
echo "Prometheus: http://localhost:9090"
echo "Tempo: http://localhost:3200"
echo "Loki: http://localhost:3100"
echo "Alertmanager: http://localhost:9093"
echo "OpenTelemetry Collector: http://localhost:9464/metrics"

echo ""
echo "📋 Usage Guide:"
echo "==============="
echo "1. Open Grafana: http://localhost:3002"
echo "2. Go to Explore to query metrics, traces, and logs"
echo "3. Check Alerting section for alert management"
echo "4. Use Prometheus for advanced metric queries"
echo "5. Use Tempo for distributed tracing analysis"
echo "6. Use Loki for log analysis and correlation"
```

Make it executable and run:
```bash
chmod +x test-complete-stack.sh
./test-complete-stack.sh
```

## Step 3: Create Comprehensive Dashboards

### Create Service Overview Dashboard

Create `monitoring/grafana/dashboards/service-overview.json`:

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
        "title": "Service Health Status",
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
            },
            "mappings": [
              {"options": {"0": {"text": "Down"}}, "type": "value"},
              {"options": {"1": {"text": "Up"}}, "type": "value"}
            ]
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0}
      },
      {
        "id": 2,
        "title": "Request Rate by Service",
        "type": "timeseries",
        "targets": [
          {
            "expr": "rate(http_requests_total[5m])",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "color": {"mode": "palette-classic"},
            "custom": {
              "axisLabel": "",
              "axisPlacement": "auto",
              "barAlignment": 0,
              "drawStyle": "line",
              "fillOpacity": 10,
              "gradientMode": "none",
              "hideFrom": {"legend": false, "tooltip": false, "vis": false},
              "lineInterpolation": "linear",
              "lineWidth": 1,
              "pointSize": 5,
              "scaleDistribution": {"type": "linear"},
              "showPoints": "never",
              "spanNulls": false,
              "stacking": {"group": "A", "mode": "none"},
              "thresholdsStyle": {"mode": "off"}
            },
            "unit": "reqps"
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
      },
      {
        "id": 3,
        "title": "Response Time (95th percentile)",
        "type": "timeseries",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "color": {"mode": "palette-classic"},
            "custom": {
              "axisLabel": "",
              "axisPlacement": "auto",
              "barAlignment": 0,
              "drawStyle": "line",
              "fillOpacity": 10,
              "gradientMode": "none",
              "hideFrom": {"legend": false, "tooltip": false, "vis": false},
              "lineInterpolation": "linear",
              "lineWidth": 1,
              "pointSize": 5,
              "scaleDistribution": {"type": "linear"},
              "showPoints": "never",
              "spanNulls": false,
              "stacking": {"group": "A", "mode": "none"},
              "thresholdsStyle": {"mode": "off"}
            },
            "unit": "s"
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8}
      },
      {
        "id": 4,
        "title": "Error Rate",
        "type": "timeseries",
        "targets": [
          {
            "expr": "rate(http_requests_total{status=~\"5..\"}[5m])",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "color": {"mode": "palette-classic"},
            "custom": {
              "axisLabel": "",
              "axisPlacement": "auto",
              "barAlignment": 0,
              "drawStyle": "line",
              "fillOpacity": 10,
              "gradientMode": "none",
              "hideFrom": {"legend": false, "tooltip": false, "vis": false},
              "lineInterpolation": "linear",
              "lineWidth": 1,
              "pointSize": 5,
              "scaleDistribution": {"type": "linear"},
              "showPoints": "never",
              "spanNulls": false,
              "stacking": {"group": "A", "mode": "none"},
              "thresholdsStyle": {"mode": "off"}
            },
            "unit": "reqps"
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8}
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

## Step 4: Create Usage Documentation

Create `exercises/USAGE_GUIDE.md`:

```markdown
# AdTech Observability Stack - Usage Guide

## Overview
This guide explains how to use the complete observability stack for monitoring adtech services.

## Quick Start

### 1. Start the Stack
```bash
docker compose up -d
```

### 2. Access Grafana
- URL: http://localhost:3002
- Username: admin
- Password: admin

### 3. Generate Traffic
```bash
# Test the services
curl http://localhost:8180/health
curl http://localhost:3000/health
curl http://localhost:3001/health

# Generate bidding traffic
curl -X POST http://localhost:3001/bidding/calculate \
  -H "Content-Type: application/json" \
  -d '{"ad_request_id": "test-123", "user_id": "user-456"}'
```

## Observability Components

### 1. Metrics (Prometheus)
- **URL**: http://localhost:9090
- **Purpose**: Time-series metrics collection
- **Key Metrics**:
  - `http_requests_total` - Request count
  - `http_request_duration_seconds` - Response time
  - `bidding_requests_total` - Bidding requests
  - `bidding_success_total` - Successful bids

### 2. Traces (Tempo)
- **URL**: http://localhost:3200
- **Purpose**: Distributed tracing
- **Key Features**:
  - Service dependency mapping
  - Request flow visualization
  - Performance bottleneck identification

### 3. Logs (Loki)
- **URL**: http://localhost:3100
- **Purpose**: Log aggregation and querying
- **Key Features**:
  - Structured log search
  - Log correlation with traces
  - Real-time log streaming

### 4. Alerts (Alertmanager)
- **URL**: http://localhost:9093
- **Purpose**: Alert management and routing
- **Key Features**:
  - Alert grouping and deduplication
  - Notification routing
  - Alert silencing

## Grafana Usage

### 1. Explore Data
1. Go to **Explore** in Grafana
2. Select data source (Prometheus, Tempo, or Loki)
3. Write queries to explore data

### 2. Create Dashboards
1. Go to **Dashboards** → **New Dashboard**
2. Add panels for different metrics
3. Configure queries and visualizations

### 3. Set Up Alerts
1. Go to **Alerting** → **Alert Rules**
2. Create new alert rules
3. Configure notification channels

## Common Queries

### Prometheus Queries
```promql
# Request rate by service
rate(http_requests_total[5m])

# Error rate
rate(http_requests_total{status=~"5.."}[5m])

# Response time 95th percentile
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Service health
up
```

### Loki Queries
```logql
# All logs
{job="docker"}

# Error logs
{job="docker"} |= "error"

# Service-specific logs
{container_name="grafotel-bidding-service-1"}

# Logs with specific text
{job="docker"} |= "bidding"
```

### Tempo Queries
```traceql
# Find traces by service
{service.name="bidding-service"}

# Find traces by operation
{operation="calculate_bid"}

# Find traces by duration
{duration > 1s}
```

## Monitoring Best Practices

### 1. Key Metrics to Monitor
- **Service Health**: `up` metric
- **Request Rate**: `rate(http_requests_total[5m])`
- **Response Time**: `histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))`
- **Error Rate**: `rate(http_requests_total{status=~"5.."}[5m])`
- **Success Rate**: `rate(http_requests_total{status=~"2.."}[5m]) / rate(http_requests_total[5m])`

### 2. Alert Thresholds
- **Service Down**: Immediate alert
- **High Error Rate**: > 5% for 2 minutes
- **High Response Time**: > 2s 95th percentile for 2 minutes
- **Low Success Rate**: < 95% for 2 minutes

### 3. Dashboard Organization
- **Overview**: High-level service health
- **Service-Specific**: Detailed metrics per service
- **Infrastructure**: System resources
- **Business**: Business metrics (bidding success, revenue)

## Troubleshooting

### 1. Service Not Responding
```bash
# Check service logs
docker compose logs [service-name]

# Check service health
curl http://localhost:[port]/health
```

### 2. No Data in Grafana
```bash
# Check data sources
curl http://localhost:9090/api/v1/targets  # Prometheus
curl http://localhost:3200/ready          # Tempo
curl http://localhost:3100/ready          # Loki
```

### 3. Alerts Not Firing
```bash
# Check alerting rules
curl http://localhost:9090/api/v1/rules

# Check Alertmanager
curl http://localhost:9093/api/v1/status
```

## Performance Tuning

### 1. Retention Settings
- **Prometheus**: 200h (8 days)
- **Tempo**: 1h (for demo)
- **Loki**: No retention (for demo)

### 2. Scrape Intervals
- **Application Metrics**: 15s
- **Infrastructure Metrics**: 30s
- **High-frequency Metrics**: 5s

### 3. Resource Limits
- Monitor memory and CPU usage
- Adjust container limits as needed
- Consider scaling for production

## Production Considerations

### 1. Security
- Enable authentication for all services
- Use HTTPS for all endpoints
- Implement proper access controls

### 2. Scalability
- Use external storage (S3, GCS) for long-term retention
- Implement horizontal scaling
- Use load balancers for high availability

### 3. Backup and Recovery
- Regular backups of configuration
- Test recovery procedures
- Document disaster recovery plans
```

## Step 5: Final Verification

Run the complete test script and verify everything is working:

```bash
./test-complete-stack.sh
```

## Expected Results

After completing this exercise, you should have:
- ✅ Complete observability stack running
- ✅ All services healthy and communicating
- ✅ Metrics, traces, and logs being collected
- ✅ Alerting system configured and working
- ✅ Comprehensive dashboards available
- ✅ Complete documentation for usage

## Congratulations! 🎉

You have successfully built a complete observability stack for adtech services with:
- **3 Microservices** (Ad, Analytics, Bidding)
- **OpenTelemetry** instrumentation
- **Prometheus** metrics collection
- **Tempo** distributed tracing
- **Loki** log aggregation
- **Grafana** visualization
- **Alertmanager** alerting
- **Comprehensive monitoring** and alerting rules

## Next Steps

1. **Explore the dashboards** in Grafana
2. **Test the alerting** by stopping services
3. **Customize the configuration** for your needs
4. **Add more services** following the same pattern
5. **Scale the stack** for production use

## Cleanup

To stop all services:
```bash
docker compose down
```

To remove all data:
```bash
docker compose down -v
``` 