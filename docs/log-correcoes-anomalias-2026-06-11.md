# Log de correções — anomalias de data confirmadas por marca d'água

> Criado em 11/06/2026. Verificação: OCR da marca d'água das fotos do bucket
> (fonte de verdade) cruzado com os campos de data da tabela `visitas` e com
> a existência dos arquivos no bucket (nome determinístico, pasta por data).
> **Regra:** apenas UPDATE — nenhuma exclusão ou inclusão de registros.
>
> Status de cada item: `PROPOSTA` (aguardando OK do Alan) → `EXECUTADA`
> (com data/hora). Antes de executar cada UPDATE, o valor antigo é anotado
> aqui para permitir reversão.

## Diagnóstico-resumo por promotor

| Promotor | Visitas | Diagnóstico | Correção |
|---|---|---|---|
| Felipe (34) | 119937 119944 119966 119970 119971 119977 119978 119979 119980 | Trabalhou no dia certo (marca d'água do dia agendado existe no bucket); arrays apontam para fotos de visita anterior do mesmo PDV (colisão de nome de arquivo) | Trocar URLs dos arrays para a pasta do dia agendado |
| Thiago (115) | 120082 120127 | Mesmo defeito do Felipe | Trocar URLs dos arrays |
| Renato (49) | 117649 | Visita atravessou 2 dias: "antes" 02/06, "depois" 04/06 (marcas d'água) | Trocar URLs "depois" para pasta 04/06 e corrigir campo `dia_hora_fotos_depois` |
| Mauro (412) | 119493 119512 119526 119529 120351 | Cópia indevida: o trabalho de 02-03/06 já está nas visitas corretas (117031-117034); as visitas de 05 e 09/06 receberam os mesmos dados/fotos por defeito de sync | Limpar os campos copiados e restaurar o status real; na 120351, antes mover o trabalho para 117587 (03/06, hoje "Incompleta") |

---

## Felipe Costa da Silva (id 34)

Fatos: marcas d'água das fotos apontadas pelos arrays = 04-05/06; campos
`abertura/realizado` = dia agendado (08-09/06) e **conferem com a marca
d'água das fotos do dia certo que existem no bucket** (verificado por OCR em
119971 e 119978). Promotor esteve no PDV no dia agendado.

| Visita | Agendada | UPDATE proposto | Obs |
|---|---|---|---|
| 119937 | 09/06 | arrays: trocar 13 URLs pasta `2026-06-04` → `2026-06-09` (13/13 existem) | **EXECUTADA 11/06** — 13 trocadas |
| 119944 | 09/06 | arrays: trocar 14 das 15 URLs antigas (14/15 existem) | **EXECUTADA 11/06** — 14 trocadas; mantida 1 (`…2026-06-04…VIV_FREGUESIA…depois-7.jpg`, sem versão de 09/06) |
| 119966 | 09/06 | **sem correção possível**: as 4 fotos "antes" são de 04/06 e não existe versão de 09/06; "depois" já é do dia certo (09/06 17:43) | ANÔMALA, sem correção possível — NENHUM UPDATE feito; destino a definir pelo Alan |
| 119970 | 09/06 | arrays: trocar 12 URLs `2026-06-04` → `2026-06-09` (12/12) | **EXECUTADA 11/06** — 12 trocadas |
| 119971 | 08/06 | arrays: trocar 16 URLs `2026-06-05` → `2026-06-08` (16/16) | **EXECUTADA 11/06** — 16 trocadas |
| 119977 | 08/06 | arrays: trocar 8 URLs `2026-06-05` → `2026-06-08` (8/8) | **EXECUTADA 11/06** — 8 trocadas |
| 119978 | 08/06 | arrays: trocar 14 URLs `2026-06-05` → `2026-06-08` (14/14) | **EXECUTADA 11/06** — 14 trocadas |
| 119979 | 08/06 | arrays: trocar 11 das 12 URLs (11/12) | **EXECUTADA 11/06** — 11 trocadas; mantida 1 (sem versão de 08/06) |
| 119980 | 08/06 | arrays: trocar 12 das 13 URLs (12/13). A 13ª é a foto "depois" de **outro PDV** (PORTAL CERVEJAS, 10/06 18:18) — não tem substituta; manter | **EXECUTADA 11/06** — 12 trocadas; mantida a foto de PDV errado (sem substituta) |

**Execução Felipe (11/06/2026):** as trocas são reversíveis de forma
determinística (mesmo nome de arquivo, só muda a data da pasta:
09/06→04/06 ou 08/06→05/06). Registro completo antes/depois de cada array
salvo em `log_execucao_felipe_2026-06-11.json` (enviado ao Alan; cópia do
conteúdo recuperável pelos padrões acima).

## Thiago Alves Silva (id 115)

Fatos: idem Felipe — campos = 09/06, fotos do dia certo existem (OCR em
120082: "FOTO Antes - 09/06/2026 16:16:18" bate com abertura 16:16:05).

| Visita | Agendada | UPDATE proposto | Obs |
|---|---|---|---|
| 120082 | 09/06 | arrays: trocar 8 das 9 URLs `2026-06-08` → `2026-06-09` | **EXECUTADA 11/06** — 8 trocadas; mantida 1 (`…2026-06-08…SICOOB…antes-5.jpg`, sem versão de 09/06) |
| 120127 | 09/06 | arrays: trocar 7 URLs `2026-06-08` → `2026-06-09` (7/7) | **EXECUTADA 11/06** — 7 trocadas |

**Execução Thiago (11/06/2026):** registro completo antes/depois em
`log_execucao_thiago_2026-06-11.json` (enviado ao Alan). Reversão
determinística: voltar a data da pasta 09/06→08/06 nas URLs trocadas.

## Renato Louzada Junior (id 49)

Fatos (revisados em 11/06 após conferência dos arrays): 117649 (PORTAL
CERVEJAS, ag 04/06): abertura 02/06 18:01; 5 fotos "antes" de 02/06
(marca d'água 02/06 18:05); array "depois" JÁ CONTÉM os dois dias —
4 fotos de 02/06 (18:23) e 4 de 04/06 (marca d'água 04/06 08:06, confere
com realizado 04/06 08:09). A visita começou em 02/06 e terminou em 04/06;
cada foto está vinculada ao seu dia verdadeiro.

⚠️ A proposta original (trocar as 4 URLs "depois" de 02/06 para a pasta
04/06) estava ERRADA — criaria duplicatas, pois as fotos de 04/06 já estão
no array. Cancelada.

| Visita | UPDATE proposto | Obs |
|---|---|---|
| 117649 | `dia_hora_fotos_depois`: `2026-06-02T18:23:28-03:00` → `2026-06-04T08:06:04-03:00` (horário da marca d'água da última leva "depois") | **EXECUTADA 11/06** — Alan escolheu corrigir só esse campo; arrays intactos (fotos dos 2 dias preservadas); demais campos de 02/06 mantidos por refletirem o fato real |

> ⚠️ **A ANOMALIA PERSISTE** (regra do mesmo dia, definida pelo Alan):
> abertura e fotos "antes" em 02/06; agendado, realizado e parte das fotos
> "depois" em 04/06 — as marcas d'água provam trabalho em DOIS dias.
> Não existe UPDATE capaz de resolver. Destino a definir pelo Alan.
> Fato registrado: `visita_aprovada = true`.

## Revalidação contra a regra do mesmo dia (11/06, pós-correções)

Critério: `dia_hora_agendado/abertura/realizado/fotos_antes/fotos_depois`
e data das fotos vinculadas, todos no mesmo dia. Data das fotos verificada
pela pasta da URL em todas; marca d'água conferida por OCR em amostra.

| Visita | Estado | Pendência |
|---|---|---|
| 119937, 119970, 119971, 119977, 119978, 120127 | CONSISTENTE | — |
| 117649 | ANÔMALA | abertura e fotos "antes" de 02/06 (fato real, sem UPDATE possível) |
| 119944 | ANÔMALA | 1 foto de 04/06 sem versão do dia certo; campo `realizado` nulo |
| 119966 | ANÔMALA | 4 fotos "antes" de 04/06; campos `abertura` e `fotos_antes` nulos |
| 119979 | ANÔMALA | 1 foto de 05/06 sem versão do dia certo |
| 119980 | ANÔMALA | 1 foto de outro PDV (10/06); campo `abertura` nulo |
| 120082 | ANÔMALA | 1 foto de 08/06 sem versão do dia certo |

Destino das visitas que permanecem anômalas: **a definir pelo Alan**.

## Mauro Alexandre Gomez Altamirano (id 412)

Fatos: o trabalho de 02/06 está corretamente registrado em 117034 (INTERTEK,
08:20-08:54), 117033 (G2L CANOPUS, 09:48-10:32), 117032 (CAIXA 23°,
10:50-11:00) e 117031 (CAIXA 16°, 11:05-11:21) — horários idênticos aos das
visitas anômalas e às marcas d'água. As visitas de 05 e 09/06 receberam
CÓPIA desses dados. Não existem fotos dos dias 05/09 no bucket. A 117587
(SORTE NA BET, ag 03/06) ficou "Incompleta" (vazia) porque o trabalho de
03/06 caiu na 120351 (ag 05/06).

**EXECUTADO em 11/06/2026** com decisões do Alan: status final **5
(Incompleta)** — coerente com o job noturno do Supabase (só lê D-1, sem
carimbo retroativo; visita passada com registro e sem foto = Incompleta) —
e **117587 (SORTE NA BET 03/06) INTOCADA** por ordem do Alan: o trabalho
de 03/06 segue referenciado apenas no bucket (fotos preservadas lá e na
galeria do Mauro), sem vínculo na tabela.

UPDATE aplicado às 5 (119493, 119512, 119526, 119529, 120351): campos de
execução → nulo (abertura, realizado, datas/localizações de fotos,
comentários, checklist 1-7), arrays de fotos → vazios, `status_visita`
1 → 5. Campos do supervisor (`visita_aprovada`, `comentarios_supervisor`)
NÃO foram tocados. Backup integral das 5 rows (todos os campos, valores
pré-limpeza) salvo em `backup_mauro_2026-06-11.json` e enviado ao Alan.

| Visita | Agendada | Resultado |
|---|---|---|
| 119493 | 05/06 | limpa, status 5 (era cópia de 117034; supervisor havia reprovado a cópia — `visita_aprovada=false` mantido) |
| 119512 | 09/06 | limpa, status 5 (era cópia de 117033) |
| 119526 | 09/06 | limpa, status 5 (era cópia de 117032) |
| 119529 | 09/06 | limpa, status 5 (era cópia de 117031) |
| 120351 | 05/06 | limpa, status 5. A proposta de mover o trabalho para a 117587 foi CANCELADA pelo Alan (117587 intocada) |

> Escolha do status 3 (Não Realizada) nas limpezas: não há evidência de
> visita nesses dias (sem fotos no bucket). Alternativa: 5 (Incompleta).
> Decisão final do Alan antes da execução.

## Sem correção proposta (registrar apenas)

- 119966 "antes" (Felipe) — fotos de 04/06 sem versão do dia certo.
- 119980 foto "depois" de outro PDV (Felipe) — sem substituta no bucket.
- Causa-raiz no app (a corrigir em código, com aprovação): nome de arquivo
  determinístico sem data + fila de fotos antigas ainda "uploaded" para o
  mesmo id temporário faz visita nova apontar para foto de visita anterior
  do mesmo PDV/turno; e o sync por chave natural sem data copia trabalho
  antigo para visitas futuras (casos Mauro).

## Recuperação manual — Jeferson Martins Sotério (id 590), 11/06/2026

Fotos enviadas pelo promotor via WhatsApp (92 arquivos), OCR completo das
marcas d'água (fonte de verdade), casamento por **promotor + PDV + data**.
Procedimento padrão de recuperação (docs/memoria-codespace/
feedback_recuperacao_manual_procedimento.md). 63 fotos enviadas ao bucket
nos paths determinísticos (uid 1fdf9537…, pastas por data); upload e
UPDATEs executados com a chave administrativa (variável de ambiente).

| Visita | PDV / dia | Antes → Depois | Resultado |
|---|---|---|---|
| 115519 | ENERGISA 30/05 | Incompleta (6/0) → **Concluída (6/4)** | depois 12:22-12:23 anexado |
| 117607 | TVV 03/06 | Não Realizada (0/0) → **Incompleta (5/0)** | só havia "antes" nas fotos; marca d'água prova presença |
| 119436 | TVV 08/06 | Não Realizada → **Concluída (7/7)** | série "antes" mais recente (decisão Alan) |
| 120209 | SOLLO 09/06 | Não Realizada → **Concluída (7/6)** | depois sem nº 2; nº 1 duplicado → usado o mais recente |
| 120219 | ENERGISA 09/06 | Não Realizada → **Concluída (6/6)** | — |
| 120951 | TVV 10/06 | Não Realizada → **Concluída (8/7)** | série "antes" mais recente |

Campos: abertura = 1ª foto antes −30s; realizado = última depois;
localização do PDV; checklist 1-5 sim / 6-7 não; turno manha;
visita_avulsa=false; sincronizada_promotor=true (payload padrão validado).
Fotos NÃO usadas: visitas já completas no servidor (TVV 29/05, SOLLO 30/05
e SOLLO 11/06 — redundantes) e 1 print de tela. Visitas de 25-27/05 e
01/02/04/05/06/06 SEM fotos no material → permanecem como falta.
Backup integral pré-UPDATE: `backup_jeferson_2026-06-11.json` (enviado ao
Alan). Hash dos nomes: convenção atual do app; na 115519 foi reusado o
hash dos arquivos pré-existentes da própria visita (agrupamento).

## Visitas-fantasma do Thiago (id 115) presas como "Agendada" — 11/06/2026

Fato: 120437, 120438, 120440, 120441 (ag 10/06, criadas 10/06 ~10:24,
avulsa=false, sem abertura/fotos) são sobras do bug de fantasma do build
224 ("caso Thiago 120437" citado nos comentários do código). O job
noturno carimbou as demais visitas de 10/06 como Não Realizada, mas
PULOU estas 4 (motivo a verificar no critério do job, lado Supabase).

**EXECUTADO 11/06 (aprovado pelo Alan):** UPDATE `status_visita` 4 → 3
(Não Realizada) nas 4. Backup pré-UPDATE:
`backup_fantasmas_thiago_2026-06-11.json` (enviado ao Alan).

Pendência: amanhã (12/06) reconferir se avulsas de 11/06 não realizadas
foram carimbadas pelo job; se amanhecerem como 4, o filtro do job tem
segunda lacuna.

## David (113) — visita 122194 INTERTECHNE, 12/06/2026

Janela do pivot (defeito conhecido, instrumentado): o Finalizar do
promotor caiu no id morto ("afetou 0 linhas") e o close foi descartado
como órfão — visita ficou Em Andamento no servidor com fotos completas.
**EXECUTADO (OK do Alan):** UPDATE fechando a 122194 — status 1,
realizado=10:09 (última foto depois), checklist padrão; em seguida
dedup do array depois (9→5; o celular re-empurrou URLs no intervalo).
Backup: `backup_david_122194.json`. Correção definitiva da janela do
pivot: candidata ao próximo build (aguardando OK).
