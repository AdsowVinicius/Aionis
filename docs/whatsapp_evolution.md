# Integração WhatsApp via Evolution API

O Aionis recebe comprovantes por WhatsApp usando a [Evolution API](https://github.com/EvolutionAPI/evolution-api)
(self-hosted, não oficial). Toda a comunicação passa pela **Integration Layer** —
nenhum outro ponto do app conhece a Evolution diretamente.

```
WhatsApp → Evolution → Webhook → Documento → Pipeline → OCR → Rule Engine → FinancialTransaction
```

## Isolamento (regra de arquitetura)

O app só fala com `Aionis::Integrations.whatsapp`, que resolve o provedor ativo:

```
Aionis::Integrations.whatsapp   # WhatsappProvider (contrato)
        ↓ (config/ENV)
EvolutionProvider               # única classe que conhece a Evolution
```

Trocar de provedor = mudar `WHATSAPP_PROVIDER` + `providers:` em
`config/aionis/integrations.yml`. O restante do código não muda.

## Configuração

Variáveis de ambiente (segredos **nunca** no código):

| ENV | Descrição |
|-----|-----------|
| `WHATSAPP_PROVIDER` | `evolution` para ativar (default `null` = desligado) |
| `EVOLUTION_BASE_URL` | URL da instância Evolution (ex.: `https://evo.seudominio.com`) |
| `EVOLUTION_API_KEY` | API key global da Evolution (header `apikey`) |
| `EVOLUTION_INSTANCE` | instância padrão (fallback) |
| `EVOLUTION_WEBHOOK_TOKEN` | token que valida os webhooks recebidos |
| `EVOLUTION_TIMEOUT` | timeout HTTP em segundos (default 15) |

Cada linha de WhatsApp é um `WorkspaceChannel` (mapeia `instance` → `workspace`).

## Webhook

Configure na Evolution o webhook para o evento `messages.upsert` apontando para:

```
POST https://SEU_APP/webhooks/whatsapp/:instance
Header: apikey: <EVOLUTION_WEBHOOK_TOKEN>
```

O controller (`Webhooks::WhatsappController`, isolado, sem Devise/CSRF):
1. valida o token (comparação constante-time);
2. enfileira `Aionis::Whatsapp::InboundJob`;
3. responde `200` imediatamente (o provedor reenvia em timeout).

## Fluxo de recebimento

`Aionis::Whatsapp::InboundProcessor` (no job):

1. `parse_inbound` normaliza o payload (texto/imagem/documento).
2. acha o `WorkspaceChannel` pela `instance`.
3. registra `IncomingMessage` (dedup por `[canal, wa_message_id]`).
4. se mídia: `download_media` → cria `Document` (`source: whatsapp`) →
   `DocumentExtractionService` (OCR → Normalizer → Rule Engine).
5. **confirmação automática** por confiança:
   - **≥ 86**: cria `FinancialTransaction` confirmada e responde ✅;
   - **61–85**: cria lançamento pendente e pede confirmação no app;
   - **< 61**: não lança e pede reenvio de foto mais nítida.
6. responde ao usuário via `OutgoingMessage` → `SendMessageJob`.

## Envio e retries

`Aionis::Whatsapp::SendMessageJob` envia via `Integrations.whatsapp.send_text`
com `retry_on DeliveryError` (3 tentativas, backoff). `OutgoingMessage` guarda
`status` (pending/sent/failed), `attempts` e `provider_message_id`.

## Auditoria

Cada evento importante gera `AuditLog` com `action: "integration"`,
`origin: "integration"` e `provider` do canal (recebimento, envio, confirmação).

## Testes sem Evolution

O `EvolutionProvider` aceita um cliente HTTP injetável (`settings[:http]`), e a
Integration Layer permite `Aionis::Integrations.override(:whatsapp, fake)`. Assim
toda a suíte roda sem rede nem Evolution instalada. Com `WHATSAPP_PROVIDER=null`
(default) o recebimento é ignorado com segurança.
