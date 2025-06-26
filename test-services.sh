#!/bin/bash

# Ad-Tech Microservices Test Script
# Tests all services and generates load for OpenTelemetry training

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Service URLs (updated to use port 8180 for ad-service)
AD_SERVICE_URL="http://localhost:8180"
ANALYTICS_SERVICE_URL="http://localhost:3000"
BIDDING_SERVICE_URL="http://localhost:3001"

# Function to make HTTP requests
make_request() {
    local method="$1"
    local url="$2"
    local data="$3"
    
    if [ -n "$data" ]; then
        curl -s -X "$method" -H "Content-Type: application/json" -d "$data" "$url"
    else
        curl -s -X "$method" "$url"
    fi
}

# Function to check if a service is responding
check_service() {
    local service_name="$1"
    local url="$2"
    
    echo -e "${BLUE}Testing $service_name...${NC}"
    local response=$(make_request "GET" "$url/health")
    
    if [ $? -eq 0 ] && echo "$response" | grep -q "healthy"; then
        echo -e "   ${GREEN}✅ $service_name: healthy${NC}"
        return 0
    else
        echo -e "   ${RED}❌ $service_name: not responding${NC}"
        return 1
    fi
}

# Function to test ad service
test_ad_service() {
    echo -e "\n${YELLOW}2. Testing Ad Service...${NC}"
    
    # Test list ads
    local ads_response=$(make_request "GET" "$AD_SERVICE_URL/ads")
    if [ $? -eq 0 ]; then
        local ad_count=$(echo "$ads_response" | jq '. | length' 2>/dev/null || echo "0")
        echo -e "   ${GREEN}✅ Available ads: $ad_count ads found${NC}"
    else
        echo -e "   ${RED}❌ Failed to get ads${NC}"
    fi
}

# Function to test complete request flow
test_request_flow() {
    echo -e "\n${YELLOW}3. Testing complete request flow...${NC}"
    
    local ad_request='{
        "user_id": "user_123",
        "ad_type": "banner",
        "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)'"
    }'
    
    local ad_response=$(make_request "POST" "$AD_SERVICE_URL/ads/request" "$ad_request")
    if [ $? -eq 0 ]; then
        local ad_id=$(echo "$ad_response" | jq -r '.ad_id' 2>/dev/null || echo "unknown")
        local bid_amount=$(echo "$ad_response" | jq -r '.bid_amount' 2>/dev/null || echo "0")
        local user_data=$(echo "$ad_response" | jq -r '.user_data' 2>/dev/null || echo "unknown")
        
        echo -e "   ${GREEN}✅ Ad request processed:${NC}"
        echo -e "      - Ad ID: $ad_id"
        echo -e "      - Bid Amount: \$$bid_amount"
        echo -e "      - User Data: $user_data"
    else
        echo -e "   ${RED}❌ Failed to process ad request${NC}"
    fi
}

# Function to test analytics service
test_analytics_service() {
    echo -e "\n${YELLOW}4. Testing Analytics Service...${NC}"
    
    # Test user analytics
    local user_analytics=$(make_request "GET" "$ANALYTICS_SERVICE_URL/analytics/user/user_123")
    if [ $? -eq 0 ]; then
        local click_rate=$(echo "$user_analytics" | jq -r '.click_rate' 2>/dev/null || echo "0")
        local impressions=$(echo "$user_analytics" | jq -r '.total_impressions' 2>/dev/null || echo "0")
        
        echo -e "   ${GREEN}✅ User analytics retrieved:${NC}"
        echo -e "      - Click Rate: $(printf "%.2f" $(echo "$click_rate * 100" | bc -l 2>/dev/null || echo "0"))%"
        echo -e "      - Total Impressions: $impressions"
    else
        echo -e "   ${RED}❌ Failed to get user analytics${NC}"
    fi
    
    # Test historical data
    local historical_data=$(make_request "GET" "$ANALYTICS_SERVICE_URL/analytics/historical")
    if [ $? -eq 0 ]; then
        local total_impressions=$(echo "$historical_data" | jq -r '.total_impressions' 2>/dev/null || echo "0")
        local avg_bid=$(echo "$historical_data" | jq -r '.average_bid' 2>/dev/null || echo "0")
        
        echo -e "   ${GREEN}✅ Historical data retrieved:${NC}"
        echo -e "      - Total Impressions: $total_impressions"
        echo -e "      - Average Bid: \$$avg_bid"
    else
        echo -e "   ${RED}❌ Failed to get historical data${NC}"
    fi
}

# Function to test bidding service
test_bidding_service() {
    echo -e "\n${YELLOW}5. Testing Bidding Service...${NC}"
    
    local ad_request='{
        "user_id": "user_123",
        "ad_type": "banner",
        "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)'"
    }'
    
    local bid_response=$(make_request "POST" "$BIDDING_SERVICE_URL/bidding/calculate" "$ad_request")
    if [ $? -eq 0 ]; then
        local bid_amount=$(echo "$bid_response" | jq -r '.bid_amount' 2>/dev/null || echo "0")
        local successful=$(echo "$bid_response" | jq -r '.successful' 2>/dev/null || echo "false")
        
        echo -e "   ${GREEN}✅ Bid calculated:${NC}"
        echo -e "      - Bid Amount: \$$bid_amount"
        echo -e "      - Successful: $successful"
    else
        echo -e "   ${RED}❌ Failed to calculate bid${NC}"
    fi
    
    # Test bidding stats
    local bidding_stats=$(make_request "GET" "$BIDDING_SERVICE_URL/bidding/stats")
    if [ $? -eq 0 ]; then
        local total_requests=$(echo "$bidding_stats" | jq -r '.total_requests' 2>/dev/null || echo "0")
        local success_rate=$(echo "$bidding_stats" | jq -r '.success_rate' 2>/dev/null || echo "0")
        
        echo -e "   ${GREEN}✅ Bidding statistics:${NC}"
        echo -e "      - Total Requests: $total_requests"
        echo -e "      - Success Rate: $(printf "%.1f" $(echo "$success_rate * 100" | bc -l 2>/dev/null || echo "0"))%"
    else
        echo -e "   ${RED}❌ Failed to get bidding stats${NC}"
    fi
}

# Function to test metrics endpoints
test_metrics() {
    echo -e "\n${YELLOW}6. Testing metrics endpoints...${NC}"
    
    # Test ad service metrics
    local ad_metrics=$(make_request "GET" "$AD_SERVICE_URL/metrics")
    if [ $? -eq 0 ]; then
        local ad_metrics_size=$(echo "$ad_metrics" | wc -c)
        echo -e "   ${GREEN}✅ Ad Service metrics available ($ad_metrics_size bytes)${NC}"
    else
        echo -e "   ${RED}❌ Failed to get ad service metrics${NC}"
    fi
    
    # Test analytics service metrics
    local analytics_metrics=$(make_request "GET" "$ANALYTICS_SERVICE_URL/metrics")
    if [ $? -eq 0 ]; then
        local analytics_metrics_size=$(echo "$analytics_metrics" | wc -c)
        echo -e "   ${GREEN}✅ Analytics Service metrics available ($analytics_metrics_size bytes)${NC}"
    else
        echo -e "   ${RED}❌ Failed to get analytics service metrics${NC}"
    fi
    
    # Test bidding service metrics
    local bidding_metrics=$(make_request "GET" "$BIDDING_SERVICE_URL/metrics")
    if [ $? -eq 0 ]; then
        local bidding_metrics_size=$(echo "$bidding_metrics" | wc -c)
        echo -e "   ${GREEN}✅ Bidding Service metrics available ($bidding_metrics_size bytes)${NC}"
    else
        echo -e "   ${RED}❌ Failed to get bidding service metrics${NC}"
    fi
}

# Function to generate load
generate_load() {
    echo -e "\n${PURPLE}🔄 Generating load for 30 seconds...${NC}"
    
    local start_time=$(date +%s)
    local duration=30
    local request_count=0
    local ad_types=("banner" "video" "native" "interstitial")
    
    while [ $(($(date +%s) - start_time)) -lt $duration ]; do
        local ad_type=${ad_types[$((RANDOM % ${#ad_types[@]}))]}
        local user_id="user_$((RANDOM % 1000))"
        
        local ad_request='{
            "user_id": "'$user_id'",
            "ad_type": "'$ad_type'",
            "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)'"
        }'
        
        make_request "POST" "$AD_SERVICE_URL/ads/request" "$ad_request" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            request_count=$((request_count + 1))
        fi
        
        sleep 1
    done
    
    echo -e "${GREEN}✅ Load generation complete: $request_count requests processed${NC}"
    echo -e "${CYAN}📈 Check Grafana for the generated data!${NC}"
    echo -e "   - Traces: Explore → Tempo"
    echo -e "   - Logs: Explore → Loki"
    echo -e "   - Metrics: Explore → Prometheus"
}

# Main test function
test_services() {
    echo -e "${CYAN}🚀 Testing Ad-Tech Microservices with OpenTelemetry & Grafana Stack${NC}\n"
    
    # Test health checks
    echo -e "${YELLOW}1. Testing health checks...${NC}"
    check_service "Ad Service" "$AD_SERVICE_URL"
    check_service "Analytics Service" "$ANALYTICS_SERVICE_URL"
    check_service "Bidding Service" "$BIDDING_SERVICE_URL"
    
    # Test individual services
    test_ad_service
    test_request_flow
    test_analytics_service
    test_bidding_service
    test_metrics
    
    echo -e "\n${GREEN}🎉 All tests completed successfully!${NC}"
    echo -e "\n${CYAN}📊 Next steps:${NC}"
    echo -e "   - Open Grafana: http://localhost:3002 (admin/admin)"
    echo -e "   - Navigate to Explore → Tempo to view traces"
    echo -e "   - Navigate to Explore → Loki to view logs"
    echo -e "   - Navigate to Explore → Prometheus to view metrics"
    echo -e "   - Use the \"Ad-Tech Microservices Overview\" dashboard"
    echo -e "   - Look for traces and metrics from this test run"
}

# Check if required tools are available
check_dependencies() {
    local missing_tools=()
    
    if ! command -v curl &> /dev/null; then
        missing_tools+=("curl")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing_tools+=("jq")
    fi
    
    if ! command -v bc &> /dev/null; then
        missing_tools+=("bc")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        echo -e "${RED}❌ Missing required tools: ${missing_tools[*]}${NC}"
        echo -e "Please install the missing tools and try again."
        exit 1
    fi
}

# Main execution
main() {
    check_dependencies
    test_services
    generate_load
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi 