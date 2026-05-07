// lib/core/constants/app_constants.dart

class AppConstants {
  // Supabase
  static const String supabaseUrl = 'https://czvrbntewaisegvjdzyj.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN6dnJibnRld2Fpc2VndmpkenlqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjE3NjYxMTYsImV4cCI6MjAzNzM0MjExNn0.placeholder';

  // Chave de sessão no secure storage
  static const String sessionUserIdKey = 'wizmart_user_id';
  static const String sessionUserPhoneKey = 'wizmart_user_phone';
  static const String sessionUserNameKey = 'wizmart_user_name';

  // Sync
  static const int syncIntervalMinutes = 5;
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
}
