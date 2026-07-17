# =============================================================================
#  Aionis — Script de inicialização (Windows PowerShell)
#  Executa: Rails server + Tailwind CSS watcher em paralelo
#  Uso: .\iniciar.ps1
# =============================================================================

$RUBY_PATH   = "C:\Ruby33-x64\bin"
$PG_PATH     = "C:\Program Files\PostgreSQL\16\bin"
$APP_ROOT    = $PSScriptRoot

# --- Ambiente -----------------------------------------------------------------
$env:PATH        = "$RUBY_PATH;$PG_PATH;" + $env:PATH
$env:DB_USERNAME = "postgres"
$env:DB_PASSWORD = "postgres"
$env:DB_HOST     = "localhost"
$env:DB_PORT     = "5432"
$env:RAILS_ENV   = "development"
$env:PORT        = "3000"

Set-Location $APP_ROOT

Write-Host ""
Write-Host "  ╔══════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║         AIONIS               ║" -ForegroundColor Cyan
Write-Host "  ║  Assistente Financeiro       ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# --- Verificar Ruby -----------------------------------------------------------
Write-Host "► Verificando Ruby..." -NoNewline
try {
    $rubyVer = & ruby --version 2>&1
    Write-Host " $rubyVer" -ForegroundColor Green
} catch {
    Write-Host " ERRO: Ruby não encontrado em $RUBY_PATH" -ForegroundColor Red
    Write-Host "  Instale via: winget install RubyInstallerTeam.RubyWithDevKit.3.3" -ForegroundColor Yellow
    exit 1
}

# --- Verificar e iniciar PostgreSQL -------------------------------------------
Write-Host "► Verificando PostgreSQL..." -NoNewline
& "$PG_PATH\pg_isready.exe" -q 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host " OK (porta 5432)" -ForegroundColor Green
} else {
    Write-Host " parado. Tentando iniciar..." -ForegroundColor Yellow
    # Tenta iniciar o serviço (requer que tenha sido configurado como automático)
    $svc = Get-Service -Name "postgresql-x64-16" -ErrorAction SilentlyContinue
    if ($svc) {
        Start-Service "postgresql-x64-16" -ErrorAction SilentlyContinue
        Start-Sleep 4
        & "$PG_PATH\pg_isready.exe" -q 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host " iniciado com sucesso." -ForegroundColor Green
        } else {
            Write-Host ""
            Write-Host "ERRO: Não foi possível iniciar o PostgreSQL." -ForegroundColor Red
            Write-Host "Execute como Administrador ou inicie o serviço manualmente:" -ForegroundColor Yellow
            Write-Host "  Start-Service postgresql-x64-16" -ForegroundColor White
            Write-Host "  (ou abra services.msc e inicie 'postgresql-x64-16')" -ForegroundColor White
            exit 1
        }
    } else {
        Write-Host ""
        Write-Host "ERRO: Serviço postgresql-x64-16 não encontrado." -ForegroundColor Red
        Write-Host "Instale via: winget install PostgreSQL.PostgreSQL.16" -ForegroundColor Yellow
        exit 1
    }
}

# --- Setup automático na primeira vez -----------------------------------------
$gemfileLock = Join-Path $APP_ROOT "Gemfile.lock"
$nodeModules  = Join-Path $APP_ROOT "node_modules"

Write-Host "► Verificando gems..." -NoNewline
$bundleOk = & bundle check 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host " instalando..." -ForegroundColor Yellow
    & bundle install
} else {
    Write-Host " OK" -ForegroundColor Green
}

# --- Verificar banco de dados -------------------------------------------------
Write-Host "► Verificando banco de dados..." -NoNewline
$dbCheck = & rails runner "ActiveRecord::Base.connection; puts 'ok'" 2>&1
if ($dbCheck -match "ok") {
    Write-Host " OK (aionis_development)" -ForegroundColor Green
} else {
    Write-Host " criando..." -ForegroundColor Yellow
    & rails db:create
    & rails db:migrate
    & rails db:seed
    Write-Host "  Banco criado e populado." -ForegroundColor Green
}

# --- Rodar migrações pendentes ------------------------------------------------
Write-Host "► Verificando migrations pendentes..." -NoNewline
$pendingMigrations = & rails db:migrate:status 2>&1 | Select-String "down"
if ($pendingMigrations) {
    Write-Host " rodando migrations..." -ForegroundColor Yellow
    & rails db:migrate
} else {
    Write-Host " OK" -ForegroundColor Green
}

# --- Iniciar aplicação --------------------------------------------------------
Write-Host ""
Write-Host "═══════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Aionis rodando em: http://localhost:3000      " -ForegroundColor Green
Write-Host "  Login:   http://localhost:3000/users/sign_in  " -ForegroundColor White
Write-Host "  Cadastro: http://localhost:3000/users/sign_up " -ForegroundColor White
Write-Host "  Ctrl+C para parar                             " -ForegroundColor Gray
Write-Host "═══════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Compila o CSS uma vez. NÃO usamos o watcher via foreman: no Windows o
# 'tailwindcss:watch' sai sozinho (code 0) e o foreman derruba o servidor junto,
# além de quebrar no kill (Errno::EINVAL). Rodar o server isolado é estável.
Write-Host "► Compilando CSS (Tailwind)..." -NoNewline
& rails tailwindcss:build | Out-Null
Write-Host " OK" -ForegroundColor Green
Write-Host "  (Para recompilar o CSS após editar estilos: rails tailwindcss:build)" -ForegroundColor Gray
Write-Host ""

# Inicia apenas o Rails server (foreground; Ctrl+C para parar).
& rails server -p 3000
