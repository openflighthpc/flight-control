Rails.application.routes.draw do
  devise_for :users
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html

  root to: 'projects#costs_breakdown'

  # Projects
  get '/costs-breakdown', to: 'projects#costs_breakdown'
  get '/billing-management', to: 'projects#billing_management'
  get '/json/data-check', to: 'projects#data_check'

  # Events (change requests and their resulting actions)
  get '/events', to: 'events#manage'
  get '/events/new', to: 'events#new'
  get '/json/events/latest', to: 'events#latest'
  get '/json/events/costs-forecast', to: 'events#costs_forecast'
  post '/events/', to: 'events#create'
end
