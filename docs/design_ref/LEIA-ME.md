# Referência de Design do Aionis (extraída do Figma)

Esta pasta contém o "design system" e a referência visual das telas, para o
Claude Code reconstruir as interfaces em ERB/Hotwire fiéis ao Figma.

## Onde colocar no projeto Rails

Crie a pasta `docs/design/` na raiz do projeto e coloque estes arquivos lá:

    seu-projeto/
      docs/
        design/
          theme.css                     <- tokens de cor, sombras, radius, dark mode
          fonts.css                     <- fontes e escala tipográfica
          figma_screens_reference.tsx   <- código React do Figma (SÓ referência visual)
          figma_routes.tsx              <- mapa das telas/rotas do Figma
          LEIA-ME.md                    <- este arquivo

> `docs/` é a convenção do próprio handbook do Aionis para documentação.
> NÃO é código que roda — é material de referência para o Claude Code ler.

## O que é cada arquivo

- **theme.css** — a fonte da verdade das CORES e tokens. Daqui saem as cores
  ink/teal/sky/amber/rose/cream/mist, sombras, radius, e o dark mode completo.
  É o que deve virar o `tailwind.config` do projeto.

- **fonts.css** — Plus Jakarta Sans (títulos), Inter (corpo), JetBrains Mono
  (números), e a escala de headings (h1..h4).

- **figma_screens_reference.tsx** — o export React do Figma com TODAS as telas
  (Dashboard, Documents, Entries, Billing, Assistant, KPIs, Settings, Login,
  Onboarding). É REFERÊNCIA VISUAL apenas — o Claude Code deve recriar em ERB,
  não copiar o React. Serve para ver layout, espaçamento, componentes.

- **figma_routes.tsx** — mostra o nome e a ordem das telas.

## Importante

Este material NÃO deve ir para o Git (é referência de trabalho, não código do app).
Veja o `.gitignore` que acompanha esta entrega.
