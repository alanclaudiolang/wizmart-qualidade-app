// lib/core/utils/photo_error_reporter.dart
//
// Cria issue no GitHub automaticamente quando algo falha no fluxo
// de captura/processamento de foto. Anexa contexto suficiente pra
// debugar sem precisar pedir info pro promotor:
//   - Promotor (id, email, nome)
//   - Device (marca, modelo, Android version, RAM total)
//   - Estado no momento (RAM, storage, bateria)
//   - Versão do app
//   - Log persistente das últimas ~500 linhas
//   - Stacktrace
//
// Dedup: mesmo erro em janela de 10 min não duplica issue.

import 'dart:convert';

import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:disk_space_plus/disk_space_plus.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:system_info_plus/system_info_plus.dart';

import '../constants/app_constants.dart';
import 'persistent_logger.dart';
import 'session_service.dart';

class PhotoErrorReporter {
  static const _repoOwner = 'alanclaudiolang';
  static const _repoName = 'wizmart-qualidade-app';

  static String? _lastHash;
  static DateTime? _lastAt;

  static Future<void> reportar({
    required String contexto,
    required Object erro,
    StackTrace? stack,
  }) async {
    // Log local sempre (mesmo se não conseguir mandar pra GitHub)
    await PersistentLogger.append('foto-erro',
        'CONTEXTO=$contexto ERRO=$erro${stack != null ? '\n$stack' : ''}',
        erro: true);

    // Dedup: mesmo "contexto+erro" em janela de 10 min vira no-op.
    final hash = '$contexto::${erro.toString()}'.hashCode.toRadixString(16);
    if (_lastHash == hash &&
        _lastAt != null &&
        DateTime.now().difference(_lastAt!) < const Duration(minutes: 10)) {
      return;
    }
    _lastHash = hash;
    _lastAt = DateTime.now();

    final token = AppConstants.githubBugReportToken;
    if (token.isEmpty) return;

    try {
      final ctx = await _coletarContexto();
      final logLines = await PersistentLogger.readRecent(lines: 500);

      final tituloErro = erro.toString();
      final titleResumo = tituloErro.length > 80
          ? '${tituloErro.substring(0, 80)}…'
          : tituloErro;

      final title = '[BUG-FOTO] $contexto — $titleResumo';
      final body = _montarBody(
        contexto: contexto,
        erro: erro,
        stack: stack,
        ctx: ctx,
        log: logLines,
      );

      await http
          .post(
            Uri.parse(
                'https://api.github.com/repos/$_repoOwner/$_repoName/issues'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/vnd.github+json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'title': title,
              'body': body,
              'labels': ['bug-foto', 'auto-reportado'],
            }),
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      await PersistentLogger.append(
          'foto-erro', 'Falha ao postar issue: $e',
          erro: true);
    }
  }

  static Future<Map<String, dynamic>> _coletarContexto() async {
    Map<String, dynamic> out = {};
    try {
      final session = await SessionService.getSession();
      out['promotor'] = {
        'id': session?.userId,
        'email': session?.email,
        'nome': session?.nome,
      };
    } catch (_) {}
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      out['device'] = {
        'marca': info.brand,
        'fabricante': info.manufacturer,
        'modelo': info.model,
        'androidVersion': info.version.release,
        'sdkInt': info.version.sdkInt,
      };
    } catch (_) {}
    try {
      out['ramTotalMb'] = await SystemInfoPlus.physicalMemory;
    } catch (_) {}
    try {
      out['storageLivreMb'] =
          (await DiskSpacePlus().getFreeDiskSpace)?.toStringAsFixed(0);
      out['storageTotalMb'] =
          (await DiskSpacePlus().getTotalDiskSpace)?.toStringAsFixed(0);
    } catch (_) {}
    try {
      out['bateriaPct'] = await Battery().batteryLevel;
      out['bateriaEstado'] = (await Battery().batteryState).name;
    } catch (_) {}
    try {
      final pkg = await PackageInfo.fromPlatform();
      out['app'] = {
        'versao': pkg.version,
        'build': pkg.buildNumber,
      };
    } catch (_) {}
    return out;
  }

  static String _montarBody({
    required String contexto,
    required Object erro,
    StackTrace? stack,
    required Map<String, dynamic> ctx,
    required String log,
  }) {
    final b = StringBuffer();
    b.writeln('## Erro');
    b.writeln('- **Contexto:** $contexto');
    b.writeln('- **Erro:** `$erro`');
    if (stack != null) {
      b.writeln('```\n$stack\n```');
    }
    b.writeln();
    b.writeln('## Promotor');
    final p = (ctx['promotor'] as Map?) ?? {};
    b.writeln('- id: ${p['id'] ?? '?'}');
    b.writeln('- email: ${p['email'] ?? '?'}');
    b.writeln('- nome: ${p['nome'] ?? '?'}');
    b.writeln();
    b.writeln('## Device');
    final d = (ctx['device'] as Map?) ?? {};
    b.writeln('- marca: ${d['marca'] ?? '?'}');
    b.writeln('- fabricante: ${d['fabricante'] ?? '?'}');
    b.writeln('- modelo: ${d['modelo'] ?? '?'}');
    b.writeln(
        '- Android: ${d['androidVersion'] ?? '?'} (SDK ${d['sdkInt'] ?? '?'})');
    b.writeln('- RAM total: ${ctx['ramTotalMb'] ?? '?'} MB');
    b.writeln();
    b.writeln('## Estado no momento');
    b.writeln(
        '- Storage livre: ${ctx['storageLivreMb'] ?? '?'} MB de ${ctx['storageTotalMb'] ?? '?'} MB');
    b.writeln(
        '- Bateria: ${ctx['bateriaPct'] ?? '?'}% (${ctx['bateriaEstado'] ?? '?'})');
    b.writeln();
    b.writeln('## App');
    final a = (ctx['app'] as Map?) ?? {};
    b.writeln('- versão: ${a['versao'] ?? '?'}+${a['build'] ?? '?'}');
    b.writeln();
    b.writeln('## Log (últimas 500 linhas)');
    b.writeln('```');
    b.writeln(log);
    b.writeln('```');
    b.writeln();
    b.writeln('_Issue criado automaticamente pelo app._');
    return b.toString();
  }
}
