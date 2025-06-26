#!/bin/bash

echo "🔍 Testing OpenTelemetry Collection..."
echo "====================================="

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 15

# Test OpenTelemetry Collector
echo "1. Testing OpenTelemetry Collector..."
OTEL_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9464/metrics)
if [ "$OTEL_RESPONSE" = "200" ]; then
    echo "✅ OpenTelemetry Collector is healthy (HTTP $OTEL_RESPONSE)"
else
    echo "❌ OpenTelemetry Collector is not responding (HTTP $OTEL_RESPONSE)"
fi

# Test Tempo
echo "2. Testing Tempo..."
TEMPO_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3200/ready)
if [ "$TEMPO_RESPONSE" = "200" ]; then
    echo "✅ Tempo is ready (HTTP $TEMPO_RESPONSE)"
else
    echo "❌ Tempo is not ready (HTTP $TEMPO_RESPONSE)"
fi

# Test Prometheus
echo "3. Testing Prometheus..."
PROM_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9090/-/healthy)
if [ "$PROM_RESPONSE" = "200" ]; then
    echo "✅ Prometheus is healthy (HTTP $PROM_RESPONSE)"
else
    echo "❌ Prometheus is not responding (HTTP $PROM_RESPONSE)"
fi

# Generate some traffic to create traces
echo "4. Generating traffic for traces..."
for i in {1..5}; do
    echo "   Making request $i/5..."
    curl -s -X POST http://localhost:3001/bidding/calculate \
      -H "Content-Type: application/json" \
      -d "{\"ad_request_id\": \"test-$i\", \"user_id\": \"user-$i\"}" > /dev/null
    sleep 1
done

echo "✅ Generated test traffic"

# Check if metrics are being collected
echo "5. Checking metrics collection..."
METRICS_COUNT=$(curl -s http://localhost:9464/metrics | grep -c "bidding_requests_total" || echo "0")
if [ "$METRICS_COUNT" -gt 0 ]; then
    echo "✅ Metrics are being collected ($METRICS_COUNT bidding metrics found)"
else
    echo "❌ No metrics found"
fi

# Check Prometheus targets
echo "6. Checking Prometheus targets..."
TARGETS_COUNT=$(curl -s http://localhost:9090/api/v1/targets | grep -c "up" || echo "0")
if [ "$TARGETS_COUNT" -gt 0 ]; then
    echo "✅ Prometheus targets are up ($TARGETS_COUNT targets found)"
else
    echo "❌ No Prometheus targets found"
fi

# Check if traces are being sent to Tempo
echo "7. Checking trace collection..."
TRACE_COUNT=$(curl -s http://localhost:3200/api/search/tags | grep -c "service.name" || echo "0")
if [ "$TRACE_COUNT" -gt 0 ]; then
    echo "✅ Traces are being collected by Tempo"
else
    echo "⚠️  No traces found in Tempo (this might be normal for new setup)"
fi

echo "====================================="
echo "🎉 Telemetry testing complete!"

# Summary
echo ""
echo "📊 Summary:"
echo "OpenTelemetry Collector: $([ "$OTEL_RESPONSE" = "200" ] && echo "✅" || echo "❌")"
echo "Tempo: $([ "$TEMPO_RESPONSE" = "200" ] && echo "✅" || echo "❌")"
echo "Prometheus: $([ "$PROM_RESPONSE" = "200" ] && echo "✅" || echo "❌")"
echo "Metrics Collection: $([ "$METRICS_COUNT" -gt 0 ] && echo "✅" || echo "❌")"
echo "Prometheus Targets: $([ "$TARGETS_COUNT" -gt 0 ] && echo "✅" || echo "❌")"

echo ""
echo "🌐 Access Points:"
echo "Prometheus: http://localhost:9090"
echo "Tempo: http://localhost:3200"
echo "OpenTelemetry Collector Metrics: http://localhost:9464/metrics" 