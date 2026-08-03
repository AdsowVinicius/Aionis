# IA — fallback de classificação + Agente Financeiro (Groq / Claude)

A IA é usada **apenas como fallback** do motor de classificação (CLAUDE.md §4:
"IA barata para revisar/classificar", "IA melhor apenas em fallback") e como
cérebro do Agente Financeiro (chat com tool calling). Toda a comunicação passa
pela Integration Layer — o app nunca conhece o provedor.

```
Rule Engine → Rule Learner → Histórico → IA → Sugestão → Usuário → Aprendizado
```

## Quando a IA é (e não é) chamada

O `ClassificationEngine` só aciona a IA quando `allow_ai: true` **e**:

- o Rule Engine **não** acertou (nenhuma regra casou), **e**
- a confiança de regra/histórico é **≤** o limite configurado (`AI_FALLBACK_THRESHOLD`, default 60).

Ou seja, **nunca chama IA** se uma regra casou ou se a confiança já é alta.
Hoje o `allow_ai: true` está ligado no pipeline de OCR
(`DocumentExtractionService`), onde o custo se justifica; o formulário web não
dispara IA a cada abertura.

## Provedores (plugável)

```
Aionis::Integrations.ai   (contrato Ai::Base)
        ↓ (config/ENV: AI_PROVIDER)
GroqProvider        ← implementado (Llama/GPT-OSS via Groq Cloud)
AnthropicProvider   ← implementado (Claude)
[GeminiProvider / OllamaProvider]   ← slots prontos
```

- **Persona:** vive em `Ai::Base::PERSONA` (compartilhada) — "assistente de
  classificação financeira do Aionis"; responde somente JSON
  `{category_id, confidence, reasons}`. Trocar de provedor não muda o prompt.
- **Modelos padrão:** groq → `llama-3.3-70b-versatile`; anthropic →
  `claude-haiku-4-5`. Ambos configuráveis por ENV.

### Contrato interno = formato Anthropic (Messages API)

O Aionis fala **um só dialeto internamente**: blocos `text`/`tool_use`/`tool_result`
e tools com `input_schema` (o formato da Messages API). `Agent::Conversation`,
`Agent::Toolbox` e `Ai::Classifier` só conhecem esse formato.

O `GroqProvider` **traduz nos dois sentidos** (a Groq usa a API estilo OpenAI):

| Aionis (contrato Anthropic)                | Groq (OpenAI Chat Completions)                       |
|--------------------------------------------|------------------------------------------------------|
| `system:` (parâmetro)                      | primeira mensagem `{role: "system"}`                 |
| tool `{name, description, input_schema}`   | `{type: "function", function: {..., parameters}}`    |
| bloco `tool_use {id, name, input}`         | `message.tool_calls[] {id, function.arguments(JSON)}`|
| bloco `tool_result {tool_use_id, content}` | mensagem `{role: "tool", tool_call_id, content}`     |
| `stop_reason: "tool_use"`                  | `finish_reason: "tool_calls"`                        |
| `usage.input_tokens/output_tokens`         | `usage.prompt_tokens/completion_tokens`              |

> Se o modelo devolver `finish_reason: "stop"` mas com `tool_calls` presentes, o
> provider força `stop_reason: "tool_use"` — a presença da tool manda.

**Trocar de provedor é trocar 2 variáveis de ambiente.** Nenhum consumidor muda.

## Configuração (somente ENV — nenhuma credencial fixa)

| ENV | Descrição |
|-----|-----------|
| `AI_PROVIDER` | `groq` \| `anthropic` \| `null` (default = desligado) |
| `AI_API_KEY` | chave do provedor ativo (Groq: `gsk_...`; Anthropic: `sk-ant-...`) |
| `AI_MODEL` | **vazio = default do provedor** (groq → `llama-3.3-70b-versatile`; anthropic → `claude-haiku-4-5`) |
| `AI_MAX_TOKENS` | teto de saída da classificação (default 400) |
| `AI_TIMEOUT` | timeout HTTP (default 20s) |
| `AI_BASE_URL` | endpoint alternativo compatível com OpenAI (opcional) |
| `AI_INPUT_PRICE` / `AI_OUTPUT_PRICE` | US$/1M tokens p/ estimar custo. Vazio = tabela do provedor (groq 0.59/0.79; anthropic 1.0/5.0) |
| `AI_FALLBACK_THRESHOLD` | confiança máxima que ainda aciona IA (default 60) |
| `AGENT_MODEL` | modelo do Agente Financeiro (vazio = `AI_MODEL`) |
| `AGENT_MAX_TOKENS` | teto de saída do agente (default 1024) |

Chave da Groq: <https://console.groq.com/keys>.
Modelos com tool calling: <https://console.groq.com/docs/models>
(`llama-3.3-70b-versatile`, `openai/gpt-oss-120b`, `meta-llama/llama-4-scout-17b-16e-instruct`).

### Deploy no Railway

No serviço do app: **Variables → Raw Editor** e cole:

```
AI_PROVIDER=groq
AI_API_KEY=gsk_sua_chave_aqui
AI_MAX_TOKENS=400
AGENT_MAX_TOKENS=1024
AI_TIMEOUT=20
AI_FALLBACK_THRESHOLD=60
```

`AI_MODEL`/`AGENT_MODEL` podem simplesmente **não existir** — em branco, o
provider usa o default dele. O Railway reinicia o serviço ao salvar; a config é
lida no boot (`config/aionis/integrations.yml` via ERB/ENV).

**Ao rotacionar a chave:** edite só `AI_API_KEY` no Railway e no `.env` local.
Nenhum deploy de código é necessário.

## Registro de cada chamada de IA

Toda classificação por IA grava um `AiInteraction` com **prompt, resposta,
custo, tokens (entrada/saída), tempo, provider, modelo e confidence**, além de um
`AuditLog` (`action: "ai"`, `origin: "ai"`) vinculado ao lançamento/documento.
O agente grava `AuditLog` por conversa e por tool executada.

## Testes sem IA real

Os providers aceitam cliente HTTP injetável (`settings[:http]`) e a Integration
Layer permite `Aionis::Integrations.override(:ai, fake)`. Com `AI_PROVIDER=null`
(default) a IA fica desligada com segurança e toda a suíte roda sem rede.
