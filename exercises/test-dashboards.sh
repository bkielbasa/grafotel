#!/bin/bash

echo "📊 Testing Dashboard Loading..."
echo "==============================="

# Wait for Grafana to be ready
echo "⏳ Waiting for Grafana to start..."
sleep 15

# Test Grafana
echo "1. Testing Grafana..."
GRAFANA_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3002/api/health)
if [ "$GRAFANA_RESPONSE" = "200" ]; then
    echo "✅ Grafana is healthy (HTTP $GRAFANA_RESPONSE)"
else
    echo "❌ Grafana is not responding (HTTP $GRAFANA_RESPONSE)"
fi

# Test data sources
echo "2. Testing Data Sources..."
PROM_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9090/-/healthy)
LOKI_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3100/ready)
TEMPO_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3200/ready)

echo "   Prometheus: $([ "$PROM_RESPONSE" = "200" ] && echo "✅" || echo "❌") (HTTP $PROM_RESPONSE)"
echo "   Loki: $([ "$LOKI_RESPONSE" = "200" ] && echo "✅" || echo "❌") (HTTP $LOKI_RESPONSE)"
echo "   Tempo: $([ "$TEMPO_RESPONSE" = "200" ] && echo "✅" || echo "❌") (HTTP $TEMPO_RESPONSE)"

# Test application services for data generation
echo "3. Testing Application Services..."
AD_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8180/health)
BIDDING_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3001/health)

echo "   Ad Service: $([ "$AD_RESPONSE" = "200" ] && echo "✅" || echo "❌") (HTTP $AD_RESPONSE)"
echo "   Bidding Service: $([ "$BIDDING_RESPONSE" = "200" ] && echo "✅" || echo "❌") (HTTP $BIDDING_RESPONSE)"

# Generate some data for dashboards
echo "4. Generating data for dashboards..."
for i in {1..10}; do
    echo "   Request $i/10..."
    curl -s -X POST http://localhost:3001/bidding/calculate \
      -H "Content-Type: application/json" \
      -d "{\"ad_request_id\": \"dashboard-test-$i\", \"user_id\": \"user-$i\"}" > /dev/null
    
    # Also test ad service
    curl -s http://localhost:8180/health > /dev/null
    
    sleep 0.5
done

echo "✅ Generated test data"

# Check if dashboards are accessible
echo "5. Checking dashboard accessibility..."
if [ "$GRAFANA_RESPONSE" = "200" ]; then
    echo "✅ Grafana is accessible - you can manually check dashboards"
    echo "   Go to http://localhost:3002 → Dashboards"
else
    echo "❌ Cannot check dashboards - Grafana not accessible"
fi

# Check Prometheus targets for metrics
echo "6. Checking Prometheus targets..."
TARGETS_COUNT=$(curl -s http://localhost:9090/api/v1/targets | grep -c "up" || echo "0")
if [ "$TARGETS_COUNT" -gt 0 ]; then
    echo "✅ Prometheus targets are up ($TARGETS_COUNT targets found)"
else
    echo "❌ No Prometheus targets found"
fi

# Check Loki labels for logs
echo "7. Checking Loki log collection..."
LOG_COUNT=$(curl -s "http://localhost:3100/loki/api/v1/labels" | grep -c "container_name" || echo "0")
if [ "$LOG_COUNT" -gt 0 ]; then
    echo "✅ Logs are being collected by Loki"
else
    echo "⚠️  No logs found in Loki (this might be normal for new setup)"
fi

# Check Tempo for traces
echo "8. Checking Tempo trace collection..."
TRACE_COUNT=$(curl -s http://localhost:3200/api/search/tags | grep -c "service.name" || echo "0")
if [ "$TRACE_COUNT" -gt 0 ]; then
    echo "✅ Traces are being collected by Tempo"
else
    echo "⚠️  No traces found in Tempo (this might be normal for new setup)"
fi

echo "==============================="
echo "🎉 Dashboard testing complete!"

# Summary
echo ""
echo "📊 Summary:"
echo "Grafana: $([ "$GRAFANA_RESPONSE" = "200" ] && echo "✅" || echo "❌")"
echo "Prometheus: $([ "$PROM_RESPONSE" = "200" ] && echo "✅" || echo "❌")"
echo "Loki: $([ "$LOKI_RESPONSE" = "200" ] && echo "✅" || echo "❌")"
echo "Tempo: $([ "$TEMPO_RESPONSE" = "200" ] && echo "✅" || echo "❌")"
echo "Application Services: $([ "$AD_RESPONSE" = "200" ] && [ "$BIDDING_RESPONSE" = "200" ] && echo "✅" || echo "❌")"
echo "Prometheus Targets: $([ "$TARGETS_COUNT" -gt 0 ] && echo "✅" || echo "❌")"
echo "Log Collection: $([ "$LOG_COUNT" -gt 0 ] && echo "✅" || echo "❌")"
echo "Trace Collection: $([ "$TRACE_COUNT" -gt 0 ] && echo "✅" || echo "❌")"

echo ""
echo "🌐 Access Points:"
echo "Grafana: http://localhost:3002 (admin/admin)"
echo "Prometheus: http://localhost:9090"
echo "Loki: http://localhost:3100"
echo "Tempo: http://localhost:3200"

echo ""
echo "📋 Next Steps:"
echo "1. Open Grafana: http://localhost:3002"
echo "2. Go to Dashboards to see imported dashboards"
echo "3. Import dashboards using these IDs:"
echo "   - Prometheus Overview: 3662"
echo "   - Node Exporter Full: 1860"
echo "   - Loki Overview: 12019"
echo "4. Explore the dashboard structure and panels"
echo "5. Customize dashboards for your specific needs"
echo "6. Export modified dashboards as JSON"

echo ""
echo "🔧 Dashboard Import Instructions:"
echo "1. Go to Grafana → Dashboards → Import"
echo "2. Enter the dashboard ID (e.g., 3662)"
echo "3. Click Load"
echo "4. Select the appropriate data source"
echo "5. Click Import"
echo "6. To export: Open dashboard → Settings → JSON Model" 