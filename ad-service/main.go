package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/gorilla/mux"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.17.0"
	"go.opentelemetry.io/otel/trace"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
)

var (
	tracer = otel.Tracer("ad-service")
	logger *zap.Logger

	// Shared HTTP client with OpenTelemetry instrumentation
	httpClient = &http.Client{
		Transport: otelhttp.NewTransport(http.DefaultTransport),
		Timeout:   10 * time.Second,
	}

	// Custom metrics
	adRequestsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "ad_requests_total",
			Help: "Total number of ad requests",
		},
		[]string{"status", "ad_type"},
	)

	adRequestDuration = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "ad_request_duration_seconds",
			Help:    "Duration of ad requests",
			Buckets: prometheus.DefBuckets,
		},
		[]string{"ad_type"},
	)
)

type AdRequest struct {
	UserID    string `json:"user_id"`
	AdType    string `json:"ad_type"`
	Timestamp string `json:"timestamp"`
}

type AdResponse struct {
	AdID      string  `json:"ad_id"`
	AdType    string  `json:"ad_type"`
	BidAmount float64 `json:"bid_amount"`
	UserData  string  `json:"user_data"`
	Message   string  `json:"message"`
}

type UserAnalytics struct {
	UserID           string  `json:"user_id"`
	ClickRate        float64 `json:"click_rate"`
	ConversionRate   float64 `json:"conversion_rate"`
	TotalImpressions int     `json:"total_impressions"`
}

type BidResponse struct {
	BidAmount float64 `json:"bid_amount"`
	BidID     string  `json:"bid_id"`
	Strategy  string  `json:"strategy"`
}

func init() {
	prometheus.MustRegister(adRequestsTotal)
	prometheus.MustRegister(adRequestDuration)
	
	// Initialize structured JSON logger
	initLogger()
}

func initLogger() {
	// Configure zap logger for JSON output
	config := zap.NewProductionConfig()
	config.EncoderConfig.TimeKey = "timestamp"
	config.EncoderConfig.EncodeTime = zapcore.ISO8601TimeEncoder
	config.EncoderConfig.LevelKey = "level"
	config.EncoderConfig.MessageKey = "message"
	config.EncoderConfig.CallerKey = "caller"
	config.EncoderConfig.StacktraceKey = "stacktrace"
	
	var err error
	logger, err = config.Build()
	if err != nil {
		panic(fmt.Sprintf("Failed to initialize logger: %v", err))
	}
	
	// Replace global logger
	zap.ReplaceGlobals(logger)
}

// logWithTrace creates a logger with trace context
func logWithTrace(ctx context.Context, level zapcore.Level, msg string, fields ...zap.Field) {
	span := trace.SpanFromContext(ctx)
	if span.SpanContext().IsValid() {
		fields = append(fields,
			zap.String("trace_id", span.SpanContext().TraceID().String()),
			zap.String("span_id", span.SpanContext().SpanID().String()),
		)
	}
	
	switch level {
	case zapcore.DebugLevel:
		logger.Debug(msg, fields...)
	case zapcore.InfoLevel:
		logger.Info(msg, fields...)
	case zapcore.WarnLevel:
		logger.Warn(msg, fields...)
	case zapcore.ErrorLevel:
		logger.Error(msg, fields...)
	default:
		logger.Info(msg, fields...)
	}
}

func initTracer() func() {
	ctx := context.Background()
	otel.SetTextMapPropagator(propagation.TraceContext{})

	// OTLP exporter
	otlpEndpoint := os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT")
	if otlpEndpoint == "" {
		otlpEndpoint = "localhost:4317"
	}

	// Remove http:// prefix if present for gRPC connections
	otlpEndpoint = strings.TrimPrefix(otlpEndpoint, "http://")
	otlpEndpoint = strings.TrimPrefix(otlpEndpoint, "https://")

	logWithTrace(ctx, zapcore.InfoLevel, "Initializing OpenTelemetry", 
		zap.String("endpoint", otlpEndpoint))

	otlpExporter, err := otlptracegrpc.New(ctx,
		otlptracegrpc.WithEndpoint(otlpEndpoint),
		otlptracegrpc.WithInsecure(),
		otlptracegrpc.WithDialOption(grpc.WithTransportCredentials(insecure.NewCredentials())),
	)
	if err != nil {
		logWithTrace(ctx, zapcore.ErrorLevel, "Failed to create OTLP exporter", 
			zap.Error(err))
		panic(err)
	}

	// Resource
	res, err := resource.New(ctx,
		resource.WithAttributes(
			semconv.ServiceName("ad-service"),
			semconv.ServiceVersion("1.0.0"),
		),
	)
	if err != nil {
		logWithTrace(ctx, zapcore.ErrorLevel, "Failed to create resource", 
			zap.Error(err))
		panic(err)
	}

	// Tracer provider
	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(otlpExporter),
		sdktrace.WithResource(res),
	)
	otel.SetTracerProvider(tp)

	logWithTrace(ctx, zapcore.InfoLevel, "OpenTelemetry initialized successfully")

	return func() {
		if err := tp.Shutdown(ctx); err != nil {
			logWithTrace(ctx, zapcore.ErrorLevel, "Error shutting down tracer provider", 
				zap.Error(err))
		}
	}
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	span := trace.SpanFromContext(ctx)
	defer span.End()

	span.SetAttributes(attribute.String("handler", "health_check"))

	logWithTrace(ctx, zapcore.DebugLevel, "Health check requested")

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{"status": "healthy", "service": "ad-service"})
}

func listAdsHandler(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	span := trace.SpanFromContext(ctx)
	defer span.End()

	span.SetAttributes(attribute.String("handler", "list_ads"))

	logWithTrace(ctx, zapcore.InfoLevel, "Listing available ads")

	ads := []map[string]interface{}{
		{"id": "ad_001", "type": "banner", "title": "Summer Sale", "price": 0.50},
		{"id": "ad_002", "type": "video", "title": "New Product", "price": 1.20},
		{"id": "ad_003", "type": "native", "title": "Special Offer", "price": 0.75},
	}

	logWithTrace(ctx, zapcore.DebugLevel, "Returning ads list", 
		zap.Int("count", len(ads)))

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(ads)
}

func requestAdHandler(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	span := trace.SpanFromContext(ctx)
	defer span.End()

	start := time.Now()

	span.SetAttributes(attribute.String("handler", "request_ad"))

	var req AdRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		logWithTrace(ctx, zapcore.ErrorLevel, "Failed to decode request body", 
			zap.Error(err))
		http.Error(w, err.Error(), http.StatusBadRequest)
		adRequestsTotal.WithLabelValues("error", "unknown").Inc()
		span.SetStatus(codes.Error, err.Error())
		return
	}

	span.SetAttributes(
		attribute.String("user_id", req.UserID),
		attribute.String("ad_type", req.AdType),
	)

	logWithTrace(ctx, zapcore.InfoLevel, "Processing ad request", 
		zap.String("user_id", req.UserID),
		zap.String("ad_type", req.AdType))

	// Get user analytics from analytics service
	userData, err := getUserAnalytics(ctx, req.UserID)
	if err != nil {
		logWithTrace(ctx, zapcore.ErrorLevel, "Error getting user analytics", 
			zap.String("user_id", req.UserID),
			zap.Error(err))
		span.SetStatus(codes.Error, err.Error())
		userData = &UserAnalytics{UserID: req.UserID, ClickRate: 0.02, ConversionRate: 0.01, TotalImpressions: 100}
	} else {
		logWithTrace(ctx, zapcore.InfoLevel, "Retrieved user analytics", 
			zap.String("user_id", req.UserID),
			zap.Float64("click_rate", userData.ClickRate),
			zap.Float64("conversion_rate", userData.ConversionRate),
			zap.Int("total_impressions", userData.TotalImpressions))
	}

	// Get bid from bidding service
	bidResponse, err := getBid(ctx, req)
	if err != nil {
		logWithTrace(ctx, zapcore.ErrorLevel, "Error getting bid", 
			zap.String("user_id", req.UserID),
			zap.String("ad_type", req.AdType),
			zap.Error(err))
		bidResponse = &BidResponse{BidAmount: 0.50, BidID: "default_bid", Strategy: "fallback"}
		span.SetStatus(codes.Error, err.Error())
	} else {
		logWithTrace(ctx, zapcore.InfoLevel, "Retrieved bid response", 
			zap.String("user_id", req.UserID),
			zap.String("ad_type", req.AdType),
			zap.Float64("bid_amount", bidResponse.BidAmount),
			zap.String("bid_id", bidResponse.BidID),
			zap.String("strategy", bidResponse.Strategy))
	}

	// Create response
	response := AdResponse{
		AdID:      fmt.Sprintf("ad_%s_%d", req.AdType, time.Now().Unix()),
		AdType:    req.AdType,
		BidAmount: bidResponse.BidAmount,
		UserData:  fmt.Sprintf("User analytics: %.2f%% click rate", userData.ClickRate*100),
		Message:   "Ad request processed successfully",
	}

	// Record metrics
	duration := time.Since(start).Seconds()
	adRequestsTotal.WithLabelValues("success", req.AdType).Inc()
	adRequestDuration.WithLabelValues(req.AdType).Observe(duration)

	span.SetAttributes(
		attribute.Float64("bid_amount", bidResponse.BidAmount),
		attribute.Float64("request_duration_seconds", duration),
	)

	logWithTrace(ctx, zapcore.InfoLevel, "Ad request completed successfully", 
		zap.String("user_id", req.UserID),
		zap.String("ad_type", req.AdType),
		zap.String("ad_id", response.AdID),
		zap.Float64("bid_amount", response.BidAmount),
		zap.Float64("duration_seconds", duration))

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
	span.SetStatus(codes.Ok, "Ad request processed successfully")
}

func getUserAnalytics(ctx context.Context, userID string) (*UserAnalytics, error) {
	ctx, span := tracer.Start(ctx, "get_user_analytics")
	defer span.End()

	span.SetAttributes(attribute.String("user_id", userID))

	analyticsURL := os.Getenv("ANALYTICS_SERVICE_URL")
	if analyticsURL == "" {
		analyticsURL = "http://localhost:3000"
	}

	url := fmt.Sprintf("%s/analytics/user/%s", analyticsURL, userID)
	span.SetAttributes(attribute.String("http.url", url))

	logWithTrace(ctx, zapcore.DebugLevel, "Fetching user analytics", 
		zap.String("user_id", userID),
		zap.String("url", url))

	// Use the shared HTTP client with OpenTelemetry instrumentation
	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		logWithTrace(ctx, zapcore.ErrorLevel, "Failed to create HTTP request", 
			zap.String("user_id", userID),
			zap.String("url", url),
			zap.Error(err))
		span.RecordError(err)
		return nil, err
	}

	// Add trace context headers (automatically handled by otelhttp.NewTransport)
	resp, err := httpClient.Do(req)
	if err != nil {
		logWithTrace(ctx, zapcore.ErrorLevel, "Failed to execute HTTP request", 
			zap.String("user_id", userID),
			zap.String("url", url),
			zap.Error(err))
		span.RecordError(err)
		span.SetStatus(codes.Error, err.Error())
		return nil, err
	}
	defer resp.Body.Close()

	span.SetAttributes(attribute.Int("http.status_code", resp.StatusCode))

	if resp.StatusCode != http.StatusOK {
		err := fmt.Errorf("analytics service returned status: %d", resp.StatusCode)
		logWithTrace(ctx, zapcore.ErrorLevel, "Analytics service returned error status", 
			zap.String("user_id", userID),
			zap.String("url", url),
			zap.Int("status_code", resp.StatusCode),
			zap.Error(err))
		span.RecordError(err)
		span.SetStatus(codes.Error, err.Error())
		return nil, err
	}

	var userData UserAnalytics
	if err := json.NewDecoder(resp.Body).Decode(&userData); err != nil {
		logWithTrace(ctx, zapcore.ErrorLevel, "Failed to decode analytics response", 
			zap.String("user_id", userID),
			zap.Error(err))
		span.RecordError(err)
		span.SetStatus(codes.Error, err.Error())
		return nil, err
	}

	span.SetAttributes(
		attribute.Float64("analytics.click_rate", userData.ClickRate),
		attribute.Float64("analytics.conversion_rate", userData.ConversionRate),
		attribute.Int("analytics.total_impressions", userData.TotalImpressions),
	)

	logWithTrace(ctx, zapcore.DebugLevel, "Successfully retrieved user analytics", 
		zap.String("user_id", userID),
		zap.Float64("click_rate", userData.ClickRate),
		zap.Float64("conversion_rate", userData.ConversionRate),
		zap.Int("total_impressions", userData.TotalImpressions))

	return &userData, nil
}

func getBid(ctx context.Context, req AdRequest) (*BidResponse, error) {
	ctx, span := tracer.Start(ctx, "get_bid")
	defer span.End()

	span.SetAttributes(
		attribute.String("user_id", req.UserID),
		attribute.String("ad_type", req.AdType),
	)

	bidURL := os.Getenv("BIDDING_SERVICE_URL")
	if bidURL == "" {
		bidURL = "http://localhost:3001"
	}

	url := fmt.Sprintf("%s/bidding/calculate", bidURL)
	span.SetAttributes(attribute.String("http.url", url))

	logWithTrace(ctx, zapcore.DebugLevel, "Fetching bid", 
		zap.String("user_id", req.UserID),
		zap.String("ad_type", req.AdType),
		zap.String("url", url))

	reqBody, err := json.Marshal(req)
	if err != nil {
		logWithTrace(ctx, zapcore.ErrorLevel, "Failed to marshal bid request", 
			zap.String("user_id", req.UserID),
			zap.String("ad_type", req.AdType),
			zap.Error(err))
		span.RecordError(err)
		return nil, err
	}

	// Use the shared HTTP client with OpenTelemetry instrumentation
	httpReq, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewBuffer(reqBody))
	if err != nil {
		logWithTrace(ctx, zapcore.ErrorLevel, "Failed to create HTTP request", 
			zap.String("user_id", req.UserID),
			zap.String("ad_type", req.AdType),
			zap.String("url", url),
			zap.Error(err))
		span.RecordError(err)
		return nil, err
	}
	httpReq.Header.Set("Content-Type", "application/json")

	// Add trace context headers (automatically handled by otelhttp.NewTransport)
	resp, err := httpClient.Do(httpReq)
	if err != nil {
		logWithTrace(ctx, zapcore.ErrorLevel, "Failed to execute HTTP request", 
			zap.String("user_id", req.UserID),
			zap.String("ad_type", req.AdType),
			zap.String("url", url),
			zap.Error(err))
		span.RecordError(err)
		span.SetStatus(codes.Error, err.Error())
		return nil, err
	}
	defer resp.Body.Close()

	span.SetAttributes(attribute.Int("http.status_code", resp.StatusCode))

	if resp.StatusCode != http.StatusOK {
		err := fmt.Errorf("bidding service returned status: %d", resp.StatusCode)
		logWithTrace(ctx, zapcore.ErrorLevel, "Bidding service returned error status", 
			zap.String("user_id", req.UserID),
			zap.String("ad_type", req.AdType),
			zap.String("url", url),
			zap.Int("status_code", resp.StatusCode),
			zap.Error(err))
		span.RecordError(err)
		span.SetStatus(codes.Error, err.Error())
		return nil, err
	}

	var bidResponse BidResponse
	if err := json.NewDecoder(resp.Body).Decode(&bidResponse); err != nil {
		logWithTrace(ctx, zapcore.ErrorLevel, "Failed to decode bid response", 
			zap.String("user_id", req.UserID),
			zap.String("ad_type", req.AdType),
			zap.Error(err))
		span.RecordError(err)
		span.SetStatus(codes.Error, err.Error())
		return nil, err
	}

	span.SetAttributes(attribute.Float64("bid_amount", bidResponse.BidAmount))

	logWithTrace(ctx, zapcore.DebugLevel, "Successfully retrieved bid", 
		zap.String("user_id", req.UserID),
		zap.String("ad_type", req.AdType),
		zap.Float64("bid_amount", bidResponse.BidAmount),
		zap.String("bid_id", bidResponse.BidID),
		zap.String("strategy", bidResponse.Strategy))

	return &bidResponse, nil
}

func testTracePropagationHandler(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	span := trace.SpanFromContext(ctx)
	defer span.End()

	span.SetAttributes(attribute.String("handler", "test_trace_propagation"))

	logWithTrace(ctx, zapcore.InfoLevel, "Testing trace propagation")

	// Get current trace context
	traceID := span.SpanContext().TraceID().String()
	spanID := span.SpanContext().SpanID().String()

	// Test making a request to analytics service
	analyticsURL := os.Getenv("ANALYTICS_SERVICE_URL")
	if analyticsURL == "" {
		analyticsURL = "http://localhost:3000"
	}

	ctx, childSpan := tracer.Start(ctx, "test.analytics_call")
	defer childSpan.End()

	url := fmt.Sprintf("%s/analytics/debug/otel", analyticsURL)
	childSpan.SetAttributes(attribute.String("http.url", url))

	logWithTrace(ctx, zapcore.DebugLevel, "Making test call to analytics service", 
		zap.String("url", url),
		zap.String("trace_id", traceID),
		zap.String("span_id", spanID))

	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		logWithTrace(ctx, zapcore.ErrorLevel, "Failed to create test request", 
			zap.String("url", url),
			zap.Error(err))
		childSpan.RecordError(err)
		childSpan.SetStatus(codes.Error, err.Error())
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	resp, err := httpClient.Do(req)
	if err != nil {
		logWithTrace(ctx, zapcore.ErrorLevel, "Failed to execute test request", 
			zap.String("url", url),
			zap.Error(err))
		childSpan.RecordError(err)
		childSpan.SetStatus(codes.Error, err.Error())
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer resp.Body.Close()

	childSpan.SetAttributes(attribute.Int("http.status_code", resp.StatusCode))

	var analyticsResponse map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&analyticsResponse); err != nil {
		logWithTrace(ctx, zapcore.ErrorLevel, "Failed to decode analytics response", 
			zap.String("url", url),
			zap.Error(err))
		childSpan.RecordError(err)
		childSpan.SetStatus(codes.Error, err.Error())
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	response := map[string]interface{}{
		"status":             "success",
		"trace_id":           traceID,
		"span_id":            spanID,
		"analytics_response": analyticsResponse,
		"message":            "Trace context propagation test completed",
		"timestamp":          time.Now().Unix(),
	}

	logWithTrace(ctx, zapcore.InfoLevel, "Trace propagation test completed successfully", 
		zap.String("trace_id", traceID),
		zap.String("span_id", spanID),
		zap.Int("status_code", resp.StatusCode))

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func main() {
	// Initialize tracer
	cleanup := initTracer()
	defer cleanup()

	// Create router
	router := mux.NewRouter()

	// Routes with OpenTelemetry instrumentation
	router.Handle("/health", otelhttp.NewHandler(http.HandlerFunc(healthHandler), "health_check"))
	router.Handle("/ads", otelhttp.NewHandler(http.HandlerFunc(listAdsHandler), "list_ads"))
	router.Handle("/ads/request", otelhttp.NewHandler(http.HandlerFunc(requestAdHandler), "request_ad"))
	router.Handle("/test/trace_propagation", otelhttp.NewHandler(http.HandlerFunc(testTracePropagationHandler), "test_trace_propagation"))

	// Prometheus metrics endpoint
	router.Handle("/metrics", promhttp.Handler())

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	ctx := context.Background()
	logWithTrace(ctx, zapcore.InfoLevel, "Ad service starting", 
		zap.String("port", port),
		zap.String("service", "ad-service"))

	logger.Info("Ad service started successfully", 
		zap.String("port", port),
		zap.String("service", "ad-service"))

	if err := http.ListenAndServe(":"+port, router); err != nil {
		logger.Fatal("Failed to start server", 
			zap.String("port", port),
			zap.Error(err))
	}
}
