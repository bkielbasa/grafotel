class MetricsController < ActionController::Base
  
  def index
    # Add tracing to metrics endpoint
    tracer = OpenTelemetry.tracer_provider.tracer('analytics-service')
    tracer.in_span('metrics.generate') do |span|
      span.set_attribute('endpoint', 'metrics')
      
      # Generate metrics in Prometheus format
      metrics = generate_prometheus_metrics
      
      render plain: metrics, content_type: 'text/plain'
    end
  end
  
  private
  
  def generate_prometheus_metrics
    # Generate random metrics for demonstration
    analytics_requests_total = rand(1000..5000)
    analytics_processing_time_seconds = rand(0.1..2.0).round(3)
    analytics_errors_total = rand(0..50)
    analytics_revenue_total = rand(10000.0..50000.0).round(2)
    
    # Format metrics in Prometheus text format
    <<~METRICS
      # HELP analytics_requests_total Total number of analytics requests
      # TYPE analytics_requests_total counter
      analytics_requests_total #{analytics_requests_total}
      
      # HELP analytics_processing_time_seconds Average processing time for analytics requests
      # TYPE analytics_processing_time_seconds gauge
      analytics_processing_time_seconds #{analytics_processing_time_seconds}
      
      # HELP analytics_errors_total Total number of analytics errors
      # TYPE analytics_errors_total counter
      analytics_errors_total #{analytics_errors_total}
      
      # HELP analytics_revenue_total Total revenue from analytics
      # TYPE analytics_revenue_total gauge
      analytics_revenue_total #{analytics_revenue_total}
    METRICS
  end
end 