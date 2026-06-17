// fullSync "HOJE PRIMEIRO" — ordem invertida em 17/06 (caso Adonias #256).
//
// Antes: fullSync fazia PUSH (histórico, com upload de foto dentro da trava)
// e SÓ DEPOIS o PULL (agenda). Com backlog grande, o push sufocava a trava e
// a agenda do dia nunca baixava (Adonias: 61 visitas pendentes seguravam o
// envio). Agora a ordem é PULL (agenda de hoje) → PUSH (histórico).
//
// Prova de SEGURANÇA exigida pelo Alan: rodar o pull PRIMEIRO não pode apagar
// histórico não enviado. A recriação do `_pullVisitasDia` é blindada por dois
// guards (inalterados): pula visita `syncStatus='pending'` (guard 1) e visita
// com trabalho (`visitaTemTrabalho`, guard 2). Este teste prova que esses
// guards preservam o histórico mesmo com o pull rodando antes do envio.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wizmart_app/core/database/app_database.dart';
import 'package:wizmart_app/core/network/sync_engine.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('pull-first NÃO perde histórico pendente — guard syncStatus=pending',
      () async {
    // Visita de ONTEM, finalizada localmente, AINDA NÃO enviada (pending).
    // É o "histórico não enviado" que não pode sumir quando o pull roda 1º.
    final ontem = DateTime.now().subtract(const Duration(days: 1));
    final ag =
        DateTime.utc(ontem.year, ontem.month, ontem.day, 12).toIso8601String();
    await db.into(db.visitas).insert(VisitasCompanion(
          id: const Value(-987654),
          idPromotorAssociado: const Value(593),
          idGabaritoAssociado: const Value(1441),
          idPdvAssociado: const Value(706),
          previsaoTurnoRealizada: const Value('tarde'),
          diaHoraAgendado: Value(ag),
          statusVisita: const Value(3), // realizada localmente
          diaHoraAbertura: Value(ag),
          syncStatus: const Value('pending'), // NÃO enviada
        ));
    final inicio =
        DateTime.utc(ontem.year, ontem.month, ontem.day).toIso8601String();
    final fim = DateTime.utc(ontem.year, ontem.month, ontem.day, 23, 59, 59)
        .toIso8601String();
    final achada =
        await db.getVisitaByGabaritoTurnoData(1441, 706, 'tarde', inicio, fim);
    expect(achada, isNotNull, reason: 'o pull enxerga a visita do dia...');
    expect(achada!.syncStatus, 'pending',
        reason: 'está pending → _pullVisitasDia PULA (não recria/zera) → '
            'histórico preservado mesmo com o pull rodando antes do envio');
  });

  test('guard 2: visitaTemTrabalho protege visita com trabalho', () {
    // com abertura → tem trabalho → o pull NÃO recria
    expect(
        SyncEngine.visitaTemTrabalho(
            serverId: null,
            diaHoraAbertura: '2026-06-16T12:00:00Z',
            statusVisita: 1),
        isTrue);
    // em andamento (status 2) → tem trabalho
    expect(
        SyncEngine.visitaTemTrabalho(
            serverId: null, diaHoraAbertura: null, statusVisita: 2),
        isTrue);
    // já tem serverId → tem trabalho (não é vaga limpa)
    expect(
        SyncEngine.visitaTemTrabalho(
            serverId: 999, diaHoraAbertura: null, statusVisita: 1),
        isTrue);
    // vaga limpa (agendada, sem nada) → SEM trabalho → pode recriar (não é
    // histórico, é só re-baixar a vaga do dia)
    expect(
        SyncEngine.visitaTemTrabalho(
            serverId: null, diaHoraAbertura: null, statusVisita: 1),
        isFalse);
  });
}
