// lib/core/utils/error_reporter.dart
//
// Cria issue no GitHub automaticamente quando algo dá erro em
// QUALQUER tela do app. Sucessor do PhotoErrorReporter (que
// cobria só o fluxo de foto).
//
// Estratégia:
//   - A tela atual é detectada via CurrentScreen (alimentado por
//     um NavigatorObserver no GoRouter).
//   - Cooldown de 5 min POR TELA: erros sucessivos na mesma
//     tela viram comentário no mesmo issue em vez de novo issue.
//     Telas diferentes podem reportar em paralelo.
//   - Labels: `bug`, `auto`, `screen:<nome>` — permite filtrar
//     no GitHub e priorizar correção por área.
//   - Anexa contexto completo: promotor, device, RAM, storage,
//     bateria, versão, últimas 500 linhas do log persistente.

import 'dart:convert';
import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:disk_space_plus/disk_space_plus.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:system_info_plus/system_info_plus.dart';

import '../constants/app_constants.dart';
import 'current_screen.dart';
import 'persistent_logger.dart';
import 'session_service.dart';

class ErrorReporter {
  static const _repoOwner = 'alanclaudiolang';
  static const _repoName = 'wizmart-qualidade-app';
  static const _cooldown = Duration(minutes: 5);

  /// GitHub Issues limita body a 65536 chars. Margem de ~5k pra cabeçalho
  /// do split, fallback de markdown e contagem de bytes vs chars em UTF-8.
  /// Acima disso, o body é dividido em partes — 1ª vira o issue, demais
  /// viram comments no mesmo issue.
  static const _maxBodyChars = 60000;

  /// Cooldown por screen — key: nome da tela.
  static final Map<String, DateTime> _ultimoReportePorScreen = {};

  /// Reporta um erro. `screen` é opcional — se não passado, lê o
  /// `CurrentScreen.nome` atual.
  /// Reporta erro automaticamente como issue no GitHub.
  /// Retorna o número do issue criado, ou null se falhou (sem rede,
  /// cooldown ativo, token vazio, etc). O caller pode usar esse retorno
  /// pra decidir UI — ex: tela de "Erro inesperado" só mostra o pedido
  /// de print quando o issue NÃO foi enviado.
  static Future<int?> reportar({
    required String contexto,
    required Object erro,
    StackTrace? stack,
    String? screen,
  }) async {
    final tela = screen ?? CurrentScreen.nome;

    // Log sempre (mesmo se reporter for skipado por cooldown).
    await PersistentLogger.append(
        'erro:$tela', 'CONTEXTO=$contexto ERRO=$erro',
        erro: true);
    if (stack != null) {
      await PersistentLogger.append('erro:$tela', '$stack', erro: true);
    }

    // Cooldown POR tela — janela de 5 min.
    final ultimo = _ultimoReportePorScreen[tela];
    if (ultimo != null &&
        DateTime.now().difference(ultimo) < _cooldown) {
      return null;
    }
    _ultimoReportePorScreen[tela] = DateTime.now();

    final token = AppConstants.githubBugReportToken;
    if (token.isEmpty) return null;

    try {
      final ctx = await _coletarContexto();
      final logLines = await PersistentLogger.readRecent(lines: 500);

      final tituloErro = erro.toString();
      final resumo = tituloErro.length > 70
          ? '${tituloErro.substring(0, 70)}…'
          : tituloErro;

      final title = '[BUG][$tela] $resumo';
      final body = _montarBody(
        contexto: contexto,
        erro: erro,
        stack: stack,
        tela: tela,
        ctx: ctx,
        log: logLines,
      );

      return await _postarIssueParticionado(
        token: token,
        title: title,
        body: body,
        labels: [
          'bug',
          'auto',
          'screen:$tela',
          'build:${AppConstants.buildNumber}',
        ],
        logTag: 'erro:$tela',
      );
    } catch (e) {
      await PersistentLogger.append(
          'erro:$tela', 'Falha ao postar issue: $e',
          erro: true);
      return null;
    }
  }

  /// Cria issue MANUAL a partir de descrição do usuário (item
  /// "Reportar problema" no menu). Diferente de [reportar]:
  ///   - Sem cooldown (cada envio é uma nova issue).
  ///   - Sem erro/stack — só a descrição livre do promotor.
  ///   - Label `user-report` em vez de `auto`.
  /// Retorna o número da issue criada (ou null em falha).
  static Future<int?> reportarUsuario({
    required String descricao,
  }) async {
    final tela = CurrentScreen.nome;
    await PersistentLogger.append(
      'user-report:$tela',
      'Promotor reportou: $descricao',
    );

    final token = AppConstants.githubBugReportToken;
    if (token.isEmpty) return null;

    try {
      final ctx = await _coletarContexto();
      final logLines = await PersistentLogger.readRecent(lines: 1000);

      final resumo = descricao.length > 60
          ? '${descricao.substring(0, 60).replaceAll('\n', ' ')}…'
          : descricao.replaceAll('\n', ' ');
      final title = '[USUÁRIO][$tela] $resumo';

      final b = StringBuffer();
      b.writeln('## Relato do promotor');
      b.writeln('> $descricao');
      b.writeln();
      b.writeln('- **Tela atual:** `$tela`');
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
      b.writeln('- **BUILD: ${a['buildNumberReal'] ?? '?'}** '
          '(compilado ${a['buildTime'] ?? '?'})');
      b.writeln('- versão define: ${a['appVersionDefine'] ?? '?'}');
      b.writeln('- pubspec: ${a['versao'] ?? '?'}+${a['build'] ?? '?'}');
      b.writeln();
      b.writeln('## Log (últimas 1000 linhas)');
      b.writeln('```');
      b.writeln(logLines);
      b.writeln('```');
      b.writeln();
      b.writeln('_Issue criado pelo promotor via menu Reportar problema._');

      return await _postarIssueParticionado(
        token: token,
        title: title,
        body: b.toString(),
        labels: [
          'bug',
          'user-report',
          'screen:$tela',
          'build:${AppConstants.buildNumber}',
        ],
        logTag: 'user-report:$tela',
      );
    } catch (e) {
      await PersistentLogger.append(
        'user-report:$tela',
        'Exceção ao postar: $e',
        erro: true,
      );
      return null;
    }
  }

  static Future<Map<String, dynamic>> _coletarContexto() async {
    final out = <String, dynamic>{};
    try {
      final session = await SessionService.getSession();
      out['promotor'] = {
        'id': session?.userId,
        'email': session?.email,
        'nome': session?.nome,
      };
    } catch (_) {}
    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        out['device'] = {
          'plataforma': 'iOS',
          'nome': info.name,
          'modelo': info.utsname.machine, // ex: iPhone14,2
          'modeloComercial': info.model,
          'iosVersion': info.systemVersion,
        };
      } else {
        final info = await plugin.androidInfo;
        out['device'] = {
          'plataforma': 'Android',
          'marca': info.brand,
          'fabricante': info.manufacturer,
          'modelo': info.model,
          'androidVersion': info.version.release,
          'sdkInt': info.version.sdkInt,
        };
      }
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
        // BUILD REAL do dart-define (injetado pelo CI). pkg.version/build
        // vêm do pubspec e são IGUAIS em todo build — inúteis pra saber
        // se o promotor já tem uma correção. buildNumber/buildTime aqui
        // identificam exatamente qual APK ele roda (ex: 163 / 27/05 13:30).
        'buildNumberReal': AppConstants.buildNumber,
        'buildTime': AppConstants.buildTime,
        'appVersionDefine': AppConstants.appVersion,
      };
    } catch (_) {
      out['app'] = {
        'buildNumberReal': AppConstants.buildNumber,
        'buildTime': AppConstants.buildTime,
        'appVersionDefine': AppConstants.appVersion,
      };
    }
    return out;
  }

  static String _montarBody({
    required String contexto,
    required Object erro,
    StackTrace? stack,
    required String tela,
    required Map<String, dynamic> ctx,
    required String log,
  }) {
    final b = StringBuffer();
    b.writeln('## Erro');
    b.writeln('- **Tela:** `$tela`');
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
    b.writeln('- **BUILD: ${a['buildNumberReal'] ?? '?'}** '
        '(compilado ${a['buildTime'] ?? '?'})');
    b.writeln('- versão define: ${a['appVersionDefine'] ?? '?'}');
    b.writeln('- pubspec: ${a['versao'] ?? '?'}+${a['build'] ?? '?'}');
    b.writeln();
    b.writeln('## Log (últimas 500 linhas)');
    b.writeln('```');
    b.writeln(log);
    b.writeln('```');
    b.writeln();
    b.writeln('_Issue criado automaticamente pelo app._');
    return b.toString();
  }

  /// Cria issue no GitHub. Se o body excede [_maxBodyChars] (limite ~65k
  /// do GitHub Issues), divide em partes — a 1ª vira o issue, as demais
  /// viram comments no mesmo issue (concatenação visual). Retorna o
  /// número do issue criado, ou null em falha do POST principal.
  static Future<int?> _postarIssueParticionado({
    required String token,
    required String title,
    required String body,
    required List<String> labels,
    required String logTag,
  }) async {
    final partes = _dividirBody(body, _maxBodyChars);
    final n = partes.length;

    final tituloIssue = n > 1 ? '$title [1/$n]' : title;
    final corpoIssue = n > 1
        ? '${partes[0]}\n\n_⚠️ Continua nos comentários (parte 1 de $n)._'
        : partes[0];

    final res = await http
        .post(
          Uri.parse(
              'https://api.github.com/repos/$_repoOwner/$_repoName/issues'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/vnd.github+json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'title': tituloIssue,
            'body': corpoIssue,
            'labels': labels,
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      await PersistentLogger.append(
        logTag,
        'POST issue falhou status=${res.statusCode} body=${res.body}',
        erro: true,
      );
      return null;
    }

    int? issueNumber;
    try {
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      issueNumber = j['number'] as int?;
    } catch (_) {/* segue null */}
    if (issueNumber == null || n == 1) return issueNumber;

    // Demais partes viram comentários. Falha em comment não invalida o
    // issue — só registra no log local. O promotor já consegue identificar
    // o issue pelo número retornado.
    for (var i = 1; i < n; i++) {
      try {
        final corpo = '## Parte ${i + 1} de $n\n\n${partes[i]}';
        final c = await http
            .post(
              Uri.parse(
                  'https://api.github.com/repos/$_repoOwner/$_repoName/issues/$issueNumber/comments'),
              headers: {
                'Authorization': 'Bearer $token',
                'Accept': 'application/vnd.github+json',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({'body': corpo}),
            )
            .timeout(const Duration(seconds: 15));
        if (c.statusCode < 200 || c.statusCode >= 300) {
          await PersistentLogger.append(
            logTag,
            'Comment parte ${i + 1}/$n falhou status=${c.statusCode}',
            erro: true,
          );
        }
      } catch (e) {
        await PersistentLogger.append(
          logTag,
          'Comment parte ${i + 1}/$n exceção: $e',
          erro: true,
        );
      }
    }
    return issueNumber;
  }

  /// Divide [body] em partes de no máximo [maxChars] caracteres,
  /// quebrando em `\n` quando possível (não corta linha pela metade).
  /// Se uma linha sozinha excede o limite (raro — payload JSON gigante),
  /// quebra por chars mesmo.
  static List<String> _dividirBody(String body, int maxChars) {
    if (body.length <= maxChars) return [body];
    final partes = <String>[];
    final buf = StringBuffer();
    for (final linha in body.split('\n')) {
      // +1 pelo \n que será adicionado depois desta linha.
      final tamanhoApos = buf.length + linha.length + 1;
      if (tamanhoApos > maxChars && buf.isNotEmpty) {
        partes.add(buf.toString());
        buf.clear();
      }
      // Linha sozinha maior que o limite: quebra forçada.
      if (linha.length + 1 > maxChars) {
        var resto = linha;
        while (resto.length > maxChars) {
          partes.add(resto.substring(0, maxChars));
          resto = resto.substring(maxChars);
        }
        if (resto.isNotEmpty) buf.writeln(resto);
      } else {
        buf.writeln(linha);
      }
    }
    if (buf.isNotEmpty) partes.add(buf.toString());
    return partes;
  }
}
