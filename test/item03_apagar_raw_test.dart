// Item 3 (Causa A) — o arquivo CRU da foto só pode ser apagado depois que
// a troca do caminho no JSON foi confirmada. Sem isso, o cru sumia com o
// JSON ainda apontando pra ele e a grade quebrava (caso Renato 13/06).

import 'package:flutter_test/flutter_test.dart';
import 'package:wizmart_app/core/utils/watermark_queue.dart';

void main() {
  group('Item 3 — deveApagarRaw', () {
    test('troca NÃO confirmada → NÃO apaga o cru (evita grade quebrada)', () {
      expect(
        WatermarkQueueService.deveApagarRaw(
          rawPath: '/x_raw.jpg',
          wmPath: '/x_wm.jpg',
          trocaNoJsonConfirmada: false,
        ),
        isFalse,
      );
    });

    test('wm diferente E troca confirmada → apaga o cru', () {
      expect(
        WatermarkQueueService.deveApagarRaw(
          rawPath: '/x_raw.jpg',
          wmPath: '/x_wm.jpg',
          trocaNoJsonConfirmada: true,
        ),
        isTrue,
      );
    });

    test('wm == raw (watermark falhou, ficou o cru) → NUNCA apaga', () {
      expect(
        WatermarkQueueService.deveApagarRaw(
          rawPath: '/x.jpg',
          wmPath: '/x.jpg',
          trocaNoJsonConfirmada: true,
        ),
        isFalse,
      );
    });
  });
}
