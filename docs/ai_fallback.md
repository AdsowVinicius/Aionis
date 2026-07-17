# IA como fallback (Claude)

A IA é usada **apenas como fallback** do motor de classificação (CLAUDE.md §4:
"IA barata para revisar/classificar", "IA melhor apenas em fallback"). Toda a
comunicação passa pela Integration Layer — o app nunca conhece o provedor.

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
Aionis::Integrations.ai   (contrato AiProvider)
        ↓ (config/ENV)
AnthropicProvider   ← implementado (Claude)
[OpenAIProvider / GeminiProvider / OllamaProvider]   ← slots prontos
```

- **Modelo:** Claude **Haiku 4.5** (`claude-haiku-4-5`) por padrão — rápido e
  barato, adequado a um fallback de classificação. Configurável por ENV.
- **Persona:** system prompt "assistente de classificação financeira do Aionis";
  responde somente JSON `{category_id, confidence, reasons}`.

## Configuração (somente ENV — nenhuma credencial fixa)

| ENV | Descrição |
|-----|-----------|
| `AI_PROVIDER` | `anthropic` para ativar (default `null` = desligado) |
| `AI_API_KEY` | chave da Anthropic |
| `AI_MODEL` | modelo (default `claude-haiku-4-5`) |
| `AI_MAX_TOKENS` | teto de saída (default 400) |
| `AI_TIMEOUT` | timeout HTTP (default 20s) |
| `AI_INPUT_PRICE` / `AI_OUTPUT_PRICE` | US$/1M tokens p/ cálculo de custo (default 1.0 / 5.0) |
| `AI_FALLBACK_THRESHOLD` | confiança máxima que ainda aciona IA (default 60) |

## Registro de cada chamada de IA

Toda classificação por IA grava um `AiInteraction` com **prompt, resposta,
custo, tokens (entrada/saída), tempo, provider, modelo e confidence**, além de um
`AuditLog` (`action: "ai"`, `origin: "ai"`) vinculado ao lançamento/documento.

## Testes sem IA real

O `AnthropicProvider` aceita cliente HTTP injetável (`settings[:http]`) e a
Integration Layer permite `Aionis::Integrations.override(:ai, fake)`. Com
`AI_PROVIDER=null` (default) a IA fica desligada com segurança e toda a suíte
roda sem rede.
