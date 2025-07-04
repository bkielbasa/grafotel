# Exercise 03a: Loading Existing Dashboards

## Objective
Learn how to load existing dashboards from Grafana's dashboard library and export them as JSON configuration files for your observability stack.

## Prerequisites
- Completed Exercise 03 (Grafana, Loki, and Promtail running)
- Basic understanding of Grafana dashboard concepts

## What We'll Do
1. **Load Existing Dashboards** - Import dashboards from Grafana's library
2. **Explore Dashboard Structure** - Understand how dashboards are organized
3. **Export as JSON** - Save dashboards as configuration files
4. **Customize Dashboards** - Modify dashboards for our adtech services
5. **Provision Dashboards** - Set up automatic dashboard loading

## Step 1: Access Grafana

1. **Open Grafana**: http://localhost:3002
2. **Login**: admin / admin
3. **Verify Data Sources**: Go to Configuration → Data Sources
   - Prometheus should be configured
   - Tempo should be configured  
   - Loki should be configured

## Step 2: Load Prometheus Dashboard

### 2.1 Import Prometheus Dashboard
1. Go to **Dashboards** → **Import**
2. Click **Upload JSON file** or use the **Import via grafana.com** option
3. Search for "Prometheus" in the dashboard library
4. Import dashboard ID **3662** (Prometheus 2.0 Overview)

### 2.2 Alternative: Import via Dashboard ID
1. In the Import screen, enter dashboard ID **3662**
2. Click **Load**
3. Select **Prometheus** as the data source
4. Click **Import**

### 2.3 Explore the Dashboard
- **Metrics Overview**: CPU, memory, disk usage
- **Prometheus Health**: Targets, rules, storage
- **Query Performance**: Query rate, duration
- **Storage**: Retention, compaction

## Step 3: Load Node Exporter Dashboard

### 3.1 Import Node Exporter Dashboard
1. Go to **Dashboards** → **Import**
2. Enter dashboard ID **1860** (Node Exporter Full)
3. Click **Load**
4. Select **Prometheus** as the data source
5. Click **Import**

### 3.2 Explore the Dashboard
- **System Overview**: CPU, memory, disk, network
- **Hardware**: Temperature, power, fans
- **Network**: Traffic, errors, connections
- **Processes**: Running processes, load average

## Step 4: Load Loki Dashboard

### 4.1 Import Loki Dashboard
1. Go to **Dashboards** → **Import**
2. Enter dashboard ID **12019** (Loki Overview)
3. Click **Load**
4. Select **Loki** as the data source
5. Click **Import**

### 4.2 Explore the Dashboard
- **Log Volume**: Log ingestion rate
- **Query Performance**: Query rate, duration
- **Storage**: Chunk storage, retention
- **Errors**: Ingestion errors, query errors

## Step 5: Export Dashboards as JSON

### 5.1 Export Prometheus Dashboard
1. Open the Prometheus dashboard
2. Click the **Settings** icon (gear) in the top right
3. Click **JSON Model**
4. Copy the entire JSON content
5. Create file: `monitoring/grafana/dashboards/prometheus-overview.json`
6. Paste the JSON content

### 5.2 Export Node Exporter Dashboard
1. Open the Node Exporter dashboard
2. Go to Settings → JSON Model
3. Copy the JSON content
4. Create file: `monitoring/grafana/dashboards/node-exporter.json`
5. Paste the JSON content

### 5.3 Export Loki Dashboard
1. Open the Loki dashboard
2. Go to Settings → JSON Model
3. Copy the JSON content
4. Create file: `monitoring/grafana/dashboards/loki-overview.json`
5. Paste the JSON content

## Step 6: Customize Dashboards for AdTech

### 6.1 Create AdTech-Specific Prometheus Dashboard
Create `monitoring/grafana/dashboards/adtech-prometheus.json`:

```json
{
  "dashboard": {
    "id": null,
    "title": "AdTech Prometheus Overview",
    "tags": ["adtech", "prometheus", "infrastructure"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "Service Health",
        "type": "stat",
        "targets": [
          {
            "expr": "up",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "color": {
              "mode": "thresholds"
            },
            "thresholds": {
              "steps": [
                {"color": "red", "value": 0},
                {"color": "green", "value": 1}
              ]
            },
            "mappings": [
              {"options": {"0": {"text": "Down"}}, "type": "value"},
              {"options": {"1": {"text": "Up"}}, "type": "value"}
            ]
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0}
      },
      {
        "id": 2,
        "title": "Request Rate by Service",
        "type": "timeseries",
        "targets": [
          {
            "expr": "rate(http_requests_total[5m])",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "color": {"mode": "palette-classic"},
            "custom": {
              "axisLabel": "",
              "axisPlacement": "auto",
              "barAlignment": 0,
              "drawStyle": "line",
              "fillOpacity": 10,
              "gradientMode": "none",
              "hideFrom": {"legend": false, "tooltip": false, "vis": false},
              "lineInterpolation": "linear",
              "lineWidth": 1,
              "pointSize": 5,
              "scaleDistribution": {"type": "linear"},
              "showPoints": "never",
              "spanNulls": false,
              "stacking": {"group": "A", "mode": "none"},
              "thresholdsStyle": {"mode": "off"}
            },
            "unit": "reqps"
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
      },
      {
        "id": 3,
        "title": "Error Rate",
        "type": "timeseries",
        "targets": [
          {
            "expr": "rate(http_requests_total{status=~\"5..\"}[5m])",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "color": {"mode": "palette-classic"},
            "custom": {
              "axisLabel": "",
              "axisPlacement": "auto",
              "barAlignment": 0,
              "drawStyle": "line",
              "fillOpacity": 10,
              "gradientMode": "none",
              "hideFrom": {"legend": false, "tooltip": false, "vis": false},
              "lineInterpolation": "linear",
              "lineWidth": 1,
              "pointSize": 5,
              "scaleDistribution": {"type": "linear"},
              "showPoints": "never",
              "spanNulls": false,
              "stacking": {"group": "A", "mode": "none"},
              "thresholdsStyle": {"mode": "off"}
            },
            "unit": "reqps"
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8}
      },
      {
        "id": 4,
        "title": "Response Time (95th percentile)",
        "type": "timeseries",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "color": {"mode": "palette-classic"},
            "custom": {
              "axisLabel": "",
              "axisPlacement": "auto",
              "barAlignment": 0,
              "drawStyle": "line",
              "fillOpacity": 10,
              "gradientMode": "none",
              "hideFrom": {"legend": false, "tooltip": false, "vis": false},
              "lineInterpolation": "linear",
              "lineWidth": 1,
              "pointSize": 5,
              "scaleDistribution": {"type": "linear"},
              "showPoints": "never",
              "spanNulls": false,
              "stacking": {"group": "A", "mode": "none"},
              "thresholdsStyle": {"mode": "off"}
            },
            "unit": "s"
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8}
      }
    ],
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "refresh": "5s"
  }
}
```

### 6.2 Create AdTech-Specific Loki Dashboard
Create `monitoring/grafana/dashboards/adtech-loki.json`:

```json
{
  "dashboard": {
    "id": null,
    "title": "AdTech Logs Overview",
    "tags": ["adtech", "loki", "logs"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "Log Volume by Service",
        "type": "timeseries",
        "targets": [
          {
            "expr": "rate({job=\"docker\"}[5m])",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "color": {"mode": "palette-classic"},
            "custom": {
              "axisLabel": "",
              "axisPlacement": "auto",
              "barAlignment": 0,
              "drawStyle": "line",
              "fillOpacity": 10,
              "gradientMode": "none",
              "hideFrom": {"legend": false, "tooltip": false, "vis": false},
              "lineInterpolation": "linear",
              "lineWidth": 1,
              "pointSize": 5,
              "scaleDistribution": {"type": "linear"},
              "showPoints": "never",
              "spanNulls": false,
              "stacking": {"group": "A", "mode": "none"},
              "thresholdsStyle": {"mode": "off"}
            },
            "unit": "logs/s"
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0}
      },
      {
        "id": 2,
        "title": "Error Logs",
        "type": "logs",
        "targets": [
          {
            "expr": "{job=\"docker\"} |= \"error\"",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "color": {"mode": "palette-classic"}
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
      },
      {
        "id": 3,
        "title": "Bidding Service Logs",
        "type": "logs",
        "targets": [
          {
            "expr": "{container_name=\"grafotel-bidding-service-1\"}",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "color": {"mode": "palette-classic"}
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8}
      },
      {
        "id": 4,
        "title": "Analytics Service Logs",
        "type": "logs",
        "targets": [
          {
            "expr": "{container_name=\"grafotel-analytics-service-1\"}",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "color": {"mode": "palette-classic"}
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8}
      }
    ],
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "refresh": "5s"
  }
}
```

## Step 7: Update Dashboard Provisioning

Update `monitoring/grafana/provisioning/dashboards/dashboards.yml`:

```yaml
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
  - name: 'adtech-dashboards'
    orgId: 1
    folder: 'AdTech'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards/adtech
```

## Step 8: Create Directory Structure

```bash
# Create directories for different dashboard categories
mkdir -p monitoring/grafana/dashboards/adtech
mkdir -p monitoring/grafana/dashboards/infrastructure
mkdir -p monitoring/grafana/dashboards/logs

# Move dashboards to appropriate directories
mv monitoring/grafana/dashboards/adtech-*.json monitoring/grafana/dashboards/adtech/
mv monitoring/grafana/dashboards/prometheus-*.json monitoring/grafana/dashboards/infrastructure/
mv monitoring/grafana/dashboards/loki-*.json monitoring/grafana/dashboards/logs/
```

## Step 9: Test Dashboard Loading

Create `test-dashboards.sh`:

```bash
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

echo "   Prometheus: $([ "$PROM_RESPONSE" = "200" ] && echo "✅" || echo "❌") (HTTP $PROM_RESPONSE)"
echo "   Loki: $([ "$LOKI_RESPONSE" = "200" ] && echo "✅" || echo "❌") (HTTP $LOKI_RESPONSE)"

# Generate some data for dashboards
echo "3. Generating data for dashboards..."
for i in {1..10}; do
    curl -s -X POST http://localhost:3001/bidding/calculate \
      -H "Content-Type: application/json" \
      -d "{\"ad_request_id\": \"dashboard-test-$i\", \"user_id\": \"user-$i\"}" > /dev/null
    sleep 0.5
done

echo "✅ Generated test data"

# Check if dashboards are accessible
echo "4. Checking dashboard accessibility..."
if [ "$GRAFANA_RESPONSE" = "200" ]; then
    echo "✅ Grafana is accessible - you can manually check dashboards"
    echo "   Go to http://localhost:3002 → Dashboards"
else
    echo "❌ Cannot check dashboards - Grafana not accessible"
fi

echo "==============================="
echo "🎉 Dashboard testing complete!"

# Summary
echo ""
echo "📊 Summary:"
echo "Grafana: $([ "$GRAFANA_RESPONSE" = "200" ] && echo "✅" || echo "❌")"
echo "Prometheus: $([ "$PROM_RESPONSE" = "200" ] && echo "✅" || echo "❌")"
echo "Loki: $([ "$LOKI_RESPONSE" = "200" ] && echo "✅" || echo "❌")"

echo ""
echo "🌐 Access Points:"
echo "Grafana: http://localhost:3002 (admin/admin)"
echo "Prometheus: http://localhost:9090"
echo "Loki: http://localhost:3100"

echo ""
echo "📋 Next Steps:"
echo "1. Open Grafana: http://localhost:3002"
echo "2. Go to Dashboards to see imported dashboards"
echo "3. Explore the dashboard structure and panels"
echo "4. Customize dashboards for your specific needs"
echo "5. Export modified dashboards as JSON"
```

Make it executable and run:
```bash
chmod +x test-dashboards.sh
./test-dashboards.sh
```

## Step 10: Manual Dashboard Verification

1. **Open Grafana**: http://localhost:3002
2. **Go to Dashboards**: You should see:
   - Prometheus Overview
   - Node Exporter Full
   - Loki Overview
   - AdTech Prometheus Overview
   - AdTech Logs Overview

3. **Test Each Dashboard**:
   - Check if data is loading
   - Verify queries are working
   - Test time range selection
   - Check refresh intervals

## Expected Results

After completing this exercise, you should have:
- ✅ Imported standard dashboards from Grafana library
- ✅ Exported dashboards as JSON configuration files
- ✅ Created custom AdTech-specific dashboards
- ✅ Organized dashboards in folders
- ✅ Set up dashboard provisioning
- ✅ Verified dashboard functionality

## Popular Dashboard IDs

Here are some useful dashboard IDs you can import:

### Infrastructure
- **Prometheus Overview**: 3662
- **Node Exporter Full**: 1860
- **Docker & System Monitoring**: 893
- **Kubernetes Cluster**: 315

### Application
- **Spring Boot 2.1+ Statistics**: 4701
- **Python Application**: 12608
- **Go Application**: 6671

### Logs
- **Loki Overview**: 12019
- **Logs Analysis**: 12020

### Traces
- **Tempo Service Graph**: 12021
- **Tempo Search**: 12022

## Troubleshooting

1. **Dashboard not loading**:
   ```bash
   docker compose logs grafana
   ```

2. **No data in dashboards**:
   - Check data source configuration
   - Verify queries are correct
   - Generate some test traffic

3. **JSON import errors**:
   - Validate JSON syntax
   - Check data source references
   - Ensure all required fields are present

## Next Steps

Once dashboards are working, proceed to Exercise 04 where we'll add Alertmanager for alerting.

## Cleanup

To stop all services:
```bash
docker compose down
```

To remove all data:
```bash
docker compose down -v
``` 