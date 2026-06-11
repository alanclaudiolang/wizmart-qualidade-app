# Mapa técnico do app — fluxos e gatilhos (granular)

> Gerado em 11/06/2026 a partir da leitura integral do código.
> **Propósito:** dar a granularidade necessária para propor alterações sem
> reestudar todo o código (regra 7 do CLAUDE.md).
> **Manutenção:** este documento DEVE ser atualizado em todo commit que
> alterar comportamento descrito aqui — mapa desatualizado é pior que
> nenhum mapa.
>
> Convenção: toda afirmação cita `arquivo:linha`. Status do servidor
> (tabela `status_visita`): 1=Concluída 2=Em Andamento 3=Não Realizada
> 4=Agendada 5=Incompleta. Status local do app: 1=agendada 2=andamento
> 3=realizada 5=(rotulado "falta" no código; equivale a Incompleta no
> servidor).

## ⚠️ MUDANÇAS DE COMPORTAMENTO — build de 11/06/2026 (pós-240)

> As linhas citadas no corpo deste mapa refletem o código ANTERIOR a
> estas mudanças; os trechos abaixo prevalecem onde houver diferença.

1. **Purga do pull condicionada à Edge Function** (`sync_engine.dart`,
   passo 5 do `_pullVisitasDia`): a purga "destruir + re-baixar" agora SÓ
   roda se a Edge Function respondeu HTTP 200. Function falhou = purga
   pulada (não esvazia mais a home — caso Thamara 11/06).
2. **Limpeza D-1** (`sync_engine.dart`, `_limparD1Sincronizada`, chamada
   ao fim do `_pullAllImpl`): roda 1x por dia (gate `limpeza_d1` em
   `sync_state`). APAGA do celular a linha de `pending_photos` e o
   arquivo interno (`wizmart_fotos/`) de fotos `uploaded` de DIAS
   ANTERIORES cuja URL foi CONFERIDA no array da visita NO SERVIDOR.
   Nunca apaga: trabalho de hoje; foto não confirmada no servidor;
   foto de visita local ainda não concluída+synced (grid em uso);
   id temporário órfão (sem como confirmar); e NUNCA a galeria do
   celular. Teto: 15 visitas consultadas por rodada (o resto fica
   para o dia seguinte). Log no canal `limpeza-d1`.
3. **D5 anti-ruído (C1)** (`sync_engine.dart`, detector D5): antes de
   enfileirar a anomalia, lê o `last_error` do outbox da visita; se casa
   com padrão de rede transitória
   (`ErrorClassifier.textoPareceRedeTransitoria`, novo helper público em
   `error_classifier.dart`), o alerta é silenciado (só log).
4. **D2 anti-ruído (C2)** (`watermark_queue.dart`, detector D2): o alerta
   só dispara se a ETAPA do slot já foi concluída (localState avançou) e
   a foto segue presa >30 min. Durante a captura (localState ainda na
   etapa do slot), silencia — elimina o alarme falso por design
   (#602/#614/#627).
5. **Guard `mounted` no `_loadVisita`** (`visita_screen.dart`): dois
   `if (!mounted) return;` após os awaits (antes dos `setState` de
   ~linha 302 e ~350) — corrige o crash fatal de boot da issue #621.

---

# PARTE 1 — Boot, ciclo de vida e telas

# Boot, Ciclo de Vida e Telas — Promotor WizMart (documentação técnica)

> Fatos verificados diretamente no código em 11/06/2026. Todas as referências no formato `arquivo:linha`.

---

## 1. Sequência completa do boot

### 1.1. `main()` — ordem exata de inicialização

| # | Passo | Referência |
|---|-------|------------|
| 1 | `WidgetsFlutterBinding.ensureInitialized()` | `lib/main.dart:85` |
| 2 | Instala `FlutterError.onError` → reporta erro Flutter não tratado como issue no GitHub (cooldown 5 min por tela; label `screen:<nome>` via `CurrentScreen`) | `lib/main.dart:90-98` |
| 3 | Instala `PlatformDispatcher.instance.onError` → erros assíncronos não tratados | `lib/main.dart:101-109` |
| 4 | Abre `runZonedGuarded` | `lib/main.dart:111` |
| 5 | `Supabase.initialize(url, anonKey)` — se falhar, guarda em `_initError` (`lib/main.dart:82`) e o app sobe mesmo assim | `lib/main.dart:113-119` |
| 6 | `Workmanager().initialize(callbackDispatcher)` + `registerPeriodicTask` (ver §1.4) — falha também só preenche `_initError` | `lib/main.dart:121-132` |
| 7 | `runApp(ProviderScope(child: WizMartApp(initError: _initError)))` | `lib/main.dart:134` |
| 8 | Handler do `runZonedGuarded`: erro fatal no boot → tenta `ErrorReporter.reportar(screen:'boot')` e mostra `_ErrorScreen` (versão amigável se o issue foi criado; versão "tire um print" se offline) | `lib/main.dart:135-156`, `lib/main.dart:263-296` |

Se `initError != null`, o `build` do `WizMartApp` renderiza só a `_ErrorScreen` e nada mais sobe (`lib/main.dart:223-228`).

### 1.2. Roteamento inicial — `/splash` (`_SplashRedirect`)

Rota inicial é `/splash` (`lib/core/utils/app_router.dart:24`). Cada navegação passa pelo `redirect` do GoRouter que só atualiza `CurrentScreen.setFromLocation` (rótulo de issues) e nunca redireciona (`lib/core/utils/app_router.dart:28-31`).

Sequência do `_redirect()` (`lib/core/utils/app_router.dart:96-181`):

1. **Delay de 300 ms** (`app_router.dart:97`).
2. **Recovery de estados presos** (dentro de try que não pode bloquear o boot, `app_router.dart:111-120`):
   - `db.resetUploadingNoBoot()` (`app_router.dart:113`) → `UPDATE pending_photos SET status='pending', next_retry_at=agora WHERE status='uploading'` (`lib/core/database/app_database.dart:565-574`). Seguro porque o upload pro Storage usa `x-upsert: true` — retry é idempotente (`app_database.dart:562-564`). Se resetou >0, grava no `PersistentLogger` canal `boot` (`app_router.dart:114-116`).
   - `wmQueue.recoverPendingOnBoot()` (`app_router.dart:118-119`) → lê `getStaleWatermarkPending()` (todas as `pending_photos` com `status='watermark_pending'`, `app_database.dart:579-583`), agrupa por par único `(visitaId, slot)`, descarta pares cuja visita não existe mais no DB, e re-enfileira no `WatermarkQueueService` (`lib/core/utils/watermark_queue.dart:89-131`). Idempotente: o processador detecta foto que já tem watermark (path sem `_raw.`) e só atualiza status sem re-renderizar (`watermark_queue.dart:217-228`).
   - **Motivo histórico documentado**: sem esse recovery, fotos congeladas em `uploading`/`watermark_pending` faziam `countFotosEmProgresso` retornar sempre >0 e o outbox da visita postergava eternamente — visita nunca consolidava no servidor (**caso Glaucia/Camila/Thiago no build 220**, `app_router.dart:100-110`; ver também `app_database.dart:552-560` e `app_database.dart:698-718`).
3. **Checagem de sessão**: `SessionService.hasSession()` (`app_router.dart:122`) — lê `wizmart_user_id` do `FlutterSecureStorage` (`lib/core/utils/session_service.dart:41-44`). Sem sessão → `context.go('/auth')` (`app_router.dart:123-125`). Com sessão mas `getSession()` nulo → `/auth` também (`app_router.dart:128-133`).
4. **`DeviceInfoService.updateForEmail(session.email)`** em background, sem await (`app_router.dart:136-138`).
5. **Retomada de visita aberta**: lê `LastVisitaService.get()` (pref `last_visita_id`, `lib/core/utils/last_visita_service.dart:22-25`). Se existir, **valida que a visita ainda existe no DB local** via `db.getVisitaById` (`app_router.dart:150-156`); se existe → `context.go('/visita/$lastVisitaId')` (`app_router.dart:157`); se está morta (sync limpou a visita ou idTemp foi reconciliado) → `LastVisitaService.clear()` e segue pra home (`app_router.dart:160-163`). Validação adicionada após o **caso da reinstalação do Edilson em produção (2026-05)**, em que o usuário ficava preso numa tela "Visita não encontrada" sem botão voltar (`app_router.dart:143-149`). O `last_visita_id` é setado no `initState` da `VisitaScreen` e limpo só quando o promotor sai explicitamente da visita (`last_visita_service.dart:8-10`).
6. **Onboarding de permissões**: `OnboardingPermissoesScreen.jaConcluido()` (flag `onboarding_permissoes_concluido` em SharedPreferences, `lib/presentation/screens/auth/onboarding_permissoes_screen.dart:27,36-39`). Não concluído → `/onboarding-permissoes` (`app_router.dart:172-178`); senão → `/home` (`app_router.dart:180`).

### 1.3. Migrações de schema (Drift, `schemaVersion = 5`)

Declarado em `lib/core/database/app_database.dart:240`; `MigrationStrategy.onUpgrade` em `app_database.dart:243-282`:

| Versão | O que fez | Referência |
|--------|-----------|------------|
| `from < 2` | Adiciona colunas em `visitas`: `titulo`, `previsao_turno_realizada`, `visita_avulsa` | `app_database.dart:245-249` |
| `from < 3` | Adiciona `visitas.server_id` + `UPDATE visitas SET server_id = id WHERE id > 0` (visitas com id positivo já vieram sincronizadas do servidor) | `app_database.dart:250-256` |
| `from < 4` | **Limpeza de órfãs**: `DELETE FROM pending_photos WHERE visita_id NOT IN (SELECT id FROM visitas)` e `DELETE FROM outbox_items WHERE entity_type='visita' AND entity_id NOT IN (...)`. Remove órfãs do **bug pré-build 202 com hash não-determinístico** que deixava o outbox em "Posterga infinito" | `app_database.dart:257-270` |
| `from < 5` | Cria tabelas `pending_issues` e `pending_bug_photos` (filas locais de anomalia) e adiciona coluna `pending_photos.last_error` | `app_database.dart:271-280` |

### 1.4. WorkManager — sync em background

- **Task periódica** `wizmart_bg_sync` (`lib/main.dart:24`): registrada no boot com `frequency = 15 min` (`AppConstants.syncIntervalMinutes`, `lib/core/constants/app_constants.dart:14-18` — 15 min é o **piso** do Android; em Doze/App Standby o intervalo real pode ser bem maior), constraint `NetworkType.connected` e `ExistingPeriodicWorkPolicy.keep` (`lib/main.dart:123-129`).
- **Task one-off** `wizmart_oneoff_sync` (`lib/main.dart:25`, `scheduleOneOffSync()` em `lib/main.dart:31-42`): enfileirada sob demanda, constraint de rede, `ExistingWorkPolicy.keep`, backoff exponencial de 30 s. Comentário: único gatilho de background dependável quando o app não está rodando (Doze Mode) (`lib/main.dart:27-30`).
- **O que a task faz** (`callbackDispatcher`, `lib/main.dart:44-79`, roda em isolate separado):
  1. Se `SyncPause.isPaused()` (pausa durante captura de fotos) → retorna sem fazer nada (`main.dart:48-51`).
  2. `pingSupabase()` — ping **real** no servidor; "ter rede" no Android não garante que o servidor responde (captive portal, DNS quebrado). Falhou → retorna sem inicializar nada (`main.dart:52-57`).
  3. `Supabase.initialize` + cria `AppDatabase` + `SyncEngine` próprios do isolate (`main.dart:59-65`).
  4. Com sessão → `syncEngine.fullSync(session.userId)` (push + pull); sem sessão → só `syncEngine.processOutbox()` (push do que sobrou) (`main.dart:66-73`). Fecha o DB ao final (`main.dart:74`).

### 1.5. Gatilhos de sync no ciclo de vida (foreground)

- **App volta ao foreground** (`AppLifecycleState.resumed`): re-checa GPS e permissões (não há stream nativa — polling no lifecycle) e chama `_kickSync()` (`lib/main.dart:208-219`).
- **`_kickSync()`** (`lib/main.dart:185-206`): só roda se `connectivityProvider` está online; com sessão faz `fullSync` e invalida `contadoresProvider`, `pdvsProvider`, `visitasHojeProvider` **e `appVersionProvider`** (sem essa invalidação o `FutureProvider` ficava cacheado pra sempre e o promotor nunca via o badge "atualizar", `main.dart:199-202`); sem sessão faz só `processOutbox`.
- **Rede voltou (offline → online)**: `ref.listen(connectivityProvider)` no `build` do `WizMartApp` chama `_kickSync()` (`lib/main.dart:230-235`).
- A `HomeScreen` tem gatilhos próprios adicionais (ver §4.1).
- O `WatermarkQueueService` dispara `fullSync` automaticamente ao terminar de processar a fila (`watermark_queue.dart:157-158, 368-378`).

---

## 2. Login, logout e troca de promotor

### 2.1. Armazenamento de sessão

- **SecureStorage** (`FlutterSecureStorage` com `encryptedSharedPreferences`): chaves `wizmart_user_id`, `wizmart_email`, `wizmart_nome`, `wizmart_senha` (`lib/core/utils/session_service.dart:6-13`). A senha só é gravada se "Lembre de mim" estiver ligado (`session_service.dart:24-26`; `auth_screen.dart:200` passa `senhaHash: _lembrarMe ? senha : ''`).
- **SharedPreferences**: `last_logged_email` (`lib/core/utils/logout_service.dart:44`), `last_visita_id`, `onboarding_permissoes_concluido`, flags de sync.

### 2.2. Login (`AuthScreen._entrar`, `lib/presentation/screens/auth/auth_screen.dart:98-261`)

1. **Pré-check de troca de conta** (`auth_screen.dart:107-165`): se `last_logged_email` existe, é diferente do e-mail digitado **e** `db.countPendentesParaSync() > 0` (outbox pending/processing + fotos pending/uploading/error + visitas com `sync_status='pending'`, `app_database.dart:588-606`) → dialog "Conta diferente neste dispositivo" avisando que as pendências do dono anterior serão apagadas (`auth_screen.dart:124-152`). Cancelou → aborta o login (`auth_screen.dart:153-156`). Confirmou → **`LogoutService.logoutCompletely(db)` ANTES do signIn** (`auth_screen.dart:157-158`). Erro no pré-check é engolido e o login segue (pior caso documentado: dados de outra conta misturam — raríssimo e recuperável, `auth_screen.dart:161-165`).
2. `signInWithPassword` com timeout de 15 s (`auth_screen.dart:168-170`).
3. Busca em `users` por `uid` (`select('id,nome,email,ativo,tipo_user')`, `auth_screen.dart:175-179`). Recusas (todas com `signOut` imediato): usuário não encontrado (`auth_screen.dart:180-184`), `ativo == false` (`auth_screen.dart:185-189`), `tipo_user != 3` — acesso apenas Promotores (`auth_screen.dart:190-194`).
4. `SessionService.saveSession(...)` (`auth_screen.dart:196-201`); grava `last_logged_email` (`auth_screen.dart:204-207`); `AuthSessionExpired.reset()` (`auth_screen.dart:210`); `DeviceInfoService.updateForEmail` e `PromotorEstadoReporter.registrar` em fire-and-forget (`auth_screen.dart:213-223`).
5. Navega: onboarding já concluído → `/home`, senão → `/onboarding-permissoes` (`auth_screen.dart:226-229`).

A tela também: pré-preenche e-mail da sessão ou do `last_logged_email` (caso típico pós-soft-logout, `auth_screen.dart:71-88`); pinga o Supabase a cada 30 s pra exibir Online/Offline/Servidor inacessível (`auth_screen.dart:51, 54-69`).

### 2.3. Soft logout (`LogoutService.softLogout`, `lib/core/utils/logout_service.dart:51-83`)

Usado pelo botão "Sair" (home `home_screen.dart:324`, programado `programado_screen.dart:157`, faltas `faltas_screen.dart:109`, realizado `realizado_screen.dart:118`) e pela detecção automática de sessão Auth expirada (`home_screen.dart:86-105` — sentinela `AuthSessionExpired` setada pelo sync engine/upload quando `currentUser==null` e refresh falha; ouvida no `initState` da home, `home_screen.dart:75`).

| Ação | O quê |
|------|-------|
| **Grava** | `last_logged_email` em SharedPreferences (antes de qualquer limpeza, pra sobreviver mesmo com Auth já morta; aceita e-mail do caller) — `logout_service.dart:52-64` |
| **Apaga** | Sessão Supabase Auth (`signOut` com timeout 5 s, `logout_service.dart:66-72`); SecureStorage inteiro via `SessionService.clearSession()` → `_storage.deleteAll()` (`logout_service.dart:74-78`; `session_service.dart:46-48`) |
| **Preserva** | SharedPreferences gerais, todas as tabelas Drift (visitas, fotos pendentes, outbox, PDVs, gabaritos), arquivos físicos, tarefas WorkManager — explicitamente "NÃO mexe" (`logout_service.dart:80-83`) |

Relogar com o **mesmo e-mail** retoma tudo de onde parou; com **e-mail diferente** cai no pré-check do §2.2 (`logout_service.dart:3-13`).

### 2.4. Logout completo (`LogoutService.logoutCompletely`, `logout_service.dart:88-144`)

Roda **só** quando a AuthScreen detecta troca de conta confirmada (ou caso especial explícito). Etapas, cada uma com try/catch individual (falha não interrompe a limpeza, `logout_service.dart:22-24`):

1. `signOut` Supabase com timeout 5 s (`logout_service.dart:91-95`).
2. `SessionService.clearSession()` — SecureStorage (`logout_service.dart:97-100`).
3. `SharedPreferences.clear()` (inclui `last_logged_email`, `sync_paused`, `last_visita_id`) + `LastVisitaService.clear()` (`logout_service.dart:102-110`).
4. Transação Drift apagando **todas** as tabelas do promotor: `pending_photos`, `outbox_items`, `visitas`, `pdvs`, `gabaritos`, `users`, `sync_state` — mantém o arquivo do DB (só apaga rows) pra não quebrar Streams ativos (`logout_service.dart:112-125`).
5. Apaga diretórios internos `wizmart_fotos/` e `wizmart_bugs/` (`logout_service.dart:127-136`). **Não toca na galeria do celular** — coerente com a regra do projeto (o app só adiciona via `Gal.putImage`, `watermark_queue.dart:278`).
6. `Workmanager().cancelAll()` — pra task não acordar com sessão antiga (`logout_service.dart:138-143`).

### 2.5. Sessão expirada (fluxo automático)

`_handleAuthExpired` na home (`home_screen.dart:86-105`): faz **soft** logout (dados locais intactos), mostra snackbar "Sua sessão expirou... suas visitas e fotos continuam salvas" e navega pra `/auth`. O flag é limpo no próximo login bem-sucedido (`auth_screen.dart:208-210`).

---

## 3. Checagem de versão e atualização (Android apenas)

### 3.1. Consulta ao release `v-latest`

`VersionCheckService.check()` (`lib/core/network/version_check_service.dart:95-163`):

- GET em `https://api.github.com/repos/alanclaudiolang/wizmart-qualidade-app/releases/tags/v-latest`, timeout 6 s (`version_check_service.dart:89-99`). **Qualquer falha retorna `upToDate`** — usuário não pode ser alarmado por instabilidade da API (`version_check_service.dart:92-94, 160-162`).
- Extrai o build do asset variável `wizmart-app-v<version>-build<NN>-<timestamp>.apk` via regex `build(\d+)` (`version_check_service.dart:109-119`).
- **URL de download = asset de nome fixo `promotor-wizmart.apk`** (URL estável entre releases); cai pro asset variável se o fixo não existir (`version_check_service.dart:121-129`).
- `outdated` = build remoto numérico > build local (`AppConstants.buildNumber`, dart-define); local não-numérico ("dev") conta como desatualizado (`version_check_service.dart:131-139`).
- `forceUpdate` = body do release contém `[FORCE-UPDATE]` (case-insensitive) (`version_check_service.dart:147-151`). Pra ativar: editar a descrição do release no GitHub (`version_check_service.dart:29-33`).
- `appVersionProvider`: `FutureProvider` que checa uma vez e cacheia; re-checagem só via `ref.invalidate` (feito em `_kickSync` `main.dart:202`, `_triggerSync` da home `home_screen.dart:137`, volta da rede `home_screen.dart:425`). **iOS sempre retorna `upToDate`** (TestFlight cuida das atualizações; Apple proíbe OTA) (`version_check_service.dart:166-176`).

### 3.2. Regra de obrigatoriedade (`atualizacaoObrigatoria`, `version_check_service.dart:54-67`)

Obrigatória quando `outdated` **e** (um dos dois):
1. `forceUpdate` (marker `[FORCE-UPDATE]`) → imediato;
2. **D+1**: hoje é dia **posterior** à data de compilação do APK **instalado** (`AppConstants.buildTime`, formato `dd/MM/yyyy HH:mm`, parseado em `version_check_service.dart:72-83`). Em dev (`BUILD_TIME='local'`) o D+1 nunca dispara. Bug histórico documentado: antes usava `published_at` do `v-latest`, mas o workflow apaga/recria o release a cada push e o timestamp resetava — promotor 2+ dias atrasado nunca era forçado (`version_check_service.dart:46-53`).

### 3.3. Bloqueio na Home (logado)

`ref.listen(appVersionProvider)` (`home_screen.dart:429-444`): dispara `_mostrarBloqueioObrigatorio` quando `atualizacaoObrigatoria`, online e ainda não tratado neste open (flag de sessão `_bloqueioObrigatorioTratado`, `home_screen.dart:60-63` — reseta ao fechar/reabrir o app, alinhado com "primeira vez no dia seguinte").

`_mostrarBloqueioObrigatorio` (`home_screen.dart:213-289`) tem **3 pré-condições** (qualquer falha reseta a flag pra tentar de novo no próximo gatilho):
- **Pré-condição 0** — `CurrentScreen.nome == 'home'`: em tela de visita pode haver foto não persistida no grid; atualizar agora derrubaria o trabalho (`home_screen.dart:221-229`).
- **Pré-condição 1** — `ProcessingTracker.total == 0 && !syncEngine.isSyncing`: zero processamento **ativo** (watermark gerando/upload agora). Pendente **acumulado** em `pending_photos` NÃO bloqueia — sobrevive ao restart e retoma no build novo; bloquear por pendente travava promotores com órfãs eternas em builds velhos sem nunca receber o force-update (`home_screen.dart:231-241`).
- **Pré-condição 2** — `ApkUpdaterService.apkAcessivel(url)`: HEAD com timeout 4 s; status 200–399 = ok (`home_screen.dart:243-251`; `lib/core/utils/apk_updater_service.dart:29-47`). Evita dialog com download fadado a falhar (captive portal/DNS/GitHub fora).

O modal é `PopScope(canPop: false)` + `barrierDismissible: false` com único botão "Atualizar agora" (`home_screen.dart:255-288`) → `_abrirDownloadAPK`.

### 3.4. Bloqueio na tela de login (deslogado)

`ref.listen(appVersionProvider)` na AuthScreen (`auth_screen.dart:303-317`): basta `outdated` (**não espera D+1** — quem não logou não tem dados locais a perder; garante que promotor novo sempre entra na versão mais recente, `auth_screen.dart:304-307, 419-422`). Também valida `apkAcessivel` antes (`auth_screen.dart:429-433`) e usa modal não-fechável (`auth_screen.dart:435-478`). Trava `_bloqueioForceUpdateAberto` evita reabertura no mesmo ciclo (`auth_screen.dart:31-33`).

### 3.5. Download e instalação (`ApkUpdaterService.downloadAndInstall`, `apk_updater_service.dart:51-111`)

- Salva em `<docs>/wizmart_apks/promotor-wizmart-latest.apk` — arquivo único sempre sobrescrito, não acumula APKs (`apk_updater_service.dart:57-69`).
- Download via Dio com progresso 0.0–1.0, `followRedirects` (GitHub → objects.githubusercontent.com), `receiveTimeout` 5 min, cancelável por `CancelToken` (`apk_updater_service.dart:71-86`; UI: `ApkDownloadDialog`, chamado em `home_screen.dart:199-210` e `auth_screen.dart:460-468`).
- Instala via `OpenFilex.open(apkPath)` → Package Installer nativo; Android 8+ pede "fontes desconhecidas" uma única vez (`apk_updater_service.dart:88-98`).

### 3.6. Badge não-obrigatório na Home

Quando `outdated` mas sem bloqueio: badge "atualizar" sublinhado no AppBar (toca → download). **Se há visitas com pendência de sync** (`watchVisitasComPendencia` — visitas distintas com `sync_status='pending'` OU foto em `watermark_pending/pending/uploading/error` OU outbox `pending/processing`, `app_database.dart:635-649`), o link é trocado por texto puro "N pendente(s)" sem ação — atualizar nesse estado perderia dados locais (`home_screen.dart:496-543`). O download manual também é barrado se há processamento ativo/sync rodando, com dialog "Aguarde o envio em andamento" (`home_screen.dart:162-197`).

---

## 4. Telas

### 4.1. Home (`/home`, `lib/presentation/screens/home/home_screen.dart`)

**Fonte de dados: 100 % DB local (Drift).**

| Provider | Consulta | Referência |
|----------|----------|------------|
| `visitasHojeProvider` (Stream) | `watchVisitasHoje`: visitas do promotor com `dia_hora_agendado` entre 00:00:00 e 23:59:59 de hoje **e `status_visita NOT IN (5)`** (esconde "Falta" local) | `home_screen.dart:28-31`; `app_database.dart:310-323` |
| `contadoresProvider` | `getContadoresHoje` (visitas de hoje; realizadas = status local 3, faltas = status local 5) — obs.: o card da home calcula contadores **em memória** sobre a lista do stream (`home_screen.dart:664-697`) | `home_screen.dart:33-36`; `app_database.dart:509-527` |
| `pdvsProvider` | `getAllPdvs()` → mapa id→Pdv | `home_screen.dart:38-42`; `app_database.dart:291` |
| `visitasComPendenciaProvider` (Stream) | `watchVisitasComPendencia` (ver §3.6) | `home_screen.dart:44-47` |
| `visitasSincronizandoProvider` (Stream) | `watchVisitasSincronizandoAtivamente`: visitas com foto `uploading` OU outbox `processing` **agora** (ícone de setas circulares no card) | `home_screen.dart:49-52`; `app_database.dart:614-628` |

⚠️ Os status **locais** diferem dos do servidor: localmente 1=Agendada, 2=Em Andamento, 3=Realizada, 5=Falta (`app_constants.dart:28-32`); no servidor 1=Concluída, 3=Não Realizada, 5=Incompleta (conversão no push via `_toServerStatus` da `visita_screen.dart` — fora do escopo deste doc, mas essencial pra não confundir os filtros abaixo).

**Gatilhos de sync que a home dispara** (todos `fullSync` = push **antes** de pull — pull deleta visitas synced sem pendência; rodar antes do push perderia trabalho ainda não enfileirado no outbox, `home_screen.dart:122-127, 653-656`):
- `initState` (`home_screen.dart:76`, `_triggerSync` `home_screen.dart:118-139` — invalida `contadores/pdvs/visitasHoje/appVersion` após).
- `AppLifecycleState.resumed` (`home_screen.dart:107-116` — WorkManager pode ter mexido no DB em outro isolate; Stream do Drift pode não notificar).
- Rede offline→online com a home aberta (`home_screen.dart:411-427`).
- Pull-to-refresh (`home_screen.dart:650-661`).

**Ações disponíveis**: abrir visita (`context.push('/visita/${v.id}')`, `home_screen.dart:784`); menu de navegação (Programado/Realizado/Faltas — `context.push`), "Reportar problema" e "Sair" (`home_screen.dart:546-644`). "Reportar problema" envia log do dia + sondas como issue sem pedir texto e abre o WhatsApp do suporte (`home_screen.dart:333-400`).

**Regras de bloqueio dos cards** (`home_screen.dart:757-789`): se há visita em andamento (status 2), só ela pode ser aberta — as agendadas ficam com cadeado; se há visita em processamento (`ProcessingTracker.visitasAtivas`), todos os cards são bloqueados exceto o da própria visita processando. Cards de visita realizada (status 3) não são clicáveis (`home_screen.dart:973`). Ordenação: em andamento → agendadas (turno manhã→tarde→noite, depois `dia_hora_agendado` asc) → realizadas (`dia_hora_realizado` desc) (`home_screen.dart:716-756`).

### 4.2. Programado (`/programado`, `lib/presentation/screens/programado/programado_screen.dart`)

**Fonte: Supabase direto (sem persistência local; refetch a cada abertura/pull-to-refresh, `programado_screen.dart:1-6`).** `programadoProvider` (`programado_screen.dart:35-99`):

1. Lê `rotas.gabaritos_associados` com `eq('promotor_associado', session.userId)` (`programado_screen.dart:41-44`).
2. Janela **D+1 a D+10** (amanhã + 9 dias) (`programado_screen.dart:52-56`).
3. POST na **Edge Function `gerar_datas_gabaritos_att`** com `{gabarito_ids, data_base, data_final, chunk_size:20, concurrency:3}`, auth via anon key, timeout 15 s (`programado_screen.dart:61-77`). (A mesma edge function é usada no pull do sync engine, `lib/core/network/sync_engine.dart:171-175`.)
4. Ordena por data e agrupa por dia com cabeçalho "DiaDaSemana · dd/MM/yyyy" (`programado_screen.dart:97, 311-340`).

**Sem gatilho de sync**; pull-to-refresh apenas `ref.invalidate(programadoProvider)` (`programado_screen.dart:271`). Ações: somente navegação pelo menu + logout (soft) (`programado_screen.dart:129-159, 186-202`).

### 4.3. Faltas (`/faltas`, `lib/presentation/screens/faltas/faltas_screen.dart`)

**Fonte: Supabase direto** (o DB local só guarda o dia, `faltas_screen.dart:5-6`). `faltasProvider` (`faltas_screen.dart:32-62`):

- `from('visitas').select('id,titulo,previsao_turno_realizada,dia_hora_agendado,status_visita')`
- Filtros exatos: `eq('id_promotor_associado', userId)` + **`eq('status_visita', 3)`** + `gte('dia_hora_agendado', hoje−90d UTC)` + `lt('dia_hora_agendado', início de hoje UTC)` — ou seja, **últimos 90 dias até D−1** e **status servidor 3 = Não Realizada** (`faltas_screen.dart:40-48`).

⚠️ **Armadilha de rótulo**: o comentário de cabeçalho diz "status_visita=5 no servidor" (`faltas_screen.dart:3`), mas a query usa **3**. Fato verificado (CLAUDE.md): no servidor 3=Não Realizada e 5=Incompleta — **o código está coerente com o servidor; o comentário é que está errado**.

Lista **somente leitura** — promotor não interage com os cards (`faltas_screen.dart:4-5`). Pull-to-refresh = `ref.invalidate(faltasProvider)` (`faltas_screen.dart:224`). Sem gatilho de sync. Menu de navegação + soft logout (`faltas_screen.dart:81-111`).

### 4.4. Realizado (`/realizado`, `lib/presentation/screens/realizado/realizado_screen.dart`)

**Fonte: Supabase direto.** `realizadoProvider` (`realizado_screen.dart:38-71`):

- `select('id,titulo,previsao_turno_realizada,dia_hora_agendado,status_visita,visita_aprovada,comentarios_supervisor')`
- Filtros exatos: `eq('id_promotor_associado', userId)` + **`or('status_visita.eq.1,status_visita.eq.5')`** (servidor: 1=Concluída, 5=Incompleta) + `gte('dia_hora_agendado', hoje−90d UTC)` — **últimos 90 dias até hoje inclusive** (sem `lt`) (`realizado_screen.dart:47-54`).

Exibição: barrinha verde (status 1) ou amarela (status 5 Incompleta) (`realizado_screen.dart:310-314`); veredito do supervisor (✓ aprovado / ✕ reprovado / nada se `visita_aprovada` null) **só pra status 1** — Incompleta não recebe veredito (`realizado_screen.dart:122-147, 381-382`); comentário do supervisor na 2ª linha (`realizado_screen.dart:307-309, 353-363`). Somente leitura; pull-to-refresh = `ref.invalidate(realizadoProvider)` (`realizado_screen.dart:260`). Sem gatilho de sync.

---

## 5. Guards de permissão e GPS

### 5.1. Arquitetura — onde os guards vivem

Os guards ficam **dentro do GoRouter via ShellRoute** (`app_router.dart:38-39`), não no builder do `MaterialApp.router`. Motivo documentado: o contexto do builder fica **fora** do Navigator do router — `showDialog`/sheet nos guards quebrava com "Null check on null Navigator" (**issues #14 e #15**, `main.dart:247-254`).

- **`PermissionsGuard`** envolve **todas** as rotas (splash, auth, home, telas, visita) via ShellRoute (`app_router.dart:38-39`).
- **`GpsGuard`** envolve **apenas** `/visita/:id` (`app_router.dart:54-58`). Motivo: Apple guideline 5.1.5 — o app deve funcionar com Location Services desligado; só a visita precisa de GPS pra registrar a localização da foto (`app_router.dart:34-37`).

### 5.2. PermissionsGuard (`lib/presentation/widgets/permissions_guard.dart`)

- Observa `permissionsStatusProvider` (`permissions_guard.dart:20`); se há pendência (câmera ou mídia ≠ granted e ≠ unknown — `permissions_status_service.dart:37-48`), sobrepõe um `ModalBarrier` não-dismissível cinza + card (`permissions_guard.dart:30-39, 111-114`). Estado `unknown` (ainda não checado) **não** bloqueia.
- Mostra **uma permissão por vez**, câmera antes de mídia (`permissions_guard.dart:22-28`).
- Botão principal chama `pedir(item)` (`permissions_guard.dart:167-169`): Android — se permanently denied abre Configurações; senão dialog nativo e, se ao final não está granted, abre Configurações automaticamente (fallback pra ROMs Samsung/Xiaomi bugadas); iOS — respeita a negativa, não abre configs automaticamente (Apple 5.1.1(iv)) (`permissions_status_service.dart:62-101`). Pra mídia no Android, granted = `Permission.photos` (Android 13+) **OU** `Permission.storage` (Android 12−) (`permissions_status_service.dart:103-117, 119-136`).
- Botão "Já concedi — verificar" chama `refresh()` (`permissions_guard.dart:170-172, 274-288`).
- **Re-checagem**: não há stream nativa de permissão — `WizMartApp` chama `refresh()` em todo `AppLifecycleState.resumed` (janela em que o usuário pode ter ido às configurações) (`permissions_status_service.dart:6-10`; `main.dart:216`). O onboarding também faz refresh ao montar (`onboarding_permissoes_screen.dart:53-56`).

### 5.3. GpsGuard (`lib/presentation/widgets/gps_guard.dart`)

- Observa `gpsStatusProvider`; bloqueia quando `status != ok && != unknown` (`gps_guard.dart:24-25`) — cobre `serviceDisabled`, `permissionDenied`, `permissionDeniedForever` (`gps_status_service.dart:13-24`).
- Ações por estado (`gps_guard.dart:77-92`): serviço desligado → `abrirConfigsGps()` (tela do sistema, `gps_status_service.dart:62-65`); permissão negada → `pedir()` (dialog nativo; se segue não-concedida, abre configs do app — `gps_status_service.dart:45-59`). Botão "Já concedi — verificar" → `refresh()` (`gps_guard.dart:209-230`).
- **Re-checagem**: além do `resumed` (`main.dart:215`), o serviço escuta `Geolocator.getServiceStatusStream()` — liga/desliga do GPS dispara `_check()` automaticamente (`gps_status_service.dart:30-36`).
- Bug histórico documentado no widget: o card ficava dentro de um `AbsorbPointer` que matava o toque do próprio botão; e um `Positioned` negativo jogava o botão de ajuda fora da área tocável (`gps_guard.dart:118-124, 153-156`).

### 5.4. Onboarding de permissões (`/onboarding-permissoes`)

Primeira abertura pós-instalação/login: pede as 3 permissões em sequência fixa **câmera → galeria → GPS**, um card por vez, com stepper 1/3–3/3 (`onboarding_permissoes_screen.dart:68-77, 116-130`). Botão "Continuar" só habilita com tudo concedido; grava a flag e vai pra `/home` (`onboarding_permissoes_screen.dart:134-140`). Depois disso os guards continuam como rede de segurança se o promotor revogar algo (`onboarding_permissoes_screen.dart:10-12`; `app_router.dart:166-171`).

---

## 6. Pontos sensíveis e bugs históricos documentados em comentários

| Tema | Resumo | Referência |
|------|--------|------------|
| **Fotos presas travando consolidação** | Status `uploading`/`watermark_pending` congelados por morte do app faziam `countFotosEmProgresso > 0` para sempre → outbox postergava eternamente e a visita nunca consolidava (Glaucia/Camila/Thiago, build 220). Corrigido pelo recovery no boot. | `app_router.dart:100-110`; `app_database.dart:552-583` |
| **`error` não conta como em-progresso** | Antes `error` era contado em `countFotosEmProgresso` e travava o outbox PRA SEMPRE (arquivo local sumido = irrecuperável). Agora a visita sincroniza com as fotos que subiram. | `app_database.dart:698-708` |
| **Consolidação idTemp → serverId** | Causa raiz histórica: visita nascia com PK = idTemp negativo; INSERT só setava `server_id` e o pull recriava com PK = serverId → fotos e outbox órfãos (fotos no bucket sem vínculo na tabela). Solução: migrar PK e re-vincular fotos+outbox na mesma transação. | `app_database.dart:429-443` |
| **"Realizadas viram em andamento"** | A consolidação antiga deletava a row PK=serverId (dados frescos) e preservava a row idTemp (dados velhos) — casos Jessica/Felipe/Thamara 09-10/06. Agora preserva os campos da row do servidor e migra só o trabalho novo. | `app_database.dart:458-491` |
| **Pull apagando visita antes da watermark queue terminar** | `deleteVisitasSincronizadasSemPendencias` precisa considerar `watermark_pending` (não só pending/uploading); sem isso o pull apagava a row idTemp no meio do processamento e o UPDATE `photos_antes` era descartado — array vazio no servidor (Cleiton/Edilson 2026-05-19/20). | `app_database.dart:386-400` |
| **Órfãs do hash não-determinístico (pré-build 202)** | Pending_photos/outbox apontando pra visitas inexistentes geravam "Posterga infinito" — limpas na migração v4. | `app_database.dart:257-270` |
| **PUSH antes de PULL** | Pull deleta visitas synced sem pendência local; rodar antes do push pode apagar trabalho recém-criado num gap entre `updateVisita` e `insertOutboxItem`. Ordem fixa em todos os gatilhos. | `home_screen.dart:122-127, 653-656` |
| **`ref` usado após dispose** | `ref.invalidate` depois de um `await` sem guard `context.mounted` crashava o app na próxima abertura ("Bad state: Cannot use ref after disposed") — caso Cleiton, 2026-05-21. | `home_screen.dart:416-421` |
| **Guards fora do Navigator** | `PermissionsGuard`/`GpsGuard` no builder do `MaterialApp.router` quebravam dialogs ("Null check on null Navigator", issues #14/#15) — movidos pra ShellRoute. | `main.dart:247-254` |
| **`appVersionProvider` cacheado pra sempre** | Sem `ref.invalidate` nos gatilhos de sync, o promotor instalava a versão N e nunca via o badge da N+1. | `main.dart:199-202` |
| **D+1 baseado em `published_at` resetava** | O workflow apaga/recria o release `v-latest` a cada push; o timestamp resetava e o force-update nunca disparava. Agora a referência é o `BUILD_TIME` do APK instalado. | `version_check_service.dart:46-53` |
| **Bloquear update por pendente acumulado** | Travava promotores com órfãs eternas em builds velhos sem nunca receber o force-update — hoje só processamento **ativo** bloqueia. | `home_screen.dart:231-241` |
| **Relato duplicado por snackbar curto** | Snackbar de 2 s sumia com o POST ainda rodando; promotor clicava de novo → issues duplicadas (Caline+Paula, build 176, issues #34/#35 e #37/#38). Hoje snackbar persistente com spinner. | `home_screen.dart:334-339` |
| **Retomada com `last_visita_id` morto** | Restaurar visita sem validar existência prendia o usuário em "Visita não encontrada" sem voltar (reinstalação do Edilson, 2026-05). | `app_router.dart:143-149` |
| **Comentário errado de status na tela Faltas** | Cabeçalho diz "status_visita=5", query (correta) usa 3 (Não Realizada no servidor). Mesmo desencontro de rótulo existe em `AppConstants.statusFalta = 5` (`app_constants.dart:32`), que no servidor significa Incompleta. | `faltas_screen.dart:3` vs `faltas_screen.dart:45` |
| **Janela JSON raw apagado** | A watermark queue atualiza o JSON da visita **antes** de apagar o arquivo raw — sem isso a grid quebrava com `PathNotFoundException` quando o promotor voltava do checklist. | `watermark_queue.dart:259-264` |
| **Galeria nunca é apagada** | Único contato do app com a galeria é `Gal.putImage` (adicionar); falha vira anomalia D6 (promotor sem backup automático). Limpezas se restringem ao banco local e a `wizmart_fotos/`. | `watermark_queue.dart:274-295`; `logout_service.dart:127-136` |
---

# PARTE 2 — Fluxo da visita e das fotos

# Fluxo da Visita e das Fotos — Documentação Técnica

> Fontes (leitura integral): `lib/presentation/screens/visita/visita_screen.dart` (1970 linhas), `lib/core/utils/watermark_queue.dart` (383), `lib/core/utils/watermark_util.dart` (183), `lib/core/utils/performance_profile.dart` (95), `lib/core/database/app_database.dart` (823); leitura dirigida de `lib/core/network/sync_engine.dart` (trechos de upload de foto) e `lib/core/utils/app_router.dart` (recovery de boot). Todas as afirmações citam arquivo:linha.

---

## 1. Máquina de estados do `localState` da visita

### 1.1 Estados

A coluna `local_state` da tabela `visitas` aceita: `'idle' | 'abertura' | 'fotos_antes' | 'em_reposicao' | 'fotos_depois' | 'checklist' | 'finalizada'`, default `'idle'` (`app_database.dart:117-118`). A tela renderiza por `switch (_localState)` (`visita_screen.dart:1302-1321`):

| `localState` | Tela renderizada | Observação |
|---|---|---|
| `idle` (e qualquer valor desconhecido) | `_buildIniciar()` | `visita_screen.dart:1304-1305, 1318-1319` |
| `fotos_antes` | `_buildFotos('antes')` | `visita_screen.dart:1306-1307` |
| `em_reposicao` | `_buildFotos('depois')` | **Estado legado** de visitas pré-refactor; tratado como `fotos_depois` "pra não travar o usuário" (`visita_screen.dart:1308-1311`) |
| `fotos_depois` | `_buildFotos('depois')` | `visita_screen.dart:1312-1313` |
| `checklist` | `_buildChecklist()` | `visita_screen.dart:1314-1315` |
| `finalizada` | `_buildFinalizada()` | `visita_screen.dart:1316-1317` |

O estado em memória `_localState` inicia em `'idle'` (`visita_screen.dart:54`) e é restaurado do banco em `_loadVisita` (`visita_screen.dart:336, 355`).

### 1.2 Transições

#### T1: `idle` → `fotos_antes` — botão **"Iniciar visita"**
- **Gatilho:** botão `ElevatedButton` "Iniciar visita" → `_iniciarVisita` (`visita_screen.dart:1350-1357`).
- **O que faz:** mostra overlay "Obtendo localização..." (`visita_screen.dart:761-764`); captura GPS *best effort* — se falhar segue com `loc = null` (`visita_screen.dart:769-771`).
- **Gravado no banco local:** `diaHoraAbertura = agora`, `localizacaoAbertura = loc`, `localState = 'fotos_antes'` (`visita_screen.dart:778-783`).
- **Enviado ao servidor:** **NADA**. A abertura é "SOMENTE local. Status fica 1 (agendada) e nada entra na outbox: se o promotor desistir antes de concluir as fotos antes, a visita continua 'agendada' no servidor — sem fantasma" (`visita_screen.dart:776-777, 864-865`).
- Após a transição: `SyncPause.pause()` (estado de captura) via `_updateSyncPause('fotos_antes')` (`visita_screen.dart:790`, lógica em 115-122).

#### T2: `fotos_antes` → `fotos_depois` — botão **"Concluir"** (fotos antes)
- **Gatilho:** botão "Concluir" (habilitado só com ≥ 4 fotos, `visita_screen.dart:1489-1494`) → dialog de confirmação `_confirmarConcluirFotos('antes')` (`visita_screen.dart:805-843`; o dialog existe porque "o botão 'Concluir' fica perto do 'Tirar foto' e o promotor estava clicando por engano", 801-804) → `_concluirFotosAntes` (`visita_screen.dart:838-839, 845`).
- **Guarda:** exige ao menos 1 foto (`visita_screen.dart:846-849`) — na prática o botão já exige o mínimo de 4 (`AppConstants.minFotosAntes = 4`, `app_constants.dart:25`).
- **Gravado no banco local:** `statusVisita = 2` (Em Andamento, `AppConstants.statusEmAndamento`, `app_constants.dart:30`), `localState = 'fotos_depois'`, `syncStatus = 'pending'` (`visita_screen.dart:865-870`). Comentário-chave: "Transição 1→2 (agendada → em andamento) acontece AQUI: só depois que o promotor concluiu as fotos antes" (`visita_screen.dart:862-864`).
- **Enviado ao servidor:** item de outbox `operation='open'` com `{id, status_visita: 2, dia_hora_abertura, localizacao_abertura, id_promotor_associado, fotos_antes_count}` (`visita_screen.dart:872-879`), via `_enfileirarVisita` que insere em `outbox_items` e chama `scheduleOneOffSync()` (`visita_screen.dart:1082-1100`). **Este é um dos 2 únicos pontos em que o app escreve status no servidor.**
- **Efeitos colaterais:** `SyncPause.resume()` (`visita_screen.dart:884`), `LastVisitaService.clear()` (886), navegação para `/home` (887) e — **só depois** do `context.go`, para o Canvas pesado não travar a tela de visita — `wmQueue.enqueue(slot: 'antes')` (`visita_screen.dart:889-898`).

#### T3: `fotos_depois` → `checklist` — botão **"Concluir — ir para checklist"**
- **Gatilho:** mesmo botão "Concluir" do grid (label diferente para `depois`, `visita_screen.dart:1500-1503`) → `_confirmarConcluirFotos('depois')` → `_concluirFotosDepois` (`visita_screen.dart:840-841, 913`).
- **O que faz:** valida ≥ 1 foto (914-917), overlay "Obtendo localização..." (919-922), captura referências do `ref` ANTES dos awaits (924-928), captura GPS (930).
- **Gravado no banco local:** `localizacaoEncerramento = loc`, `localState = 'checklist'`, `syncStatus = 'pending'` (`visita_screen.dart:934-939`).
- **Enviado ao servidor:** **nada diretamente** (nenhum outbox aqui). O upload das fotos "depois" será destravado pela watermark queue.
- **Efeitos colaterais:** `_updateSyncPause('checklist')` libera o sync (946-947); `wmQueue.enqueue(slot: 'depois')` é chamado **depois** que a UI já transicionou pro checklist — "o processamento pesado roda enquanto o promotor responde o checklist" (949-957). O promotor **permanece na tela** (diferente de T2, que vai pra home).

#### T4: `checklist` → `finalizada` — botão **"Finalizar visita"**
- **Gatilho:** botão `ElevatedButton` "Finalizar visita" → `_finalizarVisita` (`visita_screen.dart:1626-1627, 960`).
- **Guardas:** as 7 perguntas respondidas (962-967); justificativa obrigatória preenchida — perguntas 1-5 quando NÃO, 6-7 quando SIM (`_obsObrigatoria`, 968-975 e 1545-1549).
- **Gravado no banco local:** `statusVisita = 3` (Realizada **local** — no servidor vira 1, ver nota abaixo), `diaHoraRealizado = agora`, `checkPergunta1..7`, `obsPergunta1..7`, `comentariosVisita`, `localState = 'finalizada'`, `syncStatus = 'pending'` (`visita_screen.dart:990-1011`).
- **Instrumentação anti-perda:** se `updateVisita` afetar 0 linhas, loga "FINALIZAR visitaId=... afetou 0 linhas — id obsoleto (pivot durante a tela aberta?)" (`visita_screen.dart:1012-1023`; `updateVisita` retorna nº de linhas exatamente para isso, `app_database.dart:418-423`).
- **Enviado ao servidor:** outbox `operation='close'` com `{id, status_visita: 3 (local; convertido para 1 pelo sync engine — fato verificado no CLAUDE.md: `_toServerStatus`), dia_hora_realizado, localizacao_encerramento, check_pergunta_1..7, obs_pergunta_1..7}` (`visita_screen.dart:1025-1044`). **Segundo e último ponto de escrita de status no servidor.** Nota: o payload `close` **não** inclui `comentarios_visita` (só vai pro banco local em 1008).
- **Efeitos colaterais:** `SyncPause.resume()` defensivo (1046-1048); **aguarda** `syncEngine.processOutbox()` se online — "Sem o await, a home montava com a visita ainda em syncStatus='pending' local e o pullAll subsequente pulava ela" (1049-1057); SnackBar de sucesso, 1s, `/home` (1059-1064).

#### T5 (reversa): `checklist` → `fotos_depois` — botão **voltar**
- **Gatilho:** seta do AppBar ou back do sistema → `_sairParaHome` (`visita_screen.dart:1197-1199, 1184-1190`). No checklist, voltar **não** vai pra home: "volta uma etapa (grid de fotos depois) (...) Promotor pode estar revisando ou tirando mais fotos antes de finalizar" (149-153).
- **Gravado no banco local:** `localState = 'fotos_depois'` (`visita_screen.dart:155-158`).
- **Detalhe crítico:** recarrega `fotosDepoisJson` do banco antes do `setState` — "watermark queue pode ter trocado `_raw.jpg` por `_watermark.jpg` e apagado os crus. Sem isso, a grid tenta renderizar paths mortos" (`visita_screen.dart:159-172`).
- **Enviado ao servidor:** nada.

#### T6 (reversa): `fotos_antes` → `idle` — descarte de fotos ao sair
- **Gatilho:** voltar estando em `fotos_antes` com fotos no grid → dialog "Descartar fotos?" (`visita_screen.dart:177-219`); confirmando, `_descartarFotosDaEtapa` (220, 253).
- **O que faz:** apaga cada arquivo local e a linha correspondente em `pending_photos` (`deletePendingPhotosByPath`) (`visita_screen.dart:260-268`); a galeria **não é tocada** — "só recebe ao concluir" (259).
- **Gravado no banco local:** reverte a abertura por completo: `fotosAntesJson = null`, `diaHoraAbertura = null`, `localizacaoAbertura = null`, `diaHoraFotosAntes = null`, `localizacaoFotosAntes = null`, `localState = 'idle'`, `syncStatus = 'synced'` — "como se nunca tivesse clicado em iniciar (...) o início era SOMENTE local, ainda não tinha sido enfileirado" (`visita_screen.dart:270-283`).
- **Enviado ao servidor:** nada (não havia nada enfileirado).

#### T7 (parcial): descarte em `fotos_depois` — **permanece** em `fotos_depois`
- Mesmo fluxo de dialog; mas aqui a visita **mantém** status 2 e `localState='fotos_depois'`: limpa só `fotosDepoisJson = null`, `diaHoraFotosDepois = null`, `localizacaoFotosDepois = null`, `syncStatus = 'synced'` — "próxima vez já volta direto pra grid de fotos depois vazio" (`visita_screen.dart:284-295`).

#### T8 (correção no load): `idle`/`abertura`/`fotos_antes`/`em_reposicao` → `fotos_depois`
- **Gatilho:** `_loadVisita` ao abrir a tela. Se `statusVisita == 2` (em andamento no servidor) mas o `localState` ainda está em fase anterior, "significa que já passamos da etapa de antes. Pula direto pra fotos depois" e **persiste** `localState='fotos_depois'` no banco (`visita_screen.dart:333-348`).

#### Saída para home (qualquer estado não-captura)
- `_sairParaHome` fora de checklist/captura: `SyncPause.resume()` (184), `LastVisitaService.clear()` (230) e dispara `fullSync` (ou `processOutbox` sem sessão) **sem await** — "o pull pode trazer alterações que o supervisor fez no servidor" (`visita_screen.dart:232-245`), depois `context.go('/home')` (246).

### 1.3 Pausa de sync por estado

`_updateSyncPause`: `SyncPause.pause()` apenas em `fotos_antes`/`fotos_depois`; `resume()` nos demais; também atualiza `CurrentScreen.nome` (`visita-fotos-antes`, `visita-fotos-depois`, `visita-checklist`, `visita-finalizada`, `visita`) para rotular issues do ErrorReporter (`visita_screen.dart:111-143`). O sync engine respeita: "Pausado (captura ativa) — pulando ciclo" (`sync_engine.dart:530-532`). O `dispose` faz `SyncPause.resume()` defensivo (`visita_screen.dart:105-108`).

---

## 2. Máquina de estados da foto em `pending_photos`

### 2.1 Esquema

Tabela `PendingPhotos`: `id` (uuid texto), `visitaId`, `slot` (`'antes'|'depois'`), `numero`, `localPath`, `status` (default `'pending'`), `storageUrl`, `attempts`, `nextRetryAt`, `createdAt`, `lastError` (schema 5) (`app_database.dart:140-157`). Estados documentados no cabeçalho da fila (`watermark_queue.dart:18-23`):

- `watermark_pending` → tirada, esperando watermark (**sync NÃO pega**)
- `pending` → pronta pra subir
- `uploading` → em upload
- `uploaded` → no servidor
- `error` → falhou (estado **terminal** para erro real)

### 2.2 Transições

| # | Transição | Gatilho | Executor | Referência |
|---|---|---|---|---|
| P1 | (nasce) → `watermark_pending` | Foto tirada na câmera | `_enfileirarUploadFoto` insere a row com `status='watermark_pending'`, `attempts=0`, `nextRetryAt=agora`, `createdAt=capturedAt` | `visita_screen.dart:660-683` (status em 675) |
| P2 | `watermark_pending` → `pending` (caso normal) | Promotor concluiu a etapa (T2/T3) → `wmQueue.enqueue` → watermark aplicado com sucesso | `WatermarkQueueService._processarItemInner`: atualiza `localPath` para o arquivo com watermark e `status='pending'` | `watermark_queue.dart:253-257` |
| P3 | `watermark_pending` → `pending` (falha de watermark) | Exceção/timeout (30 s) no `applyWatermark` | "Watermark falhou — libera mesmo assim com o caminho cru pra que o sync suba pelo menos a foto original" | `watermark_queue.dart:305-313` (timeout em 250) |
| P4 | `watermark_pending` → `pending` (idempotência) | Foto cujo `localPath` **não** contém `_raw.` (já tem watermark; ex.: voltou do checklist e re-concluiu) | Só troca o status, sem re-renderizar | `watermark_queue.dart:218-227` |
| P5 | `pending` → `uploading` | `processOutbox` do sync engine (fotos primeiro, lote de 5 com `nextRetryAt` vencido — `app_database.dart:653-662`) | `_processPhotoUpload` marca `uploading` antes de qualquer I/O | `sync_engine.dart:1149-1153` (seleção em 547-550) |
| P6 | `uploading` → `error` (arquivo sumiu) | `File(localPath)` não existe | `_processPhotoUpload` | `sync_engine.dart:1156-1163` |
| P7 | `uploading` → `pending` (sessão expirada) | `auth.currentUser == null` e `refreshSession` falhou | Volta pra `pending` **sem consumir tentativa**; `AuthSessionExpired.set()` notifica a UI pra forçar login | `sync_engine.dart:1179-1203` |
| P8 | `uploading` → `uploaded` | Upload OK no bucket `Arquivos` (path `abastecimentos/{authUid}/{data}/{nome}-{hash}-{slot}-{numero}.{ext}`, `upsert: true`) | Grava `storageUrl` (URL pública), marca a visita `syncStatus='pending'` e enfileira outbox `photos_antes`/`photos_depois` para o UPDATE do array no servidor | `sync_engine.dart:1232-1282` (uploaded em 1256-1260; outbox em 1270-1282) |
| P9 | `uploading` → `error` (erro real) | Exceção classificada como `erroReal` (4xx, formato inválido etc.) | Marca `error` + `attempts+1` + `lastError`; enfileira anomalia D1 e upload da foto pro bucket `bug-reports` | `sync_engine.dart:1289-1328` |
| P10 | `uploading` → `pending` (rede transitória) | Exceção classificada como transitória | Backoff exponencial: `min(2^attempts * 30 s, 1800 s)`; grava `attempts`, `nextRetryAt`, `lastError` | `sync_engine.dart:1330-1341` |
| P11 | `uploading` → `pending` (recovery de boot) | App reaberto após morte (OOM/swipe/crash) com fotos congeladas em `uploading` | `resetUploadingNoBoot()` no splash — seguro porque o Storage usa `x-upsert` (retry idempotente) | `app_database.dart:565-574`; chamado em `app_router.dart:111-117` |
| P12 | `watermark_pending` (stale) → re-enfileiramento | Boot do app | `recoverPendingOnBoot()` re-enfileira pares (visitaId, slot) únicos de `getStaleWatermarkPending()` (`app_database.dart:579-583`) | `watermark_queue.dart:89-131`; chamado em `app_router.dart:118-119` |
| P13 | (remoção) | Promotor remove a foto do grid, ou descarta a etapa | `deletePendingPhotosByPath` (`app_database.dart:684-686`) | `visita_screen.dart:731-732` e `266-267` |
| P14 | (remoção em massa) | Guard "descarte de visita-fantasma" do sync engine | `deletePendingPhotosByVisita` (`app_database.dart:690-692`) | `sync_engine.dart:912` |

### 2.3 Semântica dos estados para o resto do sistema

- `countFotosEmProgresso` (usado pelo sync engine pra **postergar** operações de visita) conta `watermark_pending + pending + uploading`; **`error` NÃO conta** — "é estado terminal e irrecuperável (...) Antes 'error' era contado e travava o outbox da visita PRA SEMPRE" (`app_database.dart:698-719`; uso comentado em `sync_engine.dart:814-819`).
- `getUploadedPhotoUrls` lê só `uploaded` ordenado por `numero` pra montar os arrays `fotos_antes`/`fotos_depois` do payload da visita (`app_database.dart:724-737`; `sync_engine.dart:1251-1255`: o JSON local **nunca** recebe URLs — "Aquele JSON é a fonte de verdade dos PATHS LOCAIS").
- Badge de pendência da home conta visita com foto em `watermark_pending/pending/uploading/error` ou outbox pendente (`app_database.dart:635-649`); ícone "sincronizando agora" usa só `uploading`/`processing` (`app_database.dart:614-628`).
- `countPendentesParaSync` (bloqueia ações destrutivas, ex.: update de APK) conta `pending + uploading + error` (`app_database.dart:588-606`).

---

## 3. A fila de carimbo — `WatermarkQueueService`

Singleton via `watermarkQueueProvider` (`watermark_queue.dart:381-383`). Fila em memória `_pending` de `_QueueItem {visitaId, slot, pdvNome, promotorNome}` (`watermark_queue.dart:42-58`).

### 3.1 Todos os gatilhos

1. **Concluir fotos antes** — `wmQueue.enqueue(slot: 'antes')`, chamado **depois** do `context.go('/home')` para o trabalho pesado de Canvas rodar com o promotor já na home (`visita_screen.dart:889-898`).
2. **Concluir fotos depois** — `wmQueue.enqueue(slot: 'depois')`, chamado depois da transição da UI pro checklist (`visita_screen.dart:949-957`).
3. **Boot do app** — `recoverPendingOnBoot()` no splash (`app_router.dart:118-119`), re-enfileirando fotos órfãs em `watermark_pending` de execução anterior ("foto tirada, app fechou antes do watermark terminar"); idempotente e com falha silenciosa "não pode quebrar o boot" (`watermark_queue.dart:81-131`). O nome do PDV é reconstituído do `visita.titulo` (mesmo critério de `_pdvNomeParaWatermark`) (`watermark_queue.dart:104-107`).

`enqueue` retorna imediatamente e dispara `_processNext()` sem await (`watermark_queue.dart:64-79`). `_processNext` tem guard `_running` (só um loop por vez), processa FIFO, erro num item **não trava a fila** (reporta via `ErrorReporter`), dá um `Duration.zero` de respiro pro UI thread entre itens e, **ao esvaziar a fila, dispara sync**: `fullSync(userId)` se houver sessão, senão `processOutbox()` — "as fotos prontas sobem assim que o watermark fica pronto, sem precisar do promotor fazer nada" (`watermark_queue.dart:133-159, 368-378`; doc em 14-16).

### 3.2 Passo a passo de `_processarItem` (por visita+slot)

Envolto em `ProcessingTracker.begin/end(visitaId)` — alimenta a "engrenagem" da home (`watermark_queue.dart:161-168`). Dentro (`_processarItemInner`, 170-328):

1. Busca todas as `pending_photos` da visita+slot ordenadas por `numero` (`watermark_queue.dart:171-173`; query em `app_database.dart:674-680`). Se vazio, retorna (177).
2. **Detector D2:** foto em `watermark_pending` há > 30 min ⇒ enfileira anomalia `D2-watermark-travado` ("sinal de queue travada — app fechou no meio, isolate morreu, bug no Canvas. Não rede"); **não muda o fluxo** (`watermark_queue.dart:179-205`).
3. Para cada foto:
   - Delay de **80 ms** antes do trabalho pesado — "Canvas + toByteData são síncronos do ponto de vista do main isolate" (`watermark_queue.dart:211-215`).
   - **Se o path não contém `_raw.`** (já carimbada): adiciona o path à lista final e, se ainda `watermark_pending`, só promove pra `pending` (218-227).
   - **Senão:** chama `WatermarkUtil.applyWatermark(...)` com `capturedAt = createdAt` da foto e parâmetros do tier (`performanceProfileProvider`, default `padraoCarregando` se ainda detectando), com **`.timeout(30 s)`** (230-250).
   - Sucesso: atualiza `pending_photos.localPath = wmPath` e `status='pending'` (253-257); **antes de apagar o cru**, troca o path no `fotosXxxJson` da visita (`_trocarPathNoJson`) — "Sem isso, havia uma janela em que o JSON ainda tinha raw_path mas o raw já estava deletado, e a grid quebrava com PathNotFoundException" (259-272; implementação preservando a ordem do grid em 333-366).
   - **Galeria:** `Gal.putImage(wmPath)` com timeout de **5 s**; falha é **silenciosa pro fluxo** mas enfileira anomalia `D6-gal-falhou` ("em geral permissão negada (...) pra eu saber qual promotor está sem backup automático") (`watermark_queue.dart:274-295`). Esta é a **única** interação do subsistema com a galeria — só adiciona, nunca apaga.
   - **Descarte do cru:** `File(p.localPath).delete()` somente se `wmPath != p.localPath`, com catch vazio (297-302).
   - **Falha/timeout do watermark:** catch genérico promove `status='pending'` mantendo o **caminho cru** na lista — a foto sobe sem carimbo em vez de travar (305-313).
4. Ao final do lote, regrava `fotosAntesJson`/`fotosDepoisJson` da visita com a lista completa de novos caminhos (316-327).

### 3.3 O carimbo em si (`WatermarkUtil.applyWatermark`)

`watermark_util.dart:23-182`. Não redimensiona nem recomprime a foto base ("a foto já vem pronta da câmera — image_picker.maxWidth + imageQuality aplicados na captura", 6-9). Saída: novo arquivo `wizmart_fotos/<uuid>.jpg` (36-40). Conteúdo desenhado via Canvas/Skia:
- Badge com o **número da foto** no canto superior direito (62-96).
- Faixa preta no rodapé com altura `h*0.13` (clamp 120–600 px) (51, 98-102).
- 3 linhas: `PDV: <nome>`, `Promotor: <nome>`, `FOTO Antes|Depois  -  dd/MM/yyyy HH:mm:ss` (data = `capturedAt`, ou seja, `createdAt` da pending_photo) (104-128). **É esta a marca d'água usada como fonte de verdade/OCR.**
- Linha 4 translúcida com info técnica de debug: `imgQ:<q> · max<side> · <tier>` (130-161).
- Render: `PictureRecorder → toImage → toByteData(PNG) → FlutterImageCompress (JPG, quality 88)` (163-180).

### 3.4 Perfil de performance (tier)

`performance_profile.dart`: detecção 1x no startup por RAM total (1-8, provider 84-95). Tiers (`_byRam`, 48-74): **low** (<2560 MB): `imageQuality=70`, `imageMaxSide=1600`; **mid** (<4096 MB): 80/2048; **high**: 85/2560; `watermarkQuality=88` em todos. `padraoCarregando` = mid (76-79). Usado na captura (`visita_screen.dart:473-477, 484-490`) e no carimbo (`watermark_queue.dart:234-249`).

---

## 4. Captura, recaptura, remoção e reordenação de fotos no grid

### 4.1 Tirar foto (`_tirarFoto`, `visita_screen.dart:432-585`)

Sequência completa:
1. Checa limite (8 por slot, `app_constants.dart:21-22`); bloqueia com SnackBar (`visita_screen.dart:440-442`).
2. Guard de GPS: se `gpsStatusProvider != ok`, nem abre a câmera (anti-race com o overlay do GpsGuard) (449-452).
3. **Pré-check de storage:** < 100 MB livres ⇒ dialog bloqueante "Armazenamento cheio" e aborta (457-470).
4. Lê tier de performance (473-477) e **pausa o sync** ("câmera consome CPU/RAM e qualquer upload concorrente em device de baixa memória pode travar", 479-481).
5. `pickImage(camera)` com quality/maxSide do tier (484-490). `PlatformException` ⇒ dialog de permissão ou erro de câmera (491-502). Cancelamento ⇒ restaura pausa de sync conforme o estado e retorna (504-507).
6. Overlay "Salvando foto... Aguarde, não toque na tela" (`_savingPhoto`, 510 e 1260-1295).
7. Captura GPS da foto + `capturedAt` (514-515).
8. Copia o arquivo da câmera para `<documents>/wizmart_fotos/<uuid>_raw.<ext>` (caminho estável) (521-526).
9. **(B) Validação da cópia:** arquivo deve existir e ter tamanho > 0, senão `FileSystemException` — "copy 'silencioso' deixava grid com referência pra arquivo inexistente/zerado" (528-541).
10. **(A) Atomicidade — DB antes do grid:** monta a nova lista sem mutar o state (543-548); `_persistirListaEMetadados` grava `fotosXxxJson`, `diaHoraFotosXxx`, `localizacaoFotosXxx`, `syncStatus='pending'` (549-550, implementação 613-633); `_enfileirarUploadFoto` insere a `pending_photo` em `watermark_pending` (551, 660-683 — **sem** trigger de sync: "não há nada pra subir ainda", 680-682). Galeria não é tocada (552-553). **Só então** o `setState` atualiza o grid (555-562).
11. Erro em qualquer passo ⇒ log + auto-issue (`ErrorReporter.reportar`) + dialog bloqueante "Foto não foi salva" (564-581).

Obs.: `_salvarFotosLocalmente` (`visita_screen.dart:635-658`) **não tem nenhum caller** — código morto remanescente, substituído por `_persistirListaEMetadados`.

### 4.2 Recaptura

Não existe ação "substituir": recapturar = **remover** a foto (4.3) e **tirar outra** (4.1). Caso especial coberto pela fila: se o promotor volta do checklist (T5) e re-conclui a etapa, fotos já carimbadas (path sem `_raw.`) são reconhecidas e não re-renderizadas (`watermark_queue.dart:217-227`).

### 4.3 Remover foto (botão X do tile)

`_removerFoto` (`visita_screen.dart:697-739`), acionado pelo X vermelho do `_PhotoTile` (1880-1888, 1454):
1. Dialog "Remover foto? A foto será apagada deste celular e do envio para o servidor" (698-721).
2. `setState` remove do grid + `_persistirOrdemFotos` regrava o JSON com `syncStatus='pending'` (727-728, 741-756).
3. `deletePendingPhotosByPath(path)` cancela o upload pendente (731-732; `app_database.dart:684-686`).
4. Apaga o arquivo local (735-738). **Galeria intocada** (a foto só vai pra galeria após o carimbo; se já tiver ido, permanece lá — não há chamada de remoção de galeria em nenhum dos arquivos lidos).

### 4.4 Reordenar (setas ← →)

`_moverFoto(slot, from, to)` (`visita_screen.dart:687-695`), acionado pelas setas do tile (1455-1456, 1912-1938; desabilitadas nas bordas via `canMoveLeft/Right`, 1451-1453): muda a posição na lista em memória e `_persistirOrdemFotos` regrava o `fotosXxxJson` com `syncStatus='pending'` (741-756). **Atenção:** a ordem do JSON é a ordem visual do grid, mas `pending_photos.numero` **não é renumerado** — o número carimbado na foto e o sufixo `-{numero}` do nome no Storage (`sync_engine.dart:1232-1233`) seguem a ordem de captura, não a ordem final do grid.

---

## 5. Tudo que o promotor pode fazer na tela de visita

| Ação | Onde | Efeito |
|---|---|---|
| **Iniciar visita** | `visita_screen.dart:1350-1357` | T1: abertura local (data/hora + GPS), nada pro servidor (§1.2-T1) |
| **Tirar foto** | botão "Tirar foto", some ao atingir o limite de 8 (1467-1482) | §4.1; cria arquivo `_raw`, row `watermark_pending`, atualiza JSON |
| **Remover foto (X)** | tile, 1454/1880-1888 | §4.3 |
| **Reordenar foto (← →)** | tile, 1455-1456/1912-1938 | §4.4 |
| **Concluir (antes)** | 1489-1519, desabilitado com label "Faltam N foto(s) — mínimo 4" até o mínimo (1504) | dialog de confirmação → T2: status 2 + outbox `open` + watermark queue + volta pra home |
| **Concluir — ir para checklist (depois)** | mesmo botão, label em 1500-1503 | dialog → T3: GPS de encerramento + checklist + watermark queue (fica na tela) |
| **Responder SIM/NÃO** (7 perguntas) | 1678-1752; perguntas fixas em 1532-1540 | só `setState`; persistência ocorre apenas no Finalizar |
| **Preencher observação/justificativa** | 1756-1787 (borda vermelha quando obrigatória e vazia, 1775-1781) | idem |
| **Comentário geral (opcional)** | 1577-1618 | vai pra coluna `comentariosVisita` no Finalizar (1008) |
| **Finalizar visita** | 1622-1642 | T4: grava tudo, outbox `close`, **aguarda** push, home |
| **Voltar (AppBar ou back físico)** | 1197-1199 e `PopScope` 1184-1190 | checklist → T5 (volta pra fotos depois); captura com fotos → dialog de descarte (T6/T7); demais → home + fullSync sem await (232-245) |
| **Voltar para a lista** (tela finalizada) | 1813-1827 | `context.go('/home')` simples |
| **Sair da tela de erro** ("Visita não encontrada") | 1129-1174 | limpa `last_visita_id` e vai pra home — "o promotor ficava preso aqui sem botão de voltar e tinha que reinstalar o app" (1130-1133) |

Estado restaurado ao reabrir a tela: fotos, checklist, observações e comentário vêm do banco em `_loadVisita` (`visita_screen.dart:329-378`); `LastVisitaService.set` no `initState` permite ao SplashRedirect devolver o promotor a esta visita se "o Android mate o app durante a captura (low memory + câmera aberta = caso comum em devices fracos)" (92-96).

---

## 6. Pontos sensíveis e bugs históricos citados em comentários do código

1. **`ref` após dispose (issues #10, #12, #13, 2026-05-22):** `AppDatabase` é capturado uma vez no `initState` (`_db`) porque `ref.read` depois de awaits com widget descartado crashava com "Bad state: Cannot use ref after disposed" (`visita_screen.dart:80-86`); o mesmo padrão de "capturar referências ANTES de qualquer await" se repete em `_sairParaHome` (224-228), `_iniciarVisita` (765-768), `_concluirFotosAntes` (852-857), `_concluirFotosDepois` (924-928), `_finalizarVisita` (984-988) e `_enfileirarVisita` (1079-1082).
2. **Null check no dialog (issue #16, 2026-05-26):** usar `dialogCtx` do builder em vez do `context` do State — "se o State pai for descartado durante o dialog (...) State.context joga 'Null check operator' e o app crasha" (`visita_screen.dart:203-207`).
3. **Path morto no grid (Cleiton, A05, 2026-05):** a watermark queue troca `_raw.jpg` por arquivo carimbado e apaga o cru; se a UI rebuildar com path antigo, `Image.file` cai no `errorBuilder` com placeholder "em vez de crash" (`visita_screen.dart:1861-1876`); a mitigação na raiz é (a) recarregar o JSON ao voltar do checklist (159-167) e (b) trocar o path no JSON **antes** de deletar o cru (`watermark_queue.dart:259-272`).
4. **Visita fantasma:** abertura e fotos antes são 100% locais; o servidor só fica sabendo (status 2) quando o promotor conclui as fotos antes — desistir no meio mantém "agendada" no servidor (`visita_screen.dart:776-777, 862-865`).
5. **Pivot de id durante a tela aberta:** `updateVisita` retorna linhas afetadas e o Finalizar loga "afetou 0 linhas — id obsoleto (pivot durante a tela aberta?)" para detectar write silenciosamente perdido (`visita_screen.dart:1012-1023`; `app_database.dart:418-423`). Causa raiz histórica do idTemp/consolidação documentada em `consolidarVisitaNoServer` — fotos e outbox órfãos, "fotos iam pro bucket mas nunca eram vinculadas à tabela" (`app_database.dart:429-443`); e o bug "realizadas viram em andamento" (casos **Jessica/Felipe/Thamara, 09-10/06**), em que a implementação antiga preservava dados velhos da row idTemp por cima da row fresca do servidor (`app_database.dart:457-470`). **Área classificada como alto risco nas regras do projeto.**
6. **`watermark_pending` precisa contar como pendência no destruir+re-baixar (Cleiton/Edilson, 2026-05-19/20):** sem incluir `watermark_pending` na lista de visitas a não-apagar, o pull apagava/recriava a row e as `pending_photos` ficavam órfãs — "fotos subiam pro Storage mas o array fotos_antes na tabela ficava vazio" (`app_database.dart:386-399`).
7. **Fotos congeladas travavam o outbox pra sempre (Glaucia/Camila/Thiago, build 220):** estados `uploading`/`watermark_pending` só existem com o app vivo; o recovery de boot reseta/re-enfileira, senão `countFotosEmProgresso` ficava > 0 eternamente e "a visita nunca consolidava no servidor" (`app_database.dart:552-563`; `app_router.dart:100-120`).
8. **`error` não é mais "em progresso":** antes travava o outbox da visita indefinidamente; agora a visita sincroniza com as fotos que subiram e a falhada fica de fora (`app_database.dart:703-708`).
9. **Órfãos pré-build 202 (hash não-determinístico):** migração `from < 4` limpa `pending_photos`/`outbox_items` apontando pra visitas inexistentes — sem isso o outbox ficava em "Posterga infinito" (`app_database.dart:257-270`); o nome de arquivo no Storage passou a usar hash determinístico para não "poluir o bucket com N cópias da mesma foto" (`sync_engine.dart:1219-1227`).
10. **Lock de sync cross-process:** app em foreground e isolate do WorkManager abrem o mesmo SQLite; sem lock real (UPDATE condicional atômico na row `__sync_lock__`, com TTL), push e pull simultâneos abriam "a janela de fotos/outbox órfãos" (`app_database.dart:749-803`); WAL + `busy_timeout=5000` no setup da conexão (806-823).
11. **Sessão Supabase expirada no upload:** sem `auth.uid`, o path virava `abastecimentos//…/` e o RLS rejeitava com 403 "travando o sync"; agora tenta `refreshSession` e, falhando, volta a foto pra `pending` sem consumir tentativa (`sync_engine.dart:1171-1203`).
12. **JSON local nunca recebe URLs:** `fotosXxxJson` é exclusivamente paths locais pro `Image.file`; URLs vivem em `pending_photos.storageUrl` (`sync_engine.dart:1251-1255`) — confusão aqui quebraria o grid.
13. **GPS nunca trava o promotor:** `getCurrentPosition` com timeout de 8 s, fallback pra última posição conhecida, e `null` é aceito pelo servidor (`visita_screen.dart:405-421`).
14. **Galeria é só-escrita:** única chamada `Gal.putImage` em `watermark_queue.dart:278` (falha vira anomalia D6, 280-295); remoções afetam apenas `wizmart_fotos/` e `pending_photos` (`visita_screen.dart:260-268, 734-738`) — coerente com a regra do projeto de nunca apagar fotos da galeria.
15. **Botões de UX defensiva:** dialog de confirmação no Concluir por cliques acidentais (`visita_screen.dart:801-804`); dialogs bloqueantes em vez de SnackBar para erros críticos — "SnackBar somia em 4s e ele não entendia o que perdeu" (587-589); o `close` do Finalizar **aguarda** o push para a home não mostrar status desatualizado (1049-1053).

---

**Notas finais para revisão (fora do markdown solicitado, mas relevantes):** dois achados menores durante a leitura — (1) `_salvarFotosLocalmente` (`visita_screen.dart:635-658`) é código morto sem nenhum caller; (2) a reordenação de fotos altera só o JSON, não o campo `numero` de `pending_photos`, então o número carimbado/nome no Storage reflete a ordem de captura, não a ordem final do grid; (3) o payload `close` não envia `comentarios_visita` ao servidor (gravado só localmente). São fatos verificados no código, registrados aqui caso o Alan queira tratá-los.
---

# PARTE 3 — Motor de sincronização

# Motor de Sincronização — WizMart Qualidade App

Documento técnico do subsistema de sync (pull + push/outbox + upload de fotos), baseado exclusivamente em leitura integral de `lib/core/network/sync_engine.dart`, dos trechos relevantes de `lib/core/database/app_database.dart`, de `lib/core/utils/error_classifier.dart` e dos pontos de chamada em `lib/main.dart`, `home_screen.dart`, `visita_screen.dart` e `watermark_queue.dart`. Todas as afirmações trazem `arquivo:linha`.

---

## 1. Visão geral e gatilhos de sincronização

### 1.1 API pública do SyncEngine

| Método | O que faz | Onde |
|---|---|---|
| `pullAll(promotorId)` | Só PULL (PDVs + gabaritos + visitas do dia) | `sync_engine.dart:108-118` |
| `fullSync(promotorId)` | PUSH (`_processOutboxImpl`) **e depois** PULL (`_pullAllImpl`), sob o **mesmo lock** — unidade atômica; push antes do pull para não perder dados locais não enviados | `sync_engine.dart:126-135` |
| `processOutbox()` | Só PUSH | `sync_engine.dart:525-534` |
| `isSyncing` | Flag consultada por consumidores que evitam ações destrutivas durante sync (force-update) | `sync_engine.dart:66` |

Tudo roda sob `_runExclusive` (`sync_engine.dart:88-106`): lock de re-entrância no isolate (`_syncing`, `sync_engine.dart:61`) **+** lock cross-process no SQLite (`tryAcquireSyncLock`, `app_database.dart:771-794`), porque o WorkManager roda em outro isolate com outra instância de SyncEngine (`sync_engine.dart:54-60`). O lock é um UPDATE condicional atômico na linha `__sync_lock__` da tabela `sync_state` (`app_database.dart:749-794`), com TTL de 240 s (`sync_engine.dart:74`) e liberação só pelo dono (`app_database.dart:798-803`). Sem esse lock, o pull de um processo apagava local enquanto o push do outro inseria — fotos/outbox órfãos (`app_database.dart:751-757`). Se já há sync em qualquer processo, o ciclo é **pulado**, não enfileirado (`sync_engine.dart:89-98`).

`fullSync` e `processOutbox` são abortados se `SyncPause.isPaused()` (captura de foto/câmera aberta) — `sync_engine.dart:127-130` e `sync_engine.dart:529-532`.

### 1.2 Gatilhos (quem dispara, quando)

| # | Gatilho | Chamada | Local |
|---|---|---|---|
| 1 | **WorkManager periódico** a cada 15 min (`AppConstants.syncIntervalMinutes`, `app_constants.dart:18`), constraint de rede conectada, mesmo com app fechado/Doze | `fullSync` (com sessão) ou `processOutbox` (deslogado), após ping real no Supabase (`main.dart:55`, `connectivity_service.dart:90`) | registro `main.dart:122-129`; execução `main.dart:44-79` (`callbackDispatcher`, task `wizmart_bg_sync`) |
| 2 | **WorkManager one-off** (`scheduleOneOffSync`, `ExistingWorkPolicy.keep`, backoff exponencial 30 s) | mesma task `_bgSyncTask` | definição `main.dart:31-42`; disparado a cada item enfileirado no outbox pela tela de visita (`visita_screen.dart:1099`, dentro de `_enfileirarVisita`, `visita_screen.dart:1082-1100`) |
| 3 | **App volta ao foreground** (lifecycle `resumed` do app) | `_kickSync` → `fullSync`/`processOutbox` + invalidação de providers da home | `main.dart:208-219` chama `main.dart:185-206` |
| 4 | **Conectividade off→on** (listener global) | `_kickSync` | `main.dart:231-235` |
| 5 | **Conectividade off→on com a home aberta** | `fullSync` + invalidações | `home_screen.dart:411-427` |
| 6 | **Home montada** (`initState`) | `_triggerSync` → `fullSync` | `home_screen.dart:76` → `home_screen.dart:118-139` |
| 7 | **Home volta do background** (lifecycle da tela) | `_triggerSync` | `home_screen.dart:108-116` |
| 8 | **Pull-to-refresh na home** | `fullSync` | `home_screen.dart:650-661` |
| 9 | **Sair da tela de visita para a home** (sem await, não trava navegação) | `fullSync`/`processOutbox` | `visita_screen.dart:227-245` |
| 10 | **Finalizar visita** (close) — com await, para a home já montar com status atualizado | `processOutbox` | `visita_screen.dart:1053-1057` |
| 11 | **Watermark queue terminou uma fila** (fotos prontas para upload) | `fullSync`/`processOutbox` | `watermark_queue.dart:368-378` (comentário em `watermark_queue.dart:14`) |

---

## 2. PULL — `_pullAllImpl`

Ordem fixa: `_pullPdvs` → `_pullGabaritos` → `_pullVisitasDia` (`sync_engine.dart:111-118`).

- **PDVs** (`sync_engine.dart:471-496`): `select` na tabela `pdv` filtrando `id_promotor_associado`, upsert local (`insertOnConflictUpdate`).
- **Gabaritos** (`sync_engine.dart:498-523`): `select` em `gabarito` com `ativo=true` (de **todos** os promotores), upsert local.

### 2.1 `_pullVisitasDia` passo a passo (`sync_engine.dart:137-469`)

Todo o método está num `try/catch` que apenas loga a exceção (`sync_engine.dart:466-468`) — pull nunca propaga erro.

**Janela temporal:** `inicioDia`/`fimDia` = hoje 00:00:00–23:59:59 convertidos para UTC ISO; `dataHoje` = `yyyy-MM-dd` local (`sync_engine.dart:139-145`).

**Passo 1 — Rota** (`sync_engine.dart:148-168`): busca `rotas` por `promotor_associado`; usa a **primeira** rota; extrai `gabaritos_associados`. Sem rota ou sem gabaritos → aborta o pull de visitas.

**Passo 2 — Edge function `gerar_datas_gabaritos_att`** (`sync_engine.dart:171-207`): POST HTTP direto em `${supabaseUrl}/functions/v1/gerar_datas_gabaritos_att` com `Authorization: Bearer <anonKey>` e payload:

```json
{ "gabarito_ids": [<gabaritos da rota>], "data_base": "<hoje>", "data_final": "<hoje>", "chunk_size": 20, "concurrency": 3 }
```
(`sync_engine.dart:177-190`). Resposta esperada: lista JSON de "vagas" do dia (`sync_engine.dart:198-200`). Status ≠ 200 só loga erro e segue com lista vazia — **o pull continua e a purga do passo 5 roda mesmo assim**.

**Passo 3 — Avulsas** (`sync_engine.dart:209-222`): `visitas` com `id_promotor_associado`, `visita_avulsa=true`, `dia_hora_agendado` dentro do dia. **Sem filtro de rota** (supervisor pode criar avulsa sem rota — comentário `sync_engine.dart:210-212`).

**Passo 4 — Reconciliação** (`sync_engine.dart:224-241`): busca no servidor as visitas do promotor de hoje com `status_visita IN (1,2)` (Concluída/Em Andamento no servidor) e indexa num mapa por chave `gabarito|pdv|turno` (`sync_engine.dart:236-241`). **Atenção:** se houver 2 rows com a mesma chave, uma sobrescreve a outra no mapa — mitigado pelo passo 6b.

**Passo 5 — Purga local "destruir + re-baixar"** (`sync_engine.dart:243-250` → `deleteVisitasSincronizadasSemPendencias`, `app_database.dart:375-413`). Apaga visitas do promotor onde **todas** as condições valem:
- `sync_status = 'synced'` (`app_database.dart:407-408`);
- o `id` **não** aparece em `outbox_items` com status `pending`/`processing` (`app_database.dart:377-384`);
- o `id` **não** aparece em `pending_photos` com status `watermark_pending`, `pending` ou `uploading` (`app_database.dart:395-403`). A inclusão de `watermark_pending` é fix do caso Cleiton/Edilson 2026-05-19/20 (`app_database.dart:386-394`).

**Preserva:** qualquer visita `pending` e qualquer visita referenciada por outbox/foto em progresso. **NÃO preserva por foto `uploaded`** — fotos já enviadas não protegem a visita (e as rows `uploaded` de `pending_photos` ficam para trás; ver §6.2). Apaga visitas de **qualquer data** (não há filtro de dia nessa query). Observação: existe um método mais antigo `deleteVisitasAgendadasHojeNaoModificadas` (`app_database.dart:352-366` — apaga só agendadas+synced de hoje) que **não é chamado em lugar nenhum** do `lib/` — código morto.

**Passo 6 — Salvar vagas normais** (`sync_engine.dart:252-375`). Para cada item da edge function:
1. Extrai `gabarito_id`, `pdv_associado`, `turno`, `diaHoraAgendado` (aceita os dois nomes de campo; normaliza para UTC ISO) — `sync_engine.dart:258-262`.
2. **Guard de pending:** se já existe visita local para (gabarito, pdv, turno, dia) com `syncStatus='pending'`, **pula** (não sobrescreve trabalho não sincronizado) — `sync_engine.dart:263-269` via `getVisitaByGabaritoTurnoData` (`app_database.dart:336-349`).
3. Cruza com o mapa do passo 4: se o servidor tem a visita como 1/2, `statusFinal = _fromServerStatus(...)` e `idVisita = id` do servidor; senão `statusFinal = Agendada` e `idVisita = item['id_visita']` (se a edge function devolver) — `sync_engine.dart:271-283`.
4. **Com `idVisita`** → upsert local com `id = serverId = idVisita`, status convertido, `dia_hora_realizado`/`dia_hora_abertura` do servidor, `syncStatus='synced'` (`sync_engine.dart:285-302`).
5. **Sem `idVisita` (vaga pura)** → **id temporário determinístico**: `idTemp = -_hashDeterministico(gabaritoId, pdvId, turno)` (`sync_engine.dart:309`).

#### `_hashDeterministico` — a chave SEM data e suas consequências (`sync_engine.dart:38-47`)

```dart
int _hashDeterministico(int gabaritoId, int pdvId, String turno) {
  final bytes = utf8.encode('$gabaritoId|$pdvId|$turno');
  final digest = sha1.convert(bytes).bytes;
  return ((digest[0] << 24) | (digest[1] << 16) | (digest[2] << 8) | digest[3]) & 0x7FFFFFFF;
}
```
- **Por que existe:** o `Object.hash` anterior usava `String.hashCode`, randomizado por isolate em Dart — cada relançamento do app gerava idTemp diferente para a mesma chave natural, duplicando linhas em `visitas` e deixando órfãos em `pending_photos`/`outbox_items` (caso Gabriel/335, 2026-05-29, 150+ pendências, 11 arquivos órfãos no bucket) — comentário `sync_engine.dart:21-37`.
- **Consequência da chave NÃO incluir a data:** o mesmo trio `gabarito|pdv|turno` em **dias/semanas diferentes** produz o **mesmo idTemp**. Em PDVs recorrentes, a "visita nova" colide com a row da rodada anterior. Duas mitigações no código, **ambas só para a tabela `visitas`**:
  - **Reciclagem/reset** (`sync_engine.dart:323-370`): o upsert da vaga zera explicitamente todos os campos de execução (`localState='idle'`, `fotosAntesJson/fotosDepoisJson=null`, `diaHoraAbertura/Realizado/FotosAntes/FotosDepois=null`, localizações, comentários e os 7 pares check/obs) — sem isso `localState='finalizada'` da semana anterior "vazava" e o promotor caía em "Visita finalizada!" ao abrir card Agendada (comentário `sync_engine.dart:321-329`). O reset é considerado seguro porque só roda para visita `synced` e não realizada/em-andamento no servidor hoje.
  - **Lookup por chave natural antes de inserir** (`sync_engine.dart:312-319`): se já existe row local para (gabarito, pdv, turno, **dia**) com id diferente (upgrade de builds <182 com `Object.hash`), preserva o id antigo (`idAlvo = existente?.id ?? idTemp`) para não orfanar foto/outbox pendente.
  - **O que NÃO é resetado:** rows `uploaded` de `pending_photos` com `visitaId = idTemp` — ver defeito §6.2/§6.3.

**Passo 6b — Órfãs/colisões** (`sync_engine.dart:377-427`): itera **todas** as rows do servidor com status 1/2 (não só as que casaram no passo 6) e upserta por id, pulando as `pending` locais. Cobre visitas cujo gabarito saiu da rota e colisões de chave `gabarito|pdv|turno` (2 visitas no mesmo trio) que o mapa do passo 4 sobrescrevia (`sync_engine.dart:379-387`).

**Passo 7 — Avulsas** (`sync_engine.dart:429-459`): upsert por id do servidor, pulando `pending` locais. **Particularidade:** grava `fotosAntesJson/fotosDepoisJson` com as **URLs do servidor** (`sync_engine.dart:452-453`) — diferente das visitas normais, onde esse JSON guarda paths locais.

**Fecho:** registra `lastPullAt` em `sync_state` (`sync_engine.dart:461-464`).

---

## 3. PUSH — `_processOutboxImpl` e o outbox

### 3.1 Estrutura do ciclo (`sync_engine.dart:536-590`)

1. Limpa `_idsMigradosNaRodada` (`sync_engine.dart:537`; propósito em `sync_engine.dart:76-81`).
2. **Fotos primeiro** (`sync_engine.dart:538-550`): `getPendingPhotos()` (status `pending` com `nextRetryAt` vencido, ordem `createdAt`, **lote de 5** — `app_database.dart:653-662`) → `_processPhotoUpload` para cada uma. Motivo: as URLs entram em `pending_photos.storageUrl` e o INSERT/UPDATE da visita logo em seguida já sobe com os arrays completos num único request (`sync_engine.dart:538-542`). Upload/outbox não marcam `ProcessingTracker` — a engrenagem da home reflete só watermark/galeria (`sync_engine.dart:542-546`).
3. **Outbox relido depois das fotos** (`sync_engine.dart:551-556`): `getPendingOutboxItems()` (status `pending`, `nextRetryAt` vencido, ordem `createdAt` ASC, **lote de 10** — `app_database.dart:531-540`) → `_processOutboxItem` para cada.
4. **Detector D5** (`sync_engine.dart:558-583`): visita local `statusVisita=3` (realizada) com `syncStatus='pending'` há >1h → enfileira anomalia `D5-visita-realizada-pending` (risco de virar falta no servidor). Não muda estado.
5. **Drena fila de anomalias** (issues + bug photos) com backoff, silencioso (`sync_engine.dart:585-589`).

### 3.2 Tipos de operação e quem os cria

| Operação | Criada por | Linha |
|---|---|---|
| `open` | abrir visita (tela) | `visita_screen.dart:872` |
| `close` | finalizar visita (tela) | `visita_screen.dart:1025` |
| `photos_antes` / `photos_depois` | o próprio sync engine, após cada upload de foto concluído | `sync_engine.dart:1270-1282` |

O `payloadJson` gravado no item é **ignorado** no envio — `_processOutboxItem` sempre relê o estado atual da visita no SQLite e monta o payload na hora (`sync_engine.dart:863-865`, comentário `sync_engine.dart:863-864`).

### 3.3 `_processOutboxItem` passo a passo (`sync_engine.dart:806-1092`)

1. **Resolução de id migrado**: `entityId = _idsMigradosNaRodada[item.entityId] ?? item.entityId` (`sync_engine.dart:806-811`) — o snapshot do outbox foi lido antes da consolidação; sem isso `getVisitaById(idTemp)` daria null e o item seria descartado (fotos órfãs de novo).
2. **Guard de fotos em progresso** (`sync_engine.dart:813-856`): por operação, exige slots completos — `open`/`photos_antes` → slot `antes`; `close`/`photos_depois` → `antes` **e** `depois` (fix do caso Alexsandra 2026-05-28, issue #23, `sync_engine.dart:826-830`). `countFotosEmProgresso` conta `watermark_pending|pending|uploading`; **`error` não conta** (estado terminal; antes travava o outbox para sempre — `app_database.dart:698-719`). Se houver foto em progresso, **posterga** (retorna sem tocar no item; a watermark queue redispara sync ao terminar).
3. Marca o item `processing` (`sync_engine.dart:858-861`).
4. **Guard de órfão**: `getVisitaById(entityId)==null` → loga "ÓRFÃO" com contagem de fotos uploaded penduradas e **descarta o item** (`sync_engine.dart:865-883`).
5. **Guard anti-fantasma** (`sync_engine.dart:885-916`): visita **não-avulsa**, `serverId==null`, `diaHoraAbertura==null` e `diaHoraRealizado==null` é lixo (vaga sem execução) — INSERT dela viraria "Em Andamento sem clique" no servidor (casos Felipe 222 09/06 e Thamara 224 10/06). Ação: apaga `pending_photos` da visita, apaga a visita local e o item (`sync_engine.dart:912-914`, helpers `app_database.dart:690-696`). Avulsa nunca descarta; visita com abertura OU realizado nunca descarta (`sync_engine.dart:899-905`).
6. Monta `payload = _buildVisitaPayload(visita, operation)` (ver §3.4) — `sync_engine.dart:918-919`.
7. **INSERT vs UPDATE pelo `serverId`** (`sync_engine.dart:931-1045`):
   - **`serverId == null` → INSERT** com `.select().maybeSingle()` (não `.single`: ON CONFLICT DO NOTHING retorna 0 rows e `.single` jogava PGRST116 em retry-loop — caso Thiago/Luís 09/06, `sync_engine.dart:938-947`).
     - Retornou row → `novoServerId = res['id']`.
     - 0 rows (**UPSERT-merge**, `sync_engine.dart:951-993`): SELECT no servidor pela chave natural completa (`id_promotor + id_gabarito + id_pdv + previsao_turno + dia_hora_agendado`, `sync_engine.dart:958-967`); se não achar, lança exceção para retry com backoff (`sync_engine.dart:968-976`); se achar, faz UPDATE **apenas com `_filtrarPayloadMinimo`** (não sobrescreve status nem `dia_hora_agendado` do servidor — caso Thamara 10/06, `sync_engine.dart:978-992`).
     - **Consolidação** `consolidarVisitaNoServer(entityId, novoServerId)` (`sync_engine.dart:994-997`; ver §3.6) e registro em `_idsMigradosNaRodada` se mudou (`sync_engine.dart:998-1007`).
   - **`serverId != null` → UPDATE direto**, também com `_filtrarPayloadMinimo` (caso Thiago 120437 10/06: payload completo recriava o fantasma a cada limpeza no servidor — `sync_engine.dart:1008-1015`). Payload mínimo vazio → skip do request (`sync_engine.dart:1017-1021`); UPDATE com 0 rows afetadas → só loga aviso (`sync_engine.dart:1033-1038`). Depois marca a visita local `synced` (`sync_engine.dart:1040-1044`).
8. **Sucesso** → `deleteOutboxItem(item.id)` (`sync_engine.dart:1046`).
9. **Falha** (`sync_engine.dart:1047-1091`): backoff exponencial `min(2^attempts × 30s, 1800s)` (`sync_engine.dart:1050`), item volta a `pending` com `nextRetryAt`/`lastError` (`sync_engine.dart:1084-1090`) — **outbox nunca vira `error`** (semântica diferente da foto, `sync_engine.dart:1055-1056`). Se travado há >2h **e** (`ErrorClassifier` = erro real **ou** `attempts > 5`) → anomalia `D3-outbox-stuck` (`sync_engine.dart:1057-1083`).

### 3.4 `_buildVisitaPayload` campo a campo (`sync_engine.dart:695-761`)

URLs lidas de `getUploadedPhotoUrls(v.id, slot)` — `pending_photos` com status `uploaded`, ordenadas por `numero` (`app_database.dart:724-737`). Antes de montar, roda a instrumentação `_logDiscrepanciaFotos` (capturadas no JSON local > uploaded → log de ERRO + anomalia `D4-discrepancia-fotos`; sintoma dos casos Jessica/Leandro — `sync_engine.dart:701-710` e `768-804`).

Campos **sempre** presentes (qualquer operação):
- `status_visita: _toServerStatus(v.statusVisita)` (`sync_engine.dart:713`)
- identidade: `id_pdv_associado`, `id_promotor_associado`, `dia_hora_agendado`, `rota_associada`, `id_gabarito_associado`, `titulo`, `previsao_turno_realizada`, `visita_avulsa` (`sync_engine.dart:714-721`)
- abertura/antes: `dia_hora_abertura`, `localizacao_abertura`, `dia_hora_fotos_antes`, `localizacao_fotos_antes` (`sync_engine.dart:722-725`)
- `fotos_antes` e `fotos_depois` **se não vazios, em qualquer operação** (`sync_engine.dart:726-731`) — antes `fotos_depois` só ia no `close`; URLs ficavam órfãs no bucket se o close falhasse (caso Jessica 2026-05-26, `sync_engine.dart:726-729`).

Campos adicionados **só no `close`** (`sync_engine.dart:734-756`): `dia_hora_realizado`, `dia_hora_fotos_depois`, `localizacao_fotos_depois`, `localizacao_encerramento`, `comentarios_visita`, e os 7 pares `check_pergunta_N`/`obs_pergunta_N`.

Por fim, **remove todos os nulls** para não sobrescrever dados do servidor em UPDATE (`sync_engine.dart:759`).

### 3.5 Mapeamento de status app ↔ servidor

Constantes do app (`app_constants.dart:29-32`): `statusAgendada=1`, `statusEmAndamento=2`, `statusRealizada=3`, `statusFalta=5`.

> ⚠️ Nomenclatura: o código chama o 5 de "falta", mas na tabela `status_visita` do Supabase **5 = Incompleta** e **3 = Não Realizada** (fato verificado em 11/06/2026, registrado no CLAUDE.md). O comportamento do código é coerente com o servidor; só o rótulo está errado.

**`_toServerStatus` (app → servidor, `sync_engine.dart:606-614`):**

| App | Servidor |
|---|---|
| 3 (realizada) | **1** (Concluída) |
| 2 (em andamento) | **2** (Em Andamento) |
| 5 ("falta"/Incompleta) | **5** (Incompleta) |
| 1 (agendada) ou null | **`StateError`** — não deve chegar aqui; o default antigo retornava 2 e era "fábrica de fantasma" (casos Felipe/Mauro/Thamara/Thiago 09-10/06, comentário `sync_engine.dart:598-605`) |

**`_fromServerStatus` (servidor → app, `sync_engine.dart:684-691`):**

| Servidor | App |
|---|---|
| 1 (Concluída) | 3 (realizada) |
| 2 (Em Andamento) | 2 |
| 5 (Incompleta) | 5 |
| null/3/4/outro | 1 (agendada) |

Sem essa conversão, "realizada no servidor (1)" chegava como "agendada (1)" no app e reabria visitas finalizadas (`sync_engine.dart:680-683`).

**`_filtrarPayloadMinimo` (`sync_engine.dart:635-674`)** — usado nos dois caminhos de UPDATE (UPSERT-merge e UPDATE direto): mantém só "trabalho novo do promotor": `fotos_antes/depois`, `dia_hora_abertura/realizado/fotos_antes/fotos_depois`, as 4 localizações, `comentarios_visita` e os 7 pares check/obs (`sync_engine.dart:636-662`). **Exclui** identidade, `dia_hora_agendado` e `status_visita` — status só passa se for **1 (Concluída)** ou **5 (Incompleta)**; **2 é bloqueado** (só pode vir de fantasma — `sync_engine.dart:667-673`).

### 3.6 Consolidação idTemp → serverId (`app_database.dart:444-507`)

Causa raiz histórica documentada em `app_database.dart:429-443`: a vaga nascia com PK=idTemp negativo; o INSERT setava só `serverId` mantendo a PK, mas o pull recriava com PK=serverId — a row idTemp era deletada/duplicada e fotos+outbox ficavam órfãos (fotos no bucket, nunca vinculadas à tabela).

Fluxo de `consolidarVisitaNoServer(idLocal, serverId)`:
1. **`idLocal == serverId`** (re-edição de visita já sincronizada): só marca `serverId`, `syncStatus='synced'`, `syncedAt` (`app_database.dart:446-456`).
2. Senão, **numa única transação** (`app_database.dart:457-506`):
   - **Se já existe row local com PK=serverId** (criada pelo pull, dados frescos do servidor): preserva os campos dela (só atualiza sync state), **migra `pending_photos.visitaId` e `outbox_items.entityId` de idLocal→serverId**, e apaga a row idLocal (`app_database.dart:471-490`). A implementação antiga fazia o inverso (preservava a row idTemp com dados velhos) — causa do bug "realizadas viram em andamento" (casos Jessica/Felipe/Thamara 09-10/06, `app_database.dart:458-470`).
   - **Se não existe**: muda a própria PK da row idLocal para serverId (+ `serverId`, `synced`) e migra `pending_photos` e `outbox_items` (`app_database.dart:492-505`).

No engine, a migração é registrada em `_idsMigradosNaRodada[entityId]=novoServerId` para os demais itens do snapshot da rodada (`sync_engine.dart:998-1004`; mapa em `sync_engine.dart:81`).

---

## 4. Upload de fotos — `_processPhotoUpload` (`sync_engine.dart:1149-1343`)

1. Marca a foto `uploading` (`sync_engine.dart:1150-1153`).
2. Arquivo local não existe → status `error` e retorna (irrecuperável; não bloqueia mais o outbox — ver `countFotosEmProgresso`, `app_database.dart:703-708`) — `sync_engine.dart:1155-1164`.
3. **Auth**: precisa de `auth.uid` no path (policies do bucket comparam com `auth.uid()`). Se `currentUser==null`, tenta `refreshSession` (timeout 6 s); falhou → `AuthSessionExpired.set()`, foto volta a `pending` **sem consumir tentativa**, UI força relogin (`sync_engine.dart:1170-1204`).
4. **Path no Storage** (padrão do app FlutterFlow antigo, `sync_engine.dart:1166-1233`):

```
abastecimentos/{authUid}/{dataAgendadoBrasil sanitizada}/{nomePDV}-{visitaHash}-{slot}-{numero}.{ext}
```
   - `dataAgendadoBrasil` = `dia_hora_agendado` UTC −3h, formato `yyyy-MM-dd HH:mm:ss` (`sync_engine.dart:1205-1216`);
   - `nomePDV` = título da visita limpo (`_limparNomeArquivo`: remove acentos/especiais, máx. 6 palavras — `sync_engine.dart:1097-1122`);
   - `visitaHash` = **`_hashDeterministico(gabarito, pdv, turno)`** — mesmo nome de arquivo entre runs (antes `Object.hash` poluía o bucket com N cópias — `sync_engine.dart:1219-1227`);
   - cada segmento passa por `_sanitizePathSegment` (`:`→`-`, espaço→`_`, sem acentos — `sync_engine.dart:1124-1147`).
5. **Upload** no bucket `Arquivos` via `uploadBinary` com `upsert: true` (idempotente: retry sobrescreve o mesmo arquivo — coerente com `resetUploadingNoBoot`, `app_database.dart:562-574`) e content-type por extensão (`sync_engine.dart:1238-1246`, `_contentTypeFromExt` `sync_engine.dart:1357-1372`).
6. **Vínculo da URL**: `getPublicUrl` → grava em `pending_photos.storageUrl` com status `uploaded` (`sync_engine.dart:1247-1260`). **Não toca** em `fotosAntesJson/fotosDepoisJson` — aquele JSON é fonte de verdade dos paths locais do grid; as URLs vivem só em `pending_photos` e são lidas por `getUploadedPhotoUrls` na montagem do payload (`sync_engine.dart:1251-1255`).
7. **Marca a visita `syncStatus='pending'`** (`sync_engine.dart:1262-1266`) e **enfileira** um outbox item `photos_antes`/`photos_depois` com `payloadJson='{}'` (`sync_engine.dart:1268-1282`) — o array chega ao servidor no mesmo ciclo (o outbox é relido depois das fotos, `sync_engine.dart:551-553`).
8. **Falha** (`sync_engine.dart:1283-1342`): classifica com `ErrorClassifier` (+ `_extrairHttpStatus`, `sync_engine.dart:1345-1355`):
   - **erro real** → status `error` (destrava o outbox da visita), anomalia `D1-upload-erro-real` + upload da foto pro bucket de bug-report (`sync_engine.dart:1292-1328`);
   - **rede/desconhecido** → volta a `pending` com backoff `min(2^attempts × 30s, 1800s)` (`sync_engine.dart:1330-1341`).

Recovery no boot (antes do SyncEngine subir): `resetUploadingNoBoot` (uploading→pending, `app_database.dart:565-574`) e `getStaleWatermarkPending` para re-enfileirar watermark (`app_database.dart:579-583`) — sem isso, app morto no meio congelava fotos e travava o outbox para sempre (`app_database.dart:552-560`).

---

## 5. Classificação de erros — `ErrorClassifier` (`error_classifier.dart`)

Três categorias (`error_classifier.dart:18-28`):

| Categoria | Efeito |
|---|---|
| `redeTransitoria` | Retenta com backoff. Não vira `error`, não gera auto-issue (`error_classifier.dart:4-5`). No upload: foto volta a `pending` (`sync_engine.dart:1330-1341`). No outbox: item segue `pending` com backoff. |
| `authExpirada` | Token Supabase expirou (401) → caminho de `refreshSession`/relogin (`error_classifier.dart:22`; uso prático em `sync_engine.dart:1180-1203`). |
| `erroReal` | Permanente (4xx, arquivo apagado, payload inválido, constraint) → `error` no SQLite + auto-issue (`error_classifier.dart:25-27`). No upload: foto vira `error` + D1 (`sync_engine.dart:1292-1328`). No outbox: **não** vira `error`, só habilita a anomalia D3 se travado >2h (`sync_engine.dart:1057-1083`). |

Regras de `classificar` em ordem (`error_classifier.dart:35-118`):
1. **HTTP status manda**: 5xx → rede; 408/429 → rede; 401 → auth; demais 4xx → erro real (`error_classifier.dart:37-50`).
2. **Tipo da exceção**: `SocketException`/`TimeoutException`/`HandshakeException`/`HttpException` → rede; `FileSystemException`/`FormatException` → erro real (`error_classifier.dart:53-58`).
3. **`PostgrestException`**: código `23xxx`/`22xxx` (constraint/dados) → erro real; código `'401'` → auth (`error_classifier.dart:61-70`).
4. **`StorageException`**: reclassifica pelo statusCode numérico (`error_classifier.dart:73-79`).
5. **`AuthException`**: mensagem com `jwt`/`expir`/`invalid token` → auth (`error_classifier.dart:82-88`).
6. **Padrões de texto de rede** (`failed host lookup`, `connection refused/reset/closed`, `broken pipe`, errnos 7/101/104/110/111/113, etc.) → rede (`error_classifier.dart:92-113`).
7. **Default conservador: rede** (retenta; evita auto-issue indevido) — `error_classifier.dart:115-117` e cabeçalho `error_classifier.dart:9-11`.

---

## 6. Pontos sensíveis, bugs históricos e defeitos conhecidos

### 6.1 Bugs históricos documentados em comentários (com nome/data)

| Caso | Bug | Fix / referência |
|---|---|---|
| **Gabriel/335, 2026-05-29** | idTemp não-determinístico (`Object.hash`) duplicava visitas e orfanava fotos/outbox; 150+ pendências, 11 órfãs no bucket | `_hashDeterministico` SHA-1 (`sync_engine.dart:21-47`) + lookup por chave natural no pull (`sync_engine.dart:312-319`) |
| **Cleiton/Edilson, 2026-05-19/21** | pull apagava visita com foto ainda em `watermark_pending`; INSERT `open` subia com `fotos_antes=[]`; e `ref` após dispose crashava | purga preserva `watermark_pending` (`app_database.dart:386-394`); guard de fotos em progresso (`sync_engine.dart:813-833`); guard `context.mounted` (`home_screen.dart:417-421`) |
| **Jessica, 2026-05-26** | `fotos_depois` só ia no `close`; URLs órfãs no bucket | arrays em qualquer operação com URLs (`sync_engine.dart:726-731`) |
| **Alexsandra, 2026-05-28 (issue #23)** | `photos_depois` só checava slot `depois`; visita subiu com 2 "antes" faltando | `close`/`photos_depois` exigem ambos os slots (`sync_engine.dart:826-844`) |
| **Felipe 222 / Mauro / Thamara 224 / Thiago, 09-10/06** | default de `_toServerStatus` mandava 2 (Em Andamento) para visita Agendada → fantasmas | `StateError` no default (`sync_engine.dart:598-614`), guard anti-fantasma (`sync_engine.dart:885-916`), payload mínimo nos UPDATEs (`sync_engine.dart:635-674`, `978-992`, `1009-1016`) |
| **Thiago/Luís, 09/06 (60+ issues D5)** | `.single` após INSERT em conflito jogava PGRST116 em retry-loop infinito | `.maybeSingle` + UPSERT-merge (`sync_engine.dart:938-993`) |
| **Jessica/Felipe/Thamara, 09-10/06** | consolidação antiga preservava a row idTemp (dados velhos) e apagava a do servidor — "realizada vira em andamento" | inverteu: preserva row do servidor, migra só fotos/outbox (`app_database.dart:458-490`) |
| **Recorrência pós-fixes** | app e WorkManager (isolates distintos) sincronizando simultaneamente | lock cross-process no SQLite (`sync_engine.dart:54-60`, `app_database.dart:749-803`) |

### 6.2 Defeito conhecido: fotos `uploaded` nunca são purgadas

Não existe nenhum caminho que apague rows de `pending_photos` com status `uploaded`: as únicas deleções são `deletePendingPhotosByPath` (botão "X" do grid, `app_database.dart:684-686`) e `deletePendingPhotosByVisita` (só no guard anti-fantasma, `sync_engine.dart:912`, `app_database.dart:690-692`). A purga do pull apaga **visitas** (`app_database.dart:405-412`), não as fotos; e fotos `uploaded` nem protegem a visita da purga (apenas `watermark_pending|pending|uploading` entram no `naoApagar`, `app_database.dart:395-403`). Resultado: rows `uploaded` com `storageUrl` acumulam indefinidamente no banco local, presas a um `visitaId` que pode ser reutilizado.

### 6.3 Defeito conhecido: herança de fotos pelo idTemp sem data

Combinação dos itens anteriores: o idTemp é `-hash(gabarito|pdv|turno)` **sem data** (`sync_engine.dart:38-47`, `309`). Na semana seguinte, a vaga do mesmo trio nasce com o **mesmo idTemp**; o reset do pull zera os campos da **visita** (`sync_engine.dart:330-370`) mas **não** as rows `uploaded` antigas de `pending_photos` ainda vinculadas àquele idTemp (§6.2). Quando essa visita gerar payload, `getUploadedPhotoUrls(idTemp, slot)` (`sync_engine.dart:698-699`, `app_database.dart:724-737`) devolve também as URLs da rodada anterior — a visita nova pode **herdar fotos antigas** nos arrays.

### 6.4 Defeito conhecido: arrays re-gravados com estado local

`_buildVisitaPayload` monta `fotos_antes`/`fotos_depois` exclusivamente a partir do `pending_photos` **local** (`sync_engine.dart:698-699`, `730-731`), e `_filtrarPayloadMinimo` deixa esses campos passar em qualquer UPDATE (`sync_engine.dart:637-638`). O UPDATE **substitui** o array no servidor pelo estado local — não há merge com o que já existe na row do servidor. Qualquer outbox item tardio (ex.: `photos_*` re-tentado dias depois, ou item herdado via consolidação/idTemp reciclado) re-grava os arrays do servidor com o recorte local daquele momento, podendo remover URLs legítimas ou re-inserir antigas. É a mecânica por trás das "URLs duplicadas nos arrays" citada na investigação em aberto (pendência registrada no CLAUDE.md/handoff).

### 6.5 Outras observações de risco

- **Pull continua mesmo com edge function falhando** (`sync_engine.dart:194-200`): a purga do passo 5 roda antes do loop de recriação; se a edge function retornar erro, visitas agendadas synced de hoje são apagadas e não recriadas até o próximo pull bem-sucedido (as realizadas/andamento voltam pelo passo 6b; trabalho pendente é sempre preservado).
- **Janela de pivot com tela aberta**: se a consolidação muda a PK enquanto `visita_screen` segura o idTemp, o `updateVisita` do finalizar afeta 0 linhas — instrumentado, não corrigido (`visita_screen.dart:1012-1023`, `app_database.dart:418-423`).
- **Status 3 e 4 do servidor** (Não Realizada/Agendada) nunca são escritos pelo app — `_toServerStatus` só emite 1/2/5 (`sync_engine.dart:606-614`); são carimbados pelo Supabase. No pull, servidor 3/4 viram "agendada" no app (`sync_engine.dart:690`).
- **`deleteVisitasAgendadasHojeNaoModificadas`** (`app_database.dart:352-366`) é código morto — nenhum caller em `lib/`.
- **Lotes pequenos por ciclo**: 5 fotos (`app_database.dart:660`) e 10 outbox items (`app_database.dart:538`) por rodada — backlog grande exige múltiplos ciclos.
---

# PARTE 4 — Anomalias, banco local, infra e CI

# Anomalias, Banco Local, Infra e CI — WizMart Qualidade App

> Documento gerado em 11/06/2026 por leitura integral dos arquivos citados. Toda afirmação traz `arquivo:linha`.

---

## 1. Sistema de detecção de anomalias (D1–D6)

### 1.1 Arquitetura geral

O sistema tem 3 peças:

| Peça | Arquivo | Papel |
|---|---|---|
| `AnomaliaReporter` | `lib/core/utils/anomalia_reporter.dart` | Recebe a detecção, aplica cooldown, monta o body markdown completo (com dump SQLite e log) **no momento da detecção** e grava nas filas locais. Nunca faz HTTP. |
| `AnomaliaQueueProcessor` | `lib/core/utils/anomalia_queue_processor.dart` | Drena as filas: POST de issues pro GitHub e upload das fotos pro bucket `bug-reports` do Supabase. Roda dentro do ciclo de sync, sem timer próprio (`anomalia_queue_processor.dart:7-8`), chamado ao fim de cada `_processOutboxImpl` (`sync_engine.dart:585-589`). |
| Detectores D1–D6 | espalhados em `sync_engine.dart` e `watermark_queue.dart` | Cada um chama `AnomaliaReporter.enfileirar(...)` com um `tipo` fixo. |

**Princípio:** nada disso é crítico — tudo em try/catch defensivo, falha vira retry, "o app não pode quebrar por causa de telemetria" (`anomalia_reporter.dart:101-109`, `anomalia_queue_processor.dart:11-13`).

### 1.2 Cooldown

- **10 minutos por par (tipo, entidadeId)** — constante `_cooldownMinutos = 10` (`anomalia_reporter.dart:39`).
- Chave em **SharedPreferences**: `anomalia_cooldown_<tipo>_<entidadeId ?? "_">` (`anomalia_reporter.dart:148-149`) — **sobrevive a restart do app** (`anomalia_reporter.dart:9-10`).
- Se a mesma chave foi reportada há menos de 10 min, `enfileirar` retorna `false` sem gravar nada (`anomalia_reporter.dart:54-65`).

### 1.3 Filas locais e backoff

- **`pending_issues`**: body markdown já pronto + labels em JSON, status `pending` → `sent` (campo `githubIssueNumber` preenchido) (`anomalia_queue_processor.dart:121-145`).
- **`pending_bug_photos`**: foto física a subir pro bucket `bug-reports`, status `pending` → `uploaded` (campo `publicUrl`) ou `error` se o arquivo local sumiu (`anomalia_queue_processor.dart:60-103`).
- **Backoff exponencial idêntico ao outbox**: `min(2^attempts * 30, 1800)` segundos — teto de 30 min — tanto pra fotos (`anomalia_queue_processor.dart:107`) quanto pra issues (`anomalia_queue_processor.dart:232`). `lastError` truncado em 500 chars (`anomalia_queue_processor.dart:113-115, 238-240`).
- O processor é reentrant-safe (`_draining`, `anomalia_queue_processor.dart:41-43`) e drena primeiro as fotos, depois as issues (`anomalia_queue_processor.dart:45-46`) — assim as URLs públicas das fotos já podem ser **injetadas no final do body** antes do POST, na seção `## Fotos no bug-report bucket` (`anomalia_queue_processor.dart:150-170`).

### 1.4 Formato da issue de anomalia

- **Título:** `[ANOMALIA][<tipo>] <resumo>` (`anomalia_reporter.dart:70`).
- **Labels:** `auto`, `anomalia`, `tipo:<tipo>`, `build:<BUILD_NUMBER>`, `screen:<tela atual>` (`anomalia_reporter.dart:80-86`).
- **Repo destino:** `alanclaudiolang/wizmart-qualidade-app` (`anomalia_queue_processor.dart:28-29`).
- **Body** (montado na detecção, `anomalia_reporter.dart:154-240`), nesta ordem:
  1. `## Resumo` — tipo, entidade, visitaId (se numérico ou vindo de `contextoExtra['visitaId']`, `anomalia_reporter.dart:242-254`), mensagem, timestamp;
  2. `## Exceção` — erro + stack truncado em 2000 chars (`anomalia_reporter.dart:175-185`);
  3. `## Promotor` (id/email/nome da sessão), `## Device` (marca, fabricante, modelo, Android/SDK, RAM, storage livre, bateria %, estado), `## App` (versão pubspec, build real do dart-define, buildTime) — coleta em `anomalia_reporter.dart:357-414`;
  4. `## Contexto extra` — JSON identado (`anomalia_reporter.dart:214-220`);
  5. **Dump SQLite**: se há visitaId, dump da row de `visitas` (status, localState, datas, tamanhos dos JSONs de fotos — `anomalia_reporter.dart:257-283`) + todas as rows de `pending_photos` da visita (slot, número, status, attempts, URL, path — `anomalia_reporter.dart:285-302`) + `outbox_items` da visita (op, status, attempts, lastError truncado em 300 — `anomalia_reporter.dart:304-326`). Sem visitaId, dump geral: totais de visitas/pending/fotos/outbox (`anomalia_reporter.dart:330-344`);
  6. `## Log persistente (últimas 500 linhas)` (`anomalia_reporter.dart:230-237`).
- **Particionamento:** body > 60 000 chars (`_maxBodyChars`, `anomalia_queue_processor.dart:31`) é dividido preservando linhas e blocos de código (` ``` ` não é cortado no meio — `anomalia_queue_processor.dart:246-262`); a 1ª parte vira o issue com sufixo `[1/n]` e aviso "_Continua nos comentários_", as demais viram comments `## Parte i de n` (`anomalia_queue_processor.dart:172-228`). Timeouts: 20 s no POST do issue, 15 s por comment.

### 1.5 Os seis detectores

| # | Tipo (label `tipo:`) | Onde dispara | Condição EXATA | Efeito no fluxo |
|---|---|---|---|---|
| **D1** | `D1-upload-erro-real` | `sync_engine.dart:1300-1327` (catch de `_processPhotoUpload`) | Upload da foto pro bucket `Arquivos` lança exceção classificada como **`erroReal`** pelo `ErrorClassifier` (`sync_engine.dart:1289-1292`) | Foto vira `status='error'` (destrava o outbox da visita, `sync_engine.dart:1293-1299`); enfileira **também a foto física** via `enfileirarBugPhoto` (`sync_engine.dart:1304-1310`) com destino `bug-reports/<promotorId>/<visitaId>/<fotoId>.jpg` (`anomalia_reporter.dart:125-126`). Contexto extra: fotoId, slot, numero, visitaId, httpStatus, attempts (`sync_engine.dart:1317-1324`). Erro de rede transitória NÃO dispara — segue backoff normal (`sync_engine.dart:1330-1341`). |
| **D2** | `D2-watermark-travado` | `watermark_queue.dart:179-205` (início de `_processarItemInner`) | Foto com `status='watermark_pending'` cujo `createdAt` está há **mais de 30 minutos** no passado (`watermark_queue.dart:188`) | Nenhum — continua tentando aplicar o watermark (`watermark_queue.dart:181-182`). Contexto extra: visitaId, fotoId, slot, numero, criadoEm, tentativas (`watermark_queue.dart:196-203`). Sinais típicos: app fechou no meio, isolate morreu, bug no Canvas (`watermark_queue.dart:179-180`). |
| **D3** | `D3-outbox-stuck` | `sync_engine.dart:1053-1083` (catch de `_processOutboxItem`) | Item do outbox com `createdAt` há **mais de 2 horas** **E** (erro classificado `erroReal` **OU** `attempts > 5`) (`sync_engine.dart:1058-1063`) | Item **permanece `pending`** com backoff (não vira `error` — `sync_engine.dart:1055-1056, 1084-1090`). Contexto extra: visitaId, outboxId, operation, attempts, classe do erro, criadoEm (`sync_engine.dart:1071-1078`); inclui exceção+stack. |
| **D4** | `D4-discrepancia-fotos` | `sync_engine.dart:785-803` (`_logDiscrepanciaFotos`, chamado por `_buildVisitaPayload` em `sync_engine.dart:707-710`) | Nº de fotos **capturadas** (`fotosAntesJson`/`fotosDepoisJson` — paths locais, fonte de verdade do grid) **maior** que o nº de URLs `uploaded` prontas pra subir (`sync_engine.dart:778`). Slot `antes` checado em toda operação; `depois` só em `close` (`sync_engine.dart:707-710`) | Nenhum — a visita sobe mesmo assim (`sync_engine.dart:785`). Também loga ERRO no SyncLogger (`sync_engine.dart:779-784`). Contexto extra: visitaId, serverId, operation, slot, capturadas, uploaded, faltam (`sync_engine.dart:793-801`). É o detector do sintoma "visita sincronizou com fotos faltando" (casos Jessica/Leandro, `sync_engine.dart:705-706`). |
| **D5** | `D5-visita-realizada-pending` | `sync_engine.dart:558-583` (final de `_processOutboxImpl`, todo ciclo de push) | SQL: visita com `sync_status='pending'` **E** `status_visita=3` (statusRealizada local) **E** (`synced_at IS NULL` OU `synced_at` < agora−**1 hora**) (`sync_engine.dart:563-571`) | Nenhum — "Não muda o estado" (`sync_engine.dart:561`). Risco sinalizado: o servidor pode não ter recebido e a visita virar FALTA (`sync_engine.dart:559-560`). |
| **D6** | `D6-gal-falhou` | `watermark_queue.dart:274-295` | `Gal.putImage(wmPath)` (salvar foto com marca d'água na galeria) falha ou estoura o **timeout de 5 s** (`watermark_queue.dart:278`) | Nenhum — falha é silenciosa pro fluxo (`watermark_queue.dart:274`). Em geral indica promotor sem permissão de galeria = **sem backup automático** (`watermark_queue.dart:275-276, 286-287`). Contexto extra: visitaId, fotoId, wmPath (`watermark_queue.dart:288-292`). |

### 1.6 Classificação de erros (decide D1/D3)

`lib/core/utils/error_classifier.dart` — três classes (`error_classifier.dart:18-28`):

- **`redeTransitoria`** (retenta, NÃO gera issue): HTTP 5xx, 408, 429 (`:38-43`); `SocketException`/`TimeoutException`/`HandshakeException`/`HttpException` (`:53-56`); padrões de texto de rede ("failed host lookup", "connection refused", errno 7/101/104/110/111/113 etc., `:92-113`); **default conservador** pra tudo desconhecido (`:115-117`).
- **`authExpirada`**: HTTP 401 (`:44-46`), `PostgrestException` code 401 (`:68`), `AuthException` com "jwt"/"expir"/"invalid token" (`:82-88`).
- **`erroReal`** (vira `error` + auto-issue): HTTP 4xx restantes (`:47-49`); `FileSystemException`, `FormatException` (`:57-58`); `PostgrestException` com código `23xxx`/`22xxx` (constraint/dados, `:61-65`); `StorageException` resolvido pelo statusCode (`:73-79`).

---

## 2. ErrorReporter (crashes) e issue [ESTADO] por promotor

### 2.1 ErrorReporter — `lib/core/utils/error_reporter.dart`

**Quando dispara (ganchos globais em `lib/main.dart`):**
- `FlutterError.onError` — qualquer erro Flutter não tratado (`main.dart:90-98`);
- `PlatformDispatcher.instance.onError` — erros assíncronos não tratados (`main.dart:101-109`);
- `runZonedGuarded` — erro fatal no boot, com `screen: 'boot'`; se o issue foi criado, mostra mensagem amigável; se não (offline), mostra tela vermelha pedindo print (`main.dart:135-156`);
- Pontuais: falha de item na watermark queue (`watermark_queue.dart:144-149`) e três pontos da tela de visita (`visita_screen.dart:570, 901, 1067`).

**Comportamento:**
- Síncrono (POST direto, sem fila local) — diferente do `AnomaliaReporter`.
- **Cooldown de 5 minutos POR TELA** (`_cooldown`, `error_reporter.dart:36`; mapa em memória `_ultimoReportePorScreen`, `error_reporter.dart:45, 70-76`). A tela atual vem de `CurrentScreen.nome` (NavigatorObserver do GoRouter, `error_reporter.dart:8-9, 60`). Dentro do cooldown retorna `null` sem postar; o log persistente registra sempre (`error_reporter.dart:62-68`).
- **Título:** `[BUG][<tela>] <erro truncado em 70 chars>` (`error_reporter.dart:85-90`).
- **Labels:** `bug`, `auto`, `screen:<tela>`, `build:<BUILD_NUMBER>` (`error_reporter.dart:104-109`).
- **Body** (`error_reporter.dart:279-331`): `## Erro` (tela, contexto, erro, stack), `## Promotor`, `## Device`, `## Estado no momento` (storage livre/total, bateria), `## App` (BUILD real do dart-define + buildTime — pkg.version do pubspec é igual em todo build e inútil, `error_reporter.dart:261-264`), `## Log (últimas 500 linhas)`.
- **Particionamento:** limite de 60 000 chars com margem sobre os 65 536 do GitHub (`error_reporter.dart:38-42`); partes extras viram comments (`error_reporter.dart:333-419`); quebra preferencial em `\n`, quebra forçada por chars só se uma linha exceder o limite (`error_reporter.dart:421-450`). Timeout do POST: 20 s (`error_reporter.dart:367`).

**Variante manual `reportarUsuario`** (menu "Reportar problema", chamada em `home_screen.dart:361`): **sem cooldown**, label `user-report` no lugar de `auto`, título `[USUÁRIO][<tela>]`, **1000 linhas** de log (`error_reporter.dart:120-199`).

**PAT usado:** `AppConstants.githubBugReportToken` — PAT fine-grained com escopos **Contents:write + Issues:write** neste repo, injetado em build time via `--dart-define=GITHUB_BUG_TOKEN=...` (`app_constants.dart:45-49`); no CI vem do secret **`BUG_REPORT_PAT`** (`build_apk.yml:111, 123`). Vazio em build local → reporter vira no-op (`error_reporter.dart:78-79`).

### 2.2 Issue [ESTADO] por promotor — `lib/core/utils/promotor_estado_reporter.dart`

- **1 issue por promotor**, título `[ESTADO] <email normalizado>`, label `promotor-estado` (`promotor_estado_reporter.dart:35, 54`). Mapeia em qual build cada promotor está sem consultar o Supabase (`promotor_estado_reporter.dart:3-5`).
- **Gatilho:** só após login bem-sucedido na auth_screen — install/reinstall/expiração de sessão passam todos por lá (`promotor_estado_reporter.dart:12-15`).
- **Body:** promotor, email, build, app version, plataforma, último login ISO (`promotor_estado_reporter.dart:90-99`).
- **Fluxo de deduplicação** (`promotor_estado_reporter.dart:56-83`): (1) número salvo em SharedPreferences (`promotor_estado_issue_<email>`) → PATCH direto (reabre com `state: open`, `:140`); (2) sem número → busca por título exato via Search API com confirmação exata por causa do fuzzy (`:149-177`); (3) não existe → cria.
- **Fire-and-forget total**: qualquer falha é engolida sem log (`promotor_estado_reporter.dart:7-10, 84-87`). Timeouts de 8 s em todas as chamadas.

---

## 3. Banco local (Drift/SQLite) — `lib/core/database/app_database.dart`

Arquivo físico: `wizmart.sqlite` no documents dir do app (`app_database.dart:808-809`). Pragmas: `journal_mode=WAL`, `busy_timeout=5000`, `synchronous=NORMAL` — necessários porque o isolate do WorkManager abre conexão paralela (`app_database.dart:812-820`).

### 3.1 Tabelas

**`users`** (`app_database.dart:13-26`) — espelho do promotor logado:
| Coluna | Papel |
|---|---|
| `id` (PK) | id do usuário no Supabase |
| `nome`, `email`, `foto`, `telefone` | dados cadastrais |
| `tipoUser` | tipo de usuário |
| `ativo` (default true) | flag de ativo |
| `areaAtuacao` | área de atuação |
| `syncedAt` | timestamp do último sync |

**`pdvs`** (`app_database.dart:28-41`) — pontos de venda do promotor (pull em `sync_engine.dart:471-496`):
| Coluna | Papel |
|---|---|
| `id` (PK) | id do PDV no Supabase |
| `apiLocalName`, `apiLocalCustomerName` | nomes vindos da API |
| `endereco`, `apiSpecificLocation` | localização textual |
| `lat`, `lng` | coordenadas |
| `situacao` | ativo/inativo |
| `syncedAt` | timestamp do pull |

**`gabaritos`** (`app_database.dart:43-56`) — gabaritos ativos (pull em `sync_engine.dart:498-523`):
| Coluna | Papel |
|---|---|
| `id` (PK) | id no Supabase |
| `nome` | nome do gabarito |
| `pdvAssociado` (not null) | PDV alvo |
| `rotaAssociada`, `promotorAssociado` | vínculos |
| `ativo` (default true), `padrao` (default false) | flags |
| `prazoValidade` | prazo |
| `syncedAt` | timestamp do pull |

**`visitas`** (`app_database.dart:58-122`) — coração do app:
| Coluna | Papel |
|---|---|
| `id` (PK) | **id local**: positivo = id do servidor; negativo = idTemp determinístico `-SHA1(gabarito\|pdv\|turno)` (`sync_engine.dart:38-47, 309`) |
| `serverId` | id no servidor; `null` = ainda não criada lá (offline / aguardando INSERT). O id local "nunca muda" pra não quebrar referências de PendingPhotos/OutboxItems (`app_database.dart:76-81`) — a consolidação idTemp→serverId migra PK + fotos + outbox na mesma transação (`consolidarVisitaNoServer`, `app_database.dart:444-507`) |
| `idPdvAssociado`, `idPromotorAssociado`, `rotaAssociada`, `idGabaritoAssociado` | vínculos |
| `diaHoraAgendado`, `diaHoraRealizado`, `diaHoraAbertura`, `diaHoraFotosAntes`, `diaHoraFotosDepois` | timestamps do ciclo da visita |
| `statusVisita` | **status LOCAL: 1=agendada 2=andamento 3=realizada 5=falta** (`app_database.dart:66`) — ⚠️ codificação ≠ servidor, ver §5 |
| `titulo`, `previsaoTurnoRealizada`, `visitaAvulsa` | metadados vindos da Edge Function/Supabase |
| `localizacaoAbertura`, `localizacaoEncerramento`, `localizacaoFotosAntes`, `localizacaoFotosDepois` | GPS de cada etapa |
| `fotosAntesJson`, `fotosDepoisJson` | **JSON de PATHS LOCAIS** (fonte de verdade do grid de fotos); URLs do servidor ficam em `pending_photos.storageUrl` (`sync_engine.dart:1251-1255`) |
| `checkPergunta1..7`, `obsPergunta1..7` | checklist (bool + observação por pergunta) |
| `comentariosVisita` | comentário livre |
| `syncStatus` | `'synced'` \| `'pending'` \| `'error'` (default `synced`) (`app_database.dart:113-114`) |
| `syncedAt` | timestamp do último sync |
| `localState` | máquina de estados da UI: `'idle'`\|`'abertura'`\|`'fotos_antes'`\|`'em_reposicao'`\|`'fotos_depois'`\|`'checklist'`\|`'finalizada'` (default `idle`) (`app_database.dart:117-118`) |

**`outbox_items`** (`app_database.dart:124-138`) — fila de escrita pro servidor:
| Coluna | Papel |
|---|---|
| `id` (PK, uuid texto) | id do item |
| `entityType` | sempre `'visita'` no uso atual |
| `operation` | `open` / `close` / `photos_antes` / `photos_depois` (`sync_engine.dart:834-845, 1274-1275`) |
| `entityId` | id local da visita (migrado em consolidação) |
| `payloadJson` | legado — o payload real é remontado do estado atual da visita (`sync_engine.dart:862-865`) |
| `attempts` (default 0), `nextRetryAt`, `lastError` | backoff `min(2^attempts*30, 1800)`s (`sync_engine.dart:1049-1052`) |
| `status` | `'pending'` \| `'processing'` (default pending) |
| `createdAt` | base do limiar de 2 h do D3 |

**`pending_photos`** (`app_database.dart:140-157`) — fila de fotos:
| Coluna | Papel |
|---|---|
| `id` (PK, uuid) | id da foto |
| `visitaId` | visita dona (migrado na consolidação) |
| `slot` | `'antes'` ou `'depois'` |
| `numero` | posição no grid (ordem) |
| `localPath` | path do arquivo (cru `_raw.` ou já com watermark) |
| `status` | `'watermark_pending'` → `'pending'` → `'uploading'` → `'uploaded'`; `'error'` = terminal (arquivo sumiu/erro real) (`watermark_queue.dart:18-23`) |
| `storageUrl` | URL pública após upload OK |
| `attempts`, `nextRetryAt` | backoff igual outbox |
| `createdAt` | base do limiar de 30 min do D2 |
| `lastError` | mensagem do erro de upload — **adicionada no schema 5** (`app_database.dart:151-153`) |

**`sync_state`** (`app_database.dart:159-166`) — `entityType` (PK), `lastPullAt`, `lastPushAt`. Dupla função: timestamps de pull por entidade **e** a linha especial **`__sync_lock__`** que implementa o lock de sync CROSS-PROCESS (app ↔ WorkManager): UPDATE condicional atômico, `lastPullAt` = expiração em millis zero-padded, `lastPushAt` = dono, TTL passado pelo caller (240 s em `sync_engine.dart:74`) (`app_database.dart:749-803`).

**`pending_issues`** (`app_database.dart:171-196`) — fila de issues de anomalia:
| Coluna | Papel |
|---|---|
| `id` (PK, uuid) | id |
| `tipo` | tipo da anomalia (D1..D6); usado pra cooldown + label |
| `entidadeId` | id da entidade alvo (visitaId/fotoId/outboxId); com `tipo` forma a chave de cooldown |
| `titulo`, `bodyMd` | issue pronta (body completo congelado na detecção: dump SQLite, log, sondas) |
| `labelsJson` | JSON array de labels |
| `status` (default pending), `attempts`, `nextRetryAt`, `lastError`, `createdAt` | controle de envio/backoff |
| `githubIssueNumber` | nº do issue após envio OK |

**`pending_bug_photos`** (`app_database.dart:201-221`) — fila de fotos pro bucket `bug-reports`:
| Coluna | Papel |
|---|---|
| `id` (PK, uuid) | id |
| `fotoId` | ref à `pending_photos` original |
| `localPath` | path local no momento da gravação |
| `destStoragePath` | `bug-reports/<promotorId>/<visitaId>/<fotoId>.jpg` |
| `status` (default pending), `attempts`, `nextRetryAt`, `lastError`, `createdAt` | controle |
| `publicUrl` | URL pública após upload (injetada no issue) |

### 3.2 Migrações (`schemaVersion = 5`, `app_database.dart:240`; estratégia em `:243-282`)

| Versão | O que mudou |
|---|---|
| **→2** | `visitas` ganhou `titulo`, `previsaoTurnoRealizada`, `visitaAvulsa` (`:245-249`) |
| **→3** | `visitas` ganhou `serverId` + backfill `UPDATE visitas SET server_id = id WHERE id > 0` (ids positivos já vinham do servidor) (`:250-256`) |
| **→4** | Limpeza de órfãs: `DELETE FROM pending_photos` e `outbox_items` cujas visitas não existem mais (órfãs do bug de hash não-determinístico pré-build 202, que causava "Posterga infinito") (`:257-270`) |
| **→5** | Cria `pending_issues` e `pending_bug_photos`; adiciona `pending_photos.last_error` (`:271-280`) |

### 3.3 Rotinas de recovery no boot

- `resetUploadingNoBoot()` — fotos presas em `uploading` voltam pra `pending` (upload é idempotente via upsert) (`app_database.dart:565-574`).
- `getStaleWatermarkPending()` + `WatermarkQueueService.recoverPendingOnBoot()` — re-enfileira pares (visita, slot) com watermark pendente de execução anterior (`app_database.dart:579-583`, `watermark_queue.dart:89-131`).

---

## 4. CI / Build — `.github/workflows/build_apk.yml`

### 4.1 Gatilhos
- `push` nas branches **`main` e `dev`** (`build_apk.yml:4-5`);
- **`paths-ignore` atual**: `bug-reports/**`, `**.md`, `docs/**` (`build_apk.yml:6-9`) — commits só nesses paths NÃO geram build;
- `workflow_dispatch` manual (`build_apk.yml:10`).

### 4.2 Pipeline
1. Checkout, Java 17 (temurin), Flutter **3.35.0 stable** com cache (`build_apk.yml:20-34`).
2. `flutter pub get` + **geração do código Drift** (`dart run build_runner build --delete-conflicting-outputs`) (`build_apk.yml:42-46`).
3. `local.properties` com `flutter.versionCode=${{ github.run_number }}` (`build_apk.yml:48-55`).
4. **Numeração de build = `github.run_number`** — vira `versionCode`, `--dart-define=BUILD_NUMBER` (`build_apk.yml:114, 126`) e o sufixo `buildNN` no nome do APK (`build_apk.yml:71, 75`). `BUILD_TIME` em `TZ: America/Sao_Paulo`, formato `dd/MM/yyyy HH:mm` (`build_apk.yml:59-64`).
5. **Branch dev:** `sed` troca o label do launcher pra `Promotor Wizmart [DEV]` e o `applicationId` pra **`com.wizmart.wizmart_app.dev`** — app SEPARADO, instala lado a lado com produção, dados totalmente isolados (DB, SharedPrefs, fotos); o step falha se o sed não pegar (`build_apk.yml:86-99`).
6. **Assinatura:** secret `UPLOAD_KEYSTORE_BASE64` decodificado pra `$RUNNER_TEMP/upload-keystore.jks` (`build_apk.yml:101-107`); o gradle lê `UPLOAD_KEYSTORE_PATH/PASSWORD/KEY_ALIAS/KEY_PASSWORD` do ambiente (`build.gradle.kts:20-21, 47-51`); fonte alternativa local: `android/key.properties` não commitado (`build.gradle.kts:16-19`); **sem nenhuma fonte cai pra debug keystore** (APK só de dev) (`build.gradle.kts:61-72`). Mesma chave em todos os builds → atualiza por cima sem desinstalar (`build.gradle.kts:63-64`).
7. **Build:** `flutter build apk --release` com `--dart-define` de `GITHUB_BUG_TOKEN` (secret `BUG_REPORT_PAT`), `APP_VERSION`, `BUILD_TIME`, `BUILD_NUMBER` (`build_apk.yml:109-126`).
8. **Dois nomes de APK:** rastreável `wizmart-app[-DEV]-v<versão>-build<NN>-<timestamp>.apk` + **cópia de nome fixo** `promotor-wizmart.apk` (prod) / `promotor-wizmart-dev.apk` (dev) — URL estável pra compartilhar (`build_apk.yml:66-84, 128-137`). Artifact com retenção de 30 dias (`build_apk.yml:139-144`).

### 4.3 Releases
- **`main` → release `v-latest` (PRODUÇÃO)**: deleta e recria a tag a cada build (`gh release delete v-latest --cleanup-tag` + `create`) com os dois APKs (`build_apk.yml:152-167`). É o único release que o app instalado checa (`build_apk.yml:146-150`).
- **`dev` → release `v-dev` (TESTE)**: mesmo esquema, `--prerelease`, notes avisando "Não distribuir pra promotores" (`build_apk.yml:169-181`). Promotores não veem porque o app só consulta `v-latest` (`version_check_service.dart:89-90`).

### 4.4 Checagem de versão no app (`lib/core/network/version_check_service.dart`)
- Consulta `https://api.github.com/repos/alanclaudiolang/wizmart-qualidade-app/releases/tags/v-latest` (`:89-90`); compara o `build<NN>` do nome do asset com o `BUILD_NUMBER` local; build local não numérico (ex.: `dev`) conta como desatualizado (`:131-139`). Falha silenciosa → `upToDate` (`:92-94, 160-162`). iOS sempre `upToDate` (TestFlight) (`:169-176`).
- **URL fixa de download**: prefere o asset `promotor-wizmart.apk` (URL estável `releases/download/v-latest/promotor-wizmart.apk`); fallback pro asset variável (`:121-129`).
- **Regra D+1** (`atualizacaoObrigatoria`, `:54-67`): obrigatório se (a) `outdated` **e** hoje é dia POSTERIOR à data de compilação do **APK instalado** (`AppConstants.buildTime` parseado de `dd/MM/yyyy HH:mm`, `:72-83`) — antes usava `published_at` do release, mas o delete/recreate resetava o timestamp (`:49-53`); ou (b) **`[FORCE-UPDATE]`**: marker (case-insensitive) em qualquer lugar do body do release força atualização imediata — basta editar o release no GitHub (`:147-151`, instrução também em `build_apk.yml:158-161`). Em build local (`BUILD_TIME='local'`) o D+1 não dispara (`:70-71`).
- Download/instalação: `ApkUpdaterService` baixa via Dio pra `wizmart_apks/promotor-wizmart-latest.apk` e abre o Package Installer via `open_filex` + FileProvider (`apk_updater_service.dart:51-99`); pré-check `apkAcessivel` com HEAD em <4 s (`apk_updater_service.dart:29-47`).

---

## 5. Constantes — `lib/core/constants/app_constants.dart`

| Constante | Valor | Significado |
|---|---|---|
| `supabaseUrl` | `https://czvrbntewaisegvjdzyj.supabase.co` | projeto Supabase (`:5`) |
| `supabaseAnonKey` | JWT anon | chave pública anon (`:6-7`) |
| `sessionUserIdKey` / `sessionUserPhoneKey` / `sessionUserNameKey` | `wizmart_user_id` / `wizmart_user_phone` / `wizmart_user_name` | chaves da sessão no secure storage (`:10-12`) |
| `syncIntervalMinutes` | **15** | fail-safe periódico do WorkManager; 15 min é o piso do Android, Doze pode alongar (`:14-18`); usado no `registerPeriodicTask` (`main.dart:123-129`) |
| `pingIntervalSeconds` | 30 | intervalo de ping de conectividade (`:19`) |
| `maxSyncRetries` | 10 | teto de tentativas de sync (`:20`) |
| `maxFotosAntes` / `maxFotosDepois` | **8 / 8** | máximo de fotos por slot (`:21-22`) |
| `minFotosAntes` / `minFotosDepois` | **4 / 4** | mínimo pra habilitar o botão "Concluir" da etapa (`:23-26`) |
| `statusAgendada` | **1** | status LOCAL (`:29`) |
| `statusEmAndamento` | **2** | status LOCAL (`:30`) |
| `statusRealizada` | **3** | status LOCAL — vira **1** no servidor via `_toServerStatus` (`sync_engine.dart:607`) (`:31`) |
| `statusFalta` | **5** | ⚠️ **ALERTA DE RÓTULO**: o código chama de "Falta", mas na tabela `status_visita` do servidor **5 = Incompleta** (3 = Não Realizada é a falta real, carimbada pelo Supabase, nunca pelo app). O comentário `app_constants.dart:28` ("espelho do Supabase") e `sync_engine.dart:595-596` repetem o rótulo errado; o comportamento do código, porém, é coerente com o servidor (fato verificado em 11/06/2026, ver CLAUDE.md) (`:32`) |
| `watermarkFaixaAltura` / `watermarkFontSize` | 60.0 / 13.0 | layout da faixa de marca d'água (`:35-37`) |
| `pingTimeoutSeconds` | 5 | timeout do ping (`:39`) |
| `githubRepoOwner` / `githubRepoName` | `alanclaudiolang` / `wizmart-qualidade-app` | repo de issues/releases (`:42-43`) |
| `githubBugReportToken` | `String.fromEnvironment('GITHUB_BUG_TOKEN')` | PAT fine-grained (Contents:write + Issues:write); vazio em build local (`:45-49`) |
| `appVersion` / `buildTime` / `buildNumber` | dart-defines `APP_VERSION` / `BUILD_TIME` / `BUILD_NUMBER` (defaults `dev` / `local` / `0`) | identidade REAL do binário, injetada pelo CI; `buildTime` é a base da regra D+1 (`:51-58`) |

Conversões app↔servidor (status): `_toServerStatus` (local 3→1, 2→2, 5→5; Agendada lança `StateError` — guard anti-fantasma) em `sync_engine.dart:606-614`; `_fromServerStatus` (1→3, 2→2, 5→5, resto→1) em `sync_engine.dart:684-691`.

---

## 6. Android nativo e dependências

### 6.1 Permissões — `android/app/src/main/AndroidManifest.xml`

| Permissão | Linha | Por quê |
|---|---|---|
| `INTERNET` | 3 | Supabase, GitHub API, download de APK |
| `ACCESS_NETWORK_STATE` | 4 | detecção de conectividade (connectivity_plus) |
| `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION` | 5-6 | GPS das etapas da visita (geolocator) |
| `CAMERA` | 7 | captura das fotos (e `uses-feature camera required=true`, linha 15) |
| `READ_EXTERNAL_STORAGE` (maxSdk 32) / `WRITE_EXTERNAL_STORAGE` (maxSdk 29) | 8-9 | acesso a mídia em Androids antigos |
| `READ_MEDIA_IMAGES` | 10 | mídia no Android 13+ (galeria) |
| `RECEIVE_BOOT_COMPLETED` | 11 | WorkManager re-agendar após reboot |
| `FOREGROUND_SERVICE` | 12 | serviços do WorkManager |
| `REQUEST_INSTALL_PACKAGES` | 13-14 | abrir o instalador nativo pra APK baixada (auto-update) |

Outros pontos do manifest: `<queries>` com intent VIEW/https pra url_launcher no Android 11+ (`:19-24`); label `Promotor Wizmart` (`:27`, trocado pra `[DEV]` no build dev); `allowBackup="false"` e `usesCleartextTraffic="false"` (`:30-31`); `FileProvider` `${applicationId}.fileprovider` com `@xml/file_paths` pro instalador de APK (`:51-59`).

### 6.2 build.gradle.kts — `android/app/build.gradle.kts`
- `namespace`/`applicationId` = **`com.wizmart.wizmart_app`** (`:24, 38`) — o sufixo `.dev` é aplicado por sed só no CI da branch dev (`build_apk.yml:95-96`).
- Java/Kotlin 17 (`:28-35`); `versionCode`/`versionName` vêm do Flutter (= `local.properties` do CI) (`:41-42`).
- Assinatura: env do CI > `key.properties` local > debug keystore (`:11-21, 45-72`). Lint não aborta release (`:74-77`).

### 6.3 Dependências — `pubspec.yaml`

| Pacote | Linha | Papel |
|---|---|---|
| `supabase_flutter` | 14 | auth, Postgrest (tabela `visitas` etc.), Storage (buckets `Arquivos` e `bug-reports`) |
| `drift` + `sqlite3_flutter_libs` | 17-18 | banco local SQLite reativo (todas as tabelas do §3) |
| `path_provider` / `path` | 19-20 | diretórios do app (DB, fotos `wizmart_fotos/`, APKs) |
| `flutter_riverpod` / `riverpod_annotation` | 23-24 | state management / providers (syncEngineProvider etc.) |
| `go_router` | 27 | navegação (alimenta `CurrentScreen` via NavigatorObserver) |
| `image_picker` | 30 | captura de foto pela câmera |
| `image` | 31 | manipulação de imagem (watermark) |
| `flutter_image_compress` | 32 | compressão das fotos |
| `permission_handler` | 33 | pedido de permissões em runtime |
| `gal` | 34 | **salvar foto com marca d'água na galeria** (`Gal.putImage`, `watermark_queue.dart:278`) — backup do promotor; o app só ADICIONA, nunca apaga |
| `geolocator` | 37 | GPS das etapas |
| `flutter_secure_storage` | 40 | sessão persistente do promotor |
| `connectivity_plus` | 43 | estado de rede |
| `workmanager` | 46 | sync periódico em background (15 min, `main.dart:122-129`) |
| `dio` | 49 | download da APK com progresso (`apk_updater_service.dart`) |
| `http` | 50 | chamadas REST (GitHub Issues, Edge Function) |
| `uuid` | 53 | ids de outbox/pending_photos/issues |
| `intl` | 54 | formatação de datas |
| `collection` | 55 | utilitários de coleção |
| `shared_preferences` | 56 | cooldown de anomalias, nº do issue [ESTADO], flags |
| `crypto` | 57 | SHA-1 do idTemp determinístico (`sync_engine.dart:6, 38-47`) |
| `device_info_plus` | 60 | modelo/fabricante/SO nos reports e no `users.device_info` |
| `package_info_plus` | 61 | versão/build do pubspec |
| `url_launcher` | 64 | abrir URL externa (download de APK em fallback) |
| `open_filex` | 67 | abrir a APK baixada no instalador nativo |
| `system_info_plus` | 71 | RAM total (tier de qualidade + reports) |
| `disk_space_plus` | 71-72 | espaço em disco (pré-check de foto + reports) |
| `battery_plus` | 75 | nível de bateria nos auto-reports |
| dev: `flutter_lints`, `drift_dev`, `build_runner`, `riverpod_generator`, `flutter_launcher_icons` | 80-84 | lint, codegen do Drift/Riverpod, ícones |
| override: `app_links ^6.0.0` | 94-95 | resolução de conflito de versão transitivo do supabase_flutter |

Versão do pubspec: `1.0.0+1` (`pubspec.yaml:4`) — **não identifica o binário**; quem identifica é o `BUILD_NUMBER`/`BUILD_TIME` do dart-define (`error_reporter.dart:261-264`).