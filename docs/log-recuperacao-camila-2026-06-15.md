# Log de recuperação — Camila (prom 595), 15/06/2026

> Recuperação do trabalho preso da Camila Soares Rodrigues dos Santos
> (id 595, MG) a partir de fotos ÓRFÃS no bucket (subiram mas a visita
> nunca sincronizou — sync travado por outbox envenenado PGRST116 +
> backlog). Só UPDATE; backup em `/tmp/backup_camila_20260615/`; chave de
> serviço; conferência por URL 200. Camila NÃO usou o app hoje (trabalho
> de dias anteriores).

## Auditoria do bucket dela (corrige o número assustador)
1119 fotos no bucket. 234 vinculadas a visitas. As "885 não vinculadas":
- **546** = app **ANTIGO** (abril/maio, formato `image_<ts>.png` / numérico) — legado, NÃO mexido.
- **~240** = determinísticas antigas (maio) + duplicatas/refeitas — NÃO é perda.
- **10** = caminho quebrado (`visita-<hash>-antes-N`) — pertencem a visitas JÁ concluídas (extras do pivô), NÃO mexidas.
- **~85** = as REALMENTE perdidas → recuperadas (abaixo).

## Recuperadas: 8 visitas (Incompleta/Falta com 0 foto → Concluída) ✅
Nome do arquivo já trazia data/PDV/slot/ordem (sem OCR p/ mapear); datas
de abertura/realizado tiradas da marca d'água (OCR).
| Visita | Dia | PDV | Antes | Depois |
|---|---|---|---|---|
| 119562 | 09/06 | VALE REFEITÓRIO | 4 | 4 |
| 119563 | 09/06 | VALE ADM | 6 | 6 |
| 120212 | 09/06 | GERDAU VÁRZEA LOPES | 5 | 5 |
| 120211 | 09/06 | GERDAU VLN | 5 | 5 |
| 119564 | 09/06 | VALE TÉCNICO | 4 | 4 |
| 122388 | 12/06 | VALE REFEITÓRIO | 4 | 4 |
| 122759 | 12/06 | GERDAU MIGUEL ADM | 5 | 5 |
| 122390 | 12/06 | VALE TÉCNICO | 4 | 4 |
Todas → status 1 (Concluída), URLs 200 conferidas. (119564 e 122388 com
`dia_hora_realizado` nulo — OCR não leu o horário da última depois; visita
completa em foto, campo cosmético.)

## NÃO recuperadas (de propósito)
- 02/06 e 03/06 determinísticas, e as 2 de caminho quebrado: caíram em
  visitas JÁ Concluídas → eram extras/refeitas. Adicionar duplicaria.
- Legado (app antigo) e determinísticas de maio: fora do escopo (não é
  perda atual; risco de duplicar).

## Contexto / pendência
- A **agenda vazia** da Camila é por **sync travado** (outbox PGRST116 +
  backlog), não rede. Com este resgate, o trabalho dela está **seguro no
  servidor** → ela pode zerar o app sem perder essas 8.
- O PGRST116 é tratado no build 252 (`ehErroZeroRows`) — verificar se,
  no 252, a fila dela drena sozinha; senão, reset do app.
