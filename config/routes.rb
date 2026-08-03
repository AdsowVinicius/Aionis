Rails.application.routes.draw do
  devise_for :users

  authenticated :user do
    root "dashboard#index", as: :authenticated_root
  end

  # Landing pública de vendas (home#index antiga ficou sem rota; arquivos mantidos).
  root "landing#index"

  # Páginas legais — públicas e sem login (a Meta valida a URL da política de
  # privacidade na revisão do app do WhatsApp). Slug sem acento para evitar
  # URL percent-encoded; os apelidos redirecionam para a URL canônica.
  get "/politica-de-privacidade", to: "legal#privacy", as: :privacy_policy
  get "/politicas-privacidade",   to: redirect("/politica-de-privacidade")
  get "/privacidade",             to: redirect("/politica-de-privacidade")

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
          post  :trigger
          get   :review
          post  :confirm
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
      resources :whatsapp_channels, only: [:index]
      # Agente Financeiro (chat) e a memória do agente (LGPD: ver/apagar).
      resource  :chat, only: [:show, :create], controller: "chat"
      resources :agent_memories, only: [:index, :destroy]
      resources :reconciliations, only: [:index] do
        member do
          patch :confirm
          patch :reject
        end
      end
      resource :settings,    only: :show
    end
  end

  # Webhooks públicos do WhatsApp (sem autenticação de usuário).
  # Meta Cloud: GET (verificação) + POST (eventos, validados por HMAC).
  get  "/webhooks/whatsapp/meta", to: "webhooks/whatsapp#verify",  as: :whatsapp_meta_verify
  post "/webhooks/whatsapp/meta", to: "webhooks/whatsapp#receive", as: :whatsapp_meta_webhook
  # Evolution: POST por instância (validado por token).
  post "/webhooks/whatsapp/:instance", to: "webhooks/whatsapp#create", as: :whatsapp_webhook

  get "up" => "rails/health#show", as: :rails_health_check

  # Manifest do PWA (ícone, nome e cores ao "adicionar à tela de início").
  # O service-worker.js segue desligado de propósito: cache offline muda o
  # comportamento do app e merece decisão à parte.
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest, defaults: { format: :json }
end
