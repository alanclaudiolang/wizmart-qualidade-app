// Rotação do log por DATA (não por contagem). Regra do Alan (16/06): o
// relato do promotor "tem que ser 100% do log de hoje". Antes a rotação
// mantinha só as últimas 2000 linhas e arrancava o começo do dia (login,
// 1º pull). Estes testes garantem que readToday() devolve o dia INTEIRO,
// mesmo num dia com muito mais que 2000 linhas.
//
// Obs.: PersistentLogger cacheia o caminho do arquivo num static, então o
// PathProvider e o diretório são montados UMA vez (setUpAll) e só o
// conteúdo é zerado entre testes (clear()) — evita o cache apontar pra um
// diretório de teste já apagado.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:wizmart_app/core/utils/persistent_logger.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.dir);
  final String dir;
  @override
  Future<String?> getApplicationDocumentsPath() async => dir;
  @override
  Future<String?> getTemporaryPath() async => dir;
}

void main() {
  late Directory tmp;
  late File log;

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('wizlog');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
    log = File('${tmp.path}/wizmart_logs/app.log');
    await log.parent.create(recursive: true);
  });

  setUp(() async {
    if (await log.exists()) await log.delete();
  });

  tearDownAll(() async {
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  String ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  test('readToday devolve 100% do dia mesmo com > 2000 linhas hoje', () async {
    // Pré-popula o arquivo: 3000 linhas de hoje + lixo de dias antigos.
    final hoje = ymd(DateTime.now());
    final velho = ymd(DateTime(2020, 1, 1));
    final buf = StringBuffer();
    for (var i = 0; i < 500; i++) {
      buf.writeln('${velho}T00:00:00.000 [velho] linha antiga $i');
    }
    for (var i = 0; i < 3000; i++) {
      buf.writeln('${hoje}T08:00:00.000 [hoje] evento $i');
    }
    await log.writeAsString(buf.toString());

    final today = await PersistentLogger.readToday();
    expect(today.contains('evento 0'), isTrue,
        reason: 'o COMEÇO do dia não pode ser cortado');
    expect(today.contains('evento 2999'), isTrue);
    expect(today.contains('linha antiga'), isFalse,
        reason: 'dias anteriores não entram no relato de hoje');
    final qtd = 'evento '.allMatches(today).length;
    expect(qtd, 3000, reason: '100% do log de hoje');
  });

  test('rotação (via append) descarta dias velhos mas preserva hoje inteiro',
      () async {
    // Semente de um dia ANTIGO direto no arquivo; depois 2500 appends de
    // hoje (dispara a rotação a cada 50 writes). Nada de hoje pode sumir e o
    // dia velho tem que ser descartado.
    final velho = ymd(DateTime(2020, 1, 1));
    final seed = StringBuffer();
    for (var i = 0; i < 800; i++) {
      seed.writeln('${velho}T00:00:00.000 [velho] antiga $i');
    }
    await log.writeAsString(seed.toString());

    for (var i = 0; i < 2500; i++) {
      await PersistentLogger.append('t', 'evt $i');
    }

    final today = await PersistentLogger.readToday();
    final qtd = 'evt '.allMatches(today).length;
    expect(qtd, greaterThanOrEqualTo(2500),
        reason: 'rotação por data não pode cortar linhas de hoje');

    final full = await PersistentLogger.readRecent(lines: 1000000);
    expect(full.contains('antiga'), isFalse,
        reason: 'a rotação tem que ter descartado o dia velho');
  });
}
