.PHONY: help start-infra stop-infra start-services stop-services test clean install-deps build build-all up down logs

help: ## Show this help message
	@echo "Ad-Tech Microservices Training with OpenTelemetry & Grafana Stack"
	@echo ""
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

start-infra: ## Start monitoring infrastructure (Docker)
	docker compose up -d tempo loki prometheus grafana otel-collector redis postgres
	@echo "✅ Infrastructure started:"
	@echo "   - Grafana: http://localhost:3002 (admin/admin)"
	@echo "   - Tempo: http://localhost:3200"
	@echo "   - Loki: http://localhost:3100"
	@echo "   - Prometheus: http://localhost:9090"
	@echo "   - OpenTelemetry Collector: localhost:4317/4318"

stop-infra: ## Stop monitoring infrastructure
	docker compose stop tempo loki prometheus grafana otel-collector redis postgres

build: ## Build all application services
	@echo "Building application services..."
	docker compose build ad-service analytics-service bidding-service
	@echo "✅ All services built successfully"

build-all: ## Build all services (infrastructure + applications)
	@echo "Building all services..."
	docker compose build
	@echo "✅ All services built successfully"

up: ## Start all services (infrastructure + applications)
	docker compose up -d
	@echo "✅ All services started:"
	@echo "   - Ad Service: http://localhost:8180"
	@echo "   - Analytics Service: http://localhost:3000"
	@echo "   - Bidding Service: http://localhost:3001"
	@echo "   - Grafana: http://localhost:3002 (admin/admin)"

down: ## Stop all services
	docker compose down

install-deps: ## Install dependencies for all services
	@echo "Installing Go dependencies..."
	cd ad-service && go mod tidy
	@echo "Installing Node.js dependencies..."
	cd bidding-service && npm install
	@echo "Installing Rails dependencies..."
	cd analytics-service && bundle install

start-services: ## Start all microservices (local development)
	@echo "Starting microservices..."
	@echo "Ad Service (Go) - http://localhost:8180"
	@echo "Analytics Service (Rails) - http://localhost:3000"
	@echo "Bidding Service (Node.js) - http://localhost:3001"
	@echo ""
	@echo "Run in separate terminals:"
	@echo "  Terminal 1: cd ad-service && go run main.go"
	@echo "  Terminal 2: cd analytics-service && rails server"
	@echo "  Terminal 3: cd bidding-service && npm start"

test: ## Run the test script to verify services
	@echo "Running service tests..."
	./test-services.sh

load-test: ## Generate load for testing
	@echo "Generating load for 30 seconds..."
	@./test-services.sh

clean: ## Clean up all containers and volumes
	docker compose down -v
	@echo "✅ Cleaned up all containers and volumes"

logs: ## Show logs from all services
	docker compose logs -f

status: ## Show status of all services
	@echo "Checking service status..."
	@curl -s http://localhost:8180/health | jq . 2>/dev/null || echo "❌ Ad Service not responding"
	@curl -s http://localhost:3000/health | jq . 2>/dev/null || echo "❌ Analytics Service not responding"
	@curl -s http://localhost:3001/health | jq . 2>/dev/null || echo "❌ Bidding Service not responding"

setup: install-deps start-infra ## Complete setup (install deps + start infra)
	@echo "✅ Setup complete! Now start the services with 'make start-services'"

docker-setup: build-all up ## Complete Docker setup (build + start all services)
	@echo "✅ Docker setup complete! All services are running in containers" 