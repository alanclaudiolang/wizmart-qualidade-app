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
| 119966 | 09/06 | **sem correção possível**: as 4 fotos "antes" são de 04/06 e não existe versão de 09/06; "depois" já é do dia certo (09/06 17:43) | registrar p/ supervisor — NENHUM UPDATE feito |
| 119970 | 09/06 | arrays: trocar 12 URLs `2026-06-04` → `2026-06-09` (12/12) | **EXECUTADA 11/06** — 12 trocadas |
| 119971 | 08/06 | arrays: trocar 16 URLs `2026-06-05` → `2026-06-08` (16/16) | **EXECUTADA 11/06** — 16 trocadas |
| 119977 | 08/06 | arrays: trocar 8 URLs `2026-06-05` → `2026-06-08` (8/8) | **EXECUTADA 11/06** — 8 trocadas |
| 119978 | 08/06 | arrays: trocar 14 URLs `2026-06-05` → `2026-06-08` (14/14) | **EXECUTADA 11/06** — 14 trocadas |
| 119979 | 08/06 | arrays: trocar 11 das 12 URLs (11/12) | **EXECUTADA 11/06** — 11 trocadas; mantida 1 (sem versão de 08/06) |
| 119980 | 08/06 | arrays: trocar 12 das 13 URLs (12/13). A 13ª é a foto "depois" de **outro PDV** (PORTAL CERVEJAS, 10/06 18:18) — não tem substituta; manter e registrar p/ supervisor | **EXECUTADA 11/06** — 12 trocadas; mantida a foto de PDV errado (p/ supervisor) |

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
| 117649 | Opção 1 (recomendada): NENHUM update — dados refletem o fato real (visita em 2 dias; anomalia de processo, p/ supervisor). Opção 2: só `dia_hora_fotos_depois` `2026-06-02T18:23:28` → `2026-06-04T08:06:04` (cosmético) | AGUARDANDO decisão do Alan |

## Mauro Alexandre Gomez Altamirano (id 412)

Fatos: o trabalho de 02/06 está corretamente registrado em 117034 (INTERTEK,
08:20-08:54), 117033 (G2L CANOPUS, 09:48-10:32), 117032 (CAIXA 23°,
10:50-11:00) e 117031 (CAIXA 16°, 11:05-11:21) — horários idênticos aos das
visitas anômalas e às marcas d'água. As visitas de 05 e 09/06 receberam
CÓPIA desses dados. Não existem fotos dos dias 05/09 no bucket. A 117587
(SORTE NA BET, ag 03/06) ficou "Incompleta" (vazia) porque o trabalho de
03/06 caiu na 120351 (ag 05/06).

| Visita | Agendada | UPDATE proposto | Obs |
|---|---|---|---|
| 119493 | 05/06 | limpar campos copiados (`dia_hora_abertura/realizado/fotos_antes/fotos_depois` → NULO; arrays `fotos_antes/fotos_depois` → vazios; `status_visita` 1 → 3 Não Realizada) | dados copiados de 117034; supervisor já tinha reprovado | PROPOSTA |
| 119512 | 09/06 | idem (cópia de 117033) | PROPOSTA |
| 119526 | 09/06 | idem (cópia de 117032) | PROPOSTA |
| 119529 | 09/06 | idem (cópia de 117031) | PROPOSTA |
| 120351 | 05/06 | 1º UPDATE em **117587** (ag 03/06): receber o trabalho real (abertura 03/06 12:37, realizado 03/06 13:19, arrays de fotos, status 1); 2º UPDATE em **120351**: limpar campos copiados e `status_visita` → 3 | move o trabalho para o dia certo sem criar/excluir registros | PROPOSTA |

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
