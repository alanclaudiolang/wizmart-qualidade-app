// lib/core/utils/processing_tracker.dart
//
// Rastreia quais visitas estão em processamento ativo (watermark,
// upload, sync). Cada card de visita na home escuta esse tracker e
// mostra um ícone de engrenagem girando enquanto a sua visita estiver
// no set.
//
// Também usado pelo bloqueio de atualização obrigatória: se houver
// qualquer visita em processamento, o dialog "Atualizar agora" não
// aparece — instalar APK por cima poderia perder dados em trânsito.

import 'package:flutter/foundation.dart';

class ProcessingTracker {
  ProcessingTracker._();

  /// IDs de visitas atualmente sendo processadas. UI escuta via
  /// ValueListenableBuilder.
  static final ValueNotifier<Set<int>> visitasAtivas =
      ValueNotifier<Set<int>>({});

  static void begin(int visitaId) {
    final novo = Set<int>.from(visitasAtivas.value);
    if (novo.add(visitaId)) {
      visitasAtivas.value = novo;
    }
  }

  static void end(int visitaId) {
    final novo = Set<int>.from(visitasAtivas.value);
    if (novo.remove(visitaId)) {
      visitasAtivas.value = novo;
    }
  }

  /// Conveniência síncrona pra checar se ALGUMA visita está sendo
  /// processada (usado pelo bloqueio obrigatório).
  static int get total => visitasAtivas.value.length;

  static bool isActive(int visitaId) =>
      visitasAtivas.value.contains(visitaId);
}
