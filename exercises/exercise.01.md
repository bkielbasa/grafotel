# Exercise 01: Running Core Services

## Objective
Set up and run the three core adtech services using Docker Compose.

## Prerequisites
- Docker and Docker Compose installed
- Basic understanding of Docker concepts

## Services to Deploy
1. **Ad Service** (Go) - Core ad management
2. **Analytics Service** (Rails) - Analytics and reporting  
3. **Bidding Service** (Python) - Real-time bidding

## Step 1: Create Docker Compose File

Create a new file `docker-compose.yml` in your project root:

```yaml
version: '3.8'

services:
  # Ad Service (Go)
  ad-service:
    build:
      context: ./ad-service
      dockerfile: Dockerfile
    ports:
      - "8180:8080"
    environment:
      - ANALYTICS_SERVICE_URL=http://analytics-service:3000
      - BIDDING_SERVICE_URL=http://bidding-service:3001
    restart: unless-stopped
    networks:
      - adtech-network

  # Analytics Service (Rails)
  analytics-service:
    build:
      context: ./analytics-service
      dockerfile: Dockerfile
    ports:
      - "3000:3000"
    volumes:
      - ./analytics-service:/rails
      - /rails/tmp
      - /rails/log
    environment:
      - RAILS_ENV=development
      - DATABASE_HOST=postgres
      - DATABASE_PORT=5432
      - DATABASE_USERNAME=postgres
      - DATABASE_PASSWORD=password
      - AD_SERVICE_URL=http://ad-service:8080
      - BINDING=0.0.0.0
      - PORT=3000
      - RAILS_SERVE_STATIC_FILES=true
      - RAILS_LOG_TO_STDOUT=true
    command: ["./bin/rails", "server", "-b", "0.0.0.0", "-p", "3000", "--dev-caching"]
    restart: unless-stopped
    networks:
      - adtech-network

  # Bidding Service (Python)
  bidding-service:
    build:
      context: ./bidding-service
      dockerfile: Dockerfile
    ports:
      - "3001:3001"
    environment:
      - ANALYTICS_SERVICE_URL=http://analytics-service:3000
    restart: unless-stopped
    networks:
      - adtech-network

  # PostgreSQL for analytics service
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: adtech_analytics
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: password
    ports:
      - "5444:5432"
    volumes:
      - postgres-data:/var/lib/postgresql/data
    restart: unless-stopped
    networks:
      - adtech-network

  # Redis for caching
  redis:
    image: redis:7-alpine
    ports:
      - "6380:6379"
    restart: unless-stopped
    networks:
      - adtech-network

volumes:
  postgres-data:

networks:
  adtech-network:
    driver: bridge
```

## Step 2: Build and Start Services

```bash
# Build and start all services
docker compose up -d --build

# Check if all services are running
docker compose ps
```

## Step 3: Test the Services

Create a test script `test-services.sh`:

```bash
#!/bin/bash

echo "🧪 Testing AdTech Services..."
echo "================================"

# Test Ad Service
echo "1. Testing Ad Service..."
AD_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8180/health)
if [ "$AD_RESPONSE" = "200" ]; then
    echo "✅ Ad Service is healthy (HTTP $AD_RESPONSE)"
else
    echo "❌ Ad Service is not responding (HTTP $AD_RESPONSE)"
fi

# Test Analytics Service
echo "2. Testing Analytics Service..."
ANALYTICS_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/health)
if [ "$ANALYTICS_RESPONSE" = "200" ]; then
    echo "✅ Analytics Service is healthy (HTTP $ANALYTICS_RESPONSE)"
else
    echo "❌ Analytics Service is not responding (HTTP $ANALYTICS_RESPONSE)"
fi

# Test Bidding Service
echo "3. Testing Bidding Service..."
BIDDING_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3001/health)
if [ "$BIDDING_RESPONSE" = "200" ]; then
    echo "✅ Bidding Service is healthy (HTTP $BIDDING_RESPONSE)"
else
    echo "❌ Bidding Service is not responding (HTTP $BIDDING_RESPONSE)"
fi

# Test Service Integration
echo "4. Testing Service Integration..."
echo "   Making a bid request..."
BID_RESPONSE=$(curl -s -X POST http://localhost:3001/bidding/calculate \
  -H "Content-Type: application/json" \
  -d '{"ad_request_id": "test-123", "user_id": "user-456"}')

if echo "$BID_RESPONSE" | grep -q "bid_value"; then
    echo "✅ Bidding integration working"
    echo "   Response: $BID_RESPONSE"
else
    echo "❌ Bidding integration failed"
fi

echo "================================"
echo "🎉 Testing complete!"
```

Make the script executable and run it:

```bash
chmod +x test-services.sh
./test-services.sh
```

## Step 4: Manual Testing

You can also test the services manually:

### Ad Service
```bash
curl http://localhost:8180/health
```

### Analytics Service
```bash
curl http://localhost:3000/health
```

### Bidding Service
```bash
curl http://localhost:3001/health
curl -X POST http://localhost:3001/bidding/calculate \
  -H "Content-Type: application/json" \
  -d '{"ad_request_id": "test-123", "user_id": "user-456"}'
```

## Expected Results

After running the test script, you should see:
- All three services returning HTTP 200 for health checks
- Bidding service successfully processing bid requests
- Services communicating with each other

## Troubleshooting

If services fail to start:

1. **Check logs:**
   ```bash
   docker compose logs [service-name]
   ```

2. **Check if ports are available:**
   ```bash
   netstat -an | grep :8180
   netstat -an | grep :3000
   netstat -an | grep :3001
   ```

3. **Rebuild services:**
   ```bash
   docker compose down
   docker compose up -d --build
   ```

## Next Steps

Once all services are running and healthy, proceed to Exercise 02 where we'll add OpenTelemetry instrumentation.

## Cleanup

To stop all services:
```bash
docker compose down
```

To remove all data:
```bash
docker compose down -v
``` 