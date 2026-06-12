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

## Riscos da implantação — UM POR UM (regra 5)

Nível: 🔴 alto / 🟠 médio / 🟢 baixo. "Área de id/consolidação" é tratada
como alto risco por decisão do Alan (mudanças passadas já causaram
transtorno).

| Item | O que muda | Risco concreto (o que pode dar errado) | Nível | Mitigação / como testar antes |
|---|---|---|---|---|
| **1** Postergar consolidação enquanto a visita está em uso | `_processOutboxItem` adia o INSERT da visita sem serverId enquanto `LastVisitaService`/`ProcessingTracker`/`watermark_pending` indicarem uso | Se a flag de "em uso" não for limpa (crash da tela, `LastVisitaService.clear` não roda), a visita **nunca consolida** → fotos nunca chegam ao servidor. E o supervisor demora mais pra ver "Em Andamento" (só ao sair da visita) | 🟠 | Timeout de segurança: se a row tem >2h sem atualização, consolida assim mesmo. `dispose` já reforça resume; adicionar reforço de `clear`. Testar: abrir visita, matar o app no meio, reabrir → tem de consolidar |
| **2** Re-resolução do id novo na tela | Toda escrita da tela que afetar 0 linhas re-busca o serverId (mapa de migração) e reaplica | **Pior caso = gravar no id ERRADO** (de outra visita) se o mapa estiver trocado → corrompe a visita do colega de chave. É área de id (alto risco) | 🔴 | Mapa restrito a `idTemp→serverId` daquela visita, gravado na mesma transação do `consolidar`; reaplicar só se o id resolvido casar gabarito|pdv|turno|data da tela. Teste obrigatório com 2 visitas do mesmo PDV em semanas diferentes (colisão de idTemp determinístico) |
| **3** Guard anti-fantasma só descarta fantasma real | Descarte exige ausência TOTAL de trabalho; com trabalho e abertura nula, faz INSERT usando `abertura := createdAt` da 1ª foto | (a) Critério frouxo → fantasmas Felipe/Thamara **voltam** (visita duplicada "Em Andamento sem clique"). (b) Se a 1ª foto for de idTemp reciclado de outro dia, `createdAt` carimba **data errada** → anomalia temporal | 🟠 | (a) Exigir status local 2 OU foto no JSON OU pending_photo — fantasma não tem nenhum. (b) Só usar `createdAt` se for de HOJE; senão usa `now()`. Teste: visita com 5 fotos e abertura apagada tem de subir; vaga vazia tem de ser descartada |
| **4** Dedup de fotos na origem + índice único `(visitaId,slot,numero)` | `getUploadedPhotoUrls` distinct; índice único em `pending_photos` | **Migração de schema quebra o boot**: se um celular já tem linhas duplicadas `(visitaId,slot,numero)`, criar índice UNIQUE **falha na migração** e o app não abre. Risco sério em base instalada | 🔴 | NÃO criar índice UNIQUE direto. Fazer dedup defensivo em Dart (distinct por URL na leitura) — sem migração destrutiva. Se quiser índice, limpar duplicatas na migração ANTES de criá-lo, com try/catch que nunca derruba o boot |
| **5** Carimbo não apaga o cru se a troca no JSON não foi efetivada | `watermark_queue.dart:281-318` só deleta o raw quando `_trocarPathNoJson` confirmou a troca | Mantendo o raw e o watermarked, pode haver **upload em dobro** da mesma foto (raw + wm) se ambos entrarem no JSON. Acúmulo de arquivos raw no disco | 🟢 | Trocar a ordem: deletar o raw só DEPOIS de confirmar troca E status='pending' do wm. Raw órfão é varrido pela limpeza D-1. Teste: pivotar id no meio do carimbo → grade tem de mostrar a foto, sem duplicar |
| **6** Consolidação preserva trabalho local (merge no branch `existenteServer`) | Em vez de deletar a row local, faz MERGE dos campos de execução na row sobrevivente | 🔴 **É EXATAMENTE o bug que o código de 09-10/06 removeu de propósito**: preservar campos locais fazia "realizada virar Em Andamento" / perder `dia_hora_realizado` (Jessica/Felipe/Thamara). Reintroduzir merge mal feito **regride esse bug** | 🔴 | Merge SÓ de campos que o servidor NÃO tem (null no servidor) E só de execução de HOJE; nunca sobrescrever status nem datas já preenchidas no servidor. Teste com a sequência exata dos casos de 09/06 antes de publicar. **Se houver dúvida, NÃO mexer aqui** e resolver A1-A3 só com itens 1+2 |
| **7** Reset da largada vira UPDATE condicional atômico + insert-se-ausente | Substitui o upsert-zerador do passo 6 por `UPDATE … WHERE abertura IS NULL AND synced AND status=1` | Se a condição errar, dois caminhos ruins: (a) deixa de zerar uma vaga reciclada → `localState='finalizada'` **vaza** pra visita nova (promotor cai direto em "Visita finalizada"); (b) ainda zera numa corrida | 🟠 | Manter exatamente o conjunto de campos zerados atual; só trocar o "ler-decidir-gravar" por WHERE atômico. Teste: PDV recorrente (mesma chave 2 semanas) tem de começar do zero, sem herdar finalizada |
| **8** Pausa de sync na tela da visita INTEIRA + re-check entre push e pull | `SyncPause` liga em qualquer estado da visita; `fullSync` re-checa pausa antes do pull | Em visita longa, **nada sobe enquanto a tela está aberta** (inclui fotos antes já prontas) → acúmulo e sensação de "não sincroniza". Se um crash deixar a pausa ligada, sync trava | 🟢 | `dispose` já faz `resume()` defensivo. Pausa só bloqueia o ciclo, não perde dado. Aceitável: o upload retoma ao sair. Teste: ficar 10 min no checklist e sair → tudo sobe |
| **9** Lock com heartbeat + WorkManager só faz push | Renova o lock por lote; background deixa de rodar pull destrutivo | (a) Background não puxa mais agenda → se o promotor quase não abre o app, agenda fica velha (mas mudança de supervisor só importa com app aberto). (b) Heartbeat bugado pode **segurar o lock mais tempo** que o TTL pretendia | 🟠 | TTL continua limitando o pior caso (libera se isolate morrer). Pull continua nos gatilhos da UI (abrir app/home/voltar). Teste: 2 processos concorrentes (forçar WorkManager) não podem rodar pull+push ao mesmo tempo |
| **10** Aviso de sessão expirada vira bloqueante na home | Dialog "Entrar novamente" repetido até relogar; upload nunca monta path com segmento vazio | **Falso positivo**: uma falha transitória de auth (não expiração real) **trancaria** o promotor fora do trabalho | 🟠 | Só disparar após `refreshSession` falhar de fato (não em erro de rede transitório) — o código já distingue (`AuthSessionExpired.set()` só após refresh falhar). Não bloquear durante visita aberta. Teste: derrubar rede 30s não pode abrir o dialog; sessão realmente expirada deve abrir |
| **11** Dedup da fila de anomalias + throttle + fechar D5 antigos | 1 issue por tipo+entidade+dia; respeitar rate-limit; fechar D5 em massa | (a) Dedup pode **engolir** uma 2ª ocorrência legítima (perda de sinal). (b) Fechar D5 em massa pode fechar algum ainda não resolvido | 🟢 | Dedup só por janela de 1 dia (reabre amanhã se persistir). Fechamento em massa só dos D5 já entendidos (filtro por build/promotor), com OK. Sem impacto no app do promotor |

**Riscos transversais:**
- Promotores em versões antigas (<196) continuam expostos até atualizar —
  force-update não os alcança (item F); depende da varredura manual +
  link por WhatsApp.
- **Galeria do promotor: nenhuma das 11 mudanças toca** nela (regra 6) —
  todas operam em `pending_photos`, `outbox`, `visitas` e arquivos
  internos `wizmart_fotos/`.
- Itens 2, 4 e 6 são os 🔴 (área de id/consolidação/schema). Se o tempo
  apertar, dá pra entregar um build com 1+3+5+7+8+10 (que já mata os
  sintomas de campo) e deixar 2/4/6 para um 2º build revisado — mas
  isso contraria "não gerar infinidade de versões"; por isso a
  recomendação é fazer todos juntos COM os testes da coluna ao lado
  antes de publicar.

## Sequência de execução sugerida
1. Implementar blocos A+C+B (mesmo PR), com log de cada guard novo.
2. Blocos D, E, G no mesmo build (mudanças pequenas e independentes).
3. Revisão do diff pelo Alan → publicar com [FORCE-UPDATE].
4. Varredura [ESTADO] de builds antigos + WhatsApp com link fixo.
5. Depois do build em campo: correção dos históricos no servidor (OK
   item a item) e atualização do mapa técnico (obrigatória, regra 7).
