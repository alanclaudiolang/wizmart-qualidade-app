// lib/core/utils/auth_session_expired.dart
//
// Sentinela compartilhada que sinaliza pra UI quando uma operação
// detectou que a sessão Supabase Auth expirou e o refresh token
// também falhou. A UI escuta esse flag e, quando vê `true`, dispara
// o soft logout e navega pra /auth — sem perder visitas, fotos ou
// outbox locais (esses ficam pra retomar quando o promotor logar
// de novo com o mesmo e-mail).
//
// Implementado como ValueNotifier global (singleton estático) pra
// ser acessado de qualquer ponto do app sem precisar passar referência
// pelo Riverpod tree.

import 'package:flutter/foundation.dart';

class AuthSessionExpired {
  AuthSessionExpired._();

  static final ValueNotifier<bool> _flag = ValueNotifier(false);

  /// Escutar pra reagir (UI da home).
  static ValueListenable<bool> get listenable => _flag;

  /// Setado por qualquer fluxo (sync_engine, watermark_queue) que
  /// detecte sessão expirada. Idempotente.
  static void set() {
    if (!_flag.value) _flag.value = true;
  }

  /// Resetar após o usuário relogar — chamado pelo AuthScreen no
  /// sucesso do signIn.
  static void reset() {
    if (_flag.value) _flag.value = false;
  }

  static bool get isExpired => _flag.value;
}
