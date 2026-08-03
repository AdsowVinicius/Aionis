# Aionis Finance — Identidade Visual

**Conceito:** o "A" da marca com um *check* (✓) teal embutido — a letra e a
confirmação são a mesma forma. Comunica a promessa do produto: você manda,
o Aionis resolve. Não apenas identifica: significa.

Paleta: navy `#0E1B2C` · teal `#14B88A` · creme `#F5F4EF` · cinza `#6B7385`

---

## Arquivos

### Ícones
| Arquivo | Uso |
|---|---|
| `aionis-icon.svg` | **Principal.** A navy + check teal, sem container. Fundos claros. |
| `aionis-icon-badge.svg` | Container gradiente navy→teal. App icon, avatar, redes sociais. |
| `aionis-icon-dark.svg` | A branco + check teal. Para **fundos escuros** (sidebar, footer). |
| `aionis-icon-mono.svg` | Usa `currentColor` — herda a cor do CSS. P&B, impressão, ícone inline. |
| `favicon.svg` | Traços mais grossos, otimizado para 16–32px. |

### Lockups (com o nome)
| Arquivo | Uso |
|---|---|
| `aionis-finance-logo.svg` | **Principal.** "Aionis" navy bold + "Finance" teal medium. Header, e-mails. |
| `aionis-finance-logo-dark.svg` | Mesma coisa para fundos escuros. |
| `aionis-finance-logo-solid.svg` | Tudo em navy, peso único. Quando precisar de mais sobriedade (documentos, contratos). |
| `aionis-finance-logo-stacked.svg` | Empilhado (ícone em cima, nome embaixo). Espaços quadrados, splash screen. |

---

## Onde colocar no Rails

    app/assets/images/logo/
      aionis-icon.svg
      aionis-icon-badge.svg
      aionis-icon-dark.svg
      aionis-icon-mono.svg
      aionis-finance-logo.svg
      aionis-finance-logo-dark.svg
      aionis-finance-logo-solid.svg
      aionis-finance-logo-stacked.svg
    public/
      favicon.svg

### Na view (ERB)

    <%= image_tag "logo/aionis-finance-logo.svg", alt: "Aionis Finance", height: 40 %>

    <%# sidebar escura %>
    <%= image_tag "logo/aionis-finance-logo-dark.svg", alt: "Aionis Finance", height: 36 %>

### Favicon (no <head> do layout)

    <link rel="icon" type="image/svg+xml" href="/favicon.svg">
    <link rel="apple-touch-icon" href="/apple-touch-icon.png">

> Gere o `apple-touch-icon.png` (180×180) exportando `aionis-icon-badge.svg`
> em qualquer conversor SVG→PNG.

---

## Regras de uso

- **Respiro:** deixe ao menos 25% da altura do ícone livre ao redor da marca.
- **Tamanho mínimo:** favicon 16px · ícone 24px · lockup 120px de largura.
- **Hierarquia do nome:** "Aionis" é a marca; "Finance" é descritor. Em espaços
  curtos, use só o ícone ou só "Aionis".
- **Não** estique, gire, mude as cores para fora da paleta, adicione sombra
  ou contorno, nem separe o check do A.
- Fundo escuro → sempre a versão `-dark`.

### Nota técnica sobre os lockups

Os lockups usam `<text>` com a fonte **Plus Jakarta Sans** (peso 800 e 500).
Nos navegadores com a fonte carregada (Google Fonts) fica perfeito. Se precisar
usar em contexto sem essa fonte garantida (impressão, e-mail antigo, PDF),
peça a versão com o texto convertido em vetor.
