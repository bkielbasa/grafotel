# Exercise 05: Complete Observability Stack

## Objective
Finalize the complete observability stack and create comprehensive dashboards for the adtech services using Grafana's UI, with special focus on trace linking and alerting integration.

## Prerequisites
- Completed Exercises 01-04
- All services running and healthy
- Basic understanding of the observability stack
- Access to Grafana UI at http://localhost:3002

## What We'll Accomplish
1. **Final Integration** - Ensure all components work together
2. **Comprehensive Dashboards** - Create detailed visualizations in Grafana UI
3. **Trace Linking** - Verify and enhance trace correlation
4. **Alert Integration** - Connect dashboards with alerting
5. **End-to-End Testing** - Test the complete observability pipeline
6. **Best Practices** - Implement monitoring best practices
7. **Documentation** - Create usage documentation

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
echo "2. Go to Dashboards to see your created dashboards"
echo "3. Check the logs dashboard for trace links"
echo "4. Click on trace IDs to open traces in Tempo"
echo "5. Use Explore to query metrics, traces, and logs"
echo "6. Check Alerting section for alert management"
```

Make it executable and run:
```bash
chmod +x test-complete-stack.sh
./test-complete-stack.sh
```

## Step 3: Create Comprehensive Dashboards in Grafana UI

### 3.1 Access Grafana
1. **Open Grafana**: http://localhost:3002
2. **Login**: admin / admin
3. **Verify all data sources** are working

### 3.2 Create Service Overview Dashboard

1. **Go to Dashboards** → **New Dashboard**
2. **Add Service Health Panel**:
   - **Title**: "Service Health Status"
   - **Data Source**: Prometheus
   - **Query**: `up`
   - **Visualization**: Stat
   - **Field**: Configure thresholds and mappings

3. **Add Request Rate Panel**:
   - **Title**: "Request Rate by Service"
   - **Data Source**: Prometheus
   - **Query**: `rate(http_requests_total[5m])`
   - **Visualization**: Time series
   - **Y-axis**: Unit = "reqps"

4. **Add Response Time Panel**:
   - **Title**: "Response Time (95th percentile)"
   - **Data Source**: Prometheus
   - **Query**: `histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))`
   - **Visualization**: Time series
   - **Y-axis**: Unit = "s"

5. **Add Error Rate Panel**:
   - **Title**: "Error Rate"
   - **Data Source**: Prometheus
   - **Query**: `rate(http_requests_total{status=~"5.."}[5m])`
   - **Visualization**: Time series
   - **Y-axis**: Unit = "reqps"

6. **Add Success Rate Panel**:
   - **Title**: "Success Rate"
   - **Data Source**: Prometheus
   - **Query**: `rate(http_requests_total{status=~"2.."}[5m]) / rate(http_requests_total[5m])`
   - **Visualization**: Time series
   - **Y-axis**: Unit = "percentunit"

7. **Save Dashboard**:
   - **Name**: "AdTech Services Overview"
   - **Tags**: "adtech", "overview", "services"
   - **Time Range**: Last 1 hour
   - **Refresh**: 5s

### 3.3 Create Bidding Service Dashboard

1. **Create New Dashboard**
2. **Add Bidding Request Rate Panel**:
   - **Title**: "Bidding Request Rate"
   - **Data Source**: Prometheus
   - **Query**: `rate(bidding_requests_total[5m])`
   - **Visualization**: Time series

3. **Add Bidding Success Rate Panel**:
   - **Title**: "Bidding Success Rate"
   - **Data Source**: Prometheus
   - **Query**: `rate(bidding_success_total[5m]) / rate(bidding_requests_total[5m])`
   - **Visualization**: Time series

4. **Add Bidding Latency Panel**:
   - **Title**: "Bidding Latency"
   - **Data Source**: Prometheus
   - **Query**: `histogram_quantile(0.95, rate(bidding_request_duration_seconds_bucket[5m]))`
   - **Visualization**: Time series

5. **Add Bid Amount Distribution Panel**:
   - **Title**: "Bid Amount Distribution"
   - **Data Source**: Prometheus
   - **Query**: `rate(bid_amount_bucket[5m])`
   - **Visualization**: Heatmap

6. **Save Dashboard**:
   - **Name**: "Bidding Service Metrics"
   - **Tags**: "adtech", "bidding", "business"

### 3.4 Create Logs Dashboard with Trace Links

1. **Create New Dashboard**
2. **Add Main Logs Panel**:
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
   - **Tags**: "adtech", "logs", "traces"

### 3.5 Create Infrastructure Dashboard

1. **Create New Dashboard**
2. **Add CPU Usage Panel**:
   - **Title**: "CPU Usage"
   - **Data Source**: Prometheus
   - **Query**: `100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)`
   - **Visualization**: Time series

3. **Add Memory Usage Panel**:
   - **Title**: "Memory Usage"
   - **Data Source**: Prometheus
   - **Query**: `(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100`
   - **Visualization**: Time series

4. **Add Disk Usage Panel**:
   - **Title**: "Disk Usage"
   - **Data Source**: Prometheus
   - **Query**: `(node_filesystem_size_bytes - node_filesystem_free_bytes) / node_filesystem_size_bytes * 100`
   - **Visualization**: Time series

5. **Add Network Traffic Panel**:
   - **Title**: "Network Traffic"
   - **Data Source**: Prometheus
   - **Query**: `rate(node_network_receive_bytes_total[5m])`
   - **Visualization**: Time series

6. **Save Dashboard**:
   - **Name**: "Infrastructure Monitoring"
   - **Tags**: "infrastructure", "system"

### 3.6 Create Alert Overview Dashboard

1. **Create New Dashboard**
2. **Add Active Alerts Panel**:
   - **Title**: "Active Alerts"
   - **Data Source**: Prometheus
   - **Query**: `ALERTS{alertstate="firing"}`
   - **Visualization**: Table

3. **Add Alert Count by Severity Panel**:
   - **Title**: "Alert Count by Severity"
   - **Data Source**: Prometheus
   - **Query**: `count by (severity) (ALERTS{alertstate="firing"})`
   - **Visualization**: Stat

4. **Add Alert History Panel**:
   - **Title**: "Alert History"
   - **Data Source**: Prometheus
   - **Query**: `changes(ALERTS[1h])`
   - **Visualization**: Time series

5. **Save Dashboard**:
   - **Name**: "Alert Overview"
   - **Tags**: "alerts", "monitoring"

## Step 4: Test Trace Linking

### 4.1 Generate Traffic with Trace IDs
```bash
# Generate various types of traffic
for i in {1..10}; do
    curl -X POST http://localhost:3001/bidding/calculate \
      -H "Content-Type: application/json" \
      -d "{\"ad_request_id\": \"trace-test-$i\", \"user_id\": \"user-$i\"}"
    sleep 0.5
done
```

### 4.2 Verify Trace Links
1. **Open the Logs Dashboard** in Grafana
2. **Look for logs** with "Trace:" in the message
3. **Click on trace IDs** to open traces in Tempo
4. **Verify trace correlation** between logs and traces

## Step 5: Create Dashboard Variables

### 5.1 Add Service Variable
1. **Go to Dashboard Settings** (gear icon)
2. **Click Variables**
3. **Add New Variable**:
   - **Name**: service
   - **Type**: Query
   - **Data Source**: Prometheus
   - **Query**: `label_values(http_requests_total, service)`
   - **Refresh**: On Dashboard Load

### 5.2 Add Time Range Variable
1. **Add another variable**:
   - **Name**: time_range
   - **Type**: Custom
   - **Values**: 5m, 15m, 1h, 6h, 1d
   - **Default**: 1h

### 5.3 Use Variables in Queries
Update dashboard queries to use variables:
- `rate(http_requests_total{service="$service"}[$time_range])`
- `{tag="grafotel-$service-1"}`

## Step 6: Organize Dashboards

### 6.1 Create Folders
1. **Go to Dashboards**
2. **Click New Folder**
3. **Create folders**:
   - "AdTech Services"
   - "Infrastructure"
   - "Logs and Traces"
   - "Alerts"

### 6.2 Move Dashboards to Folders
1. **Select each dashboard**
2. **Click the three dots** (⋮)
3. **Click Move**
4. **Select the appropriate folder**

### 6.3 Add Dashboard Links
1. **Go to Dashboard Settings**
2. **Click Links**
3. **Add links** to related dashboards and external tools

## Step 7: Export Dashboards

### 7.1 Export All Dashboards
1. **Open each dashboard**
2. **Go to Settings** → **JSON Model**
3. **Copy the JSON content**
4. **Save to files**:
   - `monitoring/grafana/dashboards/service-overview.json`
   - `monitoring/grafana/dashboards/bidding-service.json`
   - `monitoring/grafana/dashboards/logs.json`
   - `monitoring/grafana/dashboards/infrastructure.json`
   - `monitoring/grafana/dashboards/alert-overview.json`

## Step 8: Create Usage Documentation

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
  - Trace linking from logs

### 3. Logs (Loki)
- **URL**: http://localhost:3100
- **Purpose**: Log aggregation and querying
- **Key Features**:
  - Structured log search
  - Log correlation with traces
  - Real-time log streaming
  - Clickable trace links

### 4. Alerts (Alertmanager + Grafana)
- **URL**: http://localhost:9093 (Alertmanager)
- **URL**: http://localhost:3002/alerting (Grafana)
- **Purpose**: Alert management and routing
- **Key Features**:
  - Alert grouping and deduplication
  - Notification routing
  - Alert silencing
  - UI-based alert configuration

## Grafana Usage

### 1. Explore Data
1. Go to **Explore** in Grafana
2. Select data source (Prometheus, Tempo, or Loki)
3. Write queries to explore data

### 2. Create Dashboards
1. Go to **Dashboards** → **New Dashboard**
2. Add panels for different metrics
3. Configure queries and visualizations
4. Use variables for flexibility

### 3. Set Up Alerts
1. Go to **Alerting** → **Alert Rules**
2. Create new alert rules
3. Configure notification channels

### 4. Trace Linking
1. View logs in dashboard panels
2. Look for "Trace:" in log messages
3. Click trace IDs to open traces in Tempo
4. Correlate logs with trace data

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

# Bidding success rate
rate(bidding_success_total[5m]) / rate(bidding_requests_total[5m])
```

### Loki Queries
```logql
# All logs
{job="docker"}

# Error logs
{job="docker"} |= "error"

# Service-specific logs
{container_name="grafotel-bidding-service-1"}

# Logs with trace IDs
{job="docker"} |= "Trace:"

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

# Find traces by error
{status="error"}
```

## Monitoring Best Practices

### 1. Key Metrics to Monitor
- **Service Health**: `up` metric
- **Request Rate**: `rate(http_requests_total[5m])`
- **Response Time**: `histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))`
- **Error Rate**: `rate(http_requests_total{status=~"5.."}[5m])`
- **Success Rate**: `rate(http_requests_total{status=~"2.."}[5m]) / rate(http_requests_total[5m])`
- **Business Metrics**: Bidding success rate, revenue per request

### 2. Alert Thresholds
- **Service Down**: Immediate alert
- **High Error Rate**: > 5% for 2 minutes
- **High Response Time**: > 2s 95th percentile for 2 minutes
- **Low Success Rate**: < 95% for 2 minutes
- **Low Bidding Success**: < 60% for 2 minutes

### 3. Dashboard Organization
- **Overview**: High-level service health
- **Service-Specific**: Detailed metrics per service
- **Infrastructure**: System resources
- **Business**: Business metrics (bidding success, revenue)
- **Logs and Traces**: Log analysis with trace correlation
- **Alerts**: Alert management and history

### 4. Trace Linking Best Practices
- Always include trace IDs in structured logs
- Use consistent trace ID format
- Correlate logs with traces for debugging
- Monitor trace sampling rates
- Set up trace-based alerting for critical paths

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

# Check Grafana alerting
# Go to http://localhost:3002/alerting
```

### 4. Trace Links Not Working
```bash
# Check derived fields configuration
# Verify log format contains "Trace:"
# Test Tempo connectivity
curl http://localhost:3200/ready
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
- Secure API keys and credentials

### 2. Scalability
- Use external storage (S3, GCS) for long-term retention
- Implement horizontal scaling
- Use load balancers for high availability
- Consider managed services (Grafana Cloud, etc.)

### 3. Backup and Recovery
- Regular backups of configuration
- Test recovery procedures
- Document disaster recovery plans
- Version control all configurations

### 4. Monitoring the Monitoring
- Monitor the observability stack itself
- Set up alerts for monitoring components
- Track resource usage of monitoring tools
- Regular health checks of all components
```

## Step 9: Final Verification

Run the complete test script and verify everything is working:

```bash
./test-complete-stack.sh
```

## Expected Results

After completing this exercise, you should have:
- ✅ Complete observability stack running
- ✅ All services healthy and communicating
- ✅ Metrics, traces, and logs being collected
- ✅ Trace linking working in logs
- ✅ Alerting system configured and working
- ✅ Comprehensive dashboards created in UI
- ✅ Dashboard variables for flexibility
- ✅ Organized dashboard structure
- ✅ Complete documentation for usage

## Congratulations! 🎉

You have successfully built a complete observability stack for adtech services with:
- **3 Microservices** (Ad, Analytics, Bidding)
- **OpenTelemetry** instrumentation
- **Prometheus** metrics collection
- **Tempo** distributed tracing
- **Loki** log aggregation with trace linking
- **Grafana** visualization with UI-first approach
- **Alertmanager** + **Grafana Alerting** for comprehensive alerting
- **Trace linking** from logs to traces
- **Comprehensive monitoring** and alerting rules

## Key Features Demonstrated

### 1. Complete Observability
- **Metrics**: Performance and business metrics
- **Traces**: Distributed tracing with correlation
- **Logs**: Structured logging with trace links
- **Alerts**: Multi-channel alerting

### 2. UI-First Approach
- Create dashboards using Grafana's intuitive interface
- Configure alerts through the UI
- Export configurations for version control
- Organize with folders and tags

### 3. Trace Correlation
- Clickable trace links in logs
- Seamless navigation between logs and traces
- End-to-end request tracking
- Performance bottleneck identification

### 4. Production-Ready Features
- Comprehensive alerting rules
- Multiple notification channels
- Dashboard variables for flexibility
- Organized dashboard structure

## Next Steps

1. **Explore the dashboards** in Grafana
2. **Test the trace linking** by clicking trace IDs
3. **Test the alerting** by stopping services
4. **Customize the configuration** for your needs
5. **Add more services** following the same pattern
6. **Scale the stack** for production use

## Cleanup

To stop all services:
```bash
docker compose down
```

To remove all data:
```bash
docker compose down -v
``` 