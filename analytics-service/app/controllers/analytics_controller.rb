class AnalyticsController < ApplicationController
  def user
    user_id = params[:id]
    
    # Create a span for this request
    tracer = OpenTelemetry.tracer_provider.tracer('analytics-service')
    
    tracer.in_span('analytics.user_analytics') do |span|
      span.set_attribute('user.id', user_id)
      
      # Simulate analytics processing
      analytics_data = {
        user_id: user_id,
        impressions: rand(1000..5000),
        clicks: rand(50..200),
        conversions: rand(5..25),
        revenue: rand(100.0..500.0).round(2),
        timestamp: Time.current
      }
      
      span.set_attribute('analytics.impressions', analytics_data[:impressions])
      span.set_attribute('analytics.clicks', analytics_data[:clicks])
      span.set_attribute('analytics.conversions', analytics_data[:conversions])
      span.set_attribute('analytics.revenue', analytics_data[:revenue])
      
      render json: analytics_data
    end
  end

  def historical
    tracer = OpenTelemetry.tracer_provider.tracer('analytics-service')
    
    tracer.in_span('analytics.historical_data') do |span|
      # Simulate historical data retrieval
      historical_data = {
        total_impressions: rand(50000..200000),
        total_clicks: rand(2000..8000),
        total_conversions: rand(200..800),
        total_revenue: rand(5000.0..20000.0).round(2),
        period: 'last_30_days',
        timestamp: Time.current
      }
      
      span.set_attribute('analytics.period', historical_data[:period])
      span.set_attribute('analytics.total_impressions', historical_data[:total_impressions])
      span.set_attribute('analytics.total_revenue', historical_data[:total_revenue])
      
      render json: historical_data
    end
  end

  def event
    tracer = OpenTelemetry.tracer_provider.tracer('analytics-service')
    
    tracer.in_span('analytics.process_event') do |span|
      event_data = params.permit(:event_type, :user_id, :timestamp, :properties)
      
      # Simulate event processing
      processed_event = {
        id: SecureRandom.uuid,
        event_type: event_data[:event_type],
        user_id: event_data[:user_id],
        timestamp: event_data[:timestamp] || Time.current,
        properties: event_data[:properties] || {},
        processed_at: Time.current
      }
      
      span.set_attribute('event.type', processed_event[:event_type])
      span.set_attribute('event.user_id', processed_event[:user_id])
      span.set_attribute('event.id', processed_event[:id])
      
      render json: processed_event, status: :created
    end
  end

  def debug_otel
    # Debug endpoint to test OpenTelemetry connectivity
    begin
      tracer = OpenTelemetry.tracer_provider.tracer('analytics-service')
      
      # Test span creation
      tracer.in_span('debug.test_span') do |span|
        span.set_attribute('debug.test', 'successful')
        span.set_attribute('debug.timestamp', Time.current.to_i)
        
        # Test OTEL Collector connectivity
        otel_endpoint = ENV.fetch('OTEL_EXPORTER_OTLP_ENDPOINT', 'otel-collector:4318')
        full_endpoint = "#{otel_endpoint}/v1/traces"
        
        debug_info = {
          status: 'success',
          otel_endpoint: otel_endpoint,
          full_endpoint: full_endpoint,
          service_name: 'analytics-service',
          timestamp: Time.current,
          message: 'OpenTelemetry test span created successfully'
        }
        
        render json: debug_info
      end
    rescue => e
      error_info = {
        status: 'error',
        error_message: e.message,
        error_class: e.class.name,
        backtrace: e.backtrace.first(5),
        otel_endpoint: ENV.fetch('OTEL_EXPORTER_OTLP_ENDPOINT', 'not_set'),
        timestamp: Time.current
      }
      
      render json: error_info, status: :internal_server_error
    end
  end

  def test_trace_propagation
    # Test endpoint to demonstrate trace context propagation
    tracer = OpenTelemetry.tracer_provider.tracer('analytics-service')
    
    tracer.in_span('test.trace_propagation') do |span|
      span.set_attribute('test.type', 'trace_propagation')
      
      # Get current trace context
      current_context = OpenTelemetry::Context.current
      trace_id = OpenTelemetry::Trace.current_span(current_context).context.trace_id
      span_id = OpenTelemetry::Trace.current_span(current_context).context.span_id
      
      # Make HTTP request to another service (this will automatically propagate trace context)
      begin
        ad_service_url = ENV.fetch('AD_SERVICE_URL', 'http://ad-service:8080')
        response = HTTP.get("#{ad_service_url}/health")
        
        span.set_attribute('http.request.url', "#{ad_service_url}/health")
        span.set_attribute('http.response.status', response.status.code)
        
        result = {
          status: 'success',
          trace_id: trace_id,
          span_id: span_id,
          ad_service_response: response.status.code,
          message: 'Trace context propagated successfully',
          timestamp: Time.current
        }
      rescue => e
        span.record_exception(e)
        span.set_attribute('error', true)
        
        result = {
          status: 'error',
          trace_id: trace_id,
          span_id: span_id,
          error_message: e.message,
          message: 'Trace context propagation test failed',
          timestamp: Time.current
        }
      end
      
      render json: result
    end
  end

  private

  # Helper method to make HTTP requests with proper trace context propagation
  def make_traced_request(url, method: :get, body: nil)
    tracer = OpenTelemetry.tracer_provider.tracer('analytics-service')
    
    tracer.in_span("http.#{method}") do |span|
      span.set_attribute('http.url', url)
      span.set_attribute('http.method', method.to_s.upcase)
      
      # The HTTP gem (used by Rails) should automatically propagate trace context
      # when OpenTelemetry instrumentation is enabled
      response = case method
      when :get
        HTTP.get(url)
      when :post
        HTTP.post(url, json: body)
      when :put
        HTTP.put(url, json: body)
      when :delete
        HTTP.delete(url)
      end
      
      span.set_attribute('http.status_code', response.status.code)
      
      if response.status.success?
        response
      else
        span.set_attribute('error', true)
        span.record_exception(StandardError.new("HTTP #{response.status.code}"))
        raise "HTTP request failed: #{response.status.code}"
      end
    end
  end
end 