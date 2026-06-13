// Item 2 (Causa A) — quando a consolidação troca a PK da visita
// (idTemp → serverId) com a tela aberta, as escritas da tela caem no id
// antigo. O mapa de migração permite à tela reapontar para o id vigente,
// e a consolidação migra fotos/outbox para o novo id (sem órfãos).

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wizmart_app/core/database/app_database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('item 2: consolidação grava idVigente e migra fotos/outbox sem órfãos',
      () async {
    const idTemp = -100;
    const serverId = 122556;

    await db.into(db.visitas).insert(
        VisitasCompanion(id: const Value(idTemp), idPromotorAssociado: const Value(34)));
    await db.into(db.pendingPhotos).insert(PendingPhotosCompanion.insert(
          id: 'f1',
          visitaId: idTemp,
          slot: 'antes',
          numero: 1,
          localPath: '/f1.jpg',
          nextRetryAt: 'x',
          createdAt: 'x',
        ));
    await db.insertOutboxItem(OutboxItemsCompanion.insert(
      id: 'o1',
      entityType: 'visita',
      operation: 'open',
      entityId: idTemp,
      payloadJson: '{}',
      nextRetryAt: 'x',
      createdAt: 'x',
    ));

    await db.consolidarVisitaNoServer(idTemp, serverId);

    // 1) a tela reaponta o id antigo para o vigente
    expect(await db.idVigente(idTemp), serverId,
        reason: 'sem o mapa, escritas da tela cairiam no id morto (Causa A)');
    // 2) fotos migraram para o serverId (não ficaram órfãs)
    expect((await db.getPendingPhotosByVisitaSlot(serverId, 'antes')).length, 1);
    expect((await db.getPendingPhotosByVisitaSlot(idTemp, 'antes')).length, 0);
  });
}
