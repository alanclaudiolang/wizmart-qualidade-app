// lib/core/utils/processing_counter.dart
//
// Contador global de operações pesadas em andamento (watermark, sync,
// upload). Quando > 0, a UI mostra um ícone de engrenagem girando na
// home pra deixar o promotor saber que tem coisa rodando — sem ele
// achar que travou.
//
// Não usa Riverpod por simplicidade: é só um ValueNotifier global
// que qualquer service pode tocar (não precisa Ref).

import 'package:flutter/foundation.dart';

class ProcessingCounter {
  ProcessingCounter._();

  /// Quantidade de operações ativas. UI escuta via ValueListenableBuilder.
  static final ValueNotifier<int> notifier = ValueNotifier<int>(0);

  static void begin() {
    notifier.value = notifier.value + 1;
  }

  static void end() {
    final v = notifier.value;
    notifier.value = v > 0 ? v - 1 : 0;
  }
}
