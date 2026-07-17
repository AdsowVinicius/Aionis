Rails.application.routes.draw do
  devise_for :users

  authenticated :user do
    root "dashboard#index", as: :authenticated_root
  end

  root "home#index"

  resources :workspaces do
    scope module: :workspaces do
      # controller: 'dashboard' mantém Workspaces::DashboardController (singular)
      resource  :dashboard,             only: :show,  controller: "dashboard"
      resources :financial_transactions
      resources :categories
      resources :category_rules
      resources :counterparties
      resources :documents, only: [:index, :new, :create, :show, :destroy] do
        member do
          post :trigger
        end
      end
      resources :payables do
        member { patch :settle }
      end
      resources :receivables do
        member { patch :settle }
      end
      resources :alerts, only: [:index]
      resources :audit_logs, only: [:index, :show]
      resources :whatsapp_channels, except: [:show]
      resource  :subscription, only: [:show, :edit, :update]
      resource  :settings,    only: :show
    end
  end

  # Webhooks públicos do WhatsApp (sem autenticação de usuário).
  # Meta Cloud: GET (verificação) + POST (eventos, validados por HMAC).
  get  "/webhooks/whatsapp/meta", to: "webhooks/whatsapp#verify",  as: :whatsapp_meta_verify
  post "/webhooks/whatsapp/meta", to: "webhooks/whatsapp#receive", as: :whatsapp_meta_webhook
  # Evolution: POST por instância (validado por token).
  post "/webhooks/whatsapp/:instance", to: "webhooks/whatsapp#create", as: :whatsapp_webhook

  get "up" => "rails/health#show", as: :rails_health_check
end
