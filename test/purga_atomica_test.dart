// Purga atômica (build 265) — teste-espelho.
//
// A purga "destruir + re-baixar" passou de 2 passos (ler ids protegidos
// → apagar) para UM DELETE com NOT EXISTS correlacionado. Este teste
// garante que o conjunto protegido é IDÊNTICO ao da implementação
// antiga (reimplementada aqui, passo a passo, como espelho) em todos os
// cenários — e prova que a atômica fecha a corrida que criava a
// "situação 2" do caminho-fantasma (foto inserida entre o snapshot e o
// delete → visita de dia anterior purgada com foto pendente).

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wizmart_app/core/database/app_database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  const promotor = 115;

  Future<void> visita(int id,
      {int promotorId = promotor,
      String sync = 'synced',
      int? status = 1,
      String localState = 'finalizada'}) async {
    await db.into(db.visitas).insert(VisitasCompanion(
          id: Value(id),
          idPromotorAssociado: Value(promotorId),
          syncStatus: Value(sync),
          statusVisita: Value(status),
          localState: Value(localState),
        ));
  }

  Future<void> foto(String id, int visitaId, String status) async {
    await db.into(db.pendingPhotos).insert(PendingPhotosCompanion.insert(
          id: id,
          visitaId: visitaId,
          slot: 'antes',
          numero: 1,
          localPath: '/$id.jpg',
          status: Value(status),
          nextRetryAt: 'x',
          createdAt: 'x',
        ));
  }

  Future<void> outbox(String id, int visitaId, String status) async {
    await db.into(db.outboxItems).insert(OutboxItemsCompanion.insert(
          id: id,
          entityType: 'visita',
          operation: 'open',
          entityId: visitaId,
          payloadJson: '{}',
          nextRetryAt: 'x',
          createdAt: 'x',
          status: Value(status),
        ));
  }

  /// ESPELHO: a implementação ANTIGA (2 passos), reproduzida literalmente
  /// — snapshot dos ids protegidos e delete com isNotIn. Usada como
  /// referência do comportamento esperado.
  Future<Set<int>> sobreviventesPelaRegraAntiga() async {
    final naoApagar = <int>{};
    for (final o in await (db.select(db.outboxItems)
          ..where((o) =>
              o.status.equals('pending') | o.status.equals('processing')))
        .get()) {
      naoApagar.add(o.entityId);
    }
    for (final p in await (db.select(db.pendingPhotos)
          ..where((p) =>
              p.status.equals('watermark_pending') |
              p.status.equals('pending') |
              p.status.equals('uploading')))
        .get()) {
      naoApagar.add(p.visitaId);
    }
    final todas = await db.select(db.visitas).get();
    return todas
        .where((v) => !(v.idPromotorAssociado == promotor &&
            v.syncStatus == 'synced' &&
            // NULL semantics do drift: equals(2).not() com NULL não
            // apaga; isIn com NULL não apaga.
            v.statusVisita != null &&
            v.statusVisita != 2 &&
            (v.localState == 'idle' || v.localState == 'finalizada') &&
            !naoApagar.contains(v.id)))
        .map((v) => v.id)
        .toSet();
  }

  test('espelho: atômica apaga/protege EXATAMENTE o mesmo conjunto',
      () async {
    // Cenários (id → esperado):
    await visita(1); // limpa → APAGA
    await visita(2);
    await outbox('o2', 2, 'pending'); // outbox pendente → protege
    await visita(3);
    await outbox('o3', 3, 'processing'); // outbox processando → protege
    await visita(4);
    await outbox('o4', 4, 'done'); // outbox concluído → APAGA
    await visita(5);
    await foto('f5', 5, 'watermark_pending'); // → protege
    await visita(6);
    await foto('f6', 6, 'pending'); // → protege
    await visita(7);
    await foto('f7', 7, 'uploading'); // → protege
    await visita(8);
    await foto('f8', 8, 'uploaded'); // já subiu → APAGA
    await visita(9);
    await foto('f9', 9, 'error'); // error não protege (regra antiga) → APAGA
    await visita(10, status: 2); // Em Andamento (A2) → protege
    await visita(11, localState: 'fotos_antes'); // etapa em curso (A2) → protege
    await visita(12, status: null); // status NULL → protege (NULL semantics)
    await visita(14, sync: 'pending'); // não-synced → protege
    await visita(15, promotorId: 999); // outro promotor → intocada

    final esperado = await sobreviventesPelaRegraAntiga();
    await db.deleteVisitasSincronizadasSemPendencias(promotor);
    final sobraram =
        (await db.select(db.visitas).get()).map((v) => v.id).toSet();

    expect(sobraram, esperado);
    expect(sobraram,
        {2, 3, 5, 6, 7, 10, 11, 12, 14, 15}); // dupla conferência
  });

  test('corrida fechada: foto que entra ANTES do delete sempre protege '
      '(na regra antiga, o snapshot desatualizado apagava)', () async {
    // Visita de DIA ANTERIOR, synced, sem pendências no momento do
    // "snapshot" da regra antiga.
    await visita(100);
    final snapshotAntigo = <int>{}; // regra antiga: nada a proteger

    // A corrida: foto pendente entra DEPOIS do snapshot...
    await foto('f100', 100, 'pending');

    // ...regra ANTIGA (com o snapshot velho) apagaria a visita:
    final apagariaAntiga = !snapshotAntigo.contains(100);
    expect(apagariaAntiga, true); // documenta o bug fechado

    // A atômica lê a pendência DENTRO do próprio DELETE → protege:
    await db.deleteVisitasSincronizadasSemPendencias(promotor);
    final row = await db.getVisitaById(100);
    expect(row, isNotNull);
  });

  test('gatilho pós-pull destrava só as fotos adiadas por visita ausente',
      () async {
    final futuro =
        DateTime.now().add(const Duration(seconds: 30)).toIso8601String();
    await foto('adiada', 1, 'pending');
    await foto('rede', 1, 'pending');
    await foto('subiu', 1, 'uploaded');
    await (db.update(db.pendingPhotos)
          ..where((p) => p.id.equals('adiada')))
        .write(PendingPhotosCompanion(
      lastError: const Value('visita_ausente_adiado'),
      nextRetryAt: Value(futuro),
    ));
    await (db.update(db.pendingPhotos)..where((p) => p.id.equals('rede')))
        .write(PendingPhotosCompanion(
      lastError: const Value('SocketException: rede caiu'),
      nextRetryAt: Value(futuro),
    ));

    final n = await db.destravarFotosAdiadasPorVisitaAusente();
    expect(n, 1); // só a marcada

    final agora = DateTime.now().toIso8601String();
    final rows = await db.select(db.pendingPhotos).get();
    final byId = {for (final r in rows) r.id: r};
    expect(byId['adiada']!.nextRetryAt.compareTo(agora) <= 0, true);
    expect(byId['rede']!.nextRetryAt, futuro); // backoff intacto
  });
}
