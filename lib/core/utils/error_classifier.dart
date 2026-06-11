// lib/core/utils/error_classifier.dart
//
// Classifica exceções/HTTP status em duas grandes categorias:
//   - REDE_TRANSITORIA: rede ruim, servidor com 5xx, timeout, TLS, etc.
//     Sempre retenta com backoff. NÃO vira `error`, NÃO gera auto-issue.
//   - ERRO_REAL: 4xx (RLS, payload), arquivo apagado, watermark quebrado,
//     constraint violado. Vira `error` no SQLite + auto-issue na fila.
//
// Default conservador: tudo que NÃO casa em padrão de erro real é tratado
// como rede (retenta). Evita gerar auto-issue indevido pra falhas
// desconhecidas — se vira problema recorrente, ajustamos depois.

import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

enum ClassificacaoErro {
  /// Falha transitória — rede off, server 5xx, timeout. Retenta.
  redeTransitoria,

  /// Token Supabase expirou (401). Tenta refreshSession.
  authExpirada,

  /// Erro permanente — 4xx, file apagado, payload inválido, constraint.
  /// Vira `error` + auto-issue.
  erroReal,
}

class ErrorClassifier {
  ErrorClassifier._();

  /// Classifica uma exceção (e opcional HTTP status). Default conservador:
  /// quando não dá pra ter certeza, retorna [redeTransitoria].
  static ClassificacaoErro classificar(Object e, {int? statusCode}) {
    // 1. HTTP status manda quando disponível.
    if (statusCode != null) {
      if (statusCode >= 500 && statusCode < 600) {
        return ClassificacaoErro.redeTransitoria;
      }
      if (statusCode == 408 || statusCode == 429) {
        return ClassificacaoErro.redeTransitoria;
      }
      if (statusCode == 401) {
        return ClassificacaoErro.authExpirada;
      }
      if (statusCode >= 400 && statusCode < 500) {
        return ClassificacaoErro.erroReal;
      }
    }

    // 2. Tipo da exceção — casos óbvios.
    if (e is SocketException) return ClassificacaoErro.redeTransitoria;
    if (e is TimeoutException) return ClassificacaoErro.redeTransitoria;
    if (e is HandshakeException) return ClassificacaoErro.redeTransitoria;
    if (e is HttpException) return ClassificacaoErro.redeTransitoria;
    if (e is FileSystemException) return ClassificacaoErro.erroReal;
    if (e is FormatException) return ClassificacaoErro.erroReal;

    // 3. PostgrestException com código de constraint (23xxx) = erro real.
    if (e is PostgrestException) {
      final code = e.code ?? '';
      if (code.startsWith('23') || code.startsWith('22')) {
        return ClassificacaoErro.erroReal;
      }
      // PostgrestException sem código de constraint: pode ser rede ou
      // wrapper de outro erro. Olha statusCode se houver.
      if (e.code == '401') return ClassificacaoErro.authExpirada;
      // Default: conservador.
    }

    // 4. StorageException — Supabase Storage.
    if (e is StorageException) {
      final code = e.statusCode ?? '';
      final asInt = int.tryParse(code);
      if (asInt != null) {
        return classificar(e, statusCode: asInt);
      }
    }

    // 5. AuthException — Supabase Auth.
    if (e is AuthException) {
      // Mensagens típicas de expirou/inválido.
      final m = e.message.toLowerCase();
      if (m.contains('jwt') || m.contains('expir') || m.contains('invalid token')) {
        return ClassificacaoErro.authExpirada;
      }
    }

    // 6. Texto da mensagem — http package wrappa SocketException em
    //    ClientException, então procuramos padrões de rede no texto.
    final s = e.toString().toLowerCase();
    const padroesRede = [
      'failed host lookup',
      'connection refused',
      'connection reset',
      'connection closed',
      'software caused connection abort',
      'broken pipe',
      'no address associated',
      'errno = 7',
      'errno = 101',
      'errno = 104',
      'errno = 110',
      'errno = 111',
      'errno = 113',
      'network is unreachable',
      'os error: network is unreachable',
      'clientexception with socket',
    ];
    for (final p in padroesRede) {
      if (s.contains(p)) return ClassificacaoErro.redeTransitoria;
    }

    // 7. Default conservador: trata como rede pra não gerar auto-issue
    //    indevido. Se aparecer problema recorrente, refinamos.
    return ClassificacaoErro.redeTransitoria;
  }

  /// Helper: rótulo curto pra log/cooldown key.
  static String rotulo(ClassificacaoErro c) {
    switch (c) {
      case ClassificacaoErro.redeTransitoria:
        return 'rede';
      case ClassificacaoErro.authExpirada:
        return 'auth';
      case ClassificacaoErro.erroReal:
        return 'erro-real';
    }
  }
}
