#!/bin/bash

echo "🚨 Testing Alerting Setup..."
echo "============================"

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 20

# Test Alertmanager
echo "1. Testing Alertmanager..."
ALERTMANAGER_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9093/-/healthy)
if [ "$ALERTMANAGER_RESPONSE" = "200" ]; then
    echo "✅ Alertmanager is healthy (HTTP $ALERTMANAGER_RESPONSE)"
else
    echo "❌ Alertmanager is not responding (HTTP $ALERTMANAGER_RESPONSE)"
fi

# Test Prometheus alerting
echo "2. Testing Prometheus alerting..."
PROM_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9090/-/healthy)
if [ "$PROM_RESPONSE" = "200" ]; then
    echo "✅ Prometheus is healthy (HTTP $PROM_RESPONSE)"
else
    echo "❌ Prometheus is not responding (HTTP $PROM_RESPONSE)"
fi

# Check if alerting rules are loaded
echo "3. Checking alerting rules..."
RULES_COUNT=$(curl -s http://localhost:9090/api/v1/rules | grep -c "alerting" || echo "0")
if [ "$RULES_COUNT" -gt 0 ]; then
    echo "✅ Alerting rules are loaded ($RULES_COUNT rule groups found)"
else
    echo "❌ No alerting rules found"
fi

# Check Alertmanager configuration
echo "4. Checking Alertmanager configuration..."
CONFIG_RESPONSE=$(curl -s http://localhost:9093/api/v1/status | grep -c "config" || echo "0")
if [ "$CONFIG_RESPONSE" -gt 0 ]; then
    echo "✅ Alertmanager configuration is valid"
else
    echo "❌ Alertmanager configuration issue"
fi

# Generate some traffic to potentially trigger alerts
echo "5. Generating traffic for alert testing..."
for i in {1..10}; do
    echo "   Making request $i/10..."
    curl -s -X POST http://localhost:3001/bidding/calculate \
      -H "Content-Type: application/json" \
      -d "{\"ad_request_id\": \"alert-test-$i\", \"user_id\": \"user-$i\"}" > /dev/null
    sleep 0.5
done

echo "✅ Generated test traffic"

# Check for active alerts
echo "6. Checking for active alerts..."
ALERTS_COUNT=$(curl -s http://localhost:9090/api/v1/alerts | grep -c "firing" || echo "0")
if [ "$ALERTS_COUNT" -gt 0 ]; then
    echo "⚠️  Active alerts found ($ALERTS_COUNT firing alerts)"
else
    echo "✅ No active alerts (this is good for a healthy system)"
fi

# Check Alertmanager receivers
echo "7. Checking Alertmanager receivers..."
RECEIVERS_COUNT=$(curl -s http://localhost:9093/api/v1/status | grep -c "web.hook" || echo "0")
if [ "$RECEIVERS_COUNT" -gt 0 ]; then
    echo "✅ Alertmanager receivers configured"
else
    echo "❌ No receivers found in Alertmanager"
fi

# Test Grafana alerting integration
echo "8. Testing Grafana alerting integration..."
GRAFANA_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3002/api/health)
if [ "$GRAFANA_RESPONSE" = "200" ]; then
    echo "✅ Grafana is accessible for alert management"
else
    echo "❌ Grafana is not accessible"
fi

echo "============================"
echo "🎉 Alerting testing complete!"

# Summary
echo ""
echo "📊 Summary:"
echo "Alertmanager: $([ "$ALERTMANAGER_RESPONSE" = "200" ] && echo "✅" || echo "❌")"
echo "Prometheus: $([ "$PROM_RESPONSE" = "200" ] && echo "✅" || echo "❌")"
echo "Alerting Rules: $([ "$RULES_COUNT" -gt 0 ] && echo "✅" || echo "❌")"
echo "Alertmanager Config: $([ "$CONFIG_RESPONSE" -gt 0 ] && echo "✅" || echo "❌")"
echo "Alertmanager Receivers: $([ "$RECEIVERS_COUNT" -gt 0 ] && echo "✅" || echo "❌")"
echo "Grafana Integration: $([ "$GRAFANA_RESPONSE" = "200" ] && echo "✅" || echo "❌")"
echo "Active Alerts: $([ "$ALERTS_COUNT" -gt 0 ] && echo "⚠️" || echo "✅")"

echo ""
echo "🌐 Access Points:"
echo "Alertmanager: http://localhost:9093"
echo "Prometheus Alerts: http://localhost:9090/alerts"
echo "Grafana Alerting: http://localhost:3002/alerting"

echo ""
echo "📋 Next Steps:"
echo "1. Open Alertmanager: http://localhost:9093"
echo "2. Check Prometheus Alerts: http://localhost:9090/alerts"
echo "3. Configure Slack webhook in alertmanager.yml"
echo "4. Test alerting by stopping a service:"
echo "   docker compose stop bidding-service"
echo "   # Wait 2 minutes, then check alerts"
echo "   docker compose start bidding-service" 