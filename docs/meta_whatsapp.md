# WhatsApp oficial — Meta Cloud API

O Aionis recebe comprovantes por WhatsApp usando a **Meta WhatsApp Cloud API**
(oficial). Toda a comunicação passa pela Integration Layer — nenhum controller,
model ou service conhece a Meta diretamente.

```
Usuário → WhatsApp → Meta Cloud API → Webhook → WhatsappController
  → Aionis::Integrations.whatsapp(provider:) → MetaCloudProvider
  → InboundJob → DownloadMediaJob → ProcessDocumentJob → DocumentExtractionService
  → OCR / XML Parser → Normalizer → Rule Engine → Rule Learner → IA (fallback)
  → FinancialTransaction → SendMessageJob → Dashboard
```

## Arquitetura

- **Único ponto de contato externo:** `Aionis::Integrations.whatsapp(provider:)`.
  `provider:` escolhe o provedor por canal (`meta_cloud`, `evolution`…), sem que
  o app conheça a implementação. Adicionar Twilio/outro = criar a classe e
  registrar em `config/aionis/integrations.yml`.
- **Provider:** `MetaCloudProvider < Whatsapp::Base` implementa `send_text`,
  `send_template`, `send_document`, `send_image`, `send_audio`, `mark_as_read`,
  `parse_inbound`, `download_media`, `verify_webhook`, `verify_signature`.
- **Multi-tenant:** cada workspace conecta seu próprio WhatsApp Business. As
  credenciais do workspace (access_token, phone_number_id) ficam no
  `WorkspaceChannel` e são passadas **por chamada** ao provider (`credentials:`).

## Pipeline (100% assíncrono)

O webhook **apenas valida, responde 200 e enfileira** — nunca baixa mídia nem
roda OCR na requisição:

1. `WhatsappController#receive` — valida assinatura HMAC (`X-Hub-Signature-256`)
   e enfileira `InboundJob`.
2. `InboundJob` → `InboundProcessor` — normaliza, acha o canal, persiste a
   `IncomingMessage` (idempotência por `wa_message_id`) e enfileira o próximo passo.
3. `DownloadMediaJob` — baixa a mídia (2 etapas na Graph API), anexa ao
   `Document` (ActiveStorage), `mark_as_read`, e enfileira `ProcessDocumentJob`.
4. `ProcessDocumentJob` → `DocumentExtractionService` — OCR / XML → Normalizer →
   Rule Engine → Rule Learner → IA (só fallback).
5. `AutoConfirmJob` — cria a `FinancialTransaction` conforme a confiança
   (≥86 confirma, 61–85 pendente, <61 pede reenvio) e responde via `SendMessageJob`.

**Status de entrega** (sent/delivered/read/failed) chegam como callbacks e
atualizam a `OutgoingMessage` (`StatusUpdater`). Envio tem **backoff exponencial**
e trata **rate limit** (429/5xx viram falha transitória → novo retry).

## Segurança (segredos só em ENV)

Segredos de **app** (compartilhados) ficam em ENV; segredos **por workspace**
ficam criptografados no banco (`encrypts`), com as chaves de criptografia em ENV.

| ENV | Uso |
|-----|-----|
| `WHATSAPP_PROVIDER=meta_cloud` | ativa o provedor padrão (canais podem sobrepor) |
| `META_APP_SECRET` | valida a assinatura HMAC dos webhooks |
| `META_VERIFY_TOKEN` | handshake de verificação (GET) |
| `META_GRAPH_VERSION` | versão do Graph (ex.: `v21.0`) — **nunca hardcoded** |
| `AR_ENCRYPTION_PRIMARY_KEY` / `AR_ENCRYPTION_DETERMINISTIC_KEY` / `AR_ENCRYPTION_KEY_DERIVATION_SALT` | chaves p/ criptografar access_token/refresh_token (gere com `bin/rails db:encryption:init`) |

`access_token` e `refresh_token` (futuro) nunca ficam em código nem em texto claro.

## Como criar o App na Meta

1. https://developers.facebook.com → **Create App** → tipo **Business**.
2. Adicione o produto **WhatsApp**.
3. Em **WhatsApp → API Setup**, pegue o **Phone Number ID** e o **WhatsApp
   Business Account ID**.

## Como gerar o Token

- **Teste:** token temporário na tela API Setup.
- **Produção:** crie um **System User** (Business Settings), gere um token
  permanente com as permissões `whatsapp_business_messaging` e
  `whatsapp_business_management`. Esse é o `access_token` do canal.

## Como configurar o Webhook

1. Em **WhatsApp → Configuration → Webhook**, URL de callback:
   `https://SEU_APP/webhooks/whatsapp/meta`
2. **Verify token:** o valor de `META_VERIFY_TOKEN`. A Meta chama `GET` com
   `hub.challenge`; o Aionis ecoa o challenge se o token bater.
3. Assine o campo **messages**. Todo `POST` é validado por HMAC com `META_APP_SECRET`.

## Como conectar um Workspace

Via serviço (regra fora do controller):

```ruby
Aionis::Whatsapp::ChannelConnector.connect(
  workspace,
  provider: "meta_cloud",
  phone_number_id: "1234567890",
  business_account_id: "..",
  display_phone_number: "+55 11 99999-0000",
  access_token: "EAAG...",   # gravado criptografado
  verify_token: "meu_verify" # opcional (por canal)
)
```

Cada workspace tem seu Business Account, Phone Number, Webhook, Token e Status.

## Como trocar credenciais (rotação)

```ruby
Aionis::Whatsapp::ChannelConnector.new(workspace).rotate(channel, access_token: "novo", refresh_token: "novo_refresh")
```

Os segredos de app rotacionam via ENV (redeploy). O `refresh_token` já é
suportado e criptografado para compatibilidade futura.

## Como adicionar novos providers

1. Crie `Aionis::Integrations::Whatsapp::SeuProvider < Whatsapp::Base` e
   implemente o contrato.
2. Registre em `config/aionis/integrations.yml` (`providers:`).
3. Aponte o canal (`WorkspaceChannel#provider`) ou `WHATSAPP_PROVIDER`.
   Nada mais muda — o resto do app fala só com `Aionis::Integrations.whatsapp`.

## Testes sem a Meta

`MetaCloudProvider` aceita cliente HTTP injetável (`settings[:http]`) e a
Integration Layer permite `Aionis::Integrations.override(:whatsapp, fake)`. Com
`WHATSAPP_PROVIDER=null` (default) tudo fica desligado com segurança.
