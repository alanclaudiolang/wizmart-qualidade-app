---
name: status-visita-regras-completas
description: "Tabela dos 5 status do servidor + regra temporal (Em Andamento só HOJE) + o que EU posso/não posso carimbar em recuperação. status=2 em dia anterior é estado inválido."
metadata:
  node_type: memory
  type: feedback
  originSessionId: 5b3db7e3-0a85-41f4-a33b-0441e2dfb1ba
---

## Tabela `status_visita` do servidor (Supabase)

| id | nome |
|---|---|
| 1 | Concluída |
| 2 | Em Andamento |
| 3 | Não Realizada |
| 4 | Agendada |
| 5 | Incompleta |

## Regra temporal — status=2 só existe HOJE

`status_visita=2` (Em Andamento) só é válido em visitas cuja
`dia_hora_agendado` é HOJE. Em dias anteriores, status=2 é estado
inválido — significa que o app não conseguiu finalizar a visita no
dia, ficou travado num estado intermediário.

## Definição de Incompleta (status=5)

Refere-se à **ausência de uma categoria inteira de foto** —
`fotos_antes` ou `fotos_depois`, ou ambas. NÃO se refere à quantidade
de fotos dentro de uma categoria.

- `fa=0 fd=0` → Incompleta (5) ou Não Realizada (3) — ver regra abaixo
- `fa=8 fd=0` → Incompleta (5) — falta a categoria depois
- `fa=0 fd=8` → Incompleta (5) — falta a categoria antes
- `fa=7 fd=8` → **NÃO é incompleta**; é Concluída (1)
- `fa=1 fd=1` → Concluída (1) — tem pelo menos 1 em cada

Nunca usar quantidade absoluta (≥8, etc.) como critério.

## O que EU posso carimbar em recuperação manual

Pra visitas de **dias anteriores** com `status_visita=2` (inválido):

- **fa≥1 E fd≥1** → carimbar como **1 (Concluída)**
- **fa=0 E fd≥1**, OU **fa≥1 E fd=0** → carimbar como **5 (Incompleta)**

## O que EU NÃO posso carimbar

- **3 (Não Realizada)** — quem carimba é o **Supabase** (trigger/cron
  do servidor). EU nunca devo escrever `status_visita=3` num PATCH.
- **Visitas de hoje** — fluxo normal do app, não mexer.
- **`fa=0 fd=0` em dia anterior** — esse caso o servidor carimba como
  3 automaticamente. Não tocar.

## Why

- O bug Mauro/Felipe/Thamara/Thiago dos builds 222-225 nasceu
  exatamente desse erro de interpretação: o app mandava status=2
  como "default seguro" quando a row local era Agendada (1). Eu
  reproduzi a confusão durante recuperação porque não tinha a regra
  temporal gravada — usei "Em Andamento" como estado válido em
  qualquer data, o que é errado.
- Em 10/06, o usuário corrigiu pela segunda vez (a primeira foi
  com a Paula 117575). Gravei aqui pra não errar de novo.

## How to apply

Em qualquer query de auditoria do servidor:
- Filtrar `status_visita=2 AND dia_hora_agendado < HOJE` = lista
  de visitas a corrigir.
- Pra cada uma, decidir 1 ou 5 conforme contagem fa/fd.
- Nunca propor PATCH com status=3.

Em qualquer chamada de `_toServerStatus` no app: status=1 (Agendada)
NÃO tem equivalente no servidor — o app deve descartar ANTES do
payload (guard upstream em `_processOutboxItem`), nunca enviar.

Conecta com [[no-speculation]], [[visita-avulsa-inferir-do-historico]]
e [[match-visita-via-path-url]].
