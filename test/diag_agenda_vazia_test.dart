// Agenda vazia (Camila/Thamara 15/06) — o pull purga as visitas do dia e
// depois RECRIA; a recriação usava getVisitaByGabaritoTurnoData com
// getSingleOrNull, que ESTOURAVA se houvesse linha local duplicada →
// purgou e não recriou → home VAZIA.
//
// FIX: a busca não usa mais getSingleOrNull — retorna a linha mais
// relevante (prioriza serverId real) e NUNCA lança.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wizmart_app/core/database/app_database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  String hojeUtc(int hora) {
    final h = DateTime.now();
    return DateTime.utc(h.year, h.month, h.day, hora).toIso8601String();
  }

  String inicio() => DateTime(DateTime.now().year, DateTime.now().month,
          DateTime.now().day)
      .toUtc()
      .toIso8601String();
  String fim() => DateTime(DateTime.now().year, DateTime.now().month,
          DateTime.now().day, 23, 59, 59)
      .toUtc()
      .toIso8601String();

  test('SANIDADE: vaga agendada (status 1) de hoje APARECE na home', () async {
    await db.into(db.visitas).insert(VisitasCompanion(
          id: const Value(-123),
          idPromotorAssociado: const Value(170),
          idGabaritoAssociado: const Value(1305),
          idPdvAssociado: const Value(808),
          previsaoTurnoRealizada: const Value('manha'),
          diaHoraAgendado: Value(hojeUtc(8)),
          statusVisita: const Value(1),
          syncStatus: const Value('synced'),
          localState: const Value('idle'),
        ));
    final home = await db.watchVisitasHoje(170).first;
    expect(home.length, 1);
  });

  test('FIX agenda vazia: 2 linhas com a MESMA chave natural NÃO estouram '
      'mais — retorna uma (prioriza serverId) sem lançar', () async {
    // -111 = idTemp (serverId null); 123456 = a mesma vaga já com serverId.
    await db.into(db.visitas).insert(VisitasCompanion(
          id: const Value(-111),
          idPromotorAssociado: const Value(170),
          idGabaritoAssociado: const Value(1305),
          idPdvAssociado: const Value(808),
          previsaoTurnoRealizada: const Value('manha'),
          diaHoraAgendado: Value(hojeUtc(8)),
          statusVisita: const Value(1),
          syncStatus: const Value('synced'),
        ));
    await db.into(db.visitas).insert(VisitasCompanion(
          id: const Value(123456),
          serverId: const Value(123456),
          idPromotorAssociado: const Value(170),
          idGabaritoAssociado: const Value(1305),
          idPdvAssociado: const Value(808),
          previsaoTurnoRealizada: const Value('manha'),
          diaHoraAgendado: Value(hojeUtc(8)),
          statusVisita: const Value(1),
          syncStatus: const Value('synced'),
        ));

    // ANTES: isto lançava StateError (Too many elements) e o pull abortava
    // depois da purga → home vazia. AGORA não lança.
    late Visita? r;
    expect(() async {
      r = await db.getVisitaByGabaritoTurnoData(
          1305, 808, 'manha', inicio(), fim());
    }, returnsNormally);
    r = await db.getVisitaByGabaritoTurnoData(
        1305, 808, 'manha', inicio(), fim());
    expect(r, isNotNull);
    expect(r!.serverId, 123456,
        reason: 'com duplicata, prioriza a linha já sincronizada (serverId)');
  });

  test('sem duplicata: comportamento normal (retorna a única / null)',
      () async {
    expect(
        await db.getVisitaByGabaritoTurnoData(
            1, 1, 'manha', inicio(), fim()),
        isNull);
  });
}
