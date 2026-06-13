// Reproduz a Causa A2 SEM celular e SEM servidor: usa um banco SQLite
// em memória e a função real de purga do pull do app.
//
// Cenário (estado real do caso Felipe 122556, 13/06): o promotor concluiu
// as fotos do "antes", o `open` subiu (visita virou `synced`), e ela está
// EM ANDAMENTO (status 2, etapa fotos_depois), sem outbox nem foto pendente.
// A purga do pull (`deleteVisitasSincronizadasSemPendencias`) NÃO pode
// apagar essa visita — se apagar, o pull a recria como "agendada", o
// promotor vê "Iniciar visita" e o "antes" some da tela.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wizmart_app/core/constants/app_constants.dart';
import 'package:wizmart_app/core/database/app_database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('A2: purga NÃO apaga visita EM ANDAMENTO (status 2 / fotos_depois) '
      'mesmo synced e sem pendência', () async {
    const promotorId = 34;
    await db.into(db.visitas).insert(VisitasCompanion(
          id: const Value(122556),
          idPromotorAssociado: const Value(promotorId),
          serverId: const Value(122556),
          statusVisita: Value(AppConstants.statusEmAndamento), // 2
          localState: const Value('fotos_depois'),
          syncStatus: const Value('synced'),
          fotosAntesJson: const Value('["/data/antes-1.jpg"]'),
        ));

    await db.deleteVisitasSincronizadasSemPendencias(promotorId);

    final v = await db.getVisitaById(122556);
    expect(v, isNotNull,
        reason: 'BUG A2 REPRODUZIDO: a purga apagou uma visita EM ANDAMENTO. '
            'No app real, o pull a recria como "agendada" e o promotor '
            'perde o "antes" / vê "Iniciar visita" de novo.');
  });
}
