import os
import time
import random
import requests
from flask import Flask, request, jsonify
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor

# Initialize OpenTelemetry
trace.set_tracer_provider(TracerProvider())
tracer = trace.get_tracer(__name__)

# Configure OTLP exporter
otlp_endpoint = os.getenv('OTEL_EXPORTER_OTLP_ENDPOINT', 'http://localhost:4318/v1/traces')
otlp_exporter = OTLPSpanExporter(endpoint=otlp_endpoint)
span_processor = BatchSpanProcessor(otlp_exporter)
trace.get_tracer_provider().add_span_processor(span_processor)

# Initialize Flask app
app = Flask(__name__)

# Instrument Flask and Requests
FlaskInstrumentor().instrument_app(app)
RequestsInstrumentor().instrument()

# Prometheus metrics
REQUEST_COUNT = Counter('bidding_requests_total', 'Total bidding requests', ['method', 'endpoint'])
REQUEST_LATENCY = Histogram('bidding_request_duration_seconds', 'Bidding request latency')
BID_SUCCESS_RATE = Counter('bidding_success_total', 'Successful bids')
BID_VALUE = Histogram('bidding_value', 'Bid values')

# Simple stats tracking
_stats = {
    'total_requests': 0,
    'successful_bids': 0,
    'total_bid_value': 0.0
}

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'service': 'bidding-service',
        'timestamp': time.time()
    })

@app.route('/bidding/calculate', methods=['POST'])
def calculate_bid():
    """Calculate bid for ad request"""
    with tracer.start_as_current_span("calculate_bid") as span:
        REQUEST_COUNT.labels(method='POST', endpoint='/bidding/calculate').inc()
        
        start_time = time.time()
        
        try:
            data = request.get_json()
            ad_request_id = data.get('ad_request_id', 'unknown')
            user_id = data.get('user_id', 'unknown')
            
            span.set_attribute("ad_request_id", ad_request_id)
            span.set_attribute("user_id", user_id)
            
            # Simulate bidding logic
            with tracer.start_as_current_span("fetch_analytics_data"):
                # Call analytics service for user data
                analytics_url = os.getenv('ANALYTICS_SERVICE_URL', 'http://localhost:3000')
                try:
                    analytics_response = requests.get(
                        f"{analytics_url}/analytics/user/{user_id}",
                        timeout=5
                    )
                    analytics_data = analytics_response.json() if analytics_response.status_code == 200 else {}
                except Exception as e:
                    span.record_exception(e)
                    analytics_data = {}
            
            with tracer.start_as_current_span("calculate_bid_value"):
                # Calculate bid based on user data and market conditions
                base_bid = 1.0
                user_multiplier = analytics_data.get('engagement_score', 1.0)
                market_multiplier = random.uniform(0.8, 1.2)
                
                bid_value = base_bid * user_multiplier * market_multiplier
                bid_value = round(bid_value, 2)
                
                # Simulate bid success/failure
                success_rate = 0.7
                is_successful = random.random() < success_rate
                
                span.set_attribute("bid_value", bid_value)
                span.set_attribute("bid_successful", is_successful)
                span.set_attribute("user_multiplier", user_multiplier)
                span.set_attribute("market_multiplier", market_multiplier)
            
            # Record metrics
            BID_VALUE.observe(bid_value)
            if is_successful:
                BID_SUCCESS_RATE.inc()
            
            # Update simple stats
            _stats['total_requests'] += 1
            _stats['total_bid_value'] += bid_value
            if is_successful:
                _stats['successful_bids'] += 1
            
            response_data = {
                'ad_request_id': ad_request_id,
                'bid_value': bid_value,
                'successful': is_successful,
                'timestamp': time.time()
            }
            
            # Record latency
            latency = time.time() - start_time
            REQUEST_LATENCY.observe(latency)
            
            return jsonify(response_data), 200
            
        except Exception as e:
            span.record_exception(e)
            return jsonify({'error': str(e)}), 500

@app.route('/bidding/stats', methods=['GET'])
def get_stats():
    """Get bidding statistics"""
    with tracer.start_as_current_span("get_bidding_stats"):
        REQUEST_COUNT.labels(method='GET', endpoint='/bidding/stats').inc()
        
        return jsonify({
            'total_requests': _stats['total_requests'],
            'successful_bids': _stats['successful_bids'],
            'success_rate': _stats['successful_bids'] / max(_stats['total_requests'], 1),
            'average_bid_value': _stats['total_bid_value'] / max(_stats['total_requests'], 1),
            'timestamp': time.time()
        })

@app.route('/metrics', methods=['GET'])
def metrics():
    """Prometheus metrics endpoint"""
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 3001))
    app.run(host='0.0.0.0', port=port, debug=False) 