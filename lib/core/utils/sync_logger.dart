// lib/core/utils/sync_logger.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

class SyncLog {
  final DateTime timestamp;
  final String etapa;
  final String mensagem;
  final bool erro;

  SyncLog({
    required this.etapa,
    required this.mensagem,
    this.erro = false,
  }) : timestamp = DateTime.now();

  String get hora {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

class SyncLoggerNotifier extends StateNotifier<List<SyncLog>> {
  SyncLoggerNotifier() : super([]);

  void log(String etapa, String mensagem, {bool erro = false}) {
    state = [
      ...state,
      SyncLog(etapa: etapa, mensagem: mensagem, erro: erro),
    ];
  }

  void clear() => state = [];
}

final syncLoggerProvider =
    StateNotifierProvider<SyncLoggerNotifier, List<SyncLog>>(
  (ref) => SyncLoggerNotifier(),
);
