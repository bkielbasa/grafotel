require 'opentelemetry/sdk'
require 'opentelemetry/exporter/otlp'
require 'opentelemetry/instrumentation/all'
require 'logger'

# Create a logger for OpenTelemetry debugging
otel_logger = Logger.new(STDOUT)
otel_logger.level = Logger::DEBUG

# Configure OpenTelemetry
OpenTelemetry::SDK.configure do |c|
  # Set the service name
  c.service_name = 'analytics-service'
  
  # Set the service version
  c.service_version = '1.0.0'
  
  # Configure the OTLP exporter
  otlp_endpoint = ENV.fetch('OTEL_EXPORTER_OTLP_ENDPOINT', 'http://localhost:4318/v1/traces')
  
  # Ensure the endpoint has the correct path for OTLP HTTP
  unless otlp_endpoint.end_with?('/v1/traces')
    otlp_endpoint = "#{otlp_endpoint}/v1/traces"
  end
  
  puts "Configuring OpenTelemetry with endpoint: #{otlp_endpoint}"
  otel_logger.info("OpenTelemetry endpoint: #{otlp_endpoint}")
  
  # Create OTLP exporter with detailed error handling
  otlp_exporter = OpenTelemetry::Exporter::OTLP::Exporter.new(
    endpoint: otlp_endpoint,
    headers: {},
    timeout: 10
  )
  
  # Add error handling to the span processor
  span_processor = OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
    otlp_exporter,
    max_queue_size: 2048,
    max_export_batch_size: 512,
    schedule_delay: 5
  )
  
  c.add_span_processor(span_processor)
  
  # Enable detailed logging for OpenTelemetry
  c.logger = otel_logger
  
  # Enable all available instrumentations with logging
  c.use_all
  
  puts "OpenTelemetry configuration completed"
  otel_logger.info("OpenTelemetry SDK configured successfully")
end

# Add a test span to verify configuration
begin
  tracer = OpenTelemetry.tracer_provider.tracer('analytics-service')
  tracer.in_span('opentelemetry.test') do |span|
    span.set_attribute('test.initialization', 'successful')
    puts "OpenTelemetry test span created successfully"
  end
rescue => e
  puts "Error creating test span: #{e.message}"
  puts "Error backtrace: #{e.backtrace.first(5).join("\n")}"
end 