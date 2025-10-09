#!/bin/bash

# Automated Kibana Dashboard Setup for Tomcat Logs
# Specifically configured for http://54.177.65.33:8090

KIBANA_INTERNAL="http://localhost:5601"  # Internal Kibana port
KIBANA_EXTERNAL="http://54.177.65.33:8090"  # External access URL
INDEX_PATTERN="tomcat-logs-*"
DASHBOARD_NAME="Group6 React App - Tomcat Access Dashboard"

echo "🚀 Automated Kibana Dashboard Setup Starting..."
echo "📊 External URL: $KIBANA_EXTERNAL"
echo "🔗 Internal API: $KIBANA_INTERNAL"
echo "📋 Index Pattern: $INDEX_PATTERN"
echo "==============================================="

# Function to make Kibana API calls
kibana_api() {
    local method=$1
    local endpoint=$2
    local data=$3
    
    curl -s -X "$method" "$KIBANA_INTERNAL$endpoint" \
        -H "Content-Type: application/json" \
        -H "kbn-xsrf: true" \
        -d "$data"
}

# Step 1: Wait for Kibana to be ready
echo "⏳ Step 1: Waiting for Kibana to be ready..."
WAIT_COUNT=0
MAX_WAIT=60  # 10 minutes
until curl -s -f "$KIBANA_INTERNAL/api/status" > /dev/null 2>&1; do
    printf "."
    sleep 10
    WAIT_COUNT=$((WAIT_COUNT + 1))
    if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
        echo ""
        echo "❌ Kibana not ready after 10 minutes. Please check if Kibana is running."
        exit 1
    fi
done
echo ""
echo "✅ Kibana is ready!"

# Step 2: Generate sample traffic to ensure we have log data
echo "🔄 Step 2: Generating sample traffic to create logs..."
echo "Sending 50 requests to create log entries..."
for i in {1..50}; do
    curl -s http://localhost:8080/group6-react-app/ > /dev/null
    if [ $((i % 10)) -eq 0 ]; then
        echo "  📊 Sent $i requests..."
    fi
    sleep 0.2
done
echo "✅ Sample traffic generated!"

# Step 3: Wait for logs to be processed by Filebeat
echo "⏳ Step 3: Waiting for logs to be processed..."
sleep 30

# Step 4: Check if we have log data in Elasticsearch
echo "🔍 Step 4: Checking for log data in Elasticsearch..."
LOG_COUNT=$(curl -s "http://localhost:9200/tomcat-logs-*/_count" | grep -o '"count":[0-9]*' | cut -d':' -f2)
if [ -z "$LOG_COUNT" ] || [ "$LOG_COUNT" -eq 0 ]; then
    echo "⚠️  No logs found yet. Creating some more traffic..."
    for i in {1..20}; do
        curl -s http://localhost:8080/group6-react-app/ > /dev/null
        sleep 0.5
    done
    sleep 20
    LOG_COUNT=$(curl -s "http://localhost:9200/tomcat-logs-*/_count" | grep -o '"count":[0-9]*' | cut -d':' -f2)
fi

if [ -n "$LOG_COUNT" ] && [ "$LOG_COUNT" -gt 0 ]; then
    echo "✅ Found $LOG_COUNT log entries in Elasticsearch!"
else
    echo "⚠️  Limited log data found, but continuing with setup..."
fi

# Step 5: Create Index Pattern
echo "📋 Step 5: Creating index pattern..."
INDEX_PATTERN_RESPONSE=$(kibana_api "POST" "/api/saved_objects/index-pattern" '{
    "attributes": {
        "title": "'$INDEX_PATTERN'",
        "timeFieldName": "@timestamp"
    }
}')

PATTERN_ID=$(echo $INDEX_PATTERN_RESPONSE | grep -o '"id":"[^"]*' | cut -d'"' -f4)

if [ -n "$PATTERN_ID" ]; then
    echo "✅ Index pattern created: $PATTERN_ID"
else
    echo "ℹ️  Index pattern may already exist, checking..."
    EXISTING_PATTERNS=$(curl -s "$KIBANA_INTERNAL/api/saved_objects/_find?type=index-pattern&search_fields=title&search=$INDEX_PATTERN")
    PATTERN_ID=$(echo $EXISTING_PATTERNS | grep -o '"id":"[^"]*' | head -n1 | cut -d'"' -f4)
    if [ -n "$PATTERN_ID" ]; then
        echo "✅ Using existing index pattern: $PATTERN_ID"
    else
        echo "❌ Failed to create or find index pattern"
        exit 1
    fi
fi

# Step 6: Set as default index pattern
echo "🔧 Step 6: Setting as default index pattern..."
curl -s -X POST "$KIBANA_INTERNAL/api/kibana/settings/defaultIndex" \
    -H "Content-Type: application/json" \
    -H "kbn-xsrf: true" \
    -d '{"value":"'$PATTERN_ID'"}' > /dev/null

# Step 7: Create Visualizations
echo "📊 Step 7: Creating visualizations..."

echo "  📈 Creating 'Request Count Over Time' line chart..."
VIS1_RESPONSE=$(kibana_api "POST" "/api/saved_objects/visualization" '{
    "attributes": {
        "title": "Group6 App - Requests Over Time",
        "visState": "{\"title\":\"Group6 App - Requests Over Time\",\"type\":\"line\",\"aggs\":[{\"id\":\"1\",\"type\":\"count\",\"schema\":\"metric\",\"params\":{}},{\"id\":\"2\",\"type\":\"date_histogram\",\"schema\":\"segment\",\"params\":{\"field\":\"@timestamp\",\"interval\":\"auto\",\"min_doc_count\":1}}]}",
        "uiStateJSON": "{}",
        "description": "Shows request volume over time for the Group6 React application",
        "version": 1,
        "kibanaSavedObjectMeta": {
            "searchSourceJSON": "{\"index\":\"'$PATTERN_ID'\",\"query\":{\"match_all\":{}},\"filter\":[]}"
        }
    }
}')
VIS1_ID=$(echo $VIS1_RESPONSE | grep -o '"id":"[^"]*' | cut -d'"' -f4)

echo "  🥧 Creating 'HTTP Response Codes' pie chart..."
VIS2_RESPONSE=$(kibana_api "POST" "/api/saved_objects/visualization" '{
    "attributes": {
        "title": "Group6 App - HTTP Response Codes",
        "visState": "{\"title\":\"Group6 App - HTTP Response Codes\",\"type\":\"pie\",\"aggs\":[{\"id\":\"1\",\"type\":\"count\",\"schema\":\"metric\",\"params\":{}},{\"id\":\"2\",\"type\":\"terms\",\"schema\":\"segment\",\"params\":{\"field\":\"message.keyword\",\"size\":10,\"order\":\"desc\",\"orderBy\":\"1\"}}]}",
        "uiStateJSON": "{}",
        "description": "Distribution of HTTP response codes from Tomcat access logs",
        "version": 1,
        "kibanaSavedObjectMeta": {
            "searchSourceJSON": "{\"index\":\"'$PATTERN_ID'\",\"query\":{\"match_all\":{}},\"filter\":[]}"
        }
    }
}')
VIS2_ID=$(echo $VIS2_RESPONSE | grep -o '"id":"[^"]*' | cut -d'"' -f4)

echo "  📊 Creating 'Total Requests' metric..."
VIS3_RESPONSE=$(kibana_api "POST" "/api/saved_objects/visualization" '{
    "attributes": {
        "title": "Group6 App - Total Log Entries",
        "visState": "{\"title\":\"Group6 App - Total Log Entries\",\"type\":\"metric\",\"aggs\":[{\"id\":\"1\",\"type\":\"count\",\"schema\":\"metric\",\"params\":{}}]}",
        "uiStateJSON": "{}",
        "description": "Total number of access log entries",
        "version": 1,
        "kibanaSavedObjectMeta": {
            "searchSourceJSON": "{\"index\":\"'$PATTERN_ID'\",\"query\":{\"match_all\":{}},\"filter\":[]}"
        }
    }
}')
VIS3_ID=$(echo $VIS3_RESPONSE | grep -o '"id":"[^"]*' | cut -d'"' -f4)

echo "  📋 Creating 'Recent Activity' data table..."
VIS4_RESPONSE=$(kibana_api "POST" "/api/saved_objects/visualization" '{
    "attributes": {
        "title": "Group6 App - Recent Access Log Entries",
        "visState": "{\"title\":\"Group6 App - Recent Access Log Entries\",\"type\":\"table\",\"aggs\":[{\"id\":\"1\",\"type\":\"count\",\"schema\":\"metric\",\"params\":{}},{\"id\":\"2\",\"type\":\"terms\",\"schema\":\"bucket\",\"params\":{\"field\":\"message.keyword\",\"size\":10,\"order\":\"desc\",\"orderBy\":\"1\"}}]}",
        "uiStateJSON": "{\"vis\":{\"params\":{\"sort\":{\"columnIndex\":null,\"direction\":null}}}}",
        "description": "Recent access log entries from Tomcat",
        "version": 1,
        "kibanaSavedObjectMeta": {
            "searchSourceJSON": "{\"index\":\"'$PATTERN_ID'\",\"query\":{\"match_all\":{}},\"filter\":[]}"
        }
    }
}')
VIS4_ID=$(echo $VIS4_RESPONSE | grep -o '"id":"[^"]*' | cut -d'"' -f4)

echo "✅ All visualizations created!"

# Step 8: Create Dashboard
echo "🏠 Step 8: Creating dashboard..."
DASHBOARD_RESPONSE=$(kibana_api "POST" "/api/saved_objects/dashboard" '{
    "attributes": {
        "title": "'$DASHBOARD_NAME'",
        "hits": 0,
        "description": "Comprehensive monitoring dashboard for Group6 React App running on Tomcat. Shows request patterns, response codes, and recent activity.",
        "panelsJSON": "[{\"version\":\"8.10.4\",\"type\":\"visualization\",\"gridData\":{\"x\":0,\"y\":0,\"w\":24,\"h\":15,\"i\":\"1\"},\"panelIndex\":\"1\",\"embeddableConfig\":{},\"panelRefName\":\"panel_1\"},{\"version\":\"8.10.4\",\"type\":\"visualization\",\"gridData\":{\"x\":24,\"y\":0,\"w\":24,\"h\":15,\"i\":\"2\"},\"panelIndex\":\"2\",\"embeddableConfig\":{},\"panelRefName\":\"panel_2\"},{\"version\":\"8.10.4\",\"type\":\"visualization\",\"gridData\":{\"x\":0,\"y\":15,\"w\":12,\"h\":15,\"i\":\"3\"},\"panelIndex\":\"3\",\"embeddableConfig\":{},\"panelRefName\":\"panel_3\"},{\"version\":\"8.10.4\",\"type\":\"visualization\",\"gridData\":{\"x\":12,\"y\":15,\"w\":36,\"h\":15,\"i\":\"4\"},\"panelIndex\":\"4\",\"embeddableConfig\":{},\"panelRefName\":\"panel_4\"}]",
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
}')

DASHBOARD_ID=$(echo $DASHBOARD_RESPONSE | grep -o '"id":"[^"]*' | cut -d'"' -f4)

# Step 9: Generate more traffic for immediate visualization
echo "🔄 Step 9: Generating additional traffic for immediate visualization..."
for i in {1..30}; do
    curl -s http://localhost:8080/group6-react-app/ > /dev/null
    if [ $((i % 10)) -eq 0 ]; then
        printf "."
    fi
    sleep 0.1
done
echo ""

# Step 10: Final Results
echo ""
echo "🎉 KIBANA DASHBOARD AUTOMATION COMPLETE! 🎉"
echo "================================================"
echo ""
if [ -n "$DASHBOARD_ID" ]; then
    echo "✅ Dashboard successfully created!"
    echo "🌐 Dashboard URL: $KIBANA_EXTERNAL/app/dashboards#/view/$DASHBOARD_ID"
    echo ""
    echo "📊 What was created:"
    echo "  ✅ Index Pattern: '$INDEX_PATTERN' (ID: $PATTERN_ID)"
    echo "  ✅ Line Chart: 'Group6 App - Requests Over Time'"
    echo "  ✅ Pie Chart: 'Group6 App - HTTP Response Codes'"
    echo "  ✅ Metric: 'Group6 App - Total Log Entries'"
    echo "  ✅ Table: 'Group6 App - Recent Access Log Entries'"
    echo "  ✅ Dashboard: '$DASHBOARD_NAME'"
    echo ""
    echo "🚀 Quick Access Links:"
    echo "  🏠 Dashboard: $KIBANA_EXTERNAL/app/dashboards#/view/$DASHBOARD_ID"
    echo "  🔍 Discover: $KIBANA_EXTERNAL/app/discover"
    echo "  📊 Visualize: $KIBANA_EXTERNAL/app/visualize"
    echo ""
    echo "📈 Usage Tips:"
    echo "  • Use the time picker (top right) to adjust the time range"
    echo "  • Click on chart elements to filter data"
    echo "  • Refresh the page to see new log entries"
    echo "  • Generate more traffic by visiting: http://54.177.65.33:8080/group6-react-app/"
    echo ""
else
    echo "❌ Dashboard creation failed"
    echo "Response: $DASHBOARD_RESPONSE"
    exit 1
fi

echo "✨ Automation completed successfully at $(date)"
echo "🎯 Your Tomcat logs are now visualized in Kibana!"