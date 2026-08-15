// Reconciliação de caminhos pós-atualização iOS (build 272) — caso
// Douglas 13/08: o iOS troca o UUID do container em TODA atualização de
// app; caminhos completos gravados em pending_photos/fotosXxxJson
// quebravam ("Arquivo local sumiu"). A reconciliação de boot reescreve
// o prefixo para a pasta atual.

import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wizmart_app/core/database/app_database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  const pastaAntiga =
      '/var/mobile/Containers/Data/Application/AAAA-1111/Documents';
  const pastaNova =
      '/var/mobile/Containers/Data/Application/BBBB-2222/Documents';

  Future<void> foto(String id, int visitaId, String path,
      {String status = 'pending'}) async {
    await db.into(db.pendingPhotos).insert(PendingPhotosCompanion.insert(
          id: id,
          visitaId: visitaId,
          slot: 'antes',
          numero: 1,
          localPath: path,
          status: Value(status),
          nextRetryAt: DateTime.now().toIso8601String(),
          createdAt: DateTime.now().toIso8601String(),
        ));
  }

  test('corrige prefixo antigo em pending_photos e fotosXxxJson', () async {
    await db.into(db.visitas).insert(VisitasCompanion.insert(
          id: const Value(10),
          fotosAntesJson: Value(jsonEncode([
            '$pastaAntiga/wizmart_fotos/a_raw.jpg',
            '$pastaNova/wizmart_fotos/b.jpg', // já correto — não mexe
          ])),
        ));
    await foto('f1', 10, '$pastaAntiga/wizmart_fotos/a_raw.jpg');
    await foto('f2', 10, '$pastaNova/wizmart_fotos/b.jpg');

    final n = await db.reconciliarCaminhosDeFotos(pastaNova);
    // f1 + 1 entrada do JSON = 2 correções.
    expect(n, 2);

    final fotos = await db.getPendingPhotosByVisitaSlot(10, 'antes');
    expect(fotos.map((f) => f.localPath), everyElement(startsWith(pastaNova)));

    final v = await db.getVisitaById(10);
    final lista = List<String>.from(jsonDecode(v!.fotosAntesJson!));
    expect(lista, [
      '$pastaNova/wizmart_fotos/a_raw.jpg',
      '$pastaNova/wizmart_fotos/b.jpg',
    ]);
  });

  test('no-op quando tudo já aponta para a pasta atual (Android)', () async {
    await db.into(db.visitas).insert(VisitasCompanion.insert(
          id: const Value(11),
          fotosDepoisJson:
              Value(jsonEncode(['$pastaNova/wizmart_fotos/c.jpg'])),
        ));
    await foto('f3', 11, '$pastaNova/wizmart_fotos/c.jpg');
    expect(await db.reconciliarCaminhosDeFotos(pastaNova), 0);
  });

  test('caminho sem marcador wizmart_fotos/bugs é ignorado', () async {
    await foto('f4', 12, '$pastaAntiga/outra_pasta/x.jpg');
    expect(await db.reconciliarCaminhosDeFotos(pastaNova), 0);
    final fotos = await db.getPendingPhotosByVisitaSlot(12, 'antes');
    expect(fotos.single.localPath, '$pastaAntiga/outra_pasta/x.jpg');
  });
}
