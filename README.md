# Aionis — Assistente Financeiro

SaaS financeiro para CPF, MEI e pequenas empresas.  
Permite lançar despesas, receitas, documentos e fornecedores via portal web.

---

## Pré-requisitos

| Ferramenta | Versão | Como instalar |
|---|---|---|
| Ruby + DevKit | 3.3.x | `winget install RubyInstallerTeam.RubyWithDevKit.3.3` |
| PostgreSQL | 16.x | `winget install PostgreSQL.PostgreSQL.16` |
| Rails | 8.1.x | `gem install rails` (após instalar Ruby) |

> **Senha padrão do PostgreSQL local:** `postgres`  
> Configurável na variável de ambiente `DB_PASSWORD`.

---

## Rodar pela primeira vez

### 1. Clone ou acesse a pasta do projeto

```
cd "G:\Meu Drive\Aionis\Portifolio Aionis\Projeto Aionis\Aionis"
```

### 2. Instale as gems

```powershell
$env:PATH = "C:\Ruby33-x64\bin;" + $env:PATH
bundle install
```

### 3. Crie e popule o banco de dados

```powershell
$env:DB_PASSWORD = "postgres"
rails db:create
rails db:migrate
rails db:seed
```

O `db:seed` cria automaticamente:
- 4 planos de assinatura (CPF, MEI, Pro, Gestão)
- 18 categorias globais (Receitas, Despesas, Impostos, Transporte, etc.)

### 4. Inicie a aplicação

```powershell
.\iniciar.ps1
```

Ou, manualmente:

```powershell
$env:PATH = "C:\Ruby33-x64\bin;C:\Program Files\PostgreSQL\16\bin;" + $env:PATH
$env:DB_PASSWORD = "postgres"
foreman start -f Procfile.dev
```

---

## Acessar a aplicação

| Tela | URL |
|---|---|
| Landing page | http://localhost:3000 |
| Login | http://localhost:3000/users/sign_in |
| Criar conta | http://localhost:3000/users/sign_up |
| Dashboard | http://localhost:3000 *(após login)* |

**Primeiro acesso:**
1. Acesse http://localhost:3000/users/sign_up
2. Preencha nome, e-mail e senha
3. Após login → crie seu primeiro workspace (empresa/MEI/CPF)
4. Acesse o dashboard

---

## O que roda quando você executa `.\iniciar.ps1`

O script `iniciar.ps1` faz automaticamente:

1. Verifica se Ruby está instalado
2. Verifica se PostgreSQL está rodando
3. Roda `bundle install` se necessário
4. Cria e popula o banco se não existir
5. Roda migrations pendentes
6. Inicia o **servidor Rails** (porta 3000) + **Tailwind watcher** em paralelo via `foreman`

Use **Ctrl+C** para parar tudo.

---

## Variáveis de ambiente

Todas têm valor padrão para desenvolvimento local. Só altere se necessário.

| Variável | Padrão | Descrição |
|---|---|---|
| `DB_USERNAME` | `postgres` | Usuário do PostgreSQL |
| `DB_PASSWORD` | `postgres` | Senha do PostgreSQL |
| `DB_HOST` | `localhost` | Host do banco |
| `DB_PORT` | `5432` | Porta do banco |
| `PORT` | `3000` | Porta do Rails |
| `RAILS_ENV` | `development` | Ambiente |

Para personalizar sem alterar o código, crie um arquivo `.env` ou use um arquivo `.env.local` (não comitar).

---

## Comandos úteis de desenvolvimento

```powershell
# Após abrir o PowerShell, configure o ambiente:
$env:PATH = "C:\Ruby33-x64\bin;C:\Program Files\PostgreSQL\16\bin;" + $env:PATH
$env:DB_PASSWORD = "postgres"

# Rodar testes
rails test

# Compilar Tailwind CSS manualmente
rails tailwindcss:build

# Ver todas as rotas
rails routes

# Acessar o console do Rails
rails console

# Rodar seeds (idempotente — pode rodar várias vezes sem duplicar)
rails db:seed

# Criar nova migration
rails generate migration NomeDaMigration

# Rodar migrations
rails db:migrate

# Reverter última migration
rails db:rollback
```

---

## Como alterar planos

Edite `config/aionis/plans.yml` e rode `rails db:seed`.

```yaml
# Exemplo: alterar preço do plano MEI
mei:
  name: "Aionis MEI"
  monthly_price_cents: 9700   # R$ 97,00
  setup_fee_cents: 29700      # R$ 297,00 de implantação
  max_users: 2
  # ...
```

---

## Como alterar categorias globais

Edite `config/aionis/categories.yml` e rode `rails db:seed`.

Adicionar nova categoria (exemplo):
```yaml
marketing:
  name: "Marketing"
  kind: "expense"
  cost_type: "variable"
  essentiality: "operational_important"
  is_system_default: true
```

Para criar subcategoria, use o campo `parent` com o nome exato da categoria pai:
```yaml
trafego_pago:
  name: "Tráfego pago"
  kind: "expense"
  parent: "Marketing"
  cost_type: "variable"
  essentiality: "operational_important"
  is_system_default: true
```

---

## Estrutura do projeto

```
app/
  controllers/
    application_controller.rb     # Auth, layout, Devise params
    dashboard_controller.rb       # Seletor de workspace / onboarding
    workspaces_controller.rb      # CRUD de workspaces
    workspaces/
      base_controller.rb          # require_workspace! para área logada
      dashboard_controller.rb     # Dashboard com cards de métricas
      financial_transactions_controller.rb
      categories_controller.rb
      counterparties_controller.rb
      documents_controller.rb
      payables_controller.rb
      receivables_controller.rb
      settings_controller.rb
  models/
    user.rb                       # Devise + name
    workspace.rb                  # CPF/MEI/Empresa, tax_id opcional
    plan.rb                       # Planos de assinatura
    subscription.rb               # Assinatura do workspace
    category.rb                   # Categorias globais e por workspace
    counterparty.rb               # Fornecedores/clientes, tax_id opcional
    document.rb                   # Documentos com ActiveStorage
    financial_transaction.rb      # Lançamentos financeiros
  views/
    layouts/
      application.html.erb        # Layout público (login, cadastro)
      authenticated.html.erb      # Layout logado (sidebar + topbar)
    workspaces/dashboard/
      show.html.erb               # Dashboard principal
    devise/                       # Views em português
config/
  aionis/
    plans.yml                     # Configuração dos planos (editável)
    categories.yml                # Categorias globais (editável)
  locales/
    pt-BR.yml                     # Locale geral
    devise.pt-BR.yml              # Mensagens do Devise em português
```

---

## Regra crítica: CPF/CNPJ é opcional

O campo CPF/CNPJ aparece nas telas mas **nunca é obrigatório no backend**.

- Workspace: `tax_id` nullable, validado apenas quando preenchido
- Counterparty: `tax_id` nullable, índice único parcial (só quando preenchido)
- FinancialTransaction: `counterparty_id`, `document_id` e `category_id` opcionais

---

## Stack

| Camada | Tecnologia |
|---|---|
| Framework | Ruby on Rails 8.1 |
| Banco | PostgreSQL 16 |
| Frontend | Hotwire (Turbo + Stimulus) + TailwindCSS v4 |
| Auth | Devise |
| Jobs | Solid Queue |
| Storage | Active Storage (local em dev) |
| Testes | Minitest |
