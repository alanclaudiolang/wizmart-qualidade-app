// test/watermark_recover_stale_test.dart
//
// Casos Adriana (20/08) e Brenda (21/08): fotos presas em
// `watermark_pending` por HORAS com o app aberto — a única recuperação
// era `recoverPendingOnBoot` (reiniciar o app). O build 273 adiciona a
// recuperação periódica `recoverStale`, que precisa de duas decisões
// seguras testadas aqui:
//
//   - parAindaEmCaptura: a etapa do slot ainda está em captura?
//     (não podemos rodar watermark no meio da câmera em aparelho fraco)
//   - deveReenfileirarPar: re-enfileira quando a etapa já foi concluída
//     OU quando a foto está presa há 30+ min mesmo "em captura"
//     (localState preso).

import 'package:flutter_test/flutter_test.dart';
import 'package:wizmart_app/core/utils/watermark_queue.dart';

void main() {
  group('parAindaEmCaptura (mesma fórmula do anti-ruído D2)', () {
    test('slot antes: em captura durante idle/abertura/fotos_antes', () {
      expect(WatermarkQueueService.parAindaEmCaptura('antes', 'idle'), isTrue);
      expect(
          WatermarkQueueService.parAindaEmCaptura('antes', 'abertura'), isTrue);
      expect(WatermarkQueueService.parAindaEmCaptura('antes', 'fotos_antes'),
          isTrue);
      expect(WatermarkQueueService.parAindaEmCaptura('antes', 'fotos_depois'),
          isFalse);
      expect(WatermarkQueueService.parAindaEmCaptura('antes', 'checklist'),
          isFalse);
      expect(WatermarkQueueService.parAindaEmCaptura('antes', 'finalizada'),
          isFalse);
    });

    test('slot depois: em captura durante fotos_depois/em_reposicao', () {
      expect(WatermarkQueueService.parAindaEmCaptura('depois', 'fotos_depois'),
          isTrue);
      expect(WatermarkQueueService.parAindaEmCaptura('depois', 'em_reposicao'),
          isTrue);
      expect(WatermarkQueueService.parAindaEmCaptura('depois', 'checklist'),
          isFalse);
      expect(WatermarkQueueService.parAindaEmCaptura('depois', 'finalizada'),
          isFalse);
      expect(
          WatermarkQueueService.parAindaEmCaptura('depois', 'idle'), isFalse);
    });
  });

  group('deveReenfileirarPar (recuperação periódica)', () {
    test('etapa JÁ concluída → re-enfileira imediatamente '
        '(caso Brenda: retake sem novo Concluir)', () {
      expect(
        WatermarkQueueService.deveReenfileirarPar(
          aindaCapturando: false,
          idadeFotoMaisNova: const Duration(minutes: 1),
        ),
        isTrue,
      );
    });

    test('em captura ativa com foto recente → NÃO mexe '
        '(não travar a câmera do promotor)', () {
      expect(
        WatermarkQueueService.deveReenfileirarPar(
          aindaCapturando: true,
          idadeFotoMaisNova: const Duration(minutes: 5),
        ),
        isFalse,
      );
      expect(
        WatermarkQueueService.deveReenfileirarPar(
          aindaCapturando: true,
          idadeFotoMaisNova: const Duration(minutes: 29),
        ),
        isFalse,
      );
    });

    test('“em captura” mas foto presa há 30+ min → re-enfileira '
        '(localState preso — caso Adriana: 2h40 presa)', () {
      expect(
        WatermarkQueueService.deveReenfileirarPar(
          aindaCapturando: true,
          idadeFotoMaisNova: const Duration(minutes: 30),
        ),
        isTrue,
      );
      expect(
        WatermarkQueueService.deveReenfileirarPar(
          aindaCapturando: true,
          idadeFotoMaisNova: const Duration(hours: 21),
        ),
        isTrue,
      );
    });
  });
}
