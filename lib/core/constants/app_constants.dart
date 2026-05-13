// lib/core/constants/app_constants.dart

class AppConstants {
  // Supabase
  static const String supabaseUrl = 'https://czvrbntewaisegvjdzyj.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN6dnJibnRld2Fpc2VndmpkenlqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjE3NjYxMTYsImV4cCI6MjAzNzM0MjExNn0.drNMrjTZ9Dye7D6g1twyUSlR_XtKCJUGoUlKLGQM-oU';

  // Chave de sessão no secure storage
  static const String sessionUserIdKey = 'wizmart_user_id';
  static const String sessionUserPhoneKey = 'wizmart_user_phone';
  static const String sessionUserNameKey = 'wizmart_user_name';

  // Sync — fail-safe periódico do WorkManager. 15 min é o mínimo
  // permitido pelo Android (qualquer valor menor é arredondado).
  // Em devices em Doze/App Standby o intervalo real pode ser bem maior.
  // 15 deixa claro que esse é o piso real.
  static const int syncIntervalMinutes = 15;
  static const int pingIntervalSeconds = 30;
  static const int maxSyncRetries = 10;
  static const int maxFotosAntes = 8;
  static const int maxFotosDepois = 8;

  // Status de visita (espelho do Supabase)
  static const int statusAgendada = 1;
  static const int statusEmAndamento = 2;
  static const int statusRealizada = 3;
  static const int statusFalta = 5;

  // Foto watermark
  static const double watermarkFaixaAltura = 60.0;
  static const double watermarkFontSize = 13.0;

  // Ping timeout
  static const int pingTimeoutSeconds = 5;

  // Bug report — repo onde os GIFs e issues são publicados.
  static const String githubRepoOwner = 'alanclaudiolang';
  static const String githubRepoName = 'wizmart-qualidade-app';

  /// PAT fine-grained com escopos Contents:write + Issues:write neste repo.
  /// Injetado em build time via --dart-define=GITHUB_BUG_TOKEN=...
  /// Vazio quando rodando local sem o token.
  static const String githubBugReportToken =
      String.fromEnvironment('GITHUB_BUG_TOKEN');

  /// Versão + datahora do build, injetadas pelo workflow via --dart-define.
  /// Ex: APP_VERSION=1.0.0 / BUILD_TIME=2026-05-10 13:50 UTC
  static const String appVersion =
      String.fromEnvironment('APP_VERSION', defaultValue: 'dev');
  static const String buildTime =
      String.fromEnvironment('BUILD_TIME', defaultValue: 'local');
  static const String buildNumber =
      String.fromEnvironment('BUILD_NUMBER', defaultValue: '0');
}
