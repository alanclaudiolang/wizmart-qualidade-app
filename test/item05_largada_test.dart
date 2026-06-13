// Item 5 (Causa B) — o reset do pull NUNCA pode zerar uma visita que o
// promotor já iniciou (corrida "clicar Iniciar no instante do sync").

import 'package:flutter_test/flutter_test.dart';
import 'package:wizmart_app/core/network/sync_engine.dart';

void main() {
  group('Item 5 — visitaTemTrabalho', () {
    test('visita com abertura → tem trabalho (reset NÃO zera)', () {
      expect(
          SyncEngine.visitaTemTrabalho(
            serverId: null,
            diaHoraAbertura: '2026-06-13T12:00:00',
            statusVisita: 1,
          ),
          isTrue);
    });

    test('visita em andamento (status 2) → tem trabalho', () {
      expect(
          SyncEngine.visitaTemTrabalho(
            serverId: null,
            diaHoraAbertura: null,
            statusVisita: 2,
          ),
          isTrue);
    });

    test('vaga limpa (agendada, sem nada) → SEM trabalho (pode resetar)', () {
      expect(
          SyncEngine.visitaTemTrabalho(
            serverId: null,
            diaHoraAbertura: null,
            statusVisita: 1,
          ),
          isFalse);
    });
  });
}
