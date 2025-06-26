package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log"
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
)

var (
	tracer = otel.Tracer("ad-service")

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

	log.Printf("Initializing OpenTelemetry with endpoint: %s", otlpEndpoint)

	otlpExporter, err := otlptracegrpc.New(ctx,
		otlptracegrpc.WithEndpoint(otlpEndpoint),
		otlptracegrpc.WithInsecure(),
		otlptracegrpc.WithDialOption(grpc.WithTransportCredentials(insecure.NewCredentials())),
	)
	if err != nil {
		log.Fatal(err)
	}

	// Resource
	res, err := resource.New(ctx,
		resource.WithAttributes(
			semconv.ServiceName("ad-service"),
			semconv.ServiceVersion("1.0.0"),
		),
	)
	if err != nil {
		log.Fatal(err)
	}

	// Tracer provider
	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(otlpExporter),
		sdktrace.WithResource(res),
	)
	otel.SetTracerProvider(tp)

	log.Printf("OpenTelemetry initialized successfully")

	return func() {
		if err := tp.Shutdown(ctx); err != nil {
			log.Printf("Error shutting down tracer provider: %v", err)
		}
	}
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{"status": "healthy", "service": "ad-service"})
}

func listAdsHandler(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	span := trace.SpanFromContext(ctx)
	defer span.End()

	span.SetAttributes(attribute.String("handler", "list_ads"))

	ads := []map[string]interface{}{
		{"id": "ad_001", "type": "banner", "title": "Summer Sale", "price": 0.50},
		{"id": "ad_002", "type": "video", "title": "New Product", "price": 1.20},
		{"id": "ad_003", "type": "native", "title": "Special Offer", "price": 0.75},
	}

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
		http.Error(w, err.Error(), http.StatusBadRequest)
		adRequestsTotal.WithLabelValues("error", "unknown").Inc()
		span.SetStatus(codes.Error, err.Error())
		return
	}

	span.SetAttributes(
		attribute.String("user_id", req.UserID),
		attribute.String("ad_type", req.AdType),
	)

	// Get user analytics from analytics service
	userData, err := getUserAnalytics(ctx, req.UserID)
	if err != nil {
		log.Printf("Error getting user analytics: %v", err)
		span.SetStatus(codes.Error, err.Error())
		userData = &UserAnalytics{UserID: req.UserID, ClickRate: 0.02, ConversionRate: 0.01, TotalImpressions: 100}
	}

	// Get bid from bidding service
	bidResponse, err := getBid(ctx, req)
	if err != nil {
		log.Printf("Error getting bid: %v", err)
		bidResponse = &BidResponse{BidAmount: 0.50, BidID: "default_bid", Strategy: "fallback"}
		span.SetStatus(codes.Error, err.Error())
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

	// Use the shared HTTP client with OpenTelemetry instrumentation
	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		span.RecordError(err)
		return nil, err
	}

	// Add trace context headers (automatically handled by otelhttp.NewTransport)
	resp, err := httpClient.Do(req)
	if err != nil {
		span.RecordError(err)
		span.SetStatus(codes.Error, err.Error())
		return nil, err
	}
	defer resp.Body.Close()

	span.SetAttributes(attribute.Int("http.status_code", resp.StatusCode))

	if resp.StatusCode != http.StatusOK {
		err := fmt.Errorf("analytics service returned status: %d", resp.StatusCode)
		span.RecordError(err)
		span.SetStatus(codes.Error, err.Error())
		return nil, err
	}

	var userData UserAnalytics
	if err := json.NewDecoder(resp.Body).Decode(&userData); err != nil {
		span.RecordError(err)
		span.SetStatus(codes.Error, err.Error())
		return nil, err
	}

	span.SetAttributes(
		attribute.Float64("analytics.click_rate", userData.ClickRate),
		attribute.Float64("analytics.conversion_rate", userData.ConversionRate),
		attribute.Int("analytics.total_impressions", userData.TotalImpressions),
	)

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

	reqBody, err := json.Marshal(req)
	if err != nil {
		span.RecordError(err)
		return nil, err
	}

	// Use the shared HTTP client with OpenTelemetry instrumentation
	httpReq, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewBuffer(reqBody))
	if err != nil {
		span.RecordError(err)
		return nil, err
	}
	httpReq.Header.Set("Content-Type", "application/json")

	// Add trace context headers (automatically handled by otelhttp.NewTransport)
	resp, err := httpClient.Do(httpReq)
	if err != nil {
		span.RecordError(err)
		span.SetStatus(codes.Error, err.Error())
		return nil, err
	}
	defer resp.Body.Close()

	span.SetAttributes(attribute.Int("http.status_code", resp.StatusCode))

	if resp.StatusCode != http.StatusOK {
		err := fmt.Errorf("bidding service returned status: %d", resp.StatusCode)
		span.RecordError(err)
		span.SetStatus(codes.Error, err.Error())
		return nil, err
	}

	var bidResponse BidResponse
	if err := json.NewDecoder(resp.Body).Decode(&bidResponse); err != nil {
		span.RecordError(err)
		span.SetStatus(codes.Error, err.Error())
		return nil, err
	}

	span.SetAttributes(attribute.Float64("bid_amount", bidResponse.BidAmount))

	return &bidResponse, nil
}

func testTracePropagationHandler(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	span := trace.SpanFromContext(ctx)
	defer span.End()

	span.SetAttributes(attribute.String("handler", "test_trace_propagation"))

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

	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		childSpan.RecordError(err)
		childSpan.SetStatus(codes.Error, err.Error())
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	resp, err := httpClient.Do(req)
	if err != nil {
		childSpan.RecordError(err)
		childSpan.SetStatus(codes.Error, err.Error())
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer resp.Body.Close()

	childSpan.SetAttributes(attribute.Int("http.status_code", resp.StatusCode))

	var analyticsResponse map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&analyticsResponse); err != nil {
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

	log.Printf("Ad service starting on port %s", port)
	log.Fatal(http.ListenAndServe(":"+port, router))
}
