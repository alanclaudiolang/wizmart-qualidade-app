# Port pra iOS — Plano técnico e contexto

Documento de handoff pra começar uma sessão dedicada ao port iOS do app.

---

## Contexto do projeto

**Promotor Wizmart** — app Flutter de visitas em PDV (point-of-sale) pra
promotores externos.

- Repo: `github.com/alanclaudiolang/wizmart-qualidade-app`
- Stack: Flutter 3.35.0 + Drift (SQLite local) + Supabase (Postgres + Storage + Auth) + Riverpod + GoRouter + WorkManager
- Branch de produção: `main` (publica em release `v-latest`)
- Branch de teste: `dev` (publica em release `v-dev`, com applicationId
  isolado `com.wizmart.wizmart_app.dev` pra coexistir com prod)
- CI: GitHub Actions (workflow `build_apk.yml`) — só Android hoje
- Distribuição Android: APK no GitHub Releases, app checa `v-latest` e
  faz auto-update (regra D+1 baseada no `BUILD_TIME` local + flag
  `[FORCE-UPDATE]` no body do release pra forçar imediato)
- Sem pasta `ios/` no repo (nunca foi rodado `flutter create --platforms=ios`)

---

## Decisão crítica que bloqueia tudo: forma de distribuição

| Opção | Conta Apple | Custo/ano | Limite | Apple revisa? | Adequado pro caso? |
|---|---|---|---|---|---|
| App Store | Individual | $99 | Sem limite | Sim (dias) | Não — app é privado |
| **TestFlight** | Individual | $99 | 10k testers | Sim (mais rápido) | **Sim — promotor recebe convite por email** |
| Enterprise | Empresa | $299 | Só funcionários internos | Não | Provavelmente não — promotores são prestadores, não funcionários |
| Ad Hoc | Individual | $99 | 100 devices (UDID) | Não | Inviável — exige cadastrar UDID de cada celular |

**Recomendação inicial: TestFlight.**
Pra promotor instalar:
1. Gestor adiciona o email do promotor como tester.
2. Promotor recebe email com convite.
3. Promotor instala app "TestFlight" da App Store, abre o convite, instala
   o app via TestFlight.
4. Builds novos chegam automáticos no TestFlight (similar ao "atualizar" hoje).

---

## Pré-requisitos antes de qualquer código

1. **Conta Apple Developer**: criar em https://developer.apple.com — $99/ano,
   pode ser CPF ou CNPJ. Cadastro leva alguns dias (Apple verifica
   identidade).
2. **Mac ou Mac na nuvem** pra builds:
   - Local: qualquer Mac com Xcode (~12 GB).
   - GitHub Actions macOS runners: funcionam, mas custam ~10x mais que Linux.
     Ainda viável pra projeto pequeno.
   - Codemagic / Bitrise: CI especializado em Flutter mobile, plano gratuito
     limitado.
3. **Decidir bundle identifier iOS**: sugiro `com.wizmart.promotor` (NÃO o
   mesmo do Android `com.wizmart.wizmart_app` — Apple não compartilha).

---

## Trabalho técnico (estimativa: 1-2 dias devs, sem contar bureaucracia da
Apple)

### 1. Criar a estrutura iOS

```bash
flutter create --platforms=ios .
```

Isso cria a pasta `ios/` com:
- `Runner.xcodeproj` (projeto Xcode)
- `Info.plist` (config nativo)
- `Podfile` (dependências iOS)

### 2. Configurar `Info.plist`

Apple **rejeita o app** se faltar descrição de cada permissão usada.
Adicionar:

```xml
<key>NSCameraUsageDescription</key>
<string>O app precisa da câmera pra tirar as fotos das visitas.</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>O app precisa do acesso à galeria pra salvar as fotos das visitas.</string>

<key>NSPhotoLibraryAddUsageDescription</key>
<string>O app precisa salvar fotos no carretel do celular.</string>

<key>NSLocationWhenInUseUsageDescription</key>
<string>O app precisa da localização pra registrar onde a visita aconteceu.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>O app precisa da localização pra registrar onde a visita aconteceu.</string>

<key>UIBackgroundModes</key>
<array>
  <string>fetch</string>
  <string>processing</string>
</array>
```

URL scheme pra deep link `wizmartqualidade://`:
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLName</key>
    <string>com.wizmart.promotor.deeplink</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>wizmartqualidade</string>
    </array>
  </dict>
</array>
```

### 3. Verificar pacotes do `pubspec.yaml`

Pra cada package, conferir suporte iOS. Atenção especial:

- `workmanager: ^0.9.0` — iOS tem **suporte limitado** (só fetch
  background, max 30s, sistema decide quando rodar). Cuidado: o sync
  periódico do Android (15min) vai funcionar de forma diferente. Pode
  precisar reescrever a estratégia de sync background pra iOS.
- `permission_handler: ^11.3.1` — funciona, mas pede setup em `Podfile`
  pra habilitar permissões específicas.
- `geolocator: ^12.0.0` — funciona em iOS, sem ajustes extras.
- `image_picker: ^1.1.2` — funciona.
- `flutter_image_compress: ^2.3.0` — funciona.
- `gal: ^1.1.0` — funciona, requer `NSPhotoLibraryAddUsageDescription`.
- `flutter_secure_storage: ^9.2.2` — usa Keychain do iOS, funciona.
- `app_links: ^6.0.0` (em `dependency_overrides`) — funciona pra
  custom URL scheme. Pode precisar `flutter_native_splash` config.
- `supabase_flutter: ^2.5.0` — funciona.
- `drift: ^2.18.0` + `sqlite3_flutter_libs: ^0.5.0` — funciona, requer
  setup em `Podfile` (geralmente automático).

### 4. Workflow CI iOS

Criar `.github/workflows/build_ios.yml` — usa `runs-on: macos-latest`.
Etapas:

1. Checkout
2. Setup Flutter
3. `flutter pub get`
4. `cd ios && pod install`
5. Decodificar certificado + provisioning profile dos GitHub Secrets
6. `flutter build ipa --release --export-options-plist=ios/ExportOptions.plist`
7. Upload do `.ipa` pro TestFlight via `xcrun altool` ou
   `transporter`/`fastlane`

Secrets necessários:
- `IOS_CERTIFICATE_BASE64` (cert .p12 convertido)
- `IOS_CERTIFICATE_PASSWORD`
- `IOS_PROVISIONING_PROFILE_BASE64`
- `APPLE_APP_SPECIFIC_PASSWORD` (gerado em appleid.apple.com)
- `APPLE_TEAM_ID`
- `APPLE_ID_EMAIL`

### 5. Pontos comportamentais a testar

- **Notificações**: iOS exige permissão explícita; configurar `permission_handler` pra pedir.
- **Background sync**: WorkManager iOS roda só algumas vezes por hora,
  decidido pelo sistema. Não dá pra forçar como no Android. **Possível
  regressão funcional pros promotores** — pode precisar adaptar UX
  (mais ênfase em sync foreground).
- **Magic link / deep link**: testar abertura do `wizmartqualidade://`
  via email no iOS — costuma funcionar, mas Mail.app pode ser mais
  restrito que Gmail Android.
- **Auto-update**: iOS NÃO permite app baixar e instalar APK. Versão
  nova vem via TestFlight automaticamente. Toda a lógica de
  `apk_updater_service.dart` + `version_check_service.dart` precisa ser
  **desabilitada no iOS** (compilar condicional, ou mover pra um wrapper
  com `Platform.isAndroid`).
- **WatermarkQueue + ProcessingTracker**: funciona igual em iOS
  (puro Dart, sem dependência de plataforma).

### 6. Diferenças no fluxo de release

| Aspecto | Android (hoje) | iOS (depois) |
|---|---|---|
| Distribuição | APK via GitHub Release | IPA via TestFlight |
| Update | Auto (D+1 ou FORCE-UPDATE) | Manual ou automático via TestFlight |
| Aprovação | Sem | Apple revisa cada build |
| Tempo de release | ~7 min CI | ~7 min CI + horas pra Apple aprovar |

---

## Ordem sugerida ao iniciar a próxima sessão

1. **Confirmar conta Apple Developer** — sem isso, parar tudo.
2. **Decidir TestFlight vs Enterprise** com base no tipo da conta criada
   (CPF → só TestFlight; CNPJ → TestFlight ou Enterprise).
3. **Rodar `flutter create --platforms=ios .`** localmente OU no codespace
   (precisa testar — Linux pode dar erro com `pod install`; em todo caso
   o arquivo `ios/` pode ser comitado).
4. **Editar `Info.plist`** com as permissões + URL scheme.
5. **Pegar um Mac** (próprio, emprestado ou GitHub Actions runner) pra
   compilar a primeira vez.
6. **Compilar `.ipa`** localmente pra validar.
7. **Subir manualmente no TestFlight** via App Store Connect (primeira vez
   sempre manual — depois CI assume).
8. **Convidar promotor de teste** (você mesmo via TestFlight).
9. **Validar fluxos críticos** (login, foto, sync, magic link).
10. **Configurar CI** depois de ter o primeiro build funcionando manual.

---

## Riscos / pontos de atenção

- **Apple pode rejeitar o app** se: descrição de permissão genérica,
  privacy policy URL faltando, app crasha na revisão, screenshots
  inadequados na App Store Connect.
- **Bureaucracia**: criar conta + verificar identidade pode levar
  1 semana. Submission do primeiro build no TestFlight: ~24h pra review.
- **iOS é mais restritivo com background**: o sync periódico pode rodar
  muito menos do que no Android. Promotores que dependem de sync
  passivo podem ter dados atrasados.
- **Sem auto-update OTA**: toda atualização passa por TestFlight + Apple
  review. Não dá pra fazer "force-update" como hoje.

---

## Arquivos importantes do projeto pra referência

- `pubspec.yaml` — dependências
- `android/app/src/main/AndroidManifest.xml` — equivalente Android do Info.plist
- `android/app/build.gradle.kts` — applicationId, signingConfig
- `.github/workflows/build_apk.yml` — workflow Android (base pra adaptar)
- `lib/main.dart` — entrypoint
- `lib/core/utils/app_router.dart` — rotas (com ShellRoute, guards)
- `lib/core/utils/permissions_status_service.dart` — abstração de permissão
- `lib/core/utils/gps_status_service.dart` — abstração de GPS
- `lib/core/utils/apk_updater_service.dart` — atualizador Android (precisa
  desabilitar no iOS)
- `lib/core/network/version_check_service.dart` — check de versão (mesmo)
- `lib/presentation/screens/auth/onboarding_permissoes_screen.dart` —
  primeira abertura, pede permissões
