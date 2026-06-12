# Proposta de correção consolidada — 12/06/2026

> Escrita após revisão completa do código (visita_screen, sync_engine,
> watermark_queue, app_database, home_screen, apk_updater, main) e dos
> logs de campo de hoje (issues #1048, #1408, #830, #678, #1413 + dados
> do servidor). Objetivo: **um único build** que cubra todas as
> situações de erro vistas em campo, sem deixar nada para depois.
> Nenhuma alteração foi feita ainda — aguarda OK do Alan (regra 3/3a).

## Diagnóstico consolidado (fatos, com evidência)

Todos os casos de hoje se reduzem a **6 causas-raiz**. Nenhuma nasceu no
249 (diff 245→249 = 3 mudanças defensivas; `visita_screen.dart` idêntico);
o 249 destravou a fila de relatos e expôs o que já acontecia.

### Causa A — Troca do id da visita (pivot) com a visita "em uso"
Quando o INSERT consolida idTemp→serverId (`consolidarVisitaNoServer`),
tudo que está EM VOO segurando o id antigo quebra:

| # | Sintoma em campo | Mecanismo (arquivo:linha) | Caso provado |
|---|---|---|---|
| A1 | Grade com ícones quebrados | `_trocarPathNoJson` não acha a visita (id velho), retorna em silêncio e o arquivo cru é **apagado mesmo assim** (`watermark_queue.dart:281-318`) | Renato 15:38 (print) |
| A2 | "Tirei foto e sumiu da grade" | TODAS as escritas da tela usam `widget.visitaId` imutável (`visita_screen.dart:628,636,677,1001…`); fotos pós-pivot caem no id morto; upload monta path órfão `…//visita-…` quando `getVisitaById`=null (`sync_engine.dart:1380-1443`) | Mauro UX 14:40-42 (#1408) |
| A3 | Finalizar "no vácuo" + fechamento descartado | `updateVisita`→0 linhas (log `integridade` 14:42:55) e close/photos_* descartados como ÓRFÃO (`sync_engine.dart:1055-1071`) | Mauro UX, David 122194 |
| A4 | Arrays com URLs duplicadas | refazer gera 2º conjunto de pending_photos com mesmos números; `getUploadedPhotoUrls` devolve os 2 conjuntos (mesmo nome de arquivo → mesma URL 2×) | Diego 122527 (4 dups), Renato 122383/122384 (4 e 7 dups) |
| A5 | Trabalho local descartado na consolidação | branch `existenteServer != null` **deleta a row local** (paths do grid, localState, checks ainda não enviados) e mantém a cópia-servidor sem nada disso (`app_database.dart:471-491`) | — |
| A6 | Fotos presas em watermark até reiniciar | item da fila de carimbo segura o id velho; `getPendingPhotosByVisitaSlot(idVelho)`=vazio após repontagem | — |

**Gatilho de campo:** sinal ruim no PDV → upload do antes atrasa → o
`open` (e o pivot) acontece minutos depois, quando o promotor já está na
etapa do depois ou revisitando a tela.

### Causa B — Corrida da largada (Iniciar × pull)
O passo 6 do pull lê-decide-grava sem atomicidade; o "Iniciar" (que
espera GPS por segundos) pode gravar a abertura ENTRE a leitura e o
upsert-zerador. A pausa de sync só liga em fotos_antes/depois e o
`fullSync` só checa a pausa na ENTRADA (`sync_engine.dart:262-271`) —
um pull já em voo segue até o fim.
**Provado:** Mauro INTERTEK 12:07:20 (pull salva "0 puladas" às .365,
câmera abre às .766; às 12:23:25 o guard anti-fantasma encontra a visita
sem abertura e a destrói).

### Causa C — Guard anti-fantasma mata trabalho real
`sync_engine.dart:1090-1105`: descarta visita sem serverId/abertura/
realizado **mesmo com status 2, fotos no grid e 5 fotos já no bucket**
(Mauro 12:23:25 — apagou visita + pending_photos + fila).

### Causa D — Lock entre processos expira sem renovação
TTL fixo de 240 s (`sync_engine.dart:74`); com rede ruim um push real
dura 15+ min → o lock expira no meio e o **WorkManager** (2º processo,
confirmado nos stacktraces `callbackDispatcher main.dart`) entra rodando
pull destrutivo em paralelo. Provado no log do Mauro: "outro processo
sincronizando" às 12:23:22 enquanto o próprio processo estava no meio do
push.

### Causa E — Sessão Supabase morta (403 RLS)
Refresh falha → fotos voltam a pending para sempre (attempts=0) e o
promotor fica SEMANAS sem subir nada (Adonias 25/05→12/06; log 10:43-45:
`new row violates row-level security` + "sessão expirou"). O aviso de
relogin existe mas não segura o promotor.

### Causa F — Build antigo nunca recebe o force-update
Builds < ~196 (até 05/06) bloqueiam a atualização obrigatória enquanto
`countPendentesParaSync() > 0` (verificado no código do build 186,
`e68510e`). Franciele (186) tem pendência eterna → **nunca verá o
dialog**. Ciclo vicioso: não sincroniza porque o build é velho, não
atualiza porque não sincronizou.

### G — Telemetria se auto-sabotando
A drenagem das filas (destravada pelo 249) estourou o rate-limit
secundário do GitHub (403 nos logs) → relatos novos (ex.: Renato hoje)
ficam represados atrás do ruído; D5 duplica por visita a cada ciclo.

## Correções propostas (1 build, com force-update)

### Bloco A+C — eliminar o pivot "sob os pés" e proteger trabalho real
1. **Postergar a consolidação enquanto a visita está em uso** (núcleo):
   em `_processOutboxItem`, item de visita SEM serverId é postergado
   (mesmo mecanismo "Posterga" já existente) enquanto:
   `LastVisitaService` aponta para ela (tela aberta), OU
   `ProcessingTracker` ativo para ela, OU existe foto `watermark_pending`
   de qualquer slot dela. O pivot passa a ocorrer só com o promotor fora
   da visita — A1, A2, A3 e A6 morrem por construção.
2. **Re-resolução de id na tela** (cinto de segurança): helper único —
   toda escrita da tela que afetar 0 linhas re-busca o id novo (mapa de
   migração gravado pelo `consolidar` em `sync_state`) e reaplica;
   `LastVisitaService` atualizado no pivot.
3. **Guard anti-fantasma só descarta fantasma de verdade**: descarte
   exige AUSÊNCIA TOTAL de trabalho (status local 1, sem fotos no JSON,
   sem pending_photos, sem checks). Com trabalho e abertura nula:
   prossegue com INSERT usando `dia_hora_abertura := createdAt` da 1ª
   foto antes (+ log).
4. **Dedup de fotos na origem**: `getUploadedPhotoUrls` passa a devolver
   URLs distintas (preservando ordem); índice único
   `(visitaId, slot, numero)` em pending_photos com upsert no
   re-registro — acaba com arrays duplicados.
5. **Carimbo nunca apaga o cru sem o JSON trocado**: `_trocarPathNoJson`
   re-resolve id migrado; se a troca não foi efetivada, o arquivo cru
   NÃO é apagado.
6. **Consolidação preserva trabalho local**: no branch
   `existenteServer != null`, fazer MERGE dos campos de execução locais
   (fotosJson, localState, checks/obs, datas) na row sobrevivente em vez
   de descartar.

### Bloco B — largada atômica
7. Reset do passo 6 vira UPDATE condicional atômico
   (`WHERE dia_hora_abertura IS NULL AND sync_status='synced' AND
   status_visita=1`) + insert-se-ausente; 0 linhas = pula (e loga).
8. Pausa de sync na tela da visita INTEIRA (incl. idle/abertura/
   checklist), e o `fullSync` re-checa a pausa entre push e pull.

### Bloco D — processos
9. Lock com renovação (heartbeat a cada lote) e **WorkManager passa a
   rodar só o push** (processOutbox); o pull destrutivo fica restrito ao
   processo da UI.

### Bloco E — sessão
10. `AuthSessionExpired` vira aviso BLOQUEANTE na home ("Entrar
    novamente", mesmo e-mail — dados preservados, verificado no
    softLogout), repetido a cada abertura até resolver; upload nunca
    monta path com segmento vazio (visita null/uid vazio → não sobe,
    loga).

### Bloco G — telemetria
11. Dedup na fila local (1 issue por tipo+entidade+dia), throttle de
    envio (respeita rate-limit), e os D5 antigos fecham em massa
    (operacional, com OK).

### Operacional (sem código, em paralelo)
- **Franciele e demais em builds <196**: varrer os cartões [ESTADO],
  mandar o link fixo do APK por WhatsApp (instala por cima, sem perder
  dados). A pendência dela drena com Wi-Fi + Sair→entrar.
- **Históricos no servidor** (tema separado, com OK): dedup dos arrays
  de hoje (Diego 122527; Renato 122383/122384) e dos de 08-09/06 do
  Felipe; 122381/119980/119966 sem abertura; órfãos `…//visita-…` no
  bucket.

## Riscos da implantação (regra 5)
- **Item 1** muda QUANDO o servidor passa a ver "Em Andamento" (chega ao
  sair da visita/concluir, não mais no meio). Risco baixo; com sinal ruim
  já era assim. Não toca consolidação em si.
- **Item 3** afrouxa um guard anti-duplicata: critério exige sinal
  POSITIVO de trabalho (fantasma não tem) — risco de fantasma voltar é
  baixo e monitorável (D-detector já loga).
- **Item 6/4** mexem em consolidação/payload — área de alto risco
  declarado; mudanças são aditivas (merge/dedup), sem alterar chaves nem
  fluxo de ids. Testar com cenário de redo antes de publicar.
- **Item 9** reduz frequência de pull em background — agenda atualiza ao
  abrir o app/home (gatilhos atuais da UI permanecem).
- Promotores em versões antigas continuam expostos até atualizar
  (force-update + varredura manual dos builds <196).
- Galeria do promotor: nenhuma das mudanças toca (regra 6).

## Sequência de execução sugerida
1. Implementar blocos A+C+B (mesmo PR), com log de cada guard novo.
2. Blocos D, E, G no mesmo build (mudanças pequenas e independentes).
3. Revisão do diff pelo Alan → publicar com [FORCE-UPDATE].
4. Varredura [ESTADO] de builds antigos + WhatsApp com link fixo.
5. Depois do build em campo: correção dos históricos no servidor (OK
   item a item) e atualização do mapa técnico (obrigatória, regra 7).
