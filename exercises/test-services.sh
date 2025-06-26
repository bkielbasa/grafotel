#!/bin/bash

echo "🧪 Testing AdTech Services..."
echo "================================"

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 10

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
    echo "   Response: $BID_RESPONSE"
fi

# Test PostgreSQL
echo "5. Testing PostgreSQL..."
PG_RESPONSE=$(docker compose exec -T postgres pg_isready -U postgres 2>/dev/null | grep -c "accepting connections")
if [ "$PG_RESPONSE" -gt 0 ]; then
    echo "✅ PostgreSQL is ready"
else
    echo "❌ PostgreSQL is not ready"
fi

# Test Redis
echo "6. Testing Redis..."
REDIS_RESPONSE=$(docker compose exec -T redis redis-cli ping 2>/dev/null | grep -c "PONG")
if [ "$REDIS_RESPONSE" -gt 0 ]; then
    echo "✅ Redis is ready"
else
    echo "❌ Redis is not ready"
fi

echo "================================"
echo "🎉 Testing complete!"

# Summary
echo ""
echo "📊 Summary:"
echo "Ad Service: $([ "$AD_RESPONSE" = "200" ] && echo "✅" || echo "❌")"
echo "Analytics Service: $([ "$ANALYTICS_RESPONSE" = "200" ] && echo "✅" || echo "❌")"
echo "Bidding Service: $([ "$BIDDING_RESPONSE" = "200" ] && echo "✅" || echo "❌")"
echo "PostgreSQL: $([ "$PG_RESPONSE" -gt 0 ] && echo "✅" || echo "❌")"
echo "Redis: $([ "$REDIS_RESPONSE" -gt 0 ] && echo "✅" || echo "❌")" 