// Reordenação do sincronismo (regra do Alan, 23/06): o trabalho pendente é
// escolhido pela VISITA mais recente primeiro — DESC por dia_hora_realizado;
// se nulo, dia_hora_agendado. Mudança MÍNIMA: só a ordenação de
// getPendingPhotos e getPendingOutboxItems. O 2º critério (created_at ASC)
// PRESERVA a ordem interna da visita (open->fotos->close / ordem de captura),
// que antes era garantida pela ordenação global por created_at.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wizmart_app/core/database/app_database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  const passado = '2000-01-01T00:00:00Z'; // nextRetryAt no passado => pronto

  Future<void> visita(int id, {String? realizado, String? agendado}) =>
      db.into(db.visitas).insert(VisitasCompanion(
            id: Value(id),
            diaHoraRealizado: Value(realizado),
            diaHoraAgendado: Value(agendado),
          ));

  Future<void> foto(String id, int visitaId, int numero, String createdAt) =>
      db.into(db.pendingPhotos).insert(PendingPhotosCompanion(
            id: Value(id),
            visitaId: Value(visitaId),
            slot: const Value('antes'),
            numero: Value(numero),
            localPath: Value('/$id.jpg'),
            status: const Value('pending'),
            nextRetryAt: const Value(passado),
            createdAt: Value(createdAt),
          ));

  Future<void> outbox(
          String id, int visitaId, String operation, String createdAt) =>
      db.into(db.outboxItems).insert(OutboxItemsCompanion(
            id: Value(id),
            entityType: const Value('visita'),
            operation: Value(operation),
            entityId: Value(visitaId),
            payloadJson: const Value('{}'),
            status: const Value('pending'),
            nextRetryAt: const Value(passado),
            createdAt: Value(createdAt),
          ));

  test('outbox: visita mais recente primeiro; ordem interna (open<close) '
      'preservada; usa agendado quando realizado é nulo', () async {
    await visita(100, realizado: '2026-06-23T10:00:00Z'); // hoje
    await visita(200,
        realizado: null, agendado: '2026-06-22T08:00:00Z'); // ontem (agendado)
    await visita(300, realizado: '2026-06-21T10:00:00Z'); // anteontem
    // Insere fora de ordem de propósito; o 'close' antes do 'open'.
    await outbox('o100b', 100, 'close', '2026-06-23T10:30:00Z');
    await outbox('o100a', 100, 'open', '2026-06-23T10:10:00Z');
    await outbox('o200', 200, 'photos_antes', '2026-06-22T09:00:00Z');
    await outbox('o300', 300, 'open', '2026-06-21T11:00:00Z');

    final itens = await db.getPendingOutboxItems();

    expect(itens.map((o) => o.id).toList(), ['o100a', 'o100b', 'o200', 'o300'],
        reason: 'visita 100 (mais recente) primeiro; DENTRO dela open antes de '
            'close (created_at ASC); depois 200 (ontem via agendado), 300');
  });

  test('pending_photos: fotos da visita mais recente primeiro, em ordem de '
      'captura', () async {
    await visita(100, realizado: '2026-06-23T10:00:00Z');
    await visita(200, agendado: '2026-06-22T08:00:00Z');
    await foto('f100n2', 100, 2, '2026-06-23T10:12:00Z');
    await foto('f100n1', 100, 1, '2026-06-23T10:11:00Z');
    await foto('f200n1', 200, 1, '2026-06-22T09:00:00Z');

    final fotos = await db.getPendingPhotos();

    expect(fotos.map((f) => f.id).toList(), ['f100n1', 'f100n2', 'f200n1'],
        reason: 'fotos da visita 100 (mais recente) primeiro, em ordem de '
            'captura (created_at ASC); depois a da 200');
  });
}
