---
name: data-da-visita-via-watermark
description: "A ÚNICA fonte confiável da data/hora real em que uma foto foi tirada é o OCR da marca d'água. Path da URL e dia_hora_agendado do SQLite local podem estar errados por bugs anteriores no app"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 5b3db7e3-0a85-41f4-a33b-0441e2dfb1ba
---

Quando precisar determinar a data/hora REAL de quando uma foto foi
tirada (pra cruzar com visita do servidor, validar agrupamentos,
preencher `dia_hora_realizado`, etc.), a **hierarquia de confiança é:**

## 1. ✅ Marca d'água da foto (ÚNICO 100% confiável)
- Escrita pelo app via `WatermarkUtil.applyWatermark` em
  `lib/core/utils/watermark_util.dart:105`:
  `DateFormat('dd/MM/yyyy HH:mm:ss').format(capturedAt)`
- `capturedAt` = `DateTime.now()` no momento exato do clique de captura
- Renderizada no Canvas como pixels, congelada no arquivo `.jpg`
- Nada (servidor, app, pull, upsert) pode alterar depois
- **Pra acessar:** baixar foto + Tesseract OCR

## 2. ⚠️ Path da URL no Storage (boa aproximação, mas não garantia)
Formato: `abastecimentos/<uid>/<DATA>_<HORA>-00-00/<nome>-<hash>-<slot>-<n>.jpg`

A `<DATA>` é derivada de `visita.diaHoraAgendado` no momento em que
o `_processPhotoUpload` foi executado ([sync_engine.dart:918-929]).
**Se o app tinha bug** que mexia em `dia_hora_agendado` ANTES do
upload (caso pre-build 215: `upsertVisita` preservando campos
velhos), o path nasce errado.

Path é congelado depois — não muda no Storage. Mas pode ter saído
errado de início.

## 3. ❌ `dia_hora_agendado` do dump SQLite (NÃO confiar)
Reflete o estado atual do app, mutável por qualquer pull subsequente.
Bug do `upsertVisita` em PDVs recorrentes preserva localState e
atualiza data — então o mesmo registro pode ter sido GERDAU SARDINHA
03/06 ontem e GERDAU SARDINHA 08/06 hoje, com fotos de ambas datas
apontando pra "mesma" visita.

## Caso concreto que motivou essa memória

Issue #410 (Camila Soares, build 220):
- Dump SQLite: `dia_hora_agendado=2026-06-08T08:00`
- 1ª URL pending_photos: path `2026-06-03_05-00-00`

Meu script confiou no dump → match com visita 08/06 no servidor →
adicionou URLs path 03/06 (na verdade da visita 03/06) numa visita
08/06. Resultado: 3 visitas com URLs misturadas.

## Procedimento correto em recuperação automática

1. **Pra cada foto, baixar e fazer OCR da marca d'água** pra extrair
   data/hora REAL.
2. Agrupar URLs por data REAL extraída do OCR.
3. Pra cada grupo (data, conjunto): buscar visita do servidor com
   `id_promotor_associado=<X>` E `dia_hora_agendado=<DATA>`.
4. Match por hash do path (gabarito|pdv|turno) OU título normalizado.
5. UPDATE/INSERT.

## Path da URL como pré-filtro (não fonte final)

Se OCR for caro, dá pra usar path da URL pra triagem inicial
(agrupar por path-data) e fazer OCR só pra confirmar quando há
suspeita (visitas mixed, datas conflitantes). Mas:
- **Validação final SEMPRE deve incluir OCR** quando o dado vai pro servidor.
- Se path-data ≠ dia_hora_agendado da visita atualizada → sinal de
  bug, requer OCR pra resolver.

## NÃO repetir

- Não confiar em `dia_hora_agendado` do dump SQLite pra match.
- Não confiar em timestamp do log persistente do app (ex: Upload OK)
  como timestamp da foto — é apenas quando o upload aconteceu, não
  quando a foto foi tirada.
- Não confiar em `nextRetry` da `pending_photos` — é agendamento de
  próxima tentativa, não data da foto.

## Causa raiz confirmada no código

`pending_photos.nextRetryAt` é populado em DOIS momentos no
`sync_engine.dart`, NUNCA como timestamp da captura:

1. **Criação inicial** (`_processOutboxItem` linha 1113):
   `nextRetryAt: Value(DateTime.now().toIso8601String())` — instante
   em que o outbox criou o registro pra processar.

2. **Após falha de upload** (`_processPhotoUpload` linha 1167-1173):
   `final nextRetry = DateTime.now().add(Duration(seconds: delaySeconds))`
   — agendamento futuro de próxima tentativa com backoff exponencial.

Logo, pra foto `uploaded`, o último `nextRetryAt` é apenas o valor
que estava na row quando deu sucesso (pode ser o timestamp inicial,
ou um retry agendado de tentativa anterior). **NUNCA reflete quando
a foto foi tirada.**

O único campo no SQLite que poderia ajudar é `pending_photos.createdAt`,
mas mesmo esse é "quando o registro foi criado", não "quando o promotor
clicou em capturar" (que é a captura real).

## Implicação operacional

Em qualquer script de recuperação que precisa de timestamps reais:
1. Baixar a foto
2. Tesseract OCR + regex `(\d{2})/(\d{2})/(\d{4})\s+(\d{2}):(\d{2}):(\d{2})`
3. Esse é o único timestamp confiável

Nunca usar timestamps de SQLite (createdAt, nextRetryAt, syncedAt).
Nunca usar timestamps de log persistente (Upload OK, watermark, etc).
