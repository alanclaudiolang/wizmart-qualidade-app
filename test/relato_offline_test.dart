// Relato manual offline (caso Thamara 15/06) — o "Reportar problema" antes
// fazia POST direto e, sem rede, o catch engolia e o log SE PERDIA. Agora o
// relato é ENFILEIRADO em pending_issues (mesma fila persistente das
// anomalias), sobrevive offline + restart e drena quando houver rede.

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wizmart_app/core/database/app_database.dart';
import 'package:wizmart_app/core/utils/anomalia_reporter.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('relato manual é PERSISTIDO na fila (não se perde offline)', () async {
    final ok = await AnomaliaReporter.enfileirarIssuePronta(
      db: db,
      tipo: 'manual',
      titulo: '[USUÁRIO][home] (relato sem descrição)',
      bodyMd: '## Relato\n```\nlog do dia...\n```',
      labels: const ['bug', 'user-report', 'screen:home', 'build:253'],
    );
    expect(ok, isTrue);

    final fila = await db.select(db.pendingIssues).get();
    expect(fila.length, 1, reason: 'o relato tem que ficar GUARDADO localmente');

    final row = fila.first;
    expect(row.status, 'pending', reason: 'pendente até drenar com rede');
    expect(row.tipo, 'manual');
    expect(row.titulo, startsWith('[USUÁRIO][home]'));
    expect(row.entidadeId, isNull,
        reason: 'relato manual não é de 1 visita — sem injeção de fotos');
    expect(
        (jsonDecode(row.labelsJson) as List).cast<String>(),
        containsAll(<String>['bug', 'user-report']));
    expect(row.githubIssueNumber, isNull, reason: 'só preenche após envio OK');
  });
}
