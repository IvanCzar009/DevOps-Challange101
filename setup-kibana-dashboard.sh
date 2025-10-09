#!/bin/bash

# Kibana Dashboard Setup Script for Tomcat Logs
# This script automatically creates index patterns, visualizations, and dashboards in Kibana

KIBANA_URL="http://localhost:5601"  # Internal Kibana port
KIBANA_EXTERNAL_URL="http://localhost:8090"  # External access port (port forwarded)
INDEX_PATTERN="tomcat-logs-*"
DASHBOARD_NAME="Tomcat Access Logs Dashboard"

echo "🔧 Setting up Kibana Dashboard for Tomcat Logs..."
echo "Kibana Internal URL: $KIBANA_URL"
echo "Kibana External URL: $KIBANA_EXTERNAL_URL"
echo "Index Pattern: $INDEX_PATTERN"

# Wait for Kibana to be ready
echo "⏳ Waiting for Kibana to be ready..."
until curl -s -f "$KIBANA_URL/api/status" > /dev/null 2>&1; do
    echo "Waiting for Kibana..."
    sleep 5
done
echo "✅ Kibana is ready!"

# Get Kibana version and space info
KIBANA_VERSION=$(curl -s "$KIBANA_URL/api/status" | grep -o '"version":"[^"]*' | cut -d'"' -f4)
echo "📊 Kibana version: $KIBANA_VERSION"

# Function to make Kibana API calls with proper headers
kibana_api() {
    local method=$1
    local endpoint=$2
    local data=$3
    
    curl -s -X "$method" "$KIBANA_URL$endpoint" \
        -H "Content-Type: application/json" \
        -H "kbn-xsrf: true" \
        -d "$data"
}

# Create Index Pattern
echo "📋 Creating index pattern: $INDEX_PATTERN..."
INDEX_PATTERN_PAYLOAD='{
  "attributes": {
    "title": "'$INDEX_PATTERN'",
    "timeFieldName": "@timestamp",
    "fields": "[{\"name\":\"@timestamp\",\"type\":\"date\",\"searchable\":true,\"aggregatable\":true},{\"name\":\"message\",\"type\":\"string\",\"searchable\":true,\"aggregatable\":false},{\"name\":\"service\",\"type\":\"string\",\"searchable\":true,\"aggregatable\":true},{\"name\":\"environment\",\"type\":\"string\",\"searchable\":true,\"aggregatable\":true}]"
  }
}'

PATTERN_RESPONSE=$(kibana_api "POST" "/api/saved_objects/index-pattern" "$INDEX_PATTERN_PAYLOAD")
PATTERN_ID=$(echo $PATTERN_RESPONSE | grep -o '"id":"[^"]*' | cut -d'"' -f4)

if [ -n "$PATTERN_ID" ]; then
    echo "✅ Index pattern created with ID: $PATTERN_ID"
else
    echo "ℹ️  Index pattern might already exist, continuing..."
    # Try to find existing pattern
    EXISTING_PATTERN=$(curl -s "$KIBANA_URL/api/saved_objects/_find?type=index-pattern&search_fields=title&search=$INDEX_PATTERN")
    PATTERN_ID=$(echo $EXISTING_PATTERN | grep -o '"id":"[^"]*' | head -n1 | cut -d'"' -f4)
    echo "📋 Using existing pattern ID: $PATTERN_ID"
fi

# Set as default index pattern
if [ -n "$PATTERN_ID" ]; then
    echo "🔧 Setting as default index pattern..."
    kibana_api "POST" "/api/kibana/settings/defaultIndex" "{\"value\":\"$PATTERN_ID\"}" > /dev/null
fi

# Create Visualizations
echo "📊 Creating visualizations..."

# 1. Request Count Over Time (Line Chart)
echo "📈 Creating 'Request Count Over Time' visualization..."
REQUESTS_OVER_TIME='{
  "attributes": {
    "title": "Tomcat Requests Over Time",
    "visState": "{\"title\":\"Tomcat Requests Over Time\",\"type\":\"line\",\"aggs\":[{\"id\":\"1\",\"type\":\"count\",\"schema\":\"metric\",\"params\":{}},{\"id\":\"2\",\"type\":\"date_histogram\",\"schema\":\"segment\",\"params\":{\"field\":\"@timestamp\",\"interval\":\"auto\",\"min_doc_count\":1}}]}",
    "uiStateJSON": "{}",
    "description": "",
    "version": 1,
    "kibanaSavedObjectMeta": {
      "searchSourceJSON": "{\"index\":\"'$PATTERN_ID'\",\"query\":{\"match_all\":{}},\"filter\":[]}"
    }
  }
}'

VIS1_RESPONSE=$(kibana_api "POST" "/api/saved_objects/visualization" "$REQUESTS_OVER_TIME")
VIS1_ID=$(echo $VIS1_RESPONSE | grep -o '"id":"[^"]*' | cut -d'"' -f4)
echo "✅ Requests Over Time visualization created: $VIS1_ID"

# 2. HTTP Status Codes (Pie Chart)
echo "🥧 Creating 'HTTP Status Codes' visualization..."
HTTP_STATUS_CODES='{
  "attributes": {
    "title": "HTTP Status Codes Distribution",
    "visState": "{\"title\":\"HTTP Status Codes Distribution\",\"type\":\"pie\",\"aggs\":[{\"id\":\"1\",\"type\":\"count\",\"schema\":\"metric\",\"params\":{}},{\"id\":\"2\",\"type\":\"terms\",\"schema\":\"segment\",\"params\":{\"field\":\"message.keyword\",\"size\":10,\"order\":\"desc\",\"orderBy\":\"1\"}}]}",
    "uiStateJSON": "{}",
    "description": "",
    "version": 1,
    "kibanaSavedObjectMeta": {
      "searchSourceJSON": "{\"index\":\"'$PATTERN_ID'\",\"query\":{\"match_all\":{}},\"filter\":[]}"
    }
  }
}'

VIS2_RESPONSE=$(kibana_api "POST" "/api/saved_objects/visualization" "$HTTP_STATUS_CODES")
VIS2_ID=$(echo $VIS2_RESPONSE | grep -o '"id":"[^"]*' | cut -d'"' -f4)
echo "✅ HTTP Status Codes visualization created: $VIS2_ID"

# 3. Top Accessed Pages (Data Table)
echo "📋 Creating 'Top Accessed Pages' visualization..."
TOP_PAGES='{
  "attributes": {
    "title": "Top Accessed Pages",
    "visState": "{\"title\":\"Top Accessed Pages\",\"type\":\"table\",\"aggs\":[{\"id\":\"1\",\"type\":\"count\",\"schema\":\"metric\",\"params\":{}},{\"id\":\"2\",\"type\":\"terms\",\"schema\":\"bucket\",\"params\":{\"field\":\"message.keyword\",\"size\":10,\"order\":\"desc\",\"orderBy\":\"1\"}}]}",
    "uiStateJSON": "{\"vis\":{\"params\":{\"sort\":{\"columnIndex\":null,\"direction\":null}}}}",
    "description": "",
    "version": 1,
    "kibanaSavedObjectMeta": {
      "searchSourceJSON": "{\"index\":\"'$PATTERN_ID'\",\"query\":{\"match_all\":{}},\"filter\":[]}"
    }
  }
}'

VIS3_RESPONSE=$(kibana_api "POST" "/api/saved_objects/visualization" "$TOP_PAGES")
VIS3_ID=$(echo $VIS3_RESPONSE | grep -o '"id":"[^"]*' | cut -d'"' -f4)
echo "✅ Top Accessed Pages visualization created: $VIS3_ID"

# 4. Log Volume Metric
echo "📊 Creating 'Total Log Entries' metric..."
LOG_VOLUME='{
  "attributes": {
    "title": "Total Log Entries",
    "visState": "{\"title\":\"Total Log Entries\",\"type\":\"metric\",\"aggs\":[{\"id\":\"1\",\"type\":\"count\",\"schema\":\"metric\",\"params\":{}}]}",
    "uiStateJSON": "{}",
    "description": "",
    "version": 1,
    "kibanaSavedObjectMeta": {
      "searchSourceJSON": "{\"index\":\"'$PATTERN_ID'\",\"query\":{\"match_all\":{}},\"filter\":[]}"
    }
  }
}'

VIS4_RESPONSE=$(kibana_api "POST" "/api/saved_objects/visualization" "$LOG_VOLUME")
VIS4_ID=$(echo $VIS4_RESPONSE | grep -o '"id":"[^"]*' | cut -d'"' -f4)
echo "✅ Total Log Entries visualization created: $VIS4_ID"

# Create Dashboard
echo "🏠 Creating dashboard: $DASHBOARD_NAME..."
DASHBOARD_PAYLOAD='{
  "attributes": {
    "title": "'$DASHBOARD_NAME'",
    "hits": 0,
    "description": "Monitoring dashboard for Tomcat access logs from the React application",
    "panelsJSON": "[{\"version\":\"8.10.4\",\"type\":\"visualization\",\"gridData\":{\"x\":0,\"y\":0,\"w\":24,\"h\":15,\"i\":\"1\"},\"panelIndex\":\"1\",\"embeddableConfig\":{},\"panelRefName\":\"panel_1\"},{\"version\":\"8.10.4\",\"type\":\"visualization\",\"gridData\":{\"x\":24,\"y\":0,\"w\":24,\"h\":15,\"i\":\"2\"},\"panelIndex\":\"2\",\"embeddableConfig\":{},\"panelRefName\":\"panel_2\"},{\"version\":\"8.10.4\",\"type\":\"visualization\",\"gridData\":{\"x\":0,\"y\":15,\"w\":24,\"h\":15,\"i\":\"3\"},\"panelIndex\":\"3\",\"embeddableConfig\":{},\"panelRefName\":\"panel_3\"},{\"version\":\"8.10.4\",\"type\":\"visualization\",\"gridData\":{\"x\":24,\"y\":15,\"w\":24,\"h\":15,\"i\":\"4\"},\"panelIndex\":\"4\",\"embeddableConfig\":{},\"panelRefName\":\"panel_4\"}]",
    "optionsJSON": "{\"useMargins\":true,\"syncColors\":false,\"hidePanelTitles\":false}",
    "version": 1,
    "timeRestore": false,
    "kibanaSavedObjectMeta": {
      "searchSourceJSON": "{\"query\":{\"match_all\":{}},\"filter\":[]}"
    }
  },
  "references": [
    {
      "name": "panel_1",
      "type": "visualization",
      "id": "'$VIS1_ID'"
    },
    {
      "name": "panel_2",
      "type": "visualization", 
      "id": "'$VIS2_ID'"
    },
    {
      "name": "panel_3",
      "type": "visualization",
      "id": "'$VIS3_ID'"
    },
    {
      "name": "panel_4",
      "type": "visualization",
      "id": "'$VIS4_ID'"
    }
  ]
}'

DASHBOARD_RESPONSE=$(kibana_api "POST" "/api/saved_objects/dashboard" "$DASHBOARD_PAYLOAD")
DASHBOARD_ID=$(echo $DASHBOARD_RESPONSE | grep -o '"id":"[^"]*' | cut -d'"' -f4)

if [ -n "$DASHBOARD_ID" ]; then
    echo "✅ Dashboard created successfully with ID: $DASHBOARD_ID"
    echo ""
    echo "🎉 Setup Complete!"
    echo "📊 Dashboard URL: $KIBANA_URL/app/dashboards#/view/$DASHBOARD_ID"
    echo ""
    echo "📋 What was created:"
    echo "  ✅ Index Pattern: $INDEX_PATTERN"
    echo "  ✅ Requests Over Time (Line Chart)"
    echo "  ✅ HTTP Status Codes (Pie Chart)" 
    echo "  ✅ Top Accessed Pages (Table)"
    echo "  ✅ Total Log Entries (Metric)"
    echo "  ✅ Complete Dashboard: $DASHBOARD_NAME"
    echo ""
    echo "🚀 Next steps:"
    echo "  1. Visit your dashboard at the URL above"
    echo "  2. Adjust time range as needed"
    echo "  3. Generate traffic to see real-time updates"
    echo "  4. Customize visualizations as needed"
else
    echo "❌ Failed to create dashboard"
    echo "Response: $DASHBOARD_RESPONSE"
fi

# Generate some sample traffic to populate the dashboard
echo ""
echo "🔄 Generating sample traffic to populate dashboard..."
for i in {1..25}; do
    curl -s http://localhost:8080/group6-react-app/ > /dev/null
    echo -n "."
    sleep 0.2
done
echo ""
echo "✅ Sample traffic generated!"
echo ""
echo "🎯 Your Tomcat Logs Dashboard is ready!"
echo "🌐 Access it at: http://54.177.65.33:8090/app/dashboards#/view/$DASHBOARD_ID"