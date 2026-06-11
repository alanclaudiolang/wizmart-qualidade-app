// lib/core/utils/sync_logger.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'persistent_logger.dart';

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

  static const _maxInMemory = 500;

  void log(String etapa, String mensagem, {bool erro = false}) {
    // Memória (UI) — buffer limitado pra não estourar.
    final novo = [
      ...state,
      SyncLog(etapa: etapa, mensagem: mensagem, erro: erro),
    ];
    state = novo.length > _maxInMemory
        ? novo.sublist(novo.length - _maxInMemory)
        : novo;
    // Persistente (arquivo) — sobrevive a clear() e a app restart.
    // Usado pelo PhotoErrorReporter pra anexar contexto nos issues.
    // ignore: discarded_futures
    PersistentLogger.append(etapa, mensagem, erro: erro);
  }

  void clear() => state = [];
}

final syncLoggerProvider =
    StateNotifierProvider<SyncLoggerNotifier, List<SyncLog>>(
  (ref) => SyncLoggerNotifier(),
);
