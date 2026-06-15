// DIAGNÓSTICO (caso Thamara/Renato 15/06) — "agenda vazia": a edge function
// devolve a vaga válida (HTTP 200, status 4), o app a perde no pull.
//
// Hipótese A: getVisitaByGabaritoTurnoData usa getSingleOrNull(), que LANÇA
// exceção se houver 2+ linhas com a mesma chave natural (gabarito|pdv|turno|
// dia). Resquício de builds antigos (idTemp = Object.hash não-determinístico)
// deixava DUAS linhas locais pra mesma vaga. No pull, esse throw acontece
// DEPOIS da purga "destruir + re-baixar" — o try/catch externo engole a
// exceção e a home fica VAZIA.
//
// Sanidade: confirmar que uma vaga status 1 (agendada) sempre aparece na home.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wizmart_app/core/database/app_database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  // String de hoje no formato que o pull grava (UTC) — garante cair na janela.
  String hojeUtc(int hora) {
    final h = DateTime.now();
    return DateTime.utc(h.year, h.month, h.day, hora).toIso8601String();
  }

  test('SANIDADE: vaga agendada (status 1) de hoje APARECE na home', () async {
    await db.into(db.visitas).insert(VisitasCompanion(
          id: const Value(-123),
          idPromotorAssociado: const Value(170),
          idGabaritoAssociado: const Value(1305),
          idPdvAssociado: const Value(808),
          previsaoTurnoRealizada: const Value('manha'),
          diaHoraAgendado: Value(hojeUtc(8)), // 05:00-03 = 08:00Z
          statusVisita: const Value(1),
          syncStatus: const Value('synced'),
          localState: const Value('idle'),
        ));
    final home = await db.watchVisitasHoje(170).first;
    expect(home.length, 1, reason: 'a vaga válida tem que aparecer na home');
  });

  test('HIPÓTESE A: 2 linhas com a MESMA chave natural fazem o lookup do '
      'pull LANÇAR — e o pull engole, deixando a home vazia', () async {
    final inicio =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)
            .toUtc()
            .toIso8601String();
    final fim = DateTime(DateTime.now().year, DateTime.now().month,
            DateTime.now().day, 23, 59, 59)
        .toUtc()
        .toIso8601String();

    // Duas linhas pra mesma (gabarito 1305, pdv 808, turno manha, hoje) —
    // exatamente o que um build antigo com idTemp não-determinístico deixava.
    for (final id in [-111, -222]) {
      await db.into(db.visitas).insert(VisitasCompanion(
            id: Value(id),
            idPromotorAssociado: const Value(170),
            idGabaritoAssociado: const Value(1305),
            idPdvAssociado: const Value(808),
            previsaoTurnoRealizada: const Value('manha'),
            diaHoraAgendado: Value(hojeUtc(8)),
            statusVisita: const Value(1),
            syncStatus: const Value('synced'),
            localState: const Value('idle'),
          ));
    }

    // É exatamente a chamada que o pull faz no passo 6 (sync_engine:503/557).
    expect(
      () => db.getVisitaByGabaritoTurnoData(1305, 808, 'manha', inicio, fim),
      throwsA(anything),
      reason:
          'getSingleOrNull LANÇA com 2 linhas → o for do pull aborta → após a '
          'purga a home fica vazia (caso agenda some sozinha)',
    );
  });
}
