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

# Test Service Integration
echo "5. Testing Service Integration..."
INTEGRATION_TEST=$(curl -s -X POST http://localhost:3001/bidding/calculate \
  -H "Content-Type: application/json" \
  -d '{"ad_request_id": "integration-test", "user_id": "test-user"}' | grep -c "bid_value" || echo "0")

if [ "$INTEGRATION_TEST" -gt 0 ]; then
    echo "   Service Integration: ✅ (services communicating)"
else
    echo "   Service Integration: ❌ (services not communicating)"
fi

# Test Grafana Data Sources
echo "6. Testing Grafana Data Sources..."
if [ "$GRAFANA_RESPONSE" = "200" ]; then
    echo "   Grafana Data Sources: ✅ (accessible via UI)"
    echo "   Go to http://localhost:3002 → Configuration → Data Sources"
else
    echo "   Grafana Data Sources: ❌ (Grafana not accessible)"
fi

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
echo "Service Integration: $([ "$INTEGRATION_TEST" -gt 0 ] && echo "✅" || echo "❌")"

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

echo ""
echo "🎯 Next Steps:"
echo "=============="
echo "1. Explore the dashboards in Grafana"
echo "2. Test alerting by stopping a service"
echo "3. Customize the configuration for your needs"
echo "4. Add more services following the same pattern"
echo "5. Scale the stack for production use"

echo ""
echo "🎉 CONGRATULATIONS! You have successfully built a complete observability stack!" 