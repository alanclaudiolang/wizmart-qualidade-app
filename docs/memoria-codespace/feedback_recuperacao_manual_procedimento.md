---
name: recuperacao-manual-procedimento
description: "Procedimento padrão para recuperação manual de visitas com fotos no bucket — não deduzir, seguir os passos exatos já validados em David/Camila/Gabriel/Mauro/Leandro"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 5b3db7e3-0a85-41f4-a33b-0441e2dfb1ba
---

Quando o usuário sobe fotos no bucket Supabase pra recuperar visitas
de um promotor (sintoma: fotos no `abastecimentos/` raiz, sem path
determinístico, vindas do WhatsApp dele), seguir:

## 1. Identificação
- Listar arquivos uploaded "hoje" em `abastecimentos/` (raiz, sem subpasta)
- Baixar todos
- OCR pra extrair: promotor, PDV (linha "PDV: ..."), slot (antes/depois), data/hora

### Match do PDV no OCR → tabela visitas
**A linha após `PDV: ` na marca d'água é literalmente o campo
`visitas.titulo` — NÃO é uma concatenação** (verificado em
`lib/presentation/screens/visita/visita_screen.dart:793-799` e
`lib/core/utils/watermark_util.dart:107`). Caminho de geração:
- `_visita.titulo` (caso normal); senão
- `_pdv.apiLocalName` → `_pdv.apiLocalCustomerName` → `'PDV <id>'`
(fallbacks raros quando título vazio).

Pra cruzar OCR com o servidor: **normalizar ambos os lados** (lowercase,
sem acento, espaços colapsados) e comparar a string inteira após `PDV:`.
Match por nome comercial parcial (substring) é frágil — se dois PDVs
compartilham nome comercial (filiais), confunde. Ver
[[pdv-lookup-via-titulo-historico]].

## 2. Mapear visitas no servidor
- Listar visitas do promotor na(s) data(s) das fotos
- Pra cada grupo (PDV, data):
  - **Já existe na tabela visitas (qualquer status, incluindo status=3
    Falta auto-D+1)**: UPDATE no registro existente — sobrescreve
    `status=3 → status=1`. NUNCA duplicar com INSERT.
  - **NÃO existe**: chamar `gerar_datas_gabaritos_att` com `gabarito_ids`
    da rota + `data_base=data_final=data` — **fonte autorizada** dos
    campos `id_pdv_associado`, `id_gabarito_associado`, `titulo`,
    `previsao_turno_realizada`, `rota_associada`. NUNCA copiar de
    histórico (dedução).

### Conceito de faltas (status_visita=3)
- Promotor não marca falta — não existe esse botão no app
- Faltas nascem **só no servidor**, em D+1, por job automático do
  Supabase que varre visitas do dia anterior não realizadas e seta
  `status=3`
- Só existem **retroativamente** — visita de hoje ou futura nunca é
  falta
- Logo, quando recuperação é de dias anteriores: a maior parte das
  visitas-alvo provavelmente já existe na tabela com `status=3` (auto
  D+1) → faz UPDATE, nunca INSERT

## 3. Path determinístico no bucket
- `abastecimentos/<uid>/<data>_05-00-00/<nome_sanitizado>-<hash>-<slot>-<n>.jpg`
- `hash = SHA-1(gabarito_id|pdv_id|turno)` (primeiros 4 bytes como int32 positivo)
- `nome_sanitizado` = sanitizar título: remove acentos, pega 6 primeiras
  palavras, espaço→`_`, regex `[^a-zA-Z0-9._-]`→`_`
- **CUIDADO em bash:** `UID` é readonly. Usar outra variável (`U`, `MYUID`).

## 4. Upload + UPDATE/INSERT
Move (ou re-upload) cada foto pro path correto, depois faz UPDATE/INSERT
com este payload **fixo**:

```python
{
  'status_visita': 1,
  'id_pdv_associado': pdv_id,           # da Edge Function
  'id_promotor_associado': PROMOTOR_ID,
  'dia_hora_agendado': f"{data}T05:00:00-03:00",  # da Edge Function
  'rota_associada': ROTA,               # da Edge Function
  'id_gabarito_associado': gab,         # da Edge Function
  'titulo': titulo_servidor,            # da Edge Function (NÃO o do OCR)
  'previsao_turno_realizada': turno,    # da Edge Function
  'turno_realizada': turno,             # mesmo turno
  'visita_avulsa': False,               # sempre False (visita_avulsa=True
                                        # só pra inserção manual de supervisor)
  'dia_hora_abertura': primeira_antes - 30s,
  'localizacao_abertura': "LatLng(lat: X, lng: Y)",  # lat/lng do PDV
  'dia_hora_fotos_antes': última_foto_antes,
  'localizacao_fotos_antes': mesma_localizacao,
  'dia_hora_fotos_depois': última_foto_depois,
  'localizacao_fotos_depois': mesma_localizacao,
  'dia_hora_realizado': última_foto_depois,
  'localizacao_encerramento': mesma_localizacao,
  'fotos_antes': [urls...],
  'fotos_depois': [urls...],
  'sincronizada_promotor': True,
  'check_pergunta_1': True,
  'check_pergunta_2': True,
  'check_pergunta_3': True,
  'check_pergunta_4': True,
  'check_pergunta_5': True,
  'check_pergunta_6': False,
  'check_pergunta_7': False,
  'feita_no_horario': True,
}
```

## 5. Cleanup
- Apagar arquivos originais da raiz `abastecimentos/`

## Fontes dos campos — sempre verificáveis
- `pdv.lat`/`pdv.lng`: tabela `pdvs` (NÃO inferir de outras visitas)
- `titulo`: SEMPRE a string exata retornada pela Edge Function (ela
  inclui espaços duplos típicos, etc — manter literal)
- `turno`: campo `turno` do retorno da Edge Function
- `data`: derivada da marca d'água da foto (campo `dataAgendada`
  retornado pela Edge Function bate)

## Status do servidor
- 1=Concluída, 2=Em Andamento, 3=Não Realizada/Falta, 4=Agendada, 5=Incompleta
- Recuperação sempre fecha como `status_visita=1` (Concluída)
- Ver [[status-incompleta-definicao]] pra critério de Incompleta vs Concluída

## NÃO fazer
- Não inferir `id_gabarito`, `id_pdv`, `titulo`, `turno` de histórico
  (memória [[visita-avulsa-inferir-do-historico]])
- Não marcar `visita_avulsa=true` pra fotos do WhatsApp (regra Gabriel
  29/05 — usuário corrigiu)
- Não deduzir `status_visita` de quantidade de fotos
- Não usar variável `UID` no bash (readonly)
