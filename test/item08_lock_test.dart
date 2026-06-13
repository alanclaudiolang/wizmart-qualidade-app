// Item 8 (Causa D) — a trava de sync entre processos não pode expirar no
// meio de um ciclo longo (rede ruim), senão o WorkManager (outro processo)
// entra em paralelo rodando pull destrutivo.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wizmart_app/core/database/app_database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('Causa D: SEM renovação o lock expira e o outro processo entra',
      () async {
    await db.tryAcquireSyncLock(holder: 'app', ttlMs: 1);
    await Future.delayed(const Duration(milliseconds: 10));
    final wmEntrou = await db.tryAcquireSyncLock(holder: 'wm', ttlMs: 1000);
    expect(wmEntrou, isTrue,
        reason: 'comportamento atual: o lock expira no meio do ciclo (Causa D)');
  });

  test('item 8: renovar mantém o lock e impede o outro processo (correção)',
      () async {
    await db.tryAcquireSyncLock(holder: 'app', ttlMs: 50);
    final renovou = await db.renewSyncLock(holder: 'app', ttlMs: 100000);
    expect(renovou, isTrue);
    await Future.delayed(const Duration(milliseconds: 60)); // > TTL original
    final wmEntrou = await db.tryAcquireSyncLock(holder: 'wm', ttlMs: 1000);
    expect(wmEntrou, isFalse,
        reason: 'com renovação o lock NÃO expira — WorkManager fica de fora');
  });
}
