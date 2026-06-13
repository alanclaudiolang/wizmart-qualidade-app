# Log de correções no Supabase — 13/06/2026

> Correções de registros já gravados (tabela `visitas` + bucket), feitas
> após o build 250. Regras seguidas: só UPDATE/substituição (sem exclusão
> de registros), backup antes (`/tmp/backup_supabase_20260613/`), conferência
> de marca d'água por OCR, verificação pós-correção. Promotores por id
> (repo público).

## 1. Dedup de fotos duplicadas — 25 visitas ✅
Arrays `fotos_antes`/`fotos_depois` tinham URLs idênticas repetidas (sintoma
de refazer após reset/pivot). Removidas só as repetições exatas, preservando
ordem; verificação garantiu que nenhuma URL distinta foi perdida.
Visitas: prom34 (119937,119944,119970,119971,119977,119978,119979,119980,
122539); prom49 (122383,122384); prom107 (121662); prom113 (121617,122439);
prom115 (120082,120127,122617,122635); prom119 (122527); prom335 (121627,
122035,122282); prom452 (121353,122193); prom545 (122857).
**Confirmado no servidor: zero duplicatas restantes.**

## 2. Recuperação de fotos órfãs no bucket ✅
- **prom107 / visita 122651** (MM DF - TSE SEDE): as 8 fotos do "antes"
  estavam no bucket mas o array estava vazio (0/8). Conferida a marca
  d'água (PDV/promotor/data 12/06 batem) e recuperadas → agora 8/8.

## 3. Felipe (prom34) — substituição das fotos do "antes" pelas ORIGINAIS ✅
Contexto (Alan): o bug rebaixou/reiniciou as visitas do Felipe; ele perdeu
as fotos reais do "antes" e tirou "qualquer foto" só para conseguir
finalizar. Ele enviou as fotos ORIGINAIS da galeria (32 fotos, já
carimbadas). Tratadas como definitivas.
Processo: OCR de cada foto (PDV + promotor + data/hora + **número do badge
no canto superior direito**); mapeadas para 5 visitas; cada foto substituiu
o arquivo `-antes-N` correspondente no bucket (upsert, URLs preservadas),
na ordem da numeração.
| Visita | PDV | nº fotos antes substituídas |
|---|---|---|
| 122541 | VIV FREGUESIA | 7 |
| 122539 | JARDIM ITANHANGÁ | 8 |
| 122543 | VILLA LUNA | 5 |
| 122542 | VILLA MARE | 4 |
| 122554 | PORTAL HALL | 8 |
**Total: 32 fotos, 0 erros.** Verificado por OCR pós-substituição
(ex.: 122541 antes-2 = VIV FREGUESIA / Felipe / 13:21:21 / badge 2 ✓).

## 4. Investigado — sem ação necessária
- **prom115 / visita 121455** (BETA, Incompleta 4/0): bucket tem só as 4
  fotos do "antes" — o depois NÃO foi feito. Sem perda no servidor a
  recuperar (se ele fez o depois e perdeu antes de subir, só na galeria dele).
- **Anomalias temporais prom34 (122541-543,122556) e prom107 (122262):**
  completas; o reinício passou e o promotor refez/completou.

## 5. Pendente de decisão do Alan
- **12 visitas concluídas sem `dia_hora_abertura`** (prom34 119966/119980,
  prom49 122381, prom107 122039, prom113 119161/119302/120726, prom335
  118959/119001/119170/119185, prom452 119965). Fotos corretas; falta só o
  campo abertura. Preencher exigiria aproximar a hora (não temos o clique
  real em "Iniciar") — NÃO preenchido para não "chutar". Aguarda decisão:
  deixar nulo (cosmético, não afeta nada) ou preencher com aproximação.

## 6. dia_hora_abertura preenchido — 11 visitas ✅ (procedimento documentado)
Procedimento de `feedback_recuperacao_manual_procedimento.md`:
`dia_hora_abertura = horário da 1ª foto do "antes" (marca d'água) − 30s`,
`localizacao_abertura = localizacao_fotos_antes`. Conferida a marca d'água
da 1ª foto de cada e verificado que a data bate com o dia agendado.
Preenchidas: 118959, 119001, 119161, 119170, 119185, 119302, 119965,
119980, 120726, 122039, 122381.
**PULADA: 119966** — a 1ª foto é de 04/06 mas a visita é agendada 09/06
(anomalia temporal real, já registrada como anômala em 11/06). Não
preenchida para não criar inconsistência.
