class HealthController < ApplicationController
  def index
    render json: { status: 'healthy', service: 'analytics-service', timestamp: Time.current }, status: :ok
  end
end 