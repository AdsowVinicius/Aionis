Rails.application.routes.draw do
  devise_for :users

  authenticated :user do
    root "dashboard#index", as: :authenticated_root
  end

  root "home#index"

  resources :workspaces do
    scope module: :workspaces do
      resource  :dashboard, only: :show
      resources :categories
      resources :counterparties
      resources :documents
      resources :financial_transactions
      resource  :subscription, only: [:show, :edit, :update]
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
