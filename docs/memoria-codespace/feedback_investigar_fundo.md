---
name: investigar-issues-a-fundo
description: "Investigar qualquer issue novo a fundo automaticamente, sem pedir confirmação — análise profunda é o default"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 5b3db7e3-0a85-41f4-a33b-0441e2dfb1ba
---

Quando um issue novo (GitHub ou relato) aparece, **investigar a fundo
automaticamente** — não pedir confirmação pra "quer que eu investigue?".
Investigação profunda é o default esperado, não opção.

**Why:** o usuário disse em 2026-05-28 "sempre tem que investigar a
fundo qualquer issue que ocorra. deixei isso gravado para não perguntar
o obvio". Cada pergunta desse tipo interrompe o fluxo dele
desnecessariamente — ele já delegou essa decisão.

**How to apply:**
- Ao ver um issue novo: ler o body completo (não só metadados), buscar
  os marcadores das sondas (`PIVOT`, `ÓRFÃO`, `DISCREPÂNCIA`,
  `integridade`, `updateVisita 0 linhas`), checar BUILD, cruzar com
  dados do servidor (visitas, bucket, logs_app, logs_visitas),
  correlacionar com timestamps, e formar hipóteses com evidência.
- Reportar o achado com evidência concreta (arquivo:linha, log:linha,
  dados:campo). Não pedir confirmação pra investigar — só pra agir.
- Combina com [[no-speculation-fixes]]: investigar a fundo PRA reunir
  evidência; agir só com evidência confirmada.
