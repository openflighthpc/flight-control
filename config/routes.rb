Rails.application.routes.draw do
  devise_for :users, only: :sessions
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
  get '/json/data-check', to: 'projects#data_check'

  # Events (change requests and their resulting actions)
  get '/events', to: 'events#manage'
  get '/events/new', to: 'events#new'
  get '/events/:id/edit', to: 'events#edit'
  get '/json/events/latest', to: 'events#latest'
  get '/json/events/costs-forecast', to: 'events#costs_forecast'
  post '/events/', to: 'events#create'
  post '/events/:id/cancel', to: 'events#cancel'
end
