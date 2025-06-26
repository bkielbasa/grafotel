# AdTech Observability Stack - Exercise Guide

## Overview

This exercise guide provides a step-by-step approach to building a complete observability stack for adtech microservices. Each exercise builds upon the previous one, gradually adding complexity and functionality.

## 🎯 Learning Objectives

By completing these exercises, you will learn:

1. **Microservices Architecture** - Building and running multiple services
2. **OpenTelemetry** - Instrumenting applications for observability
3. **Metrics Collection** - Using Prometheus for time-series data
4. **Distributed Tracing** - Using Tempo for request flow analysis
5. **Log Aggregation** - Using Loki for centralized logging
6. **Visualization** - Using Grafana for dashboards and exploration
7. **Alerting** - Using Alertmanager for monitoring and notifications
8. **Integration** - Connecting all components into a cohesive stack

## 📋 Prerequisites

- Docker and Docker Compose installed
- Basic understanding of containers and microservices
- Familiarity with command line tools
- 4-8 GB of available RAM for running all services

## 🚀 Exercise Progression

### Exercise 01: Running Core Services
**Duration**: 30-45 minutes
**Objective**: Set up and run the three core adtech services
- Ad Service (Go)
- Analytics Service (Rails)
- Bidding Service (Python)
- PostgreSQL and Redis

**Files**:
- `exercise.01.md` - Complete instructions
- `test-services.sh` - Service testing script

### Exercise 02: Adding OpenTelemetry Instrumentation
**Duration**: 45-60 minutes
**Objective**: Add telemetry collection to all services
- OpenTelemetry Collector
- Tempo (distributed tracing)
- Prometheus (metrics)
- Service instrumentation

**Files**:
- `exercise.02.md` - Complete instructions
- `test-telemetry.sh` - Telemetry testing script

### Exercise 03: Adding Grafana Visualization
**Duration**: 45-60 minutes
**Objective**: Add visualization and log aggregation
- Grafana (main UI)
- Loki (log aggregation)
- Promtail (log collection)
- Data source configuration

**Files**:
- `exercise.03.md` - Complete instructions
- `test-grafana.sh` - Grafana testing script

### Exercise 04: Adding Alertmanager and Alerting
**Duration**: 30-45 minutes
**Objective**: Add alerting and notification system
- Alertmanager
- Prometheus alerting rules
- Notification channels
- Grafana alert integration

**Files**:
- `exercise.04.md` - Complete instructions
- `test-alerting.sh` - Alerting testing script

### Exercise 05: Complete Observability Stack
**Duration**: 30-45 minutes
**Objective**: Finalize and test the complete stack
- End-to-end testing
- Comprehensive dashboards
- Usage documentation
- Best practices

**Files**:
- `exercise.05.md` - Complete instructions
- `test-complete-stack.sh` - Final testing script
- `USAGE_GUIDE.md` - Comprehensive usage guide

## 🛠️ Quick Start

### Option 1: Step-by-Step (Recommended)
Follow each exercise in order:

```bash
# Start with Exercise 01
cd exercises
# Follow exercise.01.md instructions
# Run test script
chmod +x test-services.sh
./test-services.sh

# Continue with Exercise 02
# Follow exercise.02.md instructions
# Run test script
chmod +x test-telemetry.sh
./test-telemetry.sh

# Continue through all exercises...
```

### Option 2: Jump to Final Result
If you want to see the final result immediately:

```bash
# Use the main docker-compose.yml from the project root
cd ..  # Go back to project root
docker compose up -d
# Wait for services to start
cd exercises
chmod +x test-complete-stack.sh
./test-complete-stack.sh
```

## 📊 Final Stack Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Ad Service    │    │ Analytics Svc   │    │ Bidding Service │
│   (Go)          │    │ (Rails)         │    │ (Python)        │
└─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘
          │                      │                      │
          └──────────────────────┼──────────────────────┘
                                 │
                    ┌─────────────▼─────────────┐
                    │  OpenTelemetry Collector  │
                    │  (Traces, Metrics, Logs)  │
                    └─────────────┬─────────────┘
                                  │
          ┌───────────────────────┼───────────────────────┐
          │                       │                       │
    ┌─────▼─────┐         ┌───────▼──────┐         ┌─────▼─────┐
    │  Tempo    │         │  Prometheus  │         │   Loki    │
    │(Traces)   │         │ (Metrics)    │         │  (Logs)   │
    └─────┬─────┘         └───────┬──────┘         └─────┬─────┘
          │                       │                       │
          └───────────────────────┼───────────────────────┘
                                  │
                    ┌─────────────▼─────────────┐
                    │        Grafana           │
                    │   (Visualization UI)     │
                    └─────────────┬─────────────┘
                                  │
                    ┌─────────────▼─────────────┐
                    │     Alertmanager         │
                    │   (Alert Management)     │
                    └───────────────────────────┘
```

## 🌐 Access Points

Once the complete stack is running:

| Service | URL | Purpose |
|---------|-----|---------|
| Grafana | http://localhost:3002 | Main visualization (admin/admin) |
| Prometheus | http://localhost:9090 | Metrics and alerts |
| Tempo | http://localhost:3200 | Distributed tracing |
| Loki | http://localhost:3100 | Log aggregation |
| Alertmanager | http://localhost:9093 | Alert management |
| Ad Service | http://localhost:8180 | Ad management API |
| Analytics Service | http://localhost:3000 | Analytics API |
| Bidding Service | http://localhost:3001 | Bidding API |

## 📈 Key Metrics to Monitor

### Application Metrics
- Request rate: `rate(http_requests_total[5m])`
- Response time: `histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))`
- Error rate: `rate(http_requests_total{status=~"5.."}[5m])`
- Success rate: `rate(http_requests_total{status=~"2.."}[5m]) / rate(http_requests_total[5m])`

### Business Metrics
- Bidding success rate: `rate(bidding_success_total[5m]) / rate(bidding_requests_total[5m])`
- Average bid value: `rate(bidding_value_sum[5m]) / rate(bidding_value_count[5m])`

### Infrastructure Metrics
- Service health: `up`
- Memory usage: `(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes`
- CPU usage: `100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)`

## 🔧 Troubleshooting

### Common Issues

1. **Services not starting**
   ```bash
   docker compose logs [service-name]
   docker compose down && docker compose up -d
   ```

2. **Port conflicts**
   ```bash
   netstat -an | grep :[port]
   # Change ports in docker-compose.yml if needed
   ```

3. **No data in Grafana**
   ```bash
   # Check if data sources are configured
   curl http://localhost:9090/api/v1/targets
   curl http://localhost:3200/ready
   curl http://localhost:3100/ready
   ```

4. **Alerts not firing**
   ```bash
   # Check alerting rules
   curl http://localhost:9090/api/v1/rules
   # Check Alertmanager
   curl http://localhost:9093/api/v1/status
   ```

### Resource Usage

The complete stack requires approximately:
- **CPU**: 2-4 cores
- **Memory**: 4-8 GB RAM
- **Disk**: 2-5 GB (depending on retention)

## 🎓 Learning Path

### Beginner Level
1. Complete Exercise 01 - Understand basic microservices
2. Complete Exercise 02 - Learn about telemetry collection
3. Complete Exercise 03 - Explore visualization

### Intermediate Level
1. Complete Exercise 04 - Understand alerting
2. Customize dashboards in Grafana
3. Add custom metrics to services

### Advanced Level
1. Complete Exercise 05 - Full stack integration
2. Implement custom alerting rules
3. Scale the stack for production
4. Add security and authentication

## 📚 Additional Resources

- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [Prometheus Query Language](https://prometheus.io/docs/prometheus/latest/querying/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Tempo Documentation](https://grafana.com/docs/tempo/)
- [Loki Documentation](https://grafana.com/docs/loki/)

## 🤝 Contributing

Feel free to:
- Report issues with exercises
- Suggest improvements
- Add new exercises
- Share your custom dashboards

## 📄 License

This exercise guide is provided as-is for educational purposes.

---

**Happy Observing! 🔍📊** 