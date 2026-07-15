# Reconstrução do build 260 (deep link) — 15/07/2026

## Contexto

A conta GitHub `alanclaudiolang` foi suspensa (~24/06/2026), levando junto os
commits de 20–24/06 (deep link, builds 259/260/262). O código-fonte disponível
é o de 19/06 (commit "docs: 1.0.1 aprovada...", migrado para o Azure DevOps em
15/07). Decisão do Alan (15/07): **recriar o build 260** (o que está nos
celulares dos promotores — v1.0.2, deep link), deixando de fora a reordenação
do sincronismo do build 262 (não testada o suficiente em campo).

## Fontes usadas na reconstrução (por ordem de autoridade)

1. **APK real do build 260** (extraído de um celular, analisado em 15/07):
   strings do `libapp.so` (rotas `/loginautomatico` e `/recoverpassword`,
   textos exatos das telas, versões supabase v2.12.4/auth v2.10.6), manifest
   binário (esquema `wizmartapp` + host `wizmartapp.com`,
   `flutter_deeplinking_enabled`), arquivos Dart novos citados nos paths do
   binário (`login_flow.dart`, `login_automatico_screen.dart`,
   `recuperar_senha_screen.dart`).
2. **Histórico exportado da sessão de 19–26/06** (arquivo do Alan): briefing
   do port (SessionService além da sessão Supabase; `auth_screen.dart:542`
   sem redirectTo; esquema do e-mail `wizmartapp://wizmartapp.com/
   loginautomatico`), cronologia dos builds e decisões.
3. **Leitura de 100% do código de 19/06** (regra 7a — cobertura abaixo).

## O que é fiel ao 260 vs. interpretação minha

**Fiel (evidência direta no APK/histórico):**
- Esquema/host do deep link, `flutter_deeplinking_enabled`, as 2 rotas, os 3
  arquivos novos e seus papéis;
- Textos das telas ("Definir nova senha", "Crie uma nova senha para sua
  conta.", "Nova senha", "Confirmar nova senha", "Salvar nova senha",
  "A senha deve ter pelo menos 6 caracteres.", "Senha alterada! Entre com a
  nova senha.", "Abra esta tela pelo link enviado no seu e-mail...",
  "O link expirou. Solicite um novo no login.", "Login cancelado para
  proteger os dados ainda não sincronizados...", "Não foi possível alterar a
  senha agora. Tente novamente.");
- Upgrade do supabase_flutter (2.5 → 2.9.x), versão 1.0.2, tratamento de
  `AuthWeakPasswordException`, uso do observador de deep link da lib;
- Proteção de troca de conta no login automático (string no binário).

**Interpretação (validar com o Alan / com o export da sessão de 23/06 se
aparecer):**
- Layout/ordem exata dos widgets nas telas (segui o padrão visual da
  AuthScreen);
- Timeout de 12 s para "link expirado" (o valor exato do 260 é desconhecido);
- Navegar para `/splash` no sucesso do login automático (garante recuperação
  de boot; o 260 pode ter ido direto pra home);
- Texto complementar da mensagem de senha não conferindo ("A nova senha não
  confere com a confirmação." — no binário só havia o fragmento "A nova
  senha n...");
- `redirectTo` no `resetPasswordForEmail` (o 260 quase certamente passava,
  pois o e-mail redireciona pro app; o valor segue o padrão do magic link).

## Cobertura da leitura (regra 7a)

- **Lidos integralmente por mim (linha a linha):** `main.dart`,
  `app_router.dart`, `auth_screen.dart`, `session_service.dart`,
  `logout_service.dart`, `auth_session_expired.dart`, `app_constants.dart`,
  `AndroidManifest.xml`, `Info.plist`, `pubspec.yaml`.
- **Lidos integralmente por agente de leitura (relatório completo com
  arquivo:linha, 35 arquivos):** todos os demais `.dart` de `lib/` —
  sync_engine, visita_screen, home_screen, app_database, error_reporter,
  anomalia_reporter, onboarding_permissoes_screen, watermark_queue,
  programado/realizado/faltas, anomalia_queue_processor, permissions_guard,
  version_check_service, gps_guard, persistent_logger, watermark_util,
  promotor_estado_reporter, permissions_status_service,
  permission_help_button, error_classifier, apk_updater_service,
  apk_download_dialog, connectivity_service, performance_profile,
  gps_status_service, device_info_service, syncing_indicator,
  processing_indicator, sync_logger, processing_tracker, app_colors,
  current_screen, sync_pause, last_visita_service.
- **Não lido:** `app_database.g.dart` (gerado pelo build_runner).

## Riscos mapeados e como foram tratados

1. **Sessão local ≠ sessão Supabase**: o boot decide pelo `SessionService`
   (`app_router.dart` `_SplashRedirect`); magic link só cria sessão Supabase.
   → `LoginFlow` popula a sessão local com as MESMAS validações do login
   manual (`users` por uid, ativo, tipo_user==3).
2. **Troca de conta via link** contornaria o guard do login manual →
   cancelamento protetivo quando há pendências locais (nunca apagar sem
   confirmação; clique em link não é confirmação).
3. **Race splash × deep link**: no cold start via link o GoRouter abre direto
   a rota do link (o splash não roda) → recuperação de boot não executa. →
   sucesso do login automático navega para `/splash`.
4. **Upgrade supabase 2.5→2.9**: pontos sensíveis (PGRST116/`ehErroZeroRows`,
   `AuthException.message`, `StorageException.statusCode`) verificados no
   relatório de leitura; suíte de testes completa deve ficar verde antes de
   qualquer publicação.
5. **PermissionsGuard sobre as rotas novas**: rotas dentro do ShellRoute
   (obrigatório pelo bug do Navigator, issues #14/#15); o guard pode
   sobrepor a tela de reset numa instalação sem permissões — comportamento
   aceito (usuário típico do link já tem o app configurado).

## Pendências desta reconstrução

- Validar com build real em aparelho (link do e-mail abre o app? cold e warm
  start?) — exige pipeline Android (Azure Pipelines) ainda não montado.
- Conferir template/Redirect URLs no painel do Supabase (config do Alan de
  junho — preservada, mas conferir se `wizmartapp://wizmartapp.com/*` está na
  allowlist).
- Se o export da sessão de 23/06 aparecer, comparar e ajustar os pontos de
  interpretação.
- Publicação: SOMENTE com OK explícito do Alan (regra 3a). Distribuição
  futura: Google Play (decisão de 15/07) — keystore pendente de definição.
