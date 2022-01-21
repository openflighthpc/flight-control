Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html

  root to: 'projects#costs_breakdown'

  # Projects
  get '/costs_breakdown', to: 'projects#costs_breakdown'
end
