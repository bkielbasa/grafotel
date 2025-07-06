Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Health check endpoint
  get 'health', to: 'health#index'

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
  get 'analytics/user/:id', to: 'analytics#user'
  get 'analytics/historical', to: 'analytics#historical'
  post 'analytics/event', to: 'analytics#event'
  get 'analytics/debug/otel', to: 'analytics#debug_otel'
  get 'analytics/test/trace_propagation', to: 'analytics#test_trace_propagation'

  get 'metrics', to: 'metrics#index'
end
