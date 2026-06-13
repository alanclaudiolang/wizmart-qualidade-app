// Item 7 (Causa C) — o guard que descarta "visita-fantasma" no outbox só
// pode apagar quando NÃO há nenhum sinal de trabalho. Antes, faltava
// checar status/fotos: uma visita com fotos mas sem abertura (rebaixada
// pela Causa A2) era apagada por engano (caso Mauro 12/06).

import 'package:flutter_test/flutter_test.dart';
import 'package:wizmart_app/core/network/sync_engine.dart';

void main() {
  group('Causa C — visitaEhFantasma', () {
    test('vaga vazia (sem nenhum sinal) É fantasma → descarta', () {
      expect(
        SyncEngine.visitaEhFantasma(
          isAvulsa: false,
          serverId: null,
          diaHoraAbertura: null,
          diaHoraRealizado: null,
          statusVisita: 1, // agendada
          fotosAntesJson: null,
        ),
        isTrue,
      );
    });

    test('visita COM fotos mas SEM abertura NÃO é fantasma (não apagar) '
        '— protege trabalho rebaixado pela A2', () {
      expect(
        SyncEngine.visitaEhFantasma(
          isAvulsa: false,
          serverId: null,
          diaHoraAbertura: null,
          diaHoraRealizado: null,
          statusVisita: 1,
          fotosAntesJson: '["/data/antes-1.jpg"]',
        ),
        isFalse,
        reason: 'BUG C: visita com fotos seria apagada — promotor perde o antes',
      );
    });

    test('visita EM ANDAMENTO (status 2) NÃO é fantasma', () {
      expect(
        SyncEngine.visitaEhFantasma(
          isAvulsa: false,
          serverId: null,
          diaHoraAbertura: null,
          diaHoraRealizado: null,
          statusVisita: 2, // em andamento
          fotosAntesJson: null,
        ),
        isFalse,
      );
    });

    test('avulsa NUNCA é fantasma (dados criados pelo promotor)', () {
      expect(
        SyncEngine.visitaEhFantasma(
          isAvulsa: true,
          serverId: null,
          diaHoraAbertura: null,
          diaHoraRealizado: null,
          statusVisita: 1,
          fotosAntesJson: null,
        ),
        isFalse,
      );
    });
  });
}
