// test/caso_yago_recuperacao_captura_test.dart
//
// Caso Yago (26/08/2026, Samsung A06/4GB, Android 16): o sistema mata o
// app a CADA abertura de câmera (~19 tentativas para 4 fotos). O build
// 274 adiciona a recuperação da foto perdida via retrieveLostData
// (mecanismo oficial do image_picker). Aqui testamos as duas decisões
// puras que cercam a recuperação:
//
//   - parseMarcadorCaptura: só marcador válido habilita a recuperação;
//   - podeRecuperarCaptura: nunca registrar em visita diferente da que
//     abriu a câmera, nunca estourar o limite do slot.

import 'package:flutter_test/flutter_test.dart';
import 'package:wizmart_app/presentation/screens/visita/visita_screen.dart';

void main() {
  group('parseMarcadorCaptura', () {
    test('marcador completo (formato do _tirarFoto)', () {
      final r = VisitaScreen.parseMarcadorCaptura(
          '-827562502|antes|2026-08-26T13:04:44.350992');
      expect(r, isNotNull);
      expect(r!.visitaId, -827562502);
      expect(r.slot, 'antes');
      expect(r.capturadaEm, DateTime.parse('2026-08-26T13:04:44.350992'));
    });

    test('id positivo (visita já consolidada) e slot depois', () {
      final r = VisitaScreen.parseMarcadorCaptura(
          '139513|depois|2026-08-26T14:06:24.723615');
      expect(r!.visitaId, 139513);
      expect(r.slot, 'depois');
    });

    test('timestamp ausente ou inválido → capturadaEm null, resto ok', () {
      expect(
          VisitaScreen.parseMarcadorCaptura('12|antes')!.capturadaEm, null);
      expect(VisitaScreen.parseMarcadorCaptura('12|antes|lixo')!.capturadaEm,
          null);
    });

    test('marcadores inválidos → null (recuperação não roda)', () {
      expect(VisitaScreen.parseMarcadorCaptura(''), null);
      expect(VisitaScreen.parseMarcadorCaptura('sem-pipe'), null);
      expect(VisitaScreen.parseMarcadorCaptura('abc|antes'), null);
      expect(VisitaScreen.parseMarcadorCaptura('12|slot-desconhecido'), null);
    });
  });

  group('podeRecuperarCaptura', () {
    test('mesma visita e abaixo do limite → registra', () {
      expect(
        VisitaScreen.podeRecuperarCaptura(
          visitaIdMarcador: -827562502,
          visitaIdTela: -827562502,
          fotosNoSlot: 3,
          limite: 8,
        ),
        isTrue,
      );
    });

    test('visita diferente (pivô/troca de tela no meio) → NUNCA registra',
        () {
      expect(
        VisitaScreen.podeRecuperarCaptura(
          visitaIdMarcador: -827562502,
          visitaIdTela: 139516,
          fotosNoSlot: 0,
          limite: 8,
        ),
        isFalse,
      );
    });

    test('slot no limite → não registra (regra das 8 fotos preservada)',
        () {
      expect(
        VisitaScreen.podeRecuperarCaptura(
          visitaIdMarcador: 139513,
          visitaIdTela: 139513,
          fotosNoSlot: 8,
          limite: 8,
        ),
        isFalse,
      );
    });
  });
}
