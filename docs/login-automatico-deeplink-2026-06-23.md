# Login automático (magic link) + redefinição de senha via deep link

Data: 2026-06-23 · Branch: `claude/sleepy-mccarthy-pu0s96` · Commit base: `9880548`

## Objetivo

Portar do app FlutterFlow antigo (`wizmart-app-flutterflow`, branch
`flutterflow`) o mecanismo de **login automático (magic link)** e
**redefinição de senha** via deep link, adaptado ao modelo do app novo
(build 257). O app novo não tinha esquema de deep link registrado, então
o magic link e o link de redefinir senha não abriam o app.

## Cobertura de leitura (regra 7a)

- **App antigo (FlutterFlow), branch `flutterflow`: 309 arquivos /
  ~168k linhas — 100% cobertos** por 4 leitores dedicados. A lógica de
  auth/deep-link concentra-se em ~10 arquivos (`auth/**`,
  `backend/supabase/supabase.dart`, `api_calls.dart`, `nav.dart`, telas
  login/login_automatico/recoverpassword/atualizarsenha + componentes).
- **App novo (build 257): 100% lido.** Caminho de auth/boot/navegação
  lido integralmente à mão; demais telas/serviços por leitor dedicado.
  Único não lido linha a linha: `app_database.g.dart` (gerado pelo Drift).

## Como funcionava no app antigo (fatos verificados)

1. Plataforma registrava o esquema `wizmartapp://wizmartapp.com`
   (AndroidManifest + iOS `CFBundleURLTypes`) e `flutter_deeplinking_enabled`
   / `FlutterDeepLinkingEnabled`.
2. `Supabase.initialize` com `authFlowType: AuthFlowType.implicit` — magic
   link e recuperação voltam com os tokens no **fragmento** da URL.
3. O SDK `supabase_flutter` estabelece a sessão **sozinho** a partir do
   link (não há `getSessionFromUrl` no código).
4. `onAuthStateChange` → `AppStateNotifier` → `go_router` reconstrói →
   logado. Magic link abria `/loginautomatico` ou `/home`; reset abria
   `/recoverpassword` (`resetPasswordForEmail(redirectTo: ...recoverpassword)`).

## Diferença-chave do app novo (por que precisou de "ponte")

No app novo, "estar logado" = **sessão local no `SessionService`** (o
splash decide por `SessionService.hasSession()`); não há nenhum
`onAuthStateChange` global. Logo, deixar o SDK criar a sessão do Supabase
**não basta**: depois disso é preciso rodar a mesma rotina do login por
senha (consultar `users`, validar `ativo`/`tipo_user==3`, gravar no
`SessionService`). Esse é o único trecho realmente novo.

## O que foi implementado

| Arquivo | Mudança |
|---|---|
| `android/app/src/main/AndroidManifest.xml` | intent-filter `wizmartapp://wizmartapp.com` + `flutter_deeplinking_enabled`. Só adiciona. |
| `ios/Runner/Info.plist` | `CFBundleURLTypes` (esquema `wizmartapp`) + `FlutterDeepLinkingEnabled`. `FlutterSceneDelegate` do framework já encaminha o link. |
| `lib/main.dart` | `authFlowType: AuthFlowType.implicit` nos dois `Supabase.initialize`. |
| `lib/core/constants/app_constants.dart` | Constantes do deep link (esquema/host/paths/URL de reset). |
| `lib/core/utils/login_flow.dart` (novo) | Lógica **pura** compartilhada: `validarUsuario`, `precisaConfirmarTrocaConta`, `normalizarEmail`, `deveProcessarPonte`. Sem I/O → testável headless. |
| `lib/presentation/screens/auth/auth_screen.dart` | Usa `login_flow` (login por senha e ponte compartilham a MESMA validação/guarda) + `redirectTo` no `resetPasswordForEmail`. |
| `lib/presentation/screens/auth/login_automatico_screen.dart` (novo) | Tela-ponte de `/loginautomatico`. Listener `onAuthStateChange` **escopado à tela** (não global). Valida, replica guarda anti-mistura-de-contas e popula `SessionService`. |
| `lib/presentation/screens/auth/recuperar_senha_screen.dart` (novo) | Tela `/recoverpassword`: troca a senha via `updateUser` usando a sessão de recuperação. |
| `lib/core/utils/logout_service.dart` | `logoutCompletely(..., signOutSupabase = true)`. A ponte passa `false` para não derrubar a sessão nova criada pelo link. |
| `lib/core/utils/app_router.dart` | Rotas `/loginautomatico` e `/recoverpassword`. |
| `test/login_flow_test.dart` (novo) | Simulador headless da lógica de risco (14 casos). |

## Risco e por que está contido

- O **mecanismo do link** é idêntico ao app antigo (comprovado em campo).
- O **único código novo** é a ponte, e o listener é **escopado à tela do
  link** (criado no `initState`, cancelado no `dispose`) — **não dispara
  no boot nem no login por senha**, eliminando o risco de "escutador
  global disparando na hora errada". A trava `_jaProcessou` garante
  execução única.
- A guarda anti-mistura-de-contas é a MESMA do login por senha (função
  pura compartilhada e testada).
- Não há corrida com o estado do Supabase: o app inteiro lê
  `SessionService.getSession()`; o `sync_engine` usa `session.userId`.

## Versionamento e force-update (NÃO alterados)

- **Não** foi tocado `version_check_service.dart` nem a lógica de
  force-update. **Não** será adicionado o marcador `[FORCE-UPDATE]`.
- ⚠️ **Atenção (regra D+1):** mesmo sem o marcador, quando um build novo
  entra no release `v-latest` (produção), os promotores cujo app foi
  compilado em dia anterior são forçados a atualizar **no dia seguinte**.
  "Não forçar este build" em produção exige decisão de distribuição
  (testar primeiro na `dev`/`v-dev`, que o app de produção NÃO consulta).
- **Android**: build number vem do CI (`github.run_number`); auto-update
  por APK. **iOS**: versão vem do `pubspec`; atualização só pela App Store.
  `pubspec`/`pubspec.lock` não foram alterados.

## Teste

- **Headless (feito):** `flutter test test/login_flow_test.dart` → 14/14.
  `flutter analyze` → 0 erros, 0 warnings novos.
- **No aparelho (pendente, só o dono consegue):** a entrega do link pelo
  SO não é simulável aqui (iOS exige macOS; emulador Android exige KVM,
  ausente). Checklist:
  - Android: instalar o build `v-dev` e abrir o link real do e-mail. Para
    smoke test do roteamento: `adb shell am start -a
    android.intent.action.VIEW -d "wizmartapp://wizmartapp.com/loginautomatico"`
    (sem tokens cai pro `/auth` após ~12s — esperado).
  - iOS: build via TestFlight, tocar no link do e-mail no dispositivo.
  - Pré-requisito de servidor: `wizmartapp://wizmartapp.com/*` na allowlist
    de Redirect URLs do Supabase (mesmo projeto do app antigo — já estava).

## Publicação

Pendente de OK explícito do Alan. Push na branch de desenvolvimento
(`claude/sleepy-mccarthy-pu0s96`) **não** dispara CI. Build/release só em
push para `main` (`v-latest`, produção) ou `dev` (`v-dev`, teste).
