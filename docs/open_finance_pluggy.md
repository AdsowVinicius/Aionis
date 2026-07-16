# Open Finance via Pluggy

O Aionis lê contas e transações bancárias por Open Finance usando a
[Pluggy](https://pluggy.ai) como agregador. A arquitetura é **plugável**: o app
só fala com `Aionis::Integrations.open_finance` e nunca conhece o provedor.

```
Aionis::Integrations.open_finance   # OpenFinanceProvider (contrato)
        ↓ (config/ENV)
PluggyProvider     ← implementado
BelvoProvider      ← slot pronto (config/aionis/integrations.yml)
QuantoProvider     ← slot pronto
```

Trocar/adicionar provedor = implementar a classe e apontar em `providers:` +
`OPEN_FINANCE_PROVIDER`. O restante do código não muda.

## Configuração (somente ENV — nenhuma credencial fixa)

| ENV | Descrição |
|-----|-----------|
| `OPEN_FINANCE_PROVIDER` | `pluggy` para ativar (default `null` = desligado) |
| `PLUGGY_CLIENT_ID` | client id da Pluggy |
| `PLUGGY_CLIENT_SECRET` | client secret da Pluggy |
| `PLUGGY_BASE_URL` | opcional (default `https://api.pluggy.ai`) |
| `PLUGGY_CONNECT_URL` | opcional (default `https://connect.pluggy.ai`) |
| `PLUGGY_TIMEOUT` | timeout HTTP em segundos (default 20) |

O `PluggyProvider` autentica em `POST /auth` (clientId+clientSecret → apiKey) e
usa `X-API-KEY` nas chamadas seguintes.

## Modelos

- **Consent** — consentimento (mapeia `external_id` → *item* da Pluggy). Status
  `pending/active/revoked/expired`.
- **BankAccount** — conta autorizada (saldo, agência, número, tipo).
- **BankTransaction** — transação bancária (valor, `direction` credit/debit,
  data, status de conciliação).
- **ReconciliationMatch** — vínculo BankTransaction ↔ FinancialTransaction com
  `score` e `status` (suggested/confirmed/rejected).

## Fluxo

1. **Consentimento** — `Aionis::OpenFinance::ConsentService.create(workspace)`
   gera um connect token; o widget da Pluggy cria a conexão (item) e retorna o
   `itemId`, que ativa o consentimento (`#activate`).
2. **Sincronização** — `Aionis::OpenFinance::SyncService.call(consent)` (ou
   `SyncConsentJob`) lê **contas** (`fetch_accounts`) e **transações**
   (`fetch_transactions`, últimos 90 dias), fazendo upsert por `external_id`.
3. **Conciliação** — cada transação nova passa pelo `Reconciler`.
4. **Revogação** — `ConsentService#revoke` chama o provedor e marca `revoked`.

## Conciliação e score

`Aionis::OpenFinance::Reconciler` compara a transação bancária com os
lançamentos do workspace (mesma natureza e valor idêntico, data em ±5 dias):

| Sinal | Pontos |
|-------|--------|
| valor idêntico | 55 |
| mesma data | +30 |
| data ±1–2 dias | +22 |
| data ±3–5 dias | +12 |
| descrição semelhante | +15 |

- **≥ 85** → conciliação automática (match `confirmed`, transação `matched`);
- **60–84** → sugestão (`suggested`, requer confirmação);
- **< 60** → sem match.

## Auditoria

Cada passo gera `AuditLog` com `action: "integration"`, `origin: "integration"`
e o `provider` (consentimento, sincronização, conciliação).

## Testes sem Pluggy

O `PluggyProvider` aceita cliente HTTP injetável (`settings[:http]`) e a
Integration Layer permite `Aionis::Integrations.override(:open_finance, fake)`.
Toda a suíte roda sem rede. Com `OPEN_FINANCE_PROVIDER=null` (default) o Open
Finance fica desligado com segurança.
