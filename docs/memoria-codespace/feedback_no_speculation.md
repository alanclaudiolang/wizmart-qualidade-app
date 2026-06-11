---
name: no-speculation-fixes
description: Não propor ou implementar correções baseadas em dedução/hipótese — toda fix exige causa raiz confirmada por evidência concreta
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 5b3db7e3-0a85-41f4-a33b-0441e2dfb1ba
---

Nunca propor ou implementar correção de bug sem ter **causa raiz
confirmada por evidência concreta** (log real do dispositivo, dados do
servidor que reproduzem o estado, reprodução em ambiente controlado,
ou rastreio de código que prova o caminho). "Faz sentido" / "deve ser
isso" / "provavelmente é X" não é evidência suficiente.

**Why:** o usuário não consegue testar/simular esses bugs (app em
produção com 70 promotores, race conditions, isolates). Se eu chutar e
implementar, corro o risco de mascarar o problema real, criar
regressões, ou desperdiçar ciclos de build/deploy. Em 2026-05-28 ele
explicitou: "não quero que faça algo baseado em dedução (chute). Todas
as correções tem que ser com base em elementos que testou e confirmou
a causa raiz."

**How to apply:**
- Antes de propor fix, listar a evidência concreta: arquivo:linha do
  código que prova o caminho, log de promotor, dados do banco que
  mostram o estado anômalo, ou observação reproduzida.
- Se a evidência é só dedução lógica ("se A acontece, então B
  provavelmente segue"), declarar isso explicitamente como hipótese e
  pedir confirmação antes de mexer.
- Aceitável: instrumentar com log/sondas pra capturar evidência futura
  (foi o caso das sondas DISCREPÂNCIA/ÓRFÃO/PIVOT — não corrigem nada,
  só observam).
- Preferir esperar um relato/log que confirme o cenário a sair
  corrigindo no escuro.

[[user_role]] — usuário não pode testar manualmente, então precisa
confiar que cada fix tem base verificada.
