// Sincronismo em ordem decrescente por visita (build 262, recriado 15/07).
//
// Regra definida pelo Alan (24/06): priorizar sincronizar as visitas em
// ordem decrescente sempre — `COALESCE(dia_hora_realizado,
// dia_hora_agendado) DESC` — preservando a sequência interna de cada
// visita (open → fotos → close / ordem de captura) via `created_at ASC`
// como 2º critério. Mudança mínima: só o ORDER BY de `getPendingPhotos`
// e `getPendingOutboxItems`; a trava `countFotosEmProgresso` (Posterga)
// e o resto do outbox ficam intocados.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wizmart_app/core/database/app_database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> inserirVisita(int id,
      {String? realizado, String? agendado}) async {
    await db.into(db.visitas).insert(VisitasCompanion(
          id: Value(id),
          idPromotorAssociado: const Value(115),
          diaHoraRealizado: Value(realizado),
          diaHoraAgendado: Value(agendado),
          statusVisita: const Value(2),
        ));
  }

  Future<void> inserirFoto(String id, int visitaId,
      {required String createdAt}) async {
    await db.into(db.pendingPhotos).insert(PendingPhotosCompanion.insert(
          id: id,
          visitaId: visitaId,
          slot: 'antes',
          numero: 1,
          localPath: '/$id.jpg',
          status: const Value('pending'),
          nextRetryAt: '2000-01-01T00:00:00',
          createdAt: createdAt,
        ));
  }

  Future<void> inserirOutbox(String id, int visitaId, String op,
      {required String createdAt}) async {
    await db.into(db.outboxItems).insert(OutboxItemsCompanion.insert(
          id: id,
          entityType: 'visita',
          operation: op,
          entityId: visitaId,
          payloadJson: '{}',
          nextRetryAt: '2000-01-01T00:00:00',
          createdAt: createdAt,
        ));
  }

  test('visita mais recente sincroniza primeiro (fotos e registros)',
      () async {
    // Visita antiga (03/06, realizada) capturada primeiro; visita de hoje
    // (realizado mais novo) capturada depois. Sem a ordenação nova, o
    // created_at ASC global colocaria a antiga na frente.
    await inserirVisita(1, realizado: '2026-06-03T10:00:00');
    await inserirVisita(2, realizado: '2026-07-15T09:00:00');
    // Visita 3 sem realizado → usa o agendado (mais novo que a antiga).
    await inserirVisita(3, agendado: '2026-07-14T08:00:00');

    await inserirFoto('f-antiga', 1, createdAt: '2026-06-03T10:05:00');
    await inserirFoto('f-hoje', 2, createdAt: '2026-07-15T09:05:00');
    await inserirFoto('f-agendada', 3, createdAt: '2026-07-14T08:05:00');

    await inserirOutbox('o-antiga', 1, 'open',
        createdAt: '2026-06-03T10:05:00');
    await inserirOutbox('o-hoje', 2, 'open',
        createdAt: '2026-07-15T09:05:00');
    await inserirOutbox('o-agendada', 3, 'open',
        createdAt: '2026-07-14T08:05:00');

    final fotos = await db.getPendingPhotos();
    expect(fotos.map((f) => f.id).toList(),
        ['f-hoje', 'f-agendada', 'f-antiga']);

    final itens = await db.getPendingOutboxItems();
    expect(itens.map((o) => o.id).toList(),
        ['o-hoje', 'o-agendada', 'o-antiga']);
  });

  test(
      'dentro da mesma visita a sequência interna é preservada '
      '(open→photos→close; fotos na ordem de captura)', () async {
    await inserirVisita(10, realizado: '2026-07-15T12:00:00');
    // Inserção fora de ordem de propósito — a ordem deve vir do createdAt.
    await inserirOutbox('close', 10, 'close',
        createdAt: '2026-07-15T12:30:00');
    await inserirOutbox('open', 10, 'open', //
        createdAt: '2026-07-15T11:00:00');
    await inserirOutbox('photos', 10, 'photos_antes',
        createdAt: '2026-07-15T11:30:00');

    await inserirFoto('p2', 10, createdAt: '2026-07-15T11:10:00');
    await inserirFoto('p1', 10, createdAt: '2026-07-15T11:05:00');

    final itens = await db.getPendingOutboxItems();
    expect(itens.map((o) => o.id).toList(), ['open', 'photos', 'close']);

    final fotos = await db.getPendingPhotos();
    expect(fotos.map((f) => f.id).toList(), ['p1', 'p2']);
  });
}
