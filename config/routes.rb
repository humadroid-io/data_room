Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # MCP server (Streamable HTTP) — Bearer token auth via TokenAuthMiddleware
  mount DataRoomMcpServer.app => "/mcp"

  # Investor sessions
  get    "login",  to: "sessions#new",     as: :login
  post   "login",  to: "sessions#create"
  delete "logout", to: "sessions#destroy", as: :logout

  # Admin namespace
  namespace :admin do
    root to: "dashboards#show"
    get    "login",  to: "sessions#new",     as: :login
    post   "login",  to: "sessions#create"
    delete "logout", to: "sessions#destroy", as: :logout

    resource :dashboard, only: [ :show ]
    post "dashboard/regenerate_token", to: "dashboards#regenerate_token", as: :regenerate_token
    resources :stripe_syncs, only: [ :create ]
    resources :pages do
      resources :documents, only: [ :destroy ], controller: "page_documents"
    end
    resources :customers
    resources :subscriptions
    resources :investors do
      member do
        post :regenerate_access_code
      end
    end
    resources :users do
      member do
        post :regenerate_api_token
      end
    end
    resources :attribute_definitions
    resources :page_views, only: [ :index ]
    resources :payments,   only: [ :index ]
    resources :events,     except: [ :show ]

    resources :impersonations, only: [ :create, :destroy ]
  end

  # Investor-facing root + catch-all hierarchical pages
  root to: "pages#show"

  get "*path", to: "pages#show", as: :page,
      constraints: ->(req) {
        path = req.params[:path].to_s
        path.match?(/\A[a-z0-9\-\/]*\z/) &&
          !path.start_with?("rails/", "active_storage/", "admin/")
      }
end
