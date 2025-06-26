# Quick Start Guide

## Prerequisites

- Docker and Docker Compose
- Go 1.21+
- Ruby 3.2+ and Rails 7.0+
- Node.js 18+
- Make (optional)

## 1. Start the Infrastructure

```bash
# Start monitoring stack (Grafana, Tempo, Loki, Prometheus)
make start-infra
```

This starts:
- **Grafana**: http://localhost:3002 (admin/admin) - Unified observability platform
- **Tempo**: http://localhost:3200 - Distributed tracing backend
- **Loki**: http://localhost:3100 - Log aggregation
- **Prometheus**: http://localhost:9090 - Metrics collection
- **PostgreSQL**: localhost:5444 - Database for analytics service
- **Redis**: localhost:6380 - Caching layer

## 2. Install Dependencies

```bash
make install-deps
```

## 3. Start the Services

Open 3 terminal windows and run:

**Terminal 1 - Ad Service (Go):**
```bash
cd ad-service
go run main.go
```

**Terminal 2 - Analytics Service (Rails):**
```bash
cd analytics-service
rails server
```

**Terminal 3 - Bidding Service (Node.js):**
```bash
cd bidding-service
npm start
```

## 4. Test the Setup

```bash
make test
```

This will:
- Test all service health checks
- Make requests through the full service chain
- Generate traces and metrics
- Verify everything is working

## 5. Explore the Monitoring

### Grafana (Unified Observability)
- Open http://localhost:3002
- Login: admin/admin
- Navigate to **Explore** to query traces, logs, and metrics
- Use the **Ad-Tech Microservices Overview** dashboard
- Create custom dashboards for:
  - Request rates
  - Response times
  - Error rates
  - Custom business metrics

### Tempo (Distributed Tracing)
- Access via Grafana: Explore → Tempo
- Query traces by service name, trace ID, or tags
- View service maps and dependencies
- Analyze trace spans and timing
- Correlate traces with logs and metrics

### Loki (Log Aggregation)
- Access via Grafana: Explore → Loki
- Query logs by service, level, or content
- Correlate logs with traces using trace IDs
- Set up log-based alerts
- Create log dashboards

### Prometheus (Metrics)
- Access via Grafana: Explore → Prometheus
- Query metrics like:
  - `ad_requests_total`
  - `bid_requests_total`
  - `analytics_requests_total`
  - `rate(ad_request_duration_seconds[5m])`

## 6. Training Exercises

### Exercise 1: Trace Analysis with Grafana
1. Make a request to the ad service
2. Go to Grafana → Explore → Tempo
3. Search for traces by service name "ad-service"
4. Click on a trace to see the full request flow
5. Analyze timing and identify bottlenecks

### Exercise 2: Log Correlation
1. Generate some load on the services
2. Go to Grafana → Explore → Loki
3. Query logs: `{service="ad-service"}`
4. Find a log entry with a trace ID
5. Click the trace ID to jump to Tempo

### Exercise 3: Custom Instrumentation
1. Add custom spans to business logic
2. Add custom metrics for business KPIs
3. Create alerts for important thresholds
4. Build custom dashboards

### Exercise 4: Error Handling
1. Introduce errors in services
2. Observe error propagation in traces
3. Correlate errors with logs
4. Set up error alerting

### Exercise 5: Performance Optimization
1. Use service maps to identify dependencies
2. Analyze response time percentiles
3. Optimize slow operations
4. Measure improvements

## 7. Cleanup

```bash
make clean
```

## Troubleshooting

### Services not starting?
- Check if ports are available
- Verify dependencies are installed
- Check service logs

### No traces in Tempo?
- Verify OpenTelemetry configuration
- Check if services are sending to correct endpoint
- Ensure Tempo is running and accessible
- Check Grafana datasource configuration

### No logs in Loki?
- Verify log collection is configured
- Check if services are sending logs
- Ensure Loki is running

### No metrics in Prometheus?
- Check if services expose `/metrics` endpoints
- Verify Prometheus configuration
- Check network connectivity

### Database connection issues?
- Ensure PostgreSQL is running on port 5444
- Check database credentials in `analytics-service/config/database.yml`
- Verify network connectivity to PostgreSQL

### Redis connection issues?
- Ensure Redis is running on port 6380
- Check Redis connection settings in services
- Verify network connectivity to Redis

## Next Steps

1. **Custom Dashboards**: Create Grafana dashboards for your specific needs
2. **Alerting**: Set up alerts for critical metrics and traces
3. **Custom Metrics**: Add business-specific metrics
4. **Performance Testing**: Run load tests and analyze results
5. **Error Scenarios**: Test error handling and recovery
6. **Service Maps**: Use Grafana's service map feature to visualize dependencies
7. **Log Analysis**: Set up structured logging and log-based monitoring 