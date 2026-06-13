// CASO CAMILA (13/06, build 249) — o INSERT de uma visita que bate em
// conflito no servidor lança PostgrestException onde `code` é o HTTP status
// ('406') e o 'PGRST116' fica só na mensagem. O tratamento antigo checava
// só `code=='PGRST116'`, então fazia rethrow e a visita completa (4 antes /
// 5 depois) entrava em LOOP INFINITO de INSERT, sem nunca sincronizar.

import 'package:flutter_test/flutter_test.dart';
import 'package:wizmart_app/core/network/sync_engine.dart';

void main() {
  group('ehErroZeroRows — detecção robusta de PGRST116', () {
    test('code == PGRST116 → true', () {
      expect(
          SyncEngine.ehErroZeroRows(code: 'PGRST116', message: 'qualquer'),
          isTrue);
    });

    test('code 406 com PGRST116 só na mensagem → true (CASO CAMILA)', () {
      const msg =
          '{"code":"PGRST116","details":"The result contains 0 rows",'
          '"message":"Cannot coerce the result to a single JSON object"}';
      expect(
          SyncEngine.ehErroZeroRows(code: '406', message: msg),
          isTrue,
          reason: 'BUG: sem isso, INSERT entra em loop infinito (Camila)');
    });

    test('"Cannot coerce" na mensagem → true', () {
      expect(
          SyncEngine.ehErroZeroRows(
              code: '406', message: 'Cannot coerce the result'),
          isTrue);
    });

    test('erro real diferente (ex.: constraint 23505) → false (deve rethrow)',
        () {
      expect(
          SyncEngine.ehErroZeroRows(
              code: '23505', message: 'duplicate key value'),
          isFalse);
    });
  });
}
