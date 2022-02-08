Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html

  root to: 'projects#costs_breakdown'

  # Projects
  get '/costs-breakdown', to: 'projects#costs_breakdown'
  get '/json/data-check', to: 'projects#data_check'
end
