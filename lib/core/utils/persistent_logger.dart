// lib/core/utils/persistent_logger.dart
//
// Logger persistente em arquivo. Sobrevive a:
//   - chamadas `_logger.clear()` do sync (que apagava o histórico
//     em memória do SyncLoggerNotifier);
//   - app sendo fechado/reaberto;
//   - crash do app.
//
// Rotação por DATA (não por contagem): mantém TODO o log de hoje e de
// ontem, descartando dias anteriores. O relato do promotor precisa do dia
// inteiro (login → 1º pull → falha), então cortar por "últimas N linhas"
// arrancava justamente o começo do dia (regra do Alan, 16/06: "tem que ser
// 100% do log de hoje"). Há ainda uma válvula de segurança por contagem
// (_maxLinesHardCap) contra crescimento patológico num único dia.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class PersistentLogger {
  // Válvula de segurança: mesmo mantendo o dia inteiro, nunca deixa o
  // arquivo crescer sem limite (um loop que escape do dedup). 100k linhas
  // (~10MB) é MUITO acima de um dia normal de 1 promotor — na prática nunca
  // dispara; só evita arquivo gigante num cenário patológico.
  static const int _maxLinesHardCap = 100000;
  static const String _filename = 'app.log';
  static File? _cachedFile;

  // Serializa writes pra evitar corrupção quando vários callers logam
  // ao mesmo tempo (compute isolates não escrevem aqui, mas vários
  // futures concorrentes no main isolate podem).
  static Future<void> _writeQueue = Future.value();

  static Future<File> _file() async {
    if (_cachedFile != null) return _cachedFile!;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/wizmart_logs');
    await dir.create(recursive: true);
    _cachedFile = File('${dir.path}/$_filename');
    return _cachedFile!;
  }

  static Future<void> append(String tag, String msg, {bool erro = false}) {
    final task = _appendImpl(tag, msg, erro: erro);
    _writeQueue = _writeQueue.then((_) => task);
    return _writeQueue;
  }

  // Dedup de linha repetida: um loop (ex. outbox em erro) escrevia
  // centenas de linhas idênticas e afogava as linhas úteis (o log só
  // guarda as últimas 2000). Agora linhas consecutivas IGUAIS viram 1
  // linha + um resumo "(repetiu Nx)" — mantém o log diagnóstico.
  static String? _lastKey;
  static int _dupCount = 0;
  static String? _dupFirstTs;

  static Future<void> _appendImpl(String tag, String msg,
      {bool erro = false}) async {
    try {
      final f = await _file();
      final ts = DateTime.now().toIso8601String();
      final flag = erro ? ' ERRO' : '';
      final key = '$tag|$erro|$msg';
      if (key == _lastKey) {
        _dupCount++;
        _dupFirstTs ??= ts;
        // Em loops MUITO longos, marca progresso a cada 200 — sem isso, se
        // nenhuma outra linha vier, o resumo nunca seria escrito.
        if (_dupCount % 200 == 0) {
          await f.writeAsString(
            '$ts [log] (repetiu ${_dupCount}x desde $_dupFirstTs) $msg\n',
            mode: FileMode.append,
            flush: false,
          );
        }
        return;
      }
      if (_dupCount > 0) {
        await f.writeAsString(
          '$ts [log] (linha anterior repetiu ${_dupCount}x desde $_dupFirstTs)\n',
          mode: FileMode.append,
          flush: false,
        );
      }
      _lastKey = key;
      _dupCount = 0;
      _dupFirstTs = null;
      await f.writeAsString(
        '$ts [$tag]$flag $msg\n',
        mode: FileMode.append,
        flush: false,
      );
      // Rotation barata: a cada N escritas, trunca se passou do limite.
      // Custo: leitura do arquivo todo. Aceitável em < 200KB.
      _writesSinceRotation++;
      if (_writesSinceRotation >= 50) {
        _writesSinceRotation = 0;
        await _rotateIfNeeded(f);
      }
    } catch (_) {/* logger não pode causar crash */}
  }

  static int _writesSinceRotation = 0;

  /// Lê o arquivo de log tolerando bytes mal-formados em UTF-8.
  /// f.readAsString() padrão usa decode strict e quebra inteiro o read
  /// se aparecer 1 byte inválido (texto colado de fonte estranha,
  /// caractere truncado por flush no meio, etc) — issue #8 mostrou o
  /// log vindo vazio no body.
  static Future<String> _readLenient(File f) async {
    final bytes = await f.readAsBytes();
    return utf8.decode(bytes, allowMalformed: true);
  }

  static String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static Future<void> _rotateIfNeeded(File f) async {
    try {
      final content = await _readLenient(f);
      final lines = content.split('\n');
      final agora = DateTime.now();
      final hoje = _ymd(agora);
      final ontem = _ymd(agora.subtract(const Duration(days: 1)));

      // Acha a 1ª linha de ontem/hoje (toda linha real começa com a data
      // ISO, ex. "2026-06-16T..."). Descarta tudo antes dela = dias velhos.
      // Linhas de continuação (stack trace) não começam com data, mas ficam
      // DEPOIS da linha-data do seu evento, então são preservadas junto.
      int corte = -1;
      for (var i = 0; i < lines.length; i++) {
        final l = lines[i];
        if (l.startsWith(hoje) || l.startsWith(ontem)) {
          corte = i;
          break;
        }
      }
      var novo = lines;
      if (corte > 0) novo = lines.sublist(corte);

      // Válvula de segurança contra crescimento patológico num único dia.
      if (novo.length > _maxLinesHardCap) {
        novo = novo.sublist(novo.length - _maxLinesHardCap);
      }

      if (novo.length != lines.length) {
        await f.writeAsString(novo.join('\n'));
      }
    } catch (_) {}
  }

  /// Lê as últimas N linhas — usado pelo reporter no payload do issue.
  static Future<String> readRecent({int lines = 500}) async {
    try {
      final f = await _file();
      if (!await f.exists()) return '(sem log persistido)';
      final content = await _readLenient(f);
      final split = content.split('\n');
      final start = split.length > lines ? split.length - lines : 0;
      return split.sublist(start).join('\n');
    } catch (e) {
      return '(erro ao ler log: $e)';
    }
  }

  /// Lê TODO o log de HOJE (a partir da 1ª linha com a data de hoje até o
  /// fim). Melhor que "últimas N linhas" pra relato: garante o dia inteiro
  /// (login, 1º pull, etc.) sem cortar pela contagem arbitrária. O mesmo
  /// texto vai pro arquivo compartilhado E pro issue do GitHub.
  static Future<String> readToday() async {
    try {
      final f = await _file();
      if (!await f.exists()) return '(sem log persistido)';
      final content = await _readLenient(f);
      final hoje = _ymd(DateTime.now());
      if (content.startsWith(hoje)) return content;
      final idx = content.indexOf('\n$hoje');
      if (idx < 0) return '(sem linhas de hoje no log)';
      return content.substring(idx + 1);
    } catch (e) {
      return '(erro ao ler log: $e)';
    }
  }

  static Future<void> clear() async {
    try {
      final f = await _file();
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
