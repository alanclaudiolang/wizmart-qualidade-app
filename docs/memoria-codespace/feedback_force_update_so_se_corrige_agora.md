---
name: force-update-so-se-corrige-promotor-agora
description: "NÃO ativar [FORCE-UPDATE] pra fixes que só têm efeito na próxima ocorrência. Force-update só pra correção que destrava promotor que ESTÁ travado agora."
metadata:
  type: feedback
---

**Regra:** ao publicar build em v-latest, ativar `[FORCE-UPDATE]` SÓ
quando o fix muda IMEDIATAMENTE a experiência do promotor que está em
produção naquele momento. Pra fixes que só agem em situações futuras
(nova exception, próximo erro, próximo refresh expirado), deixar
D+1 normal — o promotor escolhe a hora de atualizar.

**Why:**
- Cada force-update interrompe o promotor obrigando-o a baixar APK +
  instalar, no momento em que ele tá tentando trabalhar.
- Se o fix só ajuda 'se algo der errado depois', forçar agora é só
  fricção sem ganho.
- Em 2026-06-05 ativei force-update pro fix de _ErrorScreen reportar
  issue antes de mostrar tela vermelha — mas a mudança só roda em
  caso de erro fatal NO PRÓXIMO boot quebrado. Forçar atualização
  agora interrompia o trabalho de todo mundo sem benefício imediato.

**How to apply:**
- Fix destrava promotor travado AGORA (auth expirou, app não sincroniza,
  visita zerou, crash recorrente em uso normal) → ativa
  `[FORCE-UPDATE]`.
- Fix preventivo / muda comportamento só em casos futuros (nova
  exception, tela diferente quando algo falhar, log enriquecido) →
  D+1 normal, sem force-update.
- Quando em dúvida, perguntar OU não ativar. Reverter force-update
  é simples (editar o body do release pra remover o marker), mas o
  download já disparado pros promotores não dá pra cancelar.

Combina com [[no-force-update-em-mudanca-estrutural]]: essa proíbe
force-update em mudança de schema/hash; esta refina pra fixes não-
estruturais — só força se traz alívio AGORA pra alguém travado.
