# Camada de Integração (Integration Layer)

Provedores externos plugáveis para **WhatsApp**, **Open Finance**, **OCR** e **IA**.

> Nesta etapa **nenhuma chamada externa está implementada**. Todos os tipos usam
> o provedor `null` (stub seguro). A arquitetura permite ligar um provedor real
> depois **sem alterar o restante da aplicação**.

## Princípio

O app consome apenas a *facade* e o *contrato* de cada domínio. Ele nunca
referencia uma implementação concreta. Trocar de provedor é mudar config/ENV.

```
Consumidor  ──►  Aionis::Integrations.ocr  ──►  Registry  ──►  Provider (Base → Null/Concreto)
   (app)              (facade / DI)          (config+ENV)         (implementação)
```

## Uso

```ruby
Aionis::Integrations.ocr.extract(io: file, content_type: "image/jpeg")
Aionis::Integrations.ai.classify(context: { description:, amount_cents: })
Aionis::Integrations.whatsapp.send_text(to: "5511...", body: "Olá")
Aionis::Integrations.open_finance.fetch_accounts(consent_id: "c1")

Aionis::Integrations.configured?(:ai)          # => false (provedor null)
Aionis::Integrations.active_provider_key(:ocr) # => "null"
```

Todo método retorna um `Aionis::Integrations::Result` com interface estável:

```ruby
result.success?      # concluído com dados
result.unavailable?  # provedor null / não configurado
result.pending?      # aceito, processando de forma assíncrona
result.data          # Hash normalizado
result.message       # texto explicativo
result.provider      # "null", "meta_cloud", ...
```

Com o provedor `null`, toda chamada retorna `success? == false` e
`unavailable? == true` — o app degrada com segurança (ex.: documento continua
em revisão manual; classificação segue só com regras + histórico).

## Injeção de dependência (testes / feature flags)

```ruby
Aionis::Integrations.override(:ocr, FakeOcr.new)      # troca global
Aionis::Integrations.with(ai: FakeAi.new) { ... }     # troca só no bloco
Aionis::Integrations.reset!                           # limpa overrides
```

Em testes, prefira um `Registry` isolado para não vazar estado:

```ruby
Aionis::Integrations.registry = Aionis::Integrations::Registry.new({})
```

## Configuração

`config/aionis/integrations.yml` (ERB + ENV, por ambiente). **Segredos só via ENV.**

```yaml
ocr:
  provider: "<%= ENV.fetch('OCR_PROVIDER', 'null') %>"
  providers:
    # tesseract: "Aionis::Integrations::Ocr::TesseractProvider"
  settings:
    endpoint: "<%= ENV['OCR_ENDPOINT'] %>"
```

### Variáveis de ambiente reconhecidas

| Tipo         | Seletor de provedor      | Credenciais / settings |
|--------------|--------------------------|------------------------|
| WhatsApp     | `WHATSAPP_PROVIDER`      | `WHATSAPP_PHONE_NUMBER_ID`, `WHATSAPP_ACCESS_TOKEN`, `WHATSAPP_VERIFY_TOKEN` |
| Open Finance | `OPEN_FINANCE_PROVIDER`  | `OPEN_FINANCE_CLIENT_ID`, `OPEN_FINANCE_CLIENT_SECRET` |
| OCR          | `OCR_PROVIDER`           | `OCR_ENDPOINT`, `OCR_TIMEOUT` |
| IA           | `AI_PROVIDER`            | `AI_API_KEY`, `AI_MODEL` |

Ausentes ⇒ provedor `null`.

## Como adicionar um provedor real (futuro)

1. Crie a classe herdando do contrato do domínio e implemente os métodos:

   ```ruby
   # app/services/aionis/integrations/ocr/tesseract_provider.rb
   module Aionis::Integrations::Ocr
     class TesseractProvider < Base
       def configured? = settings[:endpoint].present?

       def extract(io:, content_type:, filename: nil)
         # ... chamada ao worker Python/Tesseract ...
         Result.ok(provider: provider_key, data: { text:, confidence: })
       end
     end
   end
   ```

2. Registre em `integrations.yml` (`providers:`) e selecione via `provider:`/ENV.
3. Preencha as credenciais em `settings:` por ENV.
4. Pronto — **nenhum consumidor muda**.

## Consumidores previstos

| Integração   | Consumidor no app                                   |
|--------------|-----------------------------------------------------|
| OCR          | `ProcessDocumentJob` (PDF escaneado / imagem)       |
| IA           | `Aionis::ClassificationEngine` (fallback de revisão)|
| WhatsApp     | recebimento/envio de documentos e alertas           |
| Open Finance | conciliação bancária (pós-MVP)                      |

## Arquivos

```
app/services/aionis/integrations.rb                # facade + DI
app/services/aionis/integrations/
  registry.rb          # fábrica: resolve provedor por config/ENV, memoiza, override
  base_provider.rb     # comportamento comum (settings, configured?, unavailable)
  result.rb            # valor de retorno unificado
  errors.rb            # erros da camada
  whatsapp/{base,null_provider}.rb
  open_finance/{base,null_provider}.rb
  ocr/{base,null_provider}.rb
  ai/{base,null_provider}.rb
config/aionis/integrations.yml                     # configuração (ERB+ENV)
config/initializers/aionis_integrations.rb         # valida provedores em produção
```
