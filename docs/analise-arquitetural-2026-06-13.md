# Análise arquitetural — leitura de 100% do código (13/06/2026)

> Feita a pedido do Alan, que cobrou (com razão) profundidade: "você tem
> que estar com 100% do código na memória para garantir que a solução de
> cada causa-raiz não gere outros bugs por cegueira". Este documento é o
> resultado da leitura sistemática de `lib/` inteiro + o mapa de TODOS os
> pontos que escrevem nas tabelas críticas. **Nenhuma alteração de código
> foi feita.** Substitui a parte de "como corrigir" da proposta anterior
> (`docs/proposta-correcao-completa-2026-06-12.md`), que estava rasa na
> arquitetura.

## 1. Cobertura da leitura (honesto)

**Lido a fundo (100% das linhas) — todo o caminho de dados crítico:**
`visita_screen.dart` (1980), `sync_engine.dart` (1595), `app_database.dart`
(823) + esquema, `home_screen.dart` (1108), `watermark_queue.dart` (399),
`watermark_util.dart`, `main.dart`, `app_router.dart`, `auth_screen.dart`,
`anomalia_reporter.dart`, `anomalia_queue_processor.dart`,
`error_reporter.dart`, `error_classifier.dart`, `logout_service.dart`,
`version_check_service.dart`, `connectivity_service.dart`,
`session_service.dart`, `sync_pause.dart`, `processing_tracker.dart`,
`auth_session_expired.dart`, `last_visita_service.dart`,
`current_screen.dart`, `app_constants.dart`, `gps_guard.dart`,
`permissions_guard.dart`, `programado_screen.dart`,
`promotor_estado_reporter.dart`, `apk_updater_service.dart`.

**Não lido linha a linha (confirmado IRRELEVANTE às 6 causas por grep de
escrita):** `realizado_screen`, `faltas_screen` (só LEEM do servidor),
`onboarding_permissoes_screen`, `gps_status_service`,
`permissions_status_service`, `device_info_service`, `persistent_logger`,
`sync_logger`, `performance_profile`, `syncing_indicator`,
`processing_indicator`, `apk_download_dialog`, `app_colors`,
`permission_help_button`. **Prova de que não escrevem em
visitas/pending_photos/outbox:** o grep de TODOS os pontos de escrita
(seção 2) não retorna nenhum deles.

## 2. Mapa COMPLETO de escritas nas tabelas críticas

Todo ponto que muda `visitas`, `pending_photos` ou `outbox_items` no app.
Esta é a superfície que qualquer correção precisa considerar.

### Tabela `visitas`
| Local | Linha | Por qual id | Quando |
|---|---|---|---|
| visita_screen `_sairParaHome` | 155 | `widget.visitaId` (imutável) | checklist→fotos_depois |
| visita_screen `_descartarFotosDaEtapa` | 274, 288 | `widget.visitaId` | descarte de fotos |
| visita_screen `_loadVisita` | 350 | `widget.visitaId` | correção localState no load |
| visita_screen `_persistir*`/`_salvar*`/`_ordem` | 627,635,650,659,754,760 | `widget.visitaId` | cada foto tirada/movida |
| visita_screen `_iniciarVisita` | 788 | `widget.visitaId` | grava abertura (local) |
| visita_screen `_concluirFotosAntes` | 875 | `widget.visitaId` | status 1→2 |
| visita_screen `_concluirFotosDepois` | 944 | `widget.visitaId` | →checklist |
| visita_screen `_finalizarVisita` | 1000 | `widget.visitaId` | status →3 (loga se 0 linhas) |
| watermark_queue regrava JSON | 334,339 | `item.visitaId` (imutável) | fim do carimbo |
| watermark_queue `_trocarPathNoJson` | 372,377 | `item.visitaId` | troca raw→wm |
| sync_engine pull upsert | 436,500,567,606 | `serverId`/`idTemp` | destruir+rebaixar |
| sync_engine UPDATE pós-envio | 1250 | `entityId` | marca synced |
| sync_engine foto uploaded | 1473 | `photo.visitaId` | marca visita pending |
| **consolidarVisitaNoServer** | db:444-507 | **migra PK idTemp→serverId** | no INSERT do 'open' |
| deleteVisitasSincronizadasSemPendencias | db:375 | promotor | purga do pull |
| deleteVisitaById | db:695 | id | guard fantasma |
| logoutCompletely | logout:119 | todas | troca de conta |

### Tabela `pending_photos`
visita_screen: 675 (insert da foto), 266/742 (delete por path). 
watermark_queue: 238/269/324 (status). sync_engine: 1360/1369/1408/1466/
1504/1545 (estados de upload), 1101 (delete em massa do guard fantasma).
logoutCompletely: 117.

### Tabela `outbox_items`
visita_screen: 1096 (insert open/close). sync_engine: 1047/1294 (update),
1070/1103/1256 (delete), 1481 (insert photos_antes/depois).

## 3. A descoberta central (raiz de TODA a Causa A)

O esquema declara, em `app_database.dart:76-80`, o invariante de design:

> "O 'id' local nunca muda, evitando bugs de referência (PendingPhotos,
> OutboxItems)."

**`consolidarVisitaNoServer` VIOLA esse invariante.** Ele migra a chave
primária de `idTemp` para `serverId` (`db:489,494-501` — deleta a row
idTemp, cria/atualiza a row serverId). Foi introduzido em 27/05 (commit
8a90d9e) para resolver um conflito real: o pull faz `upsert` com
`id = serverId` (db:436), então se a tela mantivesse PK=idTemp e o pull
criasse PK=serverId, ficariam DUAS rows da mesma visita.

O efeito colateral fatal: **a VisitaScreen e a WatermarkQueue escrevem por
um id IMUTÁVEL** capturado na criação (`widget.visitaId`, `item.visitaId`).
Quando a consolidação troca a PK **enquanto a tela está aberta**, todo
escritor subsequente aponta para uma PK que não existe mais:

- `updateVisita(idTemp)` → 0 linhas, silencioso (só o finalizar loga).
  → Foto some da grade, Finalizar no vácuo (A1, A2, A3).
- `insertPendingPhoto(visitaId: idTemp)` na linha 675 → foto órfã no id
  morto; o upload monta path `…//visita-<hash>-…` e o `_processOutboxItem`
  descarta como ÓRFÃO (sync:1055-1071). → fotos do "depois" descartadas.

**Quando isso dispara:** rede ruim no PDV → o 'open' fica postergado
(fotos antes em watermark/upload) → o promotor reabre a visita e vai para
fotos_depois → o 'open' finalmente processa e consolida **com a tela
aberta em fotos_depois**. Exatamente a sequência provada nos logs de
Mauro (UX, 14:40-43) e David (122194).

## 4. Duas arquiteturas possíveis para a Causa A (com trade-off)

### Arquitetura 1 — adiar a consolidação enquanto há escritor ativo
Postergar o INSERT/consolidação (em `_processOutboxItem`, item de visita
sem serverId) enquanto a visita está "em uso": `LastVisitaService` aponta
para ela (tela aberta) OU `ProcessingTracker` ativo OU há foto
`watermark_pending`. A consolidação só ocorre com o promotor FORA da
visita → a PK nunca muda sob os pés do escritor.
- **Toca:** só `_processOutboxItem` (sync_engine), reusando o mecanismo
  "Posterga" que já existe ali. Cirúrgico.
- **Risco:** se `LastVisitaService` não for limpo (crash da tela), a
  visita não consolida → fotos não sobem. Mitigável com timeout de
  segurança (consolida assim mesmo se a row tem >2h sem progresso).
- **Nível: 🟠 médio.** Não altera a lógica de consolidação em si.

### Arquitetura 2 — honrar o invariante: a PK NUNCA muda
Fazer o que o esquema já promete: id local imutável; `serverId` é só um
campo. O pull pararia de fazer upsert com `id=serverId` e passaria a casar
a visita por `serverId` (campo) quando existir, escrevendo na PK local
original. A consolidação só preencheria o campo `serverId`, sem deletar/
recriar row.
- **Toca:** TODO o pull (`_pullVisitasDia` 436-628), `consolidarVisitaNoServer`,
  e a forma como `getVisitaById` é usada no sync. É refatoração ampla.
- **Risco:** 🔴 alto — reescreve o coração do pull, área de 3 rodadas de
  bug. Ganho de robustez maior, mas custo e risco de regressão altos.
- **Nível: 🔴 alto.**

**Recomendação:** Arquitetura 1. Resolve a Causa A de raiz (a PK não migra
enquanto alguém escreve) com superfície mínima. O cinto de segurança
abaixo (re-resolução de id) cobre o resíduo. A Arquitetura 2 NÃO fica como
pendência: é descartada salvo evidência nos testes de que o item 1 é
insuficiente (decisão registrada no plano mestre).

## 5. As 6 causas — pontos exatos + correção + por que não regride

(detalhamento mantém o da proposta de 12/06, agora ancorado no mapa acima)

| Causa | Pontos exatos a tocar | Correção | Por que não gera regressão |
|---|---|---|---|
| **A** pivot sob os pés | sync `_processOutboxItem` 995-1045 (adiar) + visita_screen helper de re-resolução nas 12 escritas por `widget.visitaId` + watermark_queue `_trocarPathNoJson` 349 | Arq.1 + re-resolver id em 0-linhas + não apagar raw sem troca | Adiar usa mecanismo existente; re-resolução só age quando hoje já falha (0 linhas); raw órfão é varrido pela limpeza D-1 |
| **B** corrida da largada | sync passo 6 `_pullVisitasDia` 467-540 (reset) + `SyncPause`/`fullSync` 262-271 | UPDATE condicional atômico (`WHERE abertura IS NULL`) + pausa na tela inteira | Mantém exatamente os campos zerados atuais; só troca ler-decidir-gravar por WHERE atômico |
| **C** guard mata trabalho | sync `_processOutboxItem` 1090-1105 | exigir ausência TOTAL de trabalho (status 2/fotos/pending) antes de descartar; com trabalho e abertura nula, INSERT usando createdAt de HOJE | fantasma real (Felipe/Thamara) não tem nenhum sinal de trabalho → continua descartado |
| **D** lock TTL fixo | db `tryAcquireSyncLock` 771 + sync `_runExclusive` 88-106 + main callbackDispatcher 66-73 | renovar lock por lote (reescrever lastPullAt) + WorkManager só `processOutbox` | TTL continua limitando pior caso; pull segue nos gatilhos da UI (home/resume/reconexão) |
| **E** sessão morta | sync `_processPhotoUpload` 1389-1414 + home `_handleAuthExpired` 86 | aviso persistente até relogar; nunca subir com authUid vazio | já existe o flag `AuthSessionExpired`; só reforça e cobre o caso "tela de visita aberta" |
| **F** build antigo preso | (operacional) | varredura [ESTADO] + link WhatsApp; já corrigido no código ≥196 (não bloqueia update por pendência) | nenhuma mudança de código nova |

### Dedup de fotos (A4) — REVISADO após ler `getUploadedPhotoUrls`
A versão segura NÃO mexe no schema (evita o risco 🔴 do índice UNIQUE
quebrar o boot por migração). `getUploadedPhotoUrls` (db:724) já lê
ordenado por número; basta torná-lo **distinct por URL preservando a
ordem** — 3 linhas em Dart, zero migração. Resolve os arrays duplicados
(Diego/Renato) na origem do payload.

### Telemetria (G) — REVISADO após ler `anomalia_reporter`
O cooldown de 10 min já existe (`_cooldownMinutos`, por tipo+entidade). O
volume de hoje veio de visitas presas DISTINTAS (cada uma é entidade
diferente). Correção: estender o cooldown para 1 dia nos tipos
automáticos (D5/D3). Toca só `AnomaliaReporter._cooldownMinutos` + a chave
de cooldown. Risco 🟢.

## 6. Sequência recomendada
1. Arquitetura 1 (Causa A núcleo) + re-resolução de id + raw guard.
2. Causa B (reset atômico + pausa tela inteira) e Causa C (guard) — mesmo
   PR, são o mesmo arquivo `_processOutboxItem`/pull.
3. Causa D (lock heartbeat + WorkManager só push) e E (sessão).
4. Dedup distinct (A4) e cooldown 1 dia (G).
5. Cada item com seu teste reproduzindo o bug ANTES (deve falhar no código
   atual). Build de TESTE (`v-dev`, instala lado a lado) validado no
   celular real antes de produção. APK 249 guardado como rollback.
6. Atualizar o mapa técnico `docs/fluxo-e-gatilhos-app.md` (regra 7).

A Arquitetura 2 (honrar "id local nunca muda") NÃO fica como pendência: é
descartada salvo evidência nos testes de que a Arquitetura 1 é
insuficiente. O custo/risco de reescrever o pull hoje não se justifica
frente à Arquitetura 1, que resolve a Causa A de raiz.
