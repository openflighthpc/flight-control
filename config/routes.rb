Rails.application.routes.draw do
  devise_for :users, only: :sessions, controllers: { sessions: "sessions" }
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html

  devise_scope :user do
    # When user authenticated, root page is as normal
    authenticated :user do
      root 'projects#dashboard', as: :authenticated_root
    end

    # When no authenticated user, root page is the sign in page
    unauthenticated do
      root 'devise/sessions#new', as: :unauthenticated_root
    end
  end

  resources :projects, only: [] do
    get 'dashboard'
    get 'costs-breakdown'
    get 'billing-management'
    get 'policies', to: 'projects#policy_page'
    get 'audit'
    post 'config-update'
    get 'json/data-check', to: 'projects#data_check'
    get 'json/audit-logs', to: 'projects#audit_logs'

    resources :events, controller: :change_requests, only: [:new, :create] do
      collection do
        get '', to: 'change_requests#manage', as: 'manage'
        get 'json/latest', to: 'change_requests#latest', as: 'latest'
        get 'json/costs-forecast', to: 'change_requests#costs_forecast', as: 'cost_forecast'
      end
    end
  end

  resources :events, controller: :change_requests, only: [:edit, :update] do
    post 'cancel', to: 'change_requests#cancel', on: :member
  end

  post 'dashboard/:id/cancel', to: 'change_requests#cancel'
end
