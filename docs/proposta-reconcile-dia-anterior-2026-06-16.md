# Correção — visitas presas de D-1 pra trás (caso Thamara #5547)

Data: 2026-06-16. Aprovada pelo Alan ponto a ponto nesta sessão.

## Problema (causa raiz, verificada no log + servidor)
Uma visita antiga **sem `serverId`** (id local negativo) fica em loop no outbox:
o INSERT bate em ON CONFLICT (servidor já tem a visita do dia), o app então
busca a visita no servidor **pela hora exata** do agendamento, a hora diverge
(Thamara: local `2026-06-09T12:00:00Z`=09:00-03 vs servidor `05:00-03`),
**não acha**, lança exceção e tenta de novo pra sempre. Esse loop segura a
trava do sync (`processOutbox` ocupa o lock), então `fullSync` — único caminho
que roda o **pull da agenda do dia** — é rejeitado (`fullSync ignorado (outro
processo sincronizando)`). Resultado: **agenda de hoje vazia**.

Visitas normais do dia não sofrem: vêm do pull **com `serverId`** e sincronizam
por UPDATE direto pelo id, sem passar pela busca por hora.

## Correção
No reconcile do outbox (`sync_engine.dart`, ramo `serverId == null`, 0 rows):

1. **Buscar por DIA, não por hora** — só para visitas de **D-1 pra trás**
   (`visitaEhDeDiaAnterior`); hoje/futuro fica **inalterado**. A unicidade do
   servidor é por dia, então casa `gabarito+pdv+turno+DIA` (`boundsDiaCivilUtc`).
2. **Trava "exatamente 1, senão estaciona"** (`decidirReconcileDiaAnterior`):
   - **1 candidato** → reconcilia: grava o `serverId`, envia só trabalho novo
     (`_filtrarPayloadMinimo`), consolida, encerra.
   - **0** (contradição) ou **2+** (duplicata no servidor) → **ESTACIONA**
     (`status='error'`, sem loop) + anomalia `reconcile-ambiguo`. Nunca chuta.
3. **Trava de status (reforço do Alan):** Concluída (1) só se, no estado FINAL
   (envio ∪ servidor), houver foto **antes E depois** (no bucket + na array);
   senão **Incompleta (5)**. As URLs só entram via `getUploadedPhotoUrls` (upload
   já confirmado), então "na array" = "no bucket".
4. **Escopo ≤ D-1** → o trabalho corrente (hoje) nunca é tocado. A agenda de hoje
   volta como **consequência** de destravar o item antigo (o pull volta a rodar).

## Segurança / o que NUNCA acontece
- Não apaga visita, foto do bucket nem da galeria. Só vincula ao que o servidor
  já tem; em caso ambíguo, não grava nada.
- Não rebaixa status; não toca `dia_hora_agendado` do servidor.
- Hoje/futuro: comportamento idêntico ao atual.

## Validação antes da publicação
- `flutter analyze`: limpo (1 aviso informativo pré-existente).
- **45 testes** (35 + 10 novos em `reconcile_dia_anterior_test.dart`): verdes.
- **Simulação nos dados reais do servidor:**
  - Thamara (170, gab 1441, pdv 706, tarde, 09/06) → 1 candidato `119755` →
    **RECONCILIA, status final Concluída(1)** (antes=4, depois=5).
  - Duplicata 02/06 (ids 116546/117167) e 12/06 (122159/123109) → 2 candidatos →
    **ESTACIONA** (não grava nada).

## Fora de escopo
A **origem** da hora ter divergido (09:00 local vs 05:00 servidor) — provável
reagendamento no servidor depois que a cópia local nasceu do gabarito. O
reconcile por dia deixa o app resiliente a isso; investigar a origem fica para
um trabalho separado.
