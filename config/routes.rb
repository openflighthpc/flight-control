Rails.application.routes.draw do
  devise_for :users, only: :sessions, controllers: { sessions: "sessions" }
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html

  devise_scope :user do
    # When user authenticated, root page is as normal
    authenticated :user do
      root 'projects#costs_breakdown', as: :authenticated_root
    end

    # When no authenticated user, root page is the sign in page
    unauthenticated do
      root 'devise/sessions#new', as: :unauthenticated_root
    end
  end

  # Projects
  get '/costs-breakdown', to: 'projects#costs_breakdown'
  get '/billing-management', to: 'projects#billing_management'
  get '/policies', to: 'projects#policy_page'
  get '/audit', to: 'projects#audit'
  get '/json/data-check', to: 'projects#data_check'
  get '/json/audit-logs', to: 'projects#audit_logs'
  post '/config-update', to: 'projects#config_update'

  # Events (change requests and their resulting actions)
  get '/events', to: 'change_requests#manage'
  get '/events/new', to: 'change_requests#new'
  get '/events/:id/edit', to: 'change_requests#edit', as: :event_edit
  get '/json/events/latest', to: 'change_requests#latest'
  get '/json/events/costs-forecast', to: 'change_requests#costs_forecast'
  post '/events/', to: 'change_requests#create'
  post '/events/:id/cancel', to: 'change_requests#cancel'
  post '/events/:id/update', to: 'change_requests#update'
end
