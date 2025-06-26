# Ad-Tech Microservices Training with OpenTelemetry & Grafana Stack

This training setup demonstrates distributed tracing and monitoring in a microservices architecture using OpenTelemetry and the Grafana observability stack.

## Architecture

The system consists of three microservices in the ad-tech domain:

1. **Ad-Service (Go)** - Core ad management service
2. **Analytics-Service (Rails)** - Analytics and reporting service  
3. **Bidding-Service (Node.js)** - Real-time bidding service

## Services Communication Flow

```
User Request → Ad-Service (Go)
    ↓
Ad-Service calls Analytics-Service (Rails) for user data
    ↓
Ad-Service calls Bidding-Service (Node.js) for bid calculation
    ↓
Bidding-Service calls Analytics-Service for historical data
    ↓
Response flows back through the chain
```

## Prerequisites

- Docker and Docker Compose
- Go 1.21+ (for local development)
- Ruby 3.2+ and Rails 7.0+ (for local development)
- Node.js 18+ (for local development)
- Make (optional, for convenience)

## Quick Start

### Option 1: Docker (Recommended)

1. **Build and start all services:**
   ```bash
   make docker-setup
   ```

   This will:
   - Build all application services
   - Start the complete infrastructure
   - Start all application services
   - Set up proper networking between services

2. **Access the applications:**
   - Ad Service: http://localhost:8180
   - Analytics Service: http://localhost:3000
   - Bidding Service: http://localhost:3001
   - Grafana: http://localhost:3002 (admin/admin)
   - Tempo: http://localhost:3200
   - Loki: http://localhost:3100
   - Prometheus: http://localhost:9090
   - PostgreSQL: localhost:5444
   - Redis: localhost:6380
   - OpenTelemetry Collector: localhost:4317 (gRPC), localhost:4318 (HTTP)

### Option 2: Local Development

1. **Start the infrastructure:**
   ```bash
   make start-infra
   ```

2. **Install dependencies:**
   ```bash
   make install-deps
   ```

3. **Start the services:**
   ```bash
   # Terminal 1 - Ad Service (Go)
   cd ad-service && go run main.go
   
   # Terminal 2 - Analytics Service (Rails)
   cd analytics-service && rails server
   
   # Terminal 3 - Bidding Service (Node.js)
   cd bidding-service && npm start
   ```

## Docker Commands

```bash
# Build all services
make build-all

# Start all services
make up

# Stop all services
make down

# View logs
make logs

# Check service status
make status

# Clean up everything
make clean
```

## Grafana Observability Stack

This setup uses the complete Grafana observability stack:

- **Grafana**: Unified visualization and alerting
- **Tempo**: Distributed tracing backend
- **Loki**: Log aggregation
- **Prometheus**: Metrics collection
- **OpenTelemetry Collector**: Telemetry data processing

## Training Scenarios

### 1. Basic Tracing
- Make requests to the ad service and observe distributed traces in Grafana
- See how requests flow through multiple services
- Understand span relationships and context propagation
- Use Grafana's Explore feature to query traces

### 2. Custom Metrics
- Monitor request rates, response times, and error rates
- Create custom business metrics (bid success rate, ad impressions)
- Set up alerts and dashboards in Grafana
- Use Prometheus queries for advanced analysis

### 3. Error Handling
- Introduce errors in services to see error tracking
- Observe error propagation across service boundaries
- Practice debugging distributed systems
- Use logs in Loki to correlate with traces

### 4. Performance Analysis
- Identify bottlenecks in the service chain
- Analyze database query performance
- Optimize service communication
- Use service maps to visualize dependencies

## API Endpoints

### Ad Service (Go)
- `GET /ads` - List available ads
- `POST /ads/request` - Request an ad (triggers full chain)
- `GET /health` - Health check

### Analytics Service (Rails)
- `GET /analytics/user/:id` - Get user analytics
- `GET /analytics/historical` - Get historical data
- `POST /analytics/event` - Record analytics event

### Bidding Service (Node.js)
- `POST /bidding/calculate` - Calculate bid for ad request
- `GET /bidding/stats` - Get bidding statistics
- `GET /health` - Health check

## OpenTelemetry Configuration

Each service is configured with:
- Automatic instrumentation
- Custom spans for business logic
- Metrics collection
- Context propagation
- Tempo exporter for traces
- Prometheus exporter for metrics

## Monitoring Stack

- **Grafana**: Unified observability platform
- **Tempo**: Distributed tracing backend
- **Loki**: Log aggregation and querying
- **Prometheus**: Metrics collection and storage
- **OpenTelemetry Collector**: Telemetry data processing

## Training Exercises

1. **Trace Analysis**: Follow a request through all services using Grafana Explore
2. **Custom Instrumentation**: Add custom spans and metrics
3. **Error Investigation**: Debug failed requests across services
4. **Performance Optimization**: Identify and fix bottlenecks
5. **Alert Configuration**: Set up meaningful alerts in Grafana
6. **Dashboard Creation**: Build custom Grafana dashboards
7. **Log Correlation**: Correlate logs with traces using Loki and Tempo

## Cleanup

```bash
# For Docker setup
make down

# For local development
docker compose down
```

## Troubleshooting

- Check service logs for connection issues
- Verify all services are running on correct ports
- Ensure Docker containers are healthy
- Check OpenTelemetry collector configuration
- Verify Tempo and Loki are receiving data
- Ensure PostgreSQL is accessible on port 5444
- Ensure Redis is accessible on port 6380
- Verify OpenTelemetry Collector is accessible on ports 4317/4318 