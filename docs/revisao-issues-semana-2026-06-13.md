# Revisão profunda dos issues da semana (regra 8) — 13/06/2026

> Releitura de TODOS os relatos da semana aplicando a regra 8 (não parar no
> estado final; cruzar as 5 datas; anomalia temporal prova reinício). Em
> vez de ler 32 logs gigantes, varri no servidor as 295 visitas dos 13
> promotores que reclamaram e detectei inversões de data + duplicatas — o
> detector central da regra 8. Resultado: o padrão é MAIOR que o visto no
> chat.

## Método
Para cada visita: comparar `abertura ≤ fotos_antes ≤ fotos_depois ≤
realizado`. Qualquer inversão = anomalia temporal = reinício/zeramento
(mesmo com resultado final completo). + contar URLs duplicadas nos arrays.

## A) Anomalia temporal `abertura > fotos_antes` — REINÍCIO (bug A2/A)
A abertura POSTERIOR às fotos do antes é impossível no fluxo normal: prova
que a visita foi rebaixada e o promotor reiniciou.

| Visita | Promotor | Build | Inversão | Desfecho |
|---|---|---|---|---|
| 122556 | Felipe (34) | 249 | abertura 22min depois | recuperado 7/7 (fotos já tinham subido) |
| **122541** | **Felipe (34)** | **249** | abertura 6min depois | ⚠️ **NÃO recuperado: status AGENDADA com 7 fotos antes — RISCO ATIVO AGORA** |
| 121455 | Thiago (115) | 223 | abertura **124min** depois | ❌ **perda real: ficou INCOMPLETA (nunca completou o depois)** |
| 122262 | Luís Rafael (107) | 225→ | abertura 13min depois | recuperado 8/8 |

**Conclusões duras:**
- **A2 atingiu ≥4 visitas de 3 promotores** — não é caso isolado do Felipe.
- **Felipe e Luís estão no 249 e MESMO ASSIM tiveram A2** → confirma que o
  build 249 NÃO cobre A2 (é causa nova, item 14 do plano).
- **Thiago 121455 teve PERDA REAL** (Incompleta) — não foi "só susto"; a
  visita nunca foi concluída porque o reinício a desmontou.
- **Felipe 122541 é risco ATIVO**: status agendada com 7 fotos antes
  salvas no servidor. Se ele reabrir, verá "Iniciar" e pode refazer/perder.

## B) Inversão menor `fotos_depois > realizado` — investigar
Luís Rafael 119304, 119802, 119968 (status 1, completas). A foto-depois
com timestamp posterior ao "realizado" pode ser ordem de gravação
(concorrência), não necessariamente reinício. Menos grave; padrão a vigiar
mas sem perda aparente.

## C) Duplicatas de URL nos arrays — REFAZER após reset/pivot
Sintoma direto de Causa A/A2 (o promotor refez e gerou 2º conjunto):

| Promotor | Visitas com duplicata |
|---|---|
| Felipe (34) | 119937, 119944, 119970, 119971, 119977, 119978, 119979, 119980 (08–09/06, histórico) |
| David (113) | 121617, 122439 (depois ×4) |
| Thiago (115) | 120082, 120127, 122617, 122635 |
| Gabriel (335) | 121627, 122035, 122282 |
| SP06 (452) | 121353, 122193 (depois ×8) |
| Jéssica (545) | 122857 |
| Luís Rafael (107) | 121662 (depois ×8) |

**Duplicatas em 7 promotores** = a Causa A/A2 (refazer após zeramento)
afetou muito mais gente do que os casos relatados no chat. Todas entram no
Bloco 2 (correção de histórico no servidor, dedup dos arrays).

## Ações imediatas (que esta revisão tornou urgentes)
1. **Felipe — visita 122541 (VIV FREGUESIA), AGORA:** orientar a NÃO
   reiniciar do zero — as 7 fotos do antes estão salvas no servidor. Avaliar
   fechar/recuperar pelo servidor (com OK) em vez de ele refazer.
2. **Thiago — 121455:** ficou Incompleta por perda real; recuperável só se
   houver fotos do depois em algum lugar (galeria dele / bucket). Verificar.
3. O resto das duplicatas/anomalias entra no Bloco 2 do plano mestre.

## O que esta revisão prova sobre o plano
- A Causa A2 (item 14) é **a mais urgente** — atinge o build 249, causa
  perda real (Thiago) e tem caso ativo (Felipe 122541).
- O item 12 + a proteção por "trabalho em andamento" (não só `pending`)
  é o que mata A2 — confirmado pela frequência.
- O item 13 (telemetria ver a Causa A) é essencial: nada disso disparou
  alarme automático; só apareceu porque cruzei as datas manualmente.
