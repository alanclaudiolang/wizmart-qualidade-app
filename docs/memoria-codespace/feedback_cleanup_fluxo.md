---
name: cleanup-fluxo
description: "Limpar artefatos/sujeira do fluxo conforme vão surgindo, não deixar acumular"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 89a55c57-a8b0-4de7-b55f-db0e4f1cb76f
---

Quando uma escolha de configuração se mostra errada e precisa ser refeita
(ex: API key com role insuficiente, integração com nome trocado), **revogar/
deletar a versão velha ANTES de criar a nova** — não deixar sobrando "no
caso de" (2026-05-28).

**Why:** o usuário explicitou — "as sujeiras que fizermos vamos limpar para
ficar fluido". Sobra de credencial/integração/recurso antigo cria confusão
em troubleshooting futuro (qual era a "ativa"?), aumenta superfície de
segurança, e deixa o painel sujo.

**How to apply:** ao recomendar correções de config externa (Apple,
Codemagic, GitHub Actions, etc.), incluir o passo de revogar/deletar o
recurso anterior na MESMA sequência — não como "fica pra depois". Vale
também pra commits/branches: não acumular fix-up commits e branches mortos
quando dá pra rebase/squash limpo.
