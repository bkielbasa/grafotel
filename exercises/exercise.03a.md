# Exercise 03a: Creating Dashboards in Grafana UI

## Objective
Learn how to create and customize dashboards using Grafana's intuitive web interface, then export them as configuration files for your observability stack.

## Prerequisites
- Completed Exercise 03 (Grafana, Loki, and Promtail running)
- Basic understanding of Grafana dashboard concepts
- Access to Grafana UI at http://localhost:3002

## What We'll Do
1. **Create Dashboards in UI** - Use Grafana's visual interface
2. **Add Different Panel Types** - Learn various visualization options
3. **Configure Queries** - Write PromQL and LogQL queries
4. **Customize Visualizations** - Style and format panels
5. **Export as JSON** - Save dashboards as configuration files
6. **Organize Dashboards** - Use folders and tags

## Step 1: Access Grafana

1. **Open Grafana**: http://localhost:3002
2. **Login**: admin / admin
3. **Verify Data Sources**: Go to Configuration → Data Sources
   - Prometheus should be configured
   - Tempo should be configured  
   - Loki should be configured

## Step 2: Create Your First Dashboard

### 2.1 Start Dashboard Creation
1. Go to **Dashboards** → **New Dashboard**
2. Click **Add a new panel**
3. You'll see the panel editor interface

### 2.2 Create a Service Health Panel
1. **Configure the panel**:
   - **Title**: "Service Health Status"
   - **Data Source**: Prometheus
   - **Query**: `up`
   - **Visualization**: Stat
   - **Field**: 
     - Go to **Field** tab
     - Set **Unit** to "short"
     - Go to **Thresholds**
     - Add threshold: 0 = red, 1 = green
     - Go to **Mappings**
     - Add value mapping: 0 → "Down", 1 → "Up"

2. **Apply and Save**:
   - Click **Apply** to save the panel
   - Click **Save dashboard**
   - Name: "My First Dashboard"
   - Tags: "tutorial", "first"
   - Click **Save**

### 2.3 Add More Panels
1. **Click the + icon** to add another panel
2. **Create a Request Rate Panel**:
   - **Title**: "Request Rate"
   - **Data Source**: Prometheus
   - **Query**: `rate(http_requests_total[5m])`
   - **Visualization**: Time series
   - **Y-axis**: Set **Unit** to "reqps"

3. **Create an Error Rate Panel**:
   - **Title**: "Error Rate"
   - **Data Source**: Prometheus
   - **Query**: `rate(http_requests_total{status=~"5.."}[5m])`
   - **Visualization**: Time series
   - **Y-axis**: Set **Unit** to "reqps"

## Step 3: Create a Logs Dashboard

### 3.1 Create New Dashboard
1. Go to **Dashboards** → **New Dashboard**
2. Click **Add a new panel**

### 3.2 Add Log Panel
1. **Configure the panel**:
   - **Title**: "Application Logs"
   - **Data Source**: Loki
   - **Query**: `{job="docker"}`
   - **Visualization**: Logs
   - **Options**:
     - Enable **Show time**
     - Enable **Show labels**
     - Set **Deduplication** to "None"

2. **Save Dashboard**:
   - Name: "Application Logs"
   - Tags: "logs", "application"

### 3.3 Add Error Logs Panel
1. **Add another panel**:
   - **Title**: "Error Logs"
   - **Data Source**: Loki
   - **Query**: `{job="docker"} |= "error"`
   - **Visualization**: Logs

### 3.4 Test Trace Linking
1. **Generate some traffic**:
   ```bash
   curl -X POST http://localhost:3001/bidding/calculate \
     -H "Content-Type: application/json" \
     -d '{"ad_request_id": "test-123", "user_id": "user-456"}'
   ```

2. **Check for trace links**:
   - Look for logs with "Trace:" in the message
   - Trace IDs should appear as clickable links
   - Click a trace link to open it in Tempo

## Step 4: Create a Metrics Dashboard

### 4.1 Create New Dashboard
1. Go to **Dashboards** → **New Dashboard**
2. Click **Add a new panel**

### 4.2 Add Response Time Panel
1. **Configure the panel**:
   - **Title**: "Response Time (95th percentile)"
   - **Data Source**: Prometheus
   - **Query**: `histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))`
   - **Visualization**: Time series
   - **Y-axis**: Set **Unit** to "s"

### 4.3 Add Success Rate Panel
1. **Add another panel**:
   - **Title**: "Success Rate"
   - **Data Source**: Prometheus
   - **Query**: `rate(http_requests_total{status=~"2.."}[5m]) / rate(http_requests_total[5m])`
   - **Visualization**: Time series
   - **Y-axis**: Set **Unit** to "percentunit"

### 4.4 Add Bidding Metrics Panel
1. **Add another panel**:
   - **Title**: "Bidding Requests"
   - **Data Source**: Prometheus
   - **Query**: `rate(bidding_requests_total[5m])`
   - **Visualization**: Time series
   - **Y-axis**: Set **Unit** to "reqps"

### 4.5 Save Dashboard
- Name: "Application Metrics"
- Tags: "metrics", "performance"

## Step 5: Customize Dashboard Layout

### 5.1 Organize Panels
1. **Resize panels**: Click and drag panel corners
2. **Move panels**: Click and drag panel headers
3. **Arrange in grid**: Use the grid layout for better organization

### 5.2 Add Dashboard Variables
1. **Go to Dashboard Settings** (gear icon)
2. **Click Variables**
3. **Add New Variable**:
   - **Name**: service
   - **Type**: Query
   - **Data Source**: Prometheus
   - **Query**: `label_values(http_requests_total, service)`
   - **Refresh**: On Dashboard Load

4. **Use the variable in queries**:
   - Update queries to use `$service`
   - Example: `rate(http_requests_total{service="$service"}[5m])`

### 5.3 Set Dashboard Options
1. **Go to Dashboard Settings**
2. **General**:
   - Set **Time range** to "Last 1 hour"
   - Set **Refresh** to "5s"
   - Add **Description**
3. **Links**: Add links to other dashboards or external tools

## Step 6: Export Dashboards

### 6.1 Export as JSON
1. **Open any dashboard**
2. **Click Settings** (gear icon)
3. **Click JSON Model**
4. **Copy the JSON content**
5. **Create a file**: `monitoring/grafana/dashboards/my-dashboard.json`
6. **Paste the JSON content**

### 6.2 Export Multiple Dashboards
Repeat the process for each dashboard you created:
- Service Health Dashboard
- Application Logs Dashboard
- Application Metrics Dashboard

## Step 7: Organize Dashboards

### 7.1 Create Folders
1. **Go to Dashboards**
2. **Click New Folder**
3. **Create folders**:
   - "AdTech Services"
   - "Infrastructure"
   - "Logs and Traces"

### 7.2 Move Dashboards to Folders
1. **Select a dashboard**
2. **Click the three dots** (⋮)
3. **Click Move**
4. **Select the appropriate folder**

### 7.3 Add Tags
1. **Edit dashboard settings**
2. **Add relevant tags**:
   - "adtech", "services", "metrics", "logs", "traces"
   - Tags help with organization and search

## Step 8: Test Dashboard Functionality

### 8.1 Generate Test Data
```bash
# Generate various types of traffic
for i in {1..20}; do
    curl -X POST http://localhost:3001/bidding/calculate \
      -H "Content-Type: application/json" \
      -d "{\"ad_request_id\": \"test-$i\", \"user_id\": \"user-$i\"}"
    sleep 0.5
done
```

### 8.2 Verify Dashboard Data
1. **Check each dashboard** for data
2. **Test time range selection**
3. **Test refresh intervals**
4. **Verify trace linking** in logs
5. **Test dashboard variables**

## Step 9: Create Advanced Panels

### 9.1 Create a Table Panel
1. **Add new panel**
2. **Configure**:
   - **Title**: "Top Services by Request Rate"
   - **Data Source**: Prometheus
   - **Query**: `topk(5, rate(http_requests_total[5m]))`
   - **Visualization**: Table
   - **Transform**: Organize columns as needed

### 9.2 Create a Heatmap Panel
1. **Add new panel**
2. **Configure**:
   - **Title**: "Response Time Heatmap"
   - **Data Source**: Prometheus
   - **Query**: `rate(http_request_duration_seconds_bucket[5m])`
   - **Visualization**: Heatmap

### 9.3 Create a Gauge Panel
1. **Add new panel**
2. **Configure**:
   - **Title**: "Current Success Rate"
   - **Data Source**: Prometheus
   - **Query**: `rate(http_requests_total{status=~"2.."}[5m]) / rate(http_requests_total[5m])`
   - **Visualization**: Gauge
   - **Set min/max**: 0 to 1

## Step 10: Best Practices

### 10.1 Dashboard Design
- **Use consistent naming** for panels and dashboards
- **Group related metrics** together
- **Use appropriate visualizations** for data types
- **Set reasonable refresh intervals**
- **Add descriptions** to dashboards and panels

### 10.2 Query Optimization
- **Use appropriate time ranges** for queries
- **Avoid overly complex queries**
- **Use rate() for counters**
- **Use histogram_quantile() for percentiles**

### 10.3 Organization
- **Use folders** to organize dashboards
- **Add meaningful tags**
- **Create a dashboard hierarchy**
- **Document dashboard purposes**

## Expected Results

After completing this exercise, you should have:
- ✅ Created multiple dashboards using Grafana UI
- ✅ Added various panel types and visualizations
- ✅ Configured PromQL and LogQL queries
- ✅ Customized panel styling and layout
- ✅ Exported dashboards as JSON files
- ✅ Organized dashboards with folders and tags
- ✅ Tested trace linking functionality

## Popular Panel Types to Try

### Metrics Panels
- **Time series**: For trends over time
- **Stat**: For single values with thresholds
- **Gauge**: For percentage or ratio metrics
- **Bar chart**: For categorical data
- **Heatmap**: For distribution data

### Log Panels
- **Logs**: For log entries
- **Table**: For structured log data

### Special Panels
- **Text**: For documentation and notes
- **Stat**: For key metrics with thresholds
- **Pie chart**: For proportions

## Troubleshooting

1. **No data in panels**:
   - Check data source configuration
   - Verify queries are correct
   - Generate some test traffic
   - Check time range selection

2. **Panels not updating**:
   - Check refresh interval
   - Verify data source is accessible
   - Check for query errors

3. **Trace links not working**:
   - Verify derived fields configuration
   - Check log format contains "Trace:"
   - Test Tempo connectivity

## Next Steps

Once you're comfortable with dashboard creation, proceed to Exercise 04 where we'll add Alertmanager for alerting.

## Cleanup

To stop all services:
```bash
docker compose down
```

To remove all data:
```bash
docker compose down -v
``` 