# frozen_string_literal: true

# Diagnóstico de configuração do Aionis. Não faz chamadas externas: só confere
# se cada integração está apontada/configurada (provedor ativo + configured?),
# se o banco está migrado e semeado e se a criptografia está pronta para produção.
#
#   bin/rails aionis:doctor
#
# Segredos NUNCA são impressos — só o status (presente/ausente) de cada ENV.
namespace :aionis do
  desc "Verifica a configuração do app (WhatsApp, IA, OCR, banco, criptografia)"
  task doctor: :environment do
    checker = Aionis::Doctor.new
    checker.run
    exit(1) if checker.failed?
  end

  namespace :ocr do
    # Autoteste FIM-A-FIM do OCR: roda o provider real (Python + Tesseract) sobre
    # uma imagem com texto conhecido e diz EXATAMENTE o que está quebrado.
    # Use no Railway:  railway run bin/rails aionis:ocr:selftest
    desc "Testa o OCR de ponta a ponta e reporta o erro exato (útil no Railway)"
    task selftest: :environment do
      require "open3"
      say = ->(m) { puts m }

      say.call "\n\e[1mAIONIS · OCR selftest\e[0m"
      say.call "provider ativo : #{Aionis::Integrations.active_provider_key(:ocr)}"

      if Aionis::Integrations.active_provider_key(:ocr) == "null"
        say.call "\e[31m✗ OCR_PROVIDER não está 'tesseract' (está null).\e[0m"
        say.call "  → Defina OCR_PROVIDER=tesseract nas variáveis do Railway e reinicie."
        exit(1)
      end

      # 1) binários presentes? (argv como array — caminhos com espaço no Windows)
      py   = ENV.fetch("OCR_PYTHON_BIN", "python3")
      tess = ENV["TESSERACT_CMD"].presence || "tesseract"
      { "Python" => py, "Tesseract binário" => tess }.each do |label, bin|
        out, st = Open3.capture2e(bin, "--version")
        say.call(st.success? ? "\e[32m✓\e[0m #{label}: #{out.lines.first&.strip}"
                             : "\e[31m✗ #{label} não encontrado (#{bin}): #{out.lines.first&.strip}\e[0m")
      rescue => e
        say.call "\e[31m✗ #{label} não encontrado (#{bin}): #{e.message}\e[0m"
      end

      # 2) idioma por instalado?
      langs, = Open3.capture2e(tess, "--list-langs")
      say.call(langs.include?("por") ? "\e[32m✓\e[0m Idioma 'por' instalado"
                                     : "\e[31m✗ Idioma 'por' AUSENTE — instale tesseract-ocr-por\e[0m")

      # 3) libs Python do worker?
      libs, st = Open3.capture2e(py, "-c", "import cv2, numpy, pytesseract, fitz; print('ok')")
      say.call(st.success? ? "\e[32m✓\e[0m Libs Python (cv2/numpy/pytesseract/pymupdf) importam"
                           : "\e[31m✗ Libs Python faltando: #{libs.strip.lines.last}\e[0m")

      # 4) extração real na imagem de teste
      path = Rails.root.join("script", "ocr", "selftest_sample.png")
      unless File.exist?(path)
        say.call "\e[31m✗ Imagem de teste ausente: #{path}\e[0m"; exit(1)
      end
      result = Aionis::Integrations.ocr.extract(io: File.open(path, "rb"), content_type: "image/png")
      if result.success?
        text = result.data["text"].to_s
        say.call "\e[32m✓ EXTRAÇÃO OK\e[0m — confiança #{result.data['confidence']}"
        say.call "  texto lido: #{text.gsub(/\s+/, ' ').strip.truncate(120)}"
        say.call(text.match?(/123,45|CNPJ|AIONIS/i) ? "\e[32m✓ Reconheceu o conteúdo esperado. OCR 100% funcional.\e[0m"
                                                     : "\e[33m! Extraiu, mas não casou o texto esperado (qualidade baixa?).\e[0m")
      else
        say.call "\e[31m✗ EXTRAÇÃO FALHOU\e[0m (#{result.status}): #{result.message}"
        say.call "  → Veja acima qual pré-requisito falhou (binário, idioma 'por' ou libs Python)."
        exit(1)
      end
    end
  end

  namespace :whatsapp do
    # Simula o RECEBIMENTO de uma mensagem e roda o pipeline in-process (sem Meta
    # nem OCR reais). Params via ENV:
    #   FROM=5511999    remetente (deve casar com Workspace#whatsapp_number; sem
    #                   FROM usa/cria um workspace "Aionis Sandbox")
    #   TYPE=image      image | document | text            (default: image)
    #   TEXT="oi"       corpo, quando TYPE=text
    #   OCR_TEXT="..."  texto que o OCR "leria" (image/document; tem default)
    #   OCR_CONF=95     confiança do OCR 0–100             (default: 95)
    # Ex. (PowerShell):  $env:TYPE="text"; $env:TEXT="oi"; bin/rails aionis:whatsapp:simulate
    desc "Simula recebimento de WhatsApp e roda o pipeline in-process (sem Meta/OCR reais)"
    task simulate: :environment do
      Aionis::WhatsappSimulator.new.run_in_process
    end

    # Posta um payload REAL de webhook, assinado (HMAC), no controller de verdade.
    # Testa controller + verificação de assinatura + enfileiramento. Params via ENV:
    #   URL=http://localhost:3000/webhooks/whatsapp/meta   (default)
    #   FROM / TYPE / TEXT  (idem acima; TYPE=text é o mais seguro — sem download)
    # Requer o servidor rodando + META_APP_SECRET definido. Para mídia é preciso
    # credenciais reais da Meta (o download acontece no job).
    desc "Envia um POST assinado (HMAC) ao webhook real (requer servidor + META_APP_SECRET)"
    task simulate_http: :environment do
      Aionis::WhatsappSimulator.new.run_http
    end

    # Apaga o workspace "Aionis Sandbox" e tudo que a simulação gerou. Seguro:
    # só remove a identidade fixa do sandbox, nunca dados reais.
    desc "Remove o workspace sandbox e os registros gerados pela simulação"
    task reset_sandbox: :environment do
      Aionis::WhatsappSimulator.new.reset_sandbox
    end
  end
end

module Aionis
  # Coletor simples de checagens com saída colorida e resumo final.
  class Doctor
    PASS = "\e[32m✓\e[0m"
    WARN = "\e[33m!\e[0m"
    FAIL = "\e[31m✗\e[0m"

    def initialize
      @rows = []
    end

    def run
      section("Banco de dados") { check_database }
      section("Integração: WhatsApp") { check_whatsapp }
      section("Integração: IA (fallback)") { check_ai }
      section("Integração: OCR") { check_ocr }
      section("Criptografia (tokens em repouso)") { check_encryption }
      summary
    end

    def failed? = @rows.any? { |r| r[:level] == :fail }

    private

    # --- Checagens ---------------------------------------------------------

    def check_database
      ActiveRecord::Base.connection.execute("SELECT 1")
      pass "Conexão com o PostgreSQL"

      migrated?  ? pass("Schema migrado")
                 : fail_("Há migrations pendentes — rode bin/rails db:migrate")

      plans = safe_count(Plan)
      cats  = safe_count { Category.where(workspace_id: nil) }
      plans.positive? ? pass("Planos semeados (#{plans})")
                      : warn("Nenhum plano — rode bin/rails db:seed")
      cats.positive? ? pass("Categorias globais semeadas (#{cats})")
                     : warn("Nenhuma categoria global — rode bin/rails db:seed")
    rescue => e
      fail_ "Banco indisponível: #{e.message.lines.first&.strip}"
    end

    def check_whatsapp
      if Aionis::Integrations.whatsapp_dry_run?
        warn("Envio em DRY-RUN (WHATSAPP_DRY_RUN): respostas são logadas, não vão à Meta. Recebimento é real.")
      else
        pass("Envio real (dry-run desligado)")
      end

      key = active_key(:whatsapp)
      report_provider(:whatsapp, key)
      return warn("Provedor 'null': WhatsApp desligado (app sobe, mas não recebe mensagens)") if key == "null"

      if key == "meta_cloud"
        env_present("META_APP_SECRET",      "valida a assinatura HMAC dos webhooks (obrigatório)")
        env_present("META_PHONE_NUMBER_ID", "número global de envio (obrigatório p/ responder)")
        env_present("META_ACCESS_TOKEN",    "token de envio à Graph API (obrigatório p/ responder)")
        env_present("META_VERIFY_TOKEN",    "handshake de verificação do webhook (obrigatório)")
        env_present("META_GRAPH_VERSION",   "versão do Graph", optional: true)
        configured?(:whatsapp) ? pass("Provider reporta configured? = true")
                               : fail_("configured? = false — webhook vai recusar eventos (401)")
      elsif key == "evolution"
        env_present("EVOLUTION_BASE_URL", "URL da instância Evolution")
        env_present("EVOLUTION_API_KEY",  "chave da API Evolution")
      end
    end

    def check_ai
      key = active_key(:ai)
      report_provider(:ai, key)
      return warn("Provedor 'null': agente classifica só por regras/histórico (sem IA)") if key == "null"

      env_present("AI_API_KEY", "chave da Anthropic (obrigatório)")
      env_present("AI_MODEL", "modelo do Claude", optional: true)
      configured?(:ai) ? pass("Provider reporta configured? = true")
                       : fail_("configured? = false — AI_API_KEY ausente, fallback de IA não roda")
    end

    def check_ocr
      key = active_key(:ocr)
      report_provider(:ocr, key)
      return warn("Provedor 'null': fotos/PDFs escaneados NÃO são lidos (XML e PDF-texto ainda funcionam)") if key == "null"

      # OCR_WORKER_PATH é opcional: vazio usa script/ocr/tesseract_worker.py.
      # O sinal real de "pronto" é configured? (o arquivo do worker existe).
      configured?(:ocr) ? pass("Worker Python encontrado (configured? = true)")
                        : fail_("Worker do OCR não encontrado — cheque OCR_WORKER_PATH ou script/ocr/tesseract_worker.py")

      env_present("OCR_PYTHON_BIN", "binário do Python (no Windows costuma ser 'python', não 'python3')", optional: true)

      # No Windows o tesseract.exe raramente está no PATH do processo Rails.
      cmd = ENV["TESSERACT_CMD"].to_s
      if cmd.present?
        File.exist?(cmd) ? pass("TESSERACT_CMD aponta um binário existente")
                         : fail_("TESSERACT_CMD definido mas o arquivo não existe: #{cmd}")
      else
        warn("TESSERACT_CMD não definido — depende do tesseract estar no PATH (no Windows normalmente não está)")
      end
      warn("TESSDATA_PREFIX não definido — idiomas extras (ex.: por) podem não ser encontrados") if ENV["TESSDATA_PREFIX"].blank?
    end

    def check_encryption
      %w[AR_ENCRYPTION_PRIMARY_KEY AR_ENCRYPTION_DETERMINISTIC_KEY AR_ENCRYPTION_KEY_DERIVATION_SALT].each do |var|
        if ENV[var].present?
          pass "#{var} definida por ENV"
        elsif Rails.env.production?
          fail_ "#{var} ausente — OBRIGATÓRIA em produção (bin/rails db:encryption:init)"
        else
          warn "#{var} usando default de dev (OK em dev; defina em produção)"
        end
      end
    end

    # true se não há migrations pendentes. API mudou entre versões do Rails;
    # usamos check_all_pending! (levanta ActiveRecord::PendingMigrationError).
    def migrated?
      ActiveRecord::Migration.check_all_pending!
      true
    rescue ActiveRecord::PendingMigrationError
      false
    end

    # --- Helpers -----------------------------------------------------------

    def report_provider(type, key)
      key == "null" ? nil : pass("Provedor ativo: #{key}")
    end

    def active_key(type) = Aionis::Integrations.active_provider_key(type)
    def configured?(type) = Aionis::Integrations.configured?(type)

    def env_present(var, desc, optional: false)
      if ENV[var].present?
        pass "#{var} presente"
      elsif optional
        warn "#{var} ausente (opcional — #{desc})"
      else
        fail_ "#{var} AUSENTE — #{desc}"
      end
    end

    def safe_count(model = nil)
      (block_given? ? yield : model).count
    rescue
      0
    end

    def section(title)
      puts "\n\e[1m#{title}\e[0m"
      yield
    rescue => e
      fail_ "erro inesperado: #{e.message.lines.first&.strip}"
    end

    def pass(msg)  = record(:pass, PASS, msg)
    def warn(msg)  = record(:warn, WARN, msg)
    def fail_(msg) = record(:fail, FAIL, msg)

    def record(level, glyph, msg)
      @rows << { level: level, msg: msg }
      puts "  #{glyph} #{msg}"
    end

    def summary
      f = @rows.count { |r| r[:level] == :fail }
      w = @rows.count { |r| r[:level] == :warn }
      p = @rows.count { |r| r[:level] == :pass }
      puts "\n\e[1mResumo:\e[0m #{PASS} #{p}  #{WARN} #{w}  #{FAIL} #{f}"
      if f.positive?
        puts "\e[31mHá itens obrigatórios faltando — corrija antes de usar as integrações.\e[0m"
      elsif w.positive?
        puts "\e[33mApp funcional; avisos indicam integrações desligadas por opção.\e[0m"
      else
        puts "\e[32mTudo configurado. \e[0m"
      end
    end
  end

  # Simulador de webhook de WhatsApp para desenvolvimento. Constrói um payload
  # REAL da Meta e o injeta no pipeline — in-process (com providers fake, sem
  # rede) ou via HTTP assinado no controller real. Não é autoloaded (fica em
  # lib/tasks); usado só pelas rake tasks aionis:whatsapp:*.
  class WhatsappSimulator
    require "net/http"
    require "openssl"
    require "json"

    MIME = { "image" => "image/jpeg", "document" => "application/pdf" }.freeze
    DEFAULT_OCR = "MERCADO SIMULADO LTDA\nCNPJ 11.222.333/0001-81\nData 21/07/2026\nTOTAL R$ 87,90"

    # Identidade fixa do sandbox (compartilhada por criação e limpeza).
    SANDBOX_NUMBER = "5511900000000"
    SANDBOX_EMAIL  = "sandbox@aionis.local"
    SANDBOX_NAME   = "Aionis Sandbox"

    def initialize
      @from     = ENV["FROM"].to_s.gsub(/\D/, "").presence
      @type     = (ENV["TYPE"].presence || "image").downcase
      @text     = ENV["TEXT"].presence || "Olá, segue meu comprovante"
      @ocr_text = ENV["OCR_TEXT"].presence || DEFAULT_OCR
      @ocr_conf = (ENV["OCR_CONF"].presence || "95").to_i
      abort_with("TYPE inválido: #{@type} (use image, document ou text)") unless %w[image document text].include?(@type)
    end

    # --- Modo 1: pipeline in-process (sem Meta/OCR reais) ------------------

    def run_in_process
      workspace = resolve_or_create_workspace
      payload   = build_payload(workspace.whatsapp_number)
      say "→ Simulando #{@type} de #{workspace.whatsapp_number} para o workspace ##{workspace.id} (#{workspace.name})"

      incoming = with_fakes { with_inline_jobs { Aionis::Whatsapp::InboundProcessor.call(provider: "meta_cloud", payload: payload) } }
      report(incoming)
    ensure
      Aionis::Integrations.reset!
    end

    # --- Modo 2: POST assinado no webhook real ----------------------------

    def run_http
      secret = ENV["META_APP_SECRET"].to_s
      abort_with("META_APP_SECRET ausente — necessário para assinar o webhook (HMAC).") if secret.blank?

      url     = ENV["URL"].presence || "http://localhost:3000/webhooks/whatsapp/meta"
      number  = @from || "5511900000000"
      raw     = JSON.generate(build_payload(number))
      sig     = "sha256=" + OpenSSL::HMAC.hexdigest("SHA256", secret, raw)

      say "→ POST #{url}  (#{@type}, from=#{number})"
      code, body = post(url, raw, sig)
      say "← HTTP #{code} #{body.to_s.truncate(120)}"
      if code == 200
        say "OK: o webhook aceitou e enfileirou. Veja o processamento nos logs do servidor / no dashboard."
        say "Dica: o worker de jobs precisa estar rodando (bin/jobs) para o pipeline seguir." if @type != "text"
      else
        say "Falhou. Cheque: servidor no ar, META_APP_SECRET igual ao do app, e WHATSAPP_PROVIDER=meta_cloud."
      end
    end

    # --- Limpeza do sandbox -----------------------------------------------

    # Remove o workspace de simulação e TUDO que ele gerou (documentos, mensagens,
    # lançamentos… via dependent: :destroy) — e o usuário sandbox, se ele não for
    # dono de nenhum outro workspace. Só mexe na identidade fixa do sandbox:
    # nunca toca em dados reais (exige o número E o nome do sandbox).
    def reset_sandbox
      workspace = Workspace.find_by(whatsapp_number: SANDBOX_NUMBER, name: SANDBOX_NAME)
      user      = User.find_by(email: SANDBOX_EMAIL)

      if workspace.nil? && user.nil?
        say "Nada para limpar: o sandbox não existe."
        return
      end

      if workspace
        counts = sandbox_counts(workspace)
        workspace.destroy!
        say "Workspace sandbox ##{workspace.id} removido — #{counts}."
      end

      if user && Workspace.where(owner_id: user.id).none?
        user.destroy!
        say "Usuário sandbox (#{SANDBOX_EMAIL}) removido."
      elsif user
        say "Usuário sandbox mantido (ainda é dono de outro workspace)."
      end
    end

    private

    def sandbox_counts(workspace)
      [
        ["documentos",  workspace.documents.count],
        ["mensagens",   workspace.incoming_messages.count + workspace.outgoing_messages.count],
        ["lançamentos", workspace.financial_transactions.count]
      ].map { |label, n| "#{n} #{label}" }.join(", ")
    end

    # --- Workspace --------------------------------------------------------

    def resolve_or_create_workspace
      if @from
        Workspace.find_by(whatsapp_number: @from) ||
          abort_with("Nenhum workspace com whatsapp_number=#{@from}. Cadastre-o ou rode sem FROM para usar o sandbox.")
      else
        sandbox_workspace
      end
    end

    def sandbox_workspace
      user = User.find_or_create_by!(email: SANDBOX_EMAIL) do |u|
        u.name = SANDBOX_NAME
        u.password = SecureRandom.hex(16)
      end
      Workspace.find_or_create_by!(whatsapp_number: SANDBOX_NUMBER) do |w|
        w.name  = SANDBOX_NAME
        w.kind  = "empresa"
        w.owner = user
      end
    end

    # --- Payload real da Meta ---------------------------------------------

    def build_payload(from)
      message = { "from" => from, "id" => "wamid.SIM-#{SecureRandom.hex(8)}",
                  "timestamp" => Time.current.to_i.to_s, "type" => @type }
      message.merge!(message_fragment)

      {
        "object" => "whatsapp_business_account",
        "entry"  => [{
          "id"      => "WABA_SIM",
          "changes" => [{
            "field" => "messages",
            "value" => {
              "messaging_product" => "whatsapp",
              "metadata" => { "display_phone_number" => "5511999999999", "phone_number_id" => "PN_SIM" },
              "contacts" => [{ "profile" => { "name" => "Cliente Simulado" }, "wa_id" => from }],
              "messages" => [message]
            }
          }]
        }]
      }
    end

    def message_fragment
      case @type
      when "text"
        { "text" => { "body" => @text } }
      when "image"
        { "image" => { "id" => "media-#{SecureRandom.hex(6)}", "mime_type" => MIME["image"] } }
      when "document"
        { "document" => { "id" => "media-#{SecureRandom.hex(6)}", "mime_type" => MIME["document"],
                          "filename" => "comprovante.pdf" } }
      end
    end

    # --- Injeção de fakes (sem rede) --------------------------------------

    def with_fakes
      Aionis::Integrations.override(:whatsapp, FakeWhatsapp.new)
      Aionis::Integrations.override(:ocr, FakeOcr.new(@ocr_text, @ocr_conf))
      yield
    end

    def with_inline_jobs
      original = ActiveJob::Base.queue_adapter
      ActiveJob::Base.queue_adapter = :inline
      yield
    ensure
      ActiveJob::Base.queue_adapter = original
    end

    # --- HTTP -------------------------------------------------------------

    def post(url, body, signature)
      uri = URI(url)
      req = Net::HTTP::Post.new(uri)
      req["Content-Type"] = "application/json"
      req["X-Hub-Signature-256"] = signature
      req.body = body
      res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 10) { |h| h.request(req) }
      [res.code.to_i, res.body]
    rescue => e
      abort_with("Não consegui conectar em #{url}: #{utf8(e.message)}. O servidor está rodando?")
    end

    # --- Relatório --------------------------------------------------------

    def report(incoming)
      return say("Nada foi criado (remetente não reconhecido?).") if incoming.nil?

      incoming = incoming.reload
      say "\n=== Resultado ==="
      say "IncomingMessage ##{incoming.id}: kind=#{incoming.kind} status=#{incoming.status}"

      if (doc = incoming.document)
        ext = doc.document_extractions.last
        say "Document ##{doc.id}: source=#{doc.source} status=#{doc.status}" \
            "#{" · extração conf=#{ext.confidence_score}" if ext}"
      end

      # Estritamente o lançamento gerado por ESTE documento (evita pegar de runs anteriores).
      tx = incoming.document_id && FinancialTransaction.where(document_id: incoming.document_id).order(:id).last
      if tx
        say "FinancialTransaction ##{tx.id}: #{tx.description} · #{brl(tx.amount_cents)} · status=#{tx.status}" \
            "#{" · #{tx.category&.name}" if tx.category}"
      else
        say "FinancialTransaction: nenhum (mensagem de texto ou confiança baixa)."
      end

      if (out = OutgoingMessage.where(incoming_message_id: incoming.id).order(:id).last)
        say "Resposta (OutgoingMessage ##{out.id}, status=#{out.status}):"
        say "  \e[36m#{out.body}\e[0m"
      end
    end

    # --- Helpers ----------------------------------------------------------

    def brl(cents) = format("R$ %.2f", cents.to_i / 100.0).sub(".", ",")
    def say(msg)   = puts(msg)
    # Mensagens do SO no Windows vêm em CP850; normaliza p/ UTF-8 sem quebrar.
    def utf8(str)  = str.to_s.dup.force_encoding("UTF-8").scrub("?")
    def abort_with(msg)
      warn "\e[31m#{msg}\e[0m"
      exit(1)
    end

    # Provider WhatsApp fake: parse REAL (delega ao MetaCloudProvider, sem creds),
    # download/mark_as_read/send sem rede. Envio devolve provider "dry_run".
    class FakeWhatsapp
      def configured? = true

      def parse_inbound(payload)
        Aionis::Integrations::Whatsapp::MetaCloudProvider.new.parse_inbound(payload)
      end

      def download_media(media, instance: nil, credentials: nil)
        mime = (media.to_h["mimetype"] || media.to_h["mime_type"] || "image/jpeg").to_s
        Aionis::Integrations::Result.ok(provider: "meta_cloud", data: {
          "bytes" => "SIMULATED-BYTES", "mimetype" => mime,
          "filename" => "simulado#{mime == 'application/pdf' ? '.pdf' : '.jpg'}", "url" => "http://sim/local"
        })
      end

      def send_text(to:, body:, instance: nil, credentials: nil)
        Rails.logger.info("[WHATSAPP_SIMULATE] resposta suprimida — to=#{to} body=#{body.to_s.truncate(160)}")
        Aionis::Integrations::Result.ok(provider: "dry_run", data: { "message_id" => "sim-#{SecureRandom.hex(4)}" })
      end

      def mark_as_read(message_id:, instance: nil, credentials: nil)
        Aionis::Integrations::Result.ok(provider: "meta_cloud", data: {})
      end
    end

    # OCR fake: devolve o texto/confiança pedidos, sem worker Python.
    class FakeOcr
      def initialize(text, confidence)
        @text = text
        @confidence = confidence
      end

      def extract(io:, content_type:, filename: nil)
        Aionis::Integrations::Result.ok(provider: "tesseract", data: {
          "text" => @text, "confidence" => @confidence, "pages" => 1, "words" => @text.split.size
        })
      end
    end
  end
end
