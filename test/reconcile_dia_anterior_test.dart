// Reconciliação por DIA das visitas presas de D-1 pra trás (caso Thamara,
// issue #5547). O outbox casava a visita pela HORA exata do agendamento;
// quando a hora local (09:00) diverge da do servidor (05:00) pra MESMA
// visita, nunca achava → loop eterno que sufoca o sync e esvazia a agenda
// do dia. Agora casa por DIA, com trava "exatamente 1 senão estaciona" e
// trava de status (Concluída só com antes E depois no estado final).

import 'package:flutter_test/flutter_test.dart';
import 'package:wizmart_app/core/network/sync_engine.dart';

void main() {
  group('visitaEhDeDiaAnterior (escopo ≤ D-1)', () {
    final hoje = DateTime(2026, 6, 17, 10, 0); // referência (meio do dia)

    test('visita de 09/06 → é D-1 pra trás → true', () {
      expect(
          SyncEngine.visitaEhDeDiaAnterior('2026-06-09T12:00:00.000Z',
              agora: hoje),
          isTrue);
    });

    test('visita de HOJE → false (não toca o trabalho corrente)', () {
      expect(
          SyncEngine.visitaEhDeDiaAnterior('2026-06-17T12:00:00.000Z',
              agora: hoje),
          isFalse);
    });

    test('sem data → false (segurança: não aplica)', () {
      expect(SyncEngine.visitaEhDeDiaAnterior(null, agora: hoje), isFalse);
      expect(SyncEngine.visitaEhDeDiaAnterior('', agora: hoje), isFalse);
    });
  });

  group('decidirReconcileDiaAnterior', () {
    Map<String, dynamic> serv(
            {required int id, int status = 1, int fa = 4, int fd = 5}) =>
        {
          'id': id,
          'status_visita': status,
          'fotos_antes': List.generate(fa, (i) => 'a$i'),
          'fotos_depois': List.generate(fd, (i) => 'd$i'),
        };

    test('caso Thamara: 1 candidato (hora diferente) → reconcilia, Concluída',
        () {
      final dec = SyncEngine.decidirReconcileDiaAnterior(
        candidatos: [serv(id: 119755, status: 1, fa: 4, fd: 5)],
        statusEnvio: 1,
        fotosAntesEnvio: 4,
        fotosDepoisEnvio: 5,
      );
      expect(dec.tipo, TipoReconcile.reconciliar);
      expect(dec.serverId, 119755);
      expect(dec.statusFinal, 1);
    });

    test('0 candidatos (contradição) → estaciona, NÃO entra em loop', () {
      final dec = SyncEngine.decidirReconcileDiaAnterior(
        candidatos: const [],
        statusEnvio: 1,
        fotosAntesEnvio: 4,
        fotosDepoisEnvio: 5,
      );
      expect(dec.tipo, TipoReconcile.estacionar);
      expect(dec.serverId, isNull);
    });

    test('2+ candidatos (duplicata no servidor) → estaciona, não chuta', () {
      final dec = SyncEngine.decidirReconcileDiaAnterior(
        candidatos: [serv(id: 1), serv(id: 2)],
        statusEnvio: 1,
        fotosAntesEnvio: 4,
        fotosDepoisEnvio: 5,
      );
      expect(dec.tipo, TipoReconcile.estacionar);
    });

    test('trava status: envio só ANTES e servidor vazio → Incompleta (5)', () {
      final dec = SyncEngine.decidirReconcileDiaAnterior(
        candidatos: [serv(id: 9, fa: 0, fd: 0)],
        statusEnvio: 1,
        fotosAntesEnvio: 4,
        fotosDepoisEnvio: 0,
      );
      expect(dec.tipo, TipoReconcile.reconciliar);
      expect(dec.statusFinal, 5,
          reason: 'sem foto DEPOIS não pode virar Concluída');
    });

    test('trava status: final tem os dois (depois no servidor + antes no envio) → Concluída',
        () {
      final dec = SyncEngine.decidirReconcileDiaAnterior(
        candidatos: [serv(id: 9, fa: 0, fd: 5)], // servidor já tem o depois
        statusEnvio: 1,
        fotosAntesEnvio: 4, // envio traz o antes
        fotosDepoisEnvio: 0,
      );
      expect(dec.statusFinal, 1,
          reason: 'estado final tem antes (envio) + depois (servidor)');
    });

    test('status Incompleta (5) permanece 5', () {
      final dec = SyncEngine.decidirReconcileDiaAnterior(
        candidatos: [serv(id: 9, fa: 4, fd: 0)],
        statusEnvio: 5,
        fotosAntesEnvio: 4,
        fotosDepoisEnvio: 0,
      );
      expect(dec.statusFinal, 5);
    });
  });

  group('boundsDiaCivilUtc', () {
    test('cobre o instante real da visita no servidor', () {
      // local 2026-06-09T12:00Z; servidor guarda 05:00-03 = 08:00Z.
      final b = SyncEngine.boundsDiaCivilUtc('2026-06-09T12:00:00.000Z');
      const servidor = '2026-06-09T08:00:00.000Z';
      expect(b[0].compareTo(servidor) <= 0, isTrue,
          reason: 'início do dia <= instante do servidor');
      expect(b[1].compareTo(servidor) > 0, isTrue,
          reason: 'fim do dia > instante do servidor');
    });
  });
}
