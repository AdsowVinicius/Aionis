# WhatsApp oficial — Meta Cloud API

O Aionis recebe comprovantes por WhatsApp usando a **Meta WhatsApp Cloud API**
(oficial). Toda a comunicação passa pela Integration Layer — nenhum controller,
model ou service conhece a Meta diretamente.

O Aionis tem **um único número** (global, em ENV). Quem escreve para ele é
identificado pelo **número de quem envia**:

```
Usuário → WhatsApp → Meta Cloud API → Webhook → WhatsappController
  → Aionis::Integrations.whatsapp(provider:) → MetaCloudProvider
  → InboundJob → InboundProcessor → acha o Workspace pelo remetente
      ├─ FOTO/PDF → DownloadMediaJob → ProcessDocumentJob → DocumentExtractionService
      │             → OCR / XML → Normalizer → Rule Engine → Rule Learner → IA (fallback)
      │             → AutoConfirmJob → FinancialTransaction
      └─ TEXTO    → Agent::WhatsappReplyJob → Agent::Conversation (tool calling)
                    → tools consultam/gravam no BD (sempre escopadas no workspace)
  → Responder → SendMessageJob → resposta no WhatsApp
```

## Arquitetura

- **Único ponto de contato externo:** `Aionis::Integrations.whatsapp(provider:)`.
  `provider:` escolhe o provedor por canal (`meta_cloud`, `evolution`…), sem que
  o app conheça a implementação. Adicionar Twilio/outro = criar a classe e
  registrar em `config/aionis/integrations.yml`.
- **Provider:** `MetaCloudProvider < Whatsapp::Base` implementa `send_text`,
  `send_template`, `send_document`, `send_image`, `send_audio`, `mark_as_read`,
  `parse_inbound`, `download_media`, `verify_webhook`, `verify_signature`.
- **Número único/global:** as credenciais da Meta (`META_PHONE_NUMBER_ID`,
  `META_ACCESS_TOKEN`, `META_APP_SECRET`, `META_VERIFY_TOKEN`) vêm **de ENV**,
  não do workspace. O cliente cadastra o **próprio** número em
  `Workspace#whatsapp_number` (tela *Canais → WhatsApp* do portal), e é assim
  que o `InboundProcessor` sabe de quem é a mensagem. Remetente não cadastrado
  é ignorado (aparece no log como `remetente não cadastrado: …`).
- **`WorkspaceChannel`** virou só registro de status por workspace, provisionado
  sob demanda por `WorkspaceChannel.provision`.
- **9º dígito (Brasil):** a Meta entrega o `wa_id` de celulares brasileiros ora
  com, ora sem o "9" (`5511925647469` vs `551125647469`). O roteamento aceita as
  duas formas — ver `Workspace.whatsapp_number_variants`. Sem isso o bot ignora
  o cliente em silêncio, que é a falha mais comum nesse ponto.

## O que o bot faz com uma mensagem de TEXTO

Texto vai para o **Agente Financeiro** (`Agent::Conversation`), o mesmo do portal.
A LLM nunca toca no banco nem gera SQL: ela só escolhe *tools*, que o backend
executa **sempre escopadas pelo workspace da sessão** (`Agent::Toolbox`):

`consultar_saldo` · `consultar_gastos` · `consultar_transacoes` · `consultar_contas`
· `consultar_kpis` · `registrar_lancamento` · `gerar_insight` · `ler_memoria` ·
`salvar_memoria`.

Toda tool executada gera `AuditLog` (`action: "ai"`). Se `AI_PROVIDER=null`, o
texto cai na resposta de ajuda padrão — o bot não fica mudo.

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

Não há credencial por workspace. O cliente só cadastra o **próprio número** em
**Canais → WhatsApp** no portal (`Workspace#whatsapp_number`); o canal de status
é provisionado sozinho na primeira mensagem.

`ChannelConnector` segue existindo como ferramenta de backend (para o cenário de
credencial por canal), mas a UI não o usa mais.

## ✅ Checklist para rodar 100% do lado da Meta

Do lado do app tudo já está implementado — o que falta é configuração. Ordem
recomendada; cada item tem como verificar.

### 1. App e número na Meta

- [ ] App **Business** criado em <https://developers.facebook.com> com o produto
      **WhatsApp** adicionado.
- [ ] Número registrado em **WhatsApp → API Setup** e **verificado** (SMS/voz).
- [ ] Copiar o **Phone number ID** (é um número longo, **não** é o telefone).
- [ ] Enquanto usar o número de teste da Meta (remetente EUA), adicionar o seu
      número em **"To"/destinatários permitidos** (máx. 5). Com número próprio
      verificado isso não é necessário.

### 2. Token de acesso

- [ ] **Teste:** token temporário da tela API Setup (expira em 24h).
- [ ] **Produção:** *Business Settings → Usuários do sistema* → token permanente
      com `whatsapp_business_messaging` + `whatsapp_business_management`.

> Token temporário expirando é a causa nº 1 de "parou de responder do nada".

### 3. ENVs no Railway

```
WHATSAPP_PROVIDER=meta_cloud
META_PHONE_NUMBER_ID=<Phone number ID da API Setup>
META_ACCESS_TOKEN=<token permanente>
META_APP_SECRET=<App > Configurações > Básico > Chave Secreta>
META_VERIFY_TOKEN=<string que VOCÊ inventa; repita no painel da Meta>
META_GRAPH_VERSION=v21.0
WHATSAPP_DRY_RUN=false
AR_ENCRYPTION_PRIMARY_KEY=...        # gere com bin/rails db:encryption:init
AR_ENCRYPTION_DETERMINISTIC_KEY=...
AR_ENCRYPTION_KEY_DERIVATION_SALT=...
AI_PROVIDER=groq|anthropic           # sem isso o texto só recebe a msg de ajuda
AI_API_KEY=...
OCR_PROVIDER=tesseract               # sem isso foto/PDF não viram lançamento
```

- [ ] `WHATSAPP_DRY_RUN=false` — com `true` o app **não envia nada**, só loga e
      marca a `OutgoingMessage` como `dry_run`.
- [ ] `AR_ENCRYPTION_*` definidas (obrigatórias em produção).

### 4. Webhook

- [ ] **WhatsApp → Configuration → Webhook**
      Callback URL: `https://SEU_APP/webhooks/whatsapp/meta`
      Verify token: o mesmo valor de `META_VERIFY_TOKEN`
- [ ] Assinar o campo **`messages`** (sem isso nada chega).
- [ ] Clicar em **Verify and save** — se der erro, o `META_VERIFY_TOKEN` não bate
      ou o app não está no ar.

### 5. Cadastro do usuário no Aionis

- [ ] Logar no portal → **Canais → WhatsApp** → salvar o **seu número pessoal**
      (o que vai conversar com o bot), com DDI: `+55 11 9xxxx-xxxx`.
- [ ] Confirmar que ele é diferente do número do Aionis — o bot não conversa
      consigo mesmo.

### 6. Verificação

```bash
railway run bin/rails aionis:doctor          # confere ENVs e integrações
railway run bin/rails aionis:ai:selftest     # IA + tool calling ponta a ponta
railway run bin/rails aionis:ocr:selftest    # OCR ponta a ponta
```

- [ ] Mandar **"quanto eu gastei esse mês?"** para o número do Aionis → deve
      responder com dados do seu workspace.
- [ ] Mandar **foto de um comprovante** → deve virar lançamento.

### Diagnóstico rápido quando não responde

| Sintoma | Causa provável |
|---|---|
| Log `remetente não cadastrado: 55…` | número não salvo em `Workspace#whatsapp_number` |
| Nada chega no log | webhook sem o campo `messages`, ou URL/verify token errados |
| `401` no webhook | `META_APP_SECRET` errado (assinatura HMAC não bate) |
| `OutgoingMessage` fica `dry_run` | `WHATSAPP_DRY_RUN` não está `false` |
| Erro `130497` no envio | remetente EUA → destinatário BR (número de teste da Meta) |
| Responde só "Envie a foto ou o PDF…" | `AI_PROVIDER` não configurado (agente desligado) |
| Foto chega mas não vira lançamento | `OCR_PROVIDER` não é `tesseract` |

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
