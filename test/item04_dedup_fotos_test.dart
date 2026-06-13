// Item 4 — dedup de fotos. Quando o promotor refaz fotos após um
// reset/pivot, podem existir 2+ pending_photos com a MESMA URL (nome de
// arquivo determinístico + upsert no Storage). O array enviado ao servidor
// não pode conter URL repetida (casos Diego 122527, Renato 122383/122384).

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wizmart_app/core/database/app_database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('item 4: getUploadedPhotoUrls NÃO repete a mesma URL, preservando ordem',
      () async {
    const visitaId = 200;
    const urlA = 'https://x/antes-1.jpg';
    const urlB = 'https://x/antes-2.jpg';
    // Ordem de captura: A, B, e A de novo (refez a 1ª) — todas uploaded.
    Future<void> foto(String id, int numero, String url) =>
        db.into(db.pendingPhotos).insert(PendingPhotosCompanion.insert(
              id: id,
              visitaId: visitaId,
              slot: 'antes',
              numero: numero,
              localPath: '/$id.jpg',
              nextRetryAt: 'x',
              createdAt: 'x',
              status: const Value('uploaded'),
              storageUrl: Value(url),
            ));
    await foto('a', 1, urlA);
    await foto('b', 2, urlB);
    await foto('c', 3, urlA); // duplicata da 1ª

    final urls = await db.getUploadedPhotoUrls(visitaId, 'antes');
    expect(urls, [urlA, urlB],
        reason: 'BUG: URL duplicada subiria 2x no array fotos_antes do servidor');
  });
}
