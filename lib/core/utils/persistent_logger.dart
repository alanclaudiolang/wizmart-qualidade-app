// lib/core/utils/persistent_logger.dart
//
// Logger persistente em arquivo. Sobrevive a:
//   - chamadas `_logger.clear()` do sync (que apagava o histórico
//     em memória do SyncLoggerNotifier);
//   - app sendo fechado/reaberto;
//   - crash do app.
//
// Mantém só as últimas ~2000 linhas (~200KB). É lido pelo
// PhotoErrorReporter pra anexar no issue do GitHub quando algo falha
// no fluxo de fotos.

import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class PersistentLogger {
  static const int _maxLines = 2000;
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

  static Future<void> _appendImpl(String tag, String msg,
      {bool erro = false}) async {
    try {
      final f = await _file();
      final ts = DateTime.now().toIso8601String();
      final flag = erro ? ' ERRO' : '';
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

  static Future<void> _rotateIfNeeded(File f) async {
    try {
      final content = await f.readAsString();
      final lines = content.split('\n');
      if (lines.length > _maxLines) {
        final novo = lines.sublist(lines.length - _maxLines).join('\n');
        await f.writeAsString(novo);
      }
    } catch (_) {}
  }

  /// Lê as últimas N linhas — usado pelo reporter no payload do issue.
  static Future<String> readRecent({int lines = 500}) async {
    try {
      final f = await _file();
      if (!await f.exists()) return '(sem log persistido)';
      final content = await f.readAsString();
      final split = content.split('\n');
      final start = split.length > lines ? split.length - lines : 0;
      return split.sublist(start).join('\n');
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
