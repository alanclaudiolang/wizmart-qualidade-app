# WizMart App v2 — Flutter Offline-First

App dos promotores de campo. Substitui o app FlutterFlow atual.

## Pré-requisitos

- Flutter 3.24+ instalado (`flutter --version`)
- Android Studio com SDK Android instalado
- Dispositivo Android físico ou emulador (API 21+)

## Setup inicial

### 1. Instalar dependências

```bash
flutter pub get
```

### 2. Gerar código do Drift (banco local)

```bash
dart run build_runner build --delete-conflicting-outputs
```

Este comando gera o arquivo `app_database.g.dart`. **Precisa ser rodado uma vez antes de compilar.**

### 3. Configurar a anon key do Supabase

Abra `lib/core/constants/app_constants.dart` e substitua o valor de `supabaseAnonKey` pela chave anon real do seu projeto Supabase:

```dart
static const String supabaseAnonKey = 'SUA_CHAVE_ANON_AQUI';
```

A chave anon está em: Supabase Dashboard → Project Settings → API → `anon public`.

### 4. Rodar no celular (Android)

Conecte o celular com USB debugging ativado e:

```bash
flutter run --release
```

Ou gere o APK:

```bash
flutter build apk --release
```

O APK estará em: `build/app/outputs/flutter-apk/app-release.apk`

### 6. Instalar APK no celular do promotor

Envie o APK via WhatsApp ou Drive. Na primeira instalação, o promotor precisa:
1. Ativar "Instalar apps de fontes desconhecidas" nas configurações.
2. Abrir o arquivo APK e instalar.
3. Digitar o número de celular cadastrado.

---

## Estrutura do projeto

```
lib/
  core/
    constants/         → app_constants.dart (config Supabase, limites)
    database/          → app_database.dart (schema Drift, queries)
    network/           → sync_engine.dart (outbox, pull, push)
                         connectivity_service.dart (ping Supabase)
    utils/             → session_service.dart (auth por telefone)
                         watermark_util.dart (faixa inferior nas fotos)
                         app_router.dart (navegação)
  presentation/
    screens/
      auth/            → auth_screen.dart (tela de login por número)
      home/            → home_screen.dart (lista de visitas do dia)
      visita/          → visita_screen.dart (fluxo completo da visita)
```

## Fluxo da visita

```
Tela home → toca na visita
  ↓
Iniciar (captura GPS)
  ↓
Fotos ANTES (até 8, câmera obrigatória, watermark automático)
  ↓
Em reposição (promotor trabalha, pode fechar o app)
  ↓
Fotos DEPOIS (até 8, câmera obrigatória, watermark automático)
  ↓
Checklist (7 perguntas OK/NOK + observação)
  ↓
Visita finalizada → sync em background
```

## Sincronização

- **Offline-first:** toda ação é salva localmente primeiro.
- **Sync automático:** WorkManager roda a cada 5 minutos em background.
- **Sync imediato:** quando online, o app tenta sync logo após cada ação.
- **Retry com backoff:** falhas de rede reagem com espera exponencial (30s, 60s, 120s... até 30min).
- **Fotos:** pipeline separado do sync da visita. Upload independente com retry.
- **Detecção de rejeição silenciosa:** após cada INSERT, o app verifica se a linha existe. Se não, marca como "rejected" e loga.

## Indicador de conectividade

O ícone 🟢/🔴 na barra superior é baseado em **ping real ao Supabase**, não no status de rede do celular. Verde = servidor acessível. Vermelho = offline real.

## Autenticação

- Primeira vez: promotor digita número de celular.
- App verifica em `users.telefone` no Supabase.
- Token salvo em `flutter_secure_storage` (persiste entre versões).
- Nunca precisa logar novamente no mesmo celular.
- Revogação: setar `users.ativo = false` no Supabase.

---

## Próximas versões

- [ ] Tela de agenda (consulta)
- [ ] Verificação de versão via `versoes_app`
- [ ] Push notifications via OneSignal
- [ ] RLS por `auth.uid()` no Supabase
