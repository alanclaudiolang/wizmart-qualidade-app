---
name: nao-deduzir-campos-de-dominio
description: "NÃO deduzir o valor de campos de domínio (visita_avulsa, status, flags) do histórico. Ou tem fonte explícita (Edge Function, regra do código, instrução do usuário) ou se PERGUNTA."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 5b3db7e3-0a85-41f4-a33b-0441e2dfb1ba
---

**Regra:** ao inserir/atualizar registros direto no Postgres pra
substituir o fluxo do app, NÃO inferir o valor de campos de **domínio**
(`visita_avulsa`, `status_visita`, flags de aprovação, `turno_realizada`,
etc) olhando o histórico recente. Ou tem fonte explícita — Edge Function
canônica, regra escrita no código, instrução direta do usuário — ou
pergunta antes.

**Why:**
- Em 2026-05-29 inseri 6 visitas do Gabriel/335 com `visita_avulsa=true`
  só porque a única que existia no dia (Dálias) estava assim. O usuário
  corrigiu: avulsa é flag inserida manualmente; visitas REGULARES vêm da
  Edge Function `gerar_datas_gabaritos_att`. As 7 visitas dele deveriam
  ter vindo dessa function (não vieram — daí estarem ausentes).
- Em seguida salvei memória dizendo "inferir do histórico" — duplo erro,
  porque histórico é evidência indireta, não fonte de verdade. Dois
  promotores podem ter o mesmo par (PDV, gabarito) com avulsa diferente
  conforme decisão operacional do dia.
- Padrão geral: deduzir de histórico parece "investigação a fundo" mas
  na verdade é chute estatístico. Combina com [[no-speculation-fixes]].

**How to apply:**
- Ao escrever bypass-do-app no Postgres: liste os campos de domínio do
  payload e pra cada um identifique a fonte. Se a fonte for "o que o
  histórico mostra" → PARE e pergunte.
- Edge Functions canônicas (ex: `gerar_datas_gabaritos_att`) são fontes
  de verdade pro shape de visita agendada. Quando o trabalho está
  recriando o que essa function faria, replicar exatamente o shape dela
  (incluindo `visita_avulsa=false`, `status_visita=4`).
- Quando o usuário não passou um campo do checklist (check_pergunta_*,
  obs_pergunta_*, comentarios_visita), perguntar — não inventar.
