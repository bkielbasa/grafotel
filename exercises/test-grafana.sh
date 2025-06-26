#!/bin/bash

echo "📊 Testing Grafana Setup..."
echo "============================"

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

# Generate some logs
echo "4. Generating logs..."
for i in {1..3}; do
    echo "   Making request $i/3..."
    curl -s -X POST http://localhost:3001/bidding/calculate \
      -H "Content-Type: application/json" \
      -d "{\"ad_request_id\": \"log-test-$i\", \"user_id\": \"user-$i\"}" > /dev/null
    sleep 1
done

echo "✅ Generated test logs"

# Check if logs are in Loki
echo "5. Checking log collection..."
LOG_COUNT=$(curl -s "http://localhost:3100/loki/api/v1/labels" | grep -c "container_name" || echo "0")
if [ "$LOG_COUNT" -gt 0 ]; then
    echo "✅ Logs are being collected by Loki"
else
    echo "⚠️  No logs found in Loki (this might be normal for new setup)"
fi

# Test Grafana data sources
echo "6. Testing Grafana data sources..."
if [ "$GRAFANA_RESPONSE" = "200" ]; then
    echo "✅ Grafana is accessible - you can manually check data sources"
    echo "   Go to http://localhost:3002 (admin/admin) → Configuration → Data Sources"
else
    echo "❌ Cannot test data sources - Grafana not accessible"
fi

# Test Prometheus integration
echo "7. Testing Prometheus integration..."
PROM_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9090/-/healthy)
if [ "$PROM_RESPONSE" = "200" ]; then
    echo "✅ Prometheus is healthy and can be used by Grafana"
else
    echo "❌ Prometheus is not responding"
fi

# Test Tempo integration
echo "8. Testing Tempo integration..."
TEMPO_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3200/ready)
if [ "$TEMPO_RESPONSE" = "200" ]; then
    echo "✅ Tempo is ready and can be used by Grafana"
else
    echo "❌ Tempo is not ready"
fi

echo "============================"
echo "🎉 Grafana testing complete!"

# Summary
echo ""
echo "📊 Summary:"
echo "Grafana: $([ "$GRAFANA_RESPONSE" = "200" ] && echo "✅" || echo "❌")"
echo "Loki: $([ "$LOKI_RESPONSE" = "200" ] && echo "✅" || echo "❌")"
echo "Promtail: $([ "$PROMTAIL_RESPONSE" = "200" ] && echo "✅" || echo "❌")"
echo "Prometheus: $([ "$PROM_RESPONSE" = "200" ] && echo "✅" || echo "❌")"
echo "Tempo: $([ "$TEMPO_RESPONSE" = "200" ] && echo "✅" || echo "❌")"
echo "Log Collection: $([ "$LOG_COUNT" -gt 0 ] && echo "✅" || echo "❌")"

echo ""
echo "🌐 Access Points:"
echo "Grafana: http://localhost:3002 (admin/admin)"
echo "Loki: http://localhost:3100"
echo "Promtail: http://localhost:9080/metrics"
echo "Prometheus: http://localhost:9090"
echo "Tempo: http://localhost:3200"

echo ""
echo "📋 Next Steps:"
echo "1. Open Grafana: http://localhost:3002"
echo "2. Login with admin/admin"
echo "3. Go to Explore to query metrics, traces, and logs"
echo "4. Check Data Sources in Configuration" 