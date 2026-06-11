// lib/core/utils/anomalia_reporter.dart
//
// Detecta + enfileira anomalias REAIS (não rede transitória) pra envio
// posterior ao GitHub. Trabalha em duas filas locais:
//   - pending_issues: corpo do issue já montado, espera rede pra POST
//   - pending_bug_photos: fotos físicas a subir pro bucket bug-reports
//
// Cooldown 10 min por (tipo + entidadeId) — evita ruído de detecção
// repetida da mesma anomalia. Cooldown vive em SharedPreferences, então
// sobrevive a restart do app.
//
// Coloca tudo na fila e retorna rápido — não espera POST. O envio é
// responsabilidade do AnomaliaQueueProcessor (que roda no ciclo de sync).
// Se o app está offline, fica na fila esperando rede.
//
// NÃO chamar de hot path crítico (UI thread). É async + acessa DB.

import 'dart:convert';
import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:disk_space_plus/disk_space_plus.dart';
import 'package:drift/drift.dart' as drift;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:system_info_plus/system_info_plus.dart';
import 'package:uuid/uuid.dart';

import '../constants/app_constants.dart';
import '../database/app_database.dart';
import 'current_screen.dart';
import 'persistent_logger.dart';
import 'session_service.dart';

class AnomaliaReporter {
  AnomaliaReporter._();

  static const _cooldownMinutos = 10;

  /// Enfileira uma anomalia. Aplica cooldown — se mesma (tipo,
  /// entidadeId) foi reportada nos últimos 10 min, ignora.
  /// NUNCA lança. Retorna `true` se enfileirou, `false` se ignorado.
  static Future<bool> enfileirar({
    required AppDatabase db,
    required String tipo,
    String? entidadeId,
    required String resumo,
    Map<String, dynamic>? contextoExtra,
    Object? erro,
    StackTrace? stack,
  }) async {
    try {
      final key = _cooldownKey(tipo, entidadeId);
      final agora = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      final ultimoIso = prefs.getString(key);
      if (ultimoIso != null) {
        final ultimo = DateTime.tryParse(ultimoIso);
        if (ultimo != null &&
            agora.difference(ultimo) <
                const Duration(minutes: _cooldownMinutos)) {
          return false;
        }
      }
      await prefs.setString(key, agora.toIso8601String());

      // Monta body + grava na fila. Faz fora do cooldown pra não bloquear
      // se algo der ruim aqui.
      final titulo = '[ANOMALIA][$tipo] $resumo';
      final body = await _montarBodyMarkdown(
        db: db,
        tipo: tipo,
        entidadeId: entidadeId,
        resumo: resumo,
        contextoExtra: contextoExtra,
        erro: erro,
        stack: stack,
      );
      final labels = <String>[
        'auto',
        'anomalia',
        'tipo:$tipo',
        'build:${AppConstants.buildNumber}',
        'screen:${CurrentScreen.nome}',
      ];

      await db.into(db.pendingIssues).insert(PendingIssuesCompanion(
            id: drift.Value(const Uuid().v4()),
            tipo: drift.Value(tipo),
            entidadeId: drift.Value(entidadeId),
            titulo: drift.Value(titulo),
            bodyMd: drift.Value(body),
            labelsJson: drift.Value(jsonEncode(labels)),
            nextRetryAt: drift.Value(agora.toIso8601String()),
            createdAt: drift.Value(agora.toIso8601String()),
          ));
      await PersistentLogger.append('anomalia',
          'Enfileirado $tipo entidade=$entidadeId resumo="$resumo"');
      return true;
    } catch (e) {
      // Engole — se falhou enfileirar, vamos perder esse report mas o
      // app não pode quebrar por causa de telemetria.
      try {
        await PersistentLogger.append(
            'anomalia', 'Falha ao enfileirar $tipo: $e', erro: true);
      } catch (_) {}
      return false;
    }
  }

  /// Enfileira upload de uma foto física pro bucket bug-reports. Usado
  /// junto com [enfileirar] quando a anomalia precisa anexar a foto pra
  /// recovery posterior (D1, D2). NUNCA lança.
  static Future<void> enfileirarBugPhoto({
    required AppDatabase db,
    required String fotoId,
    required String localPath,
    required int promotorId,
    required int visitaId,
  }) async {
    try {
      // Só enfileira se arquivo existe localmente.
      if (!await File(localPath).exists()) return;
      final destPath =
          'bug-reports/$promotorId/$visitaId/$fotoId.jpg';
      // Idempotente: se já tem entrada pra mesma foto+dest, não duplica.
      final existente = await (db.select(db.pendingBugPhotos)
            ..where((p) =>
                p.fotoId.equals(fotoId) &
                p.destStoragePath.equals(destPath)))
          .getSingleOrNull();
      if (existente != null) return;
      final agora = DateTime.now();
      await db.into(db.pendingBugPhotos).insert(PendingBugPhotosCompanion(
            id: drift.Value(const Uuid().v4()),
            fotoId: drift.Value(fotoId),
            localPath: drift.Value(localPath),
            destStoragePath: drift.Value(destPath),
            nextRetryAt: drift.Value(agora.toIso8601String()),
            createdAt: drift.Value(agora.toIso8601String()),
          ));
    } catch (_) {
      // Silencioso.
    }
  }

  static String _cooldownKey(String tipo, String? entidadeId) =>
      'anomalia_cooldown_${tipo}_${entidadeId ?? "_"}';

  /// Monta o body markdown do issue, com dump SQLite filtrado por
  /// `entidadeId` quando ela é um visitaId (numérico). Pra entidades de
  /// foto (uuid) cai no dump da visita-pai se conhecida via contextoExtra.
  static Future<String> _montarBodyMarkdown({
    required AppDatabase db,
    required String tipo,
    String? entidadeId,
    required String resumo,
    Map<String, dynamic>? contextoExtra,
    Object? erro,
    StackTrace? stack,
  }) async {
    final ctx = await _coletarContexto();
    final visitaId = _extrairVisitaId(entidadeId, contextoExtra);

    final buf = StringBuffer();
    buf.writeln('## Resumo');
    buf.writeln('- **Tipo:** `$tipo`');
    buf.writeln('- **Entidade:** `${entidadeId ?? "-"}`');
    if (visitaId != null) buf.writeln('- **VisitaId:** `$visitaId`');
    buf.writeln('- **Mensagem:** $resumo');
    buf.writeln('- **Detectado em:** ${DateTime.now().toIso8601String()}');
    buf.writeln();

    if (erro != null) {
      buf.writeln('## Exceção');
      buf.writeln('```');
      buf.writeln(erro.toString());
      if (stack != null) {
        final s = stack.toString();
        buf.writeln(s.length > 2000 ? '${s.substring(0, 2000)}…' : s);
      }
      buf.writeln('```');
      buf.writeln();
    }

    buf.writeln('## Promotor');
    final p = ctx['promotor'] as Map?;
    if (p != null) {
      buf.writeln('- id: ${p['id']}');
      buf.writeln('- email: ${p['email']}');
      buf.writeln('- nome: ${p['nome']}');
    }
    buf.writeln();

    buf.writeln('## Device');
    final d = ctx['device'] as Map?;
    if (d != null) {
      d.forEach((k, v) => buf.writeln('- $k: $v'));
    }
    buf.writeln('- ramTotalMb: ${ctx['ramTotalMb']}');
    buf.writeln('- storageLivreMb: ${ctx['storageLivreMb']}');
    buf.writeln('- bateriaPct: ${ctx['bateriaPct']}');
    buf.writeln('- bateriaEstado: ${ctx['bateriaEstado']}');
    buf.writeln();

    buf.writeln('## App');
    final a = ctx['app'] as Map?;
    if (a != null) {
      a.forEach((k, v) => buf.writeln('- $k: $v'));
    }
    buf.writeln();

    if (contextoExtra != null && contextoExtra.isNotEmpty) {
      buf.writeln('## Contexto extra');
      buf.writeln('```json');
      buf.writeln(_jsonPretty(contextoExtra));
      buf.writeln('```');
      buf.writeln();
    }

    // Dump SQLite focado na visita (se conhecida) — limita pra não
    // estourar o body limit (60k chars). Queries pequenas.
    if (visitaId != null) {
      await _dumpVisitaContexto(db, visitaId, buf);
    } else {
      await _dumpEstadoGeral(db, buf);
    }

    // Log persistente — últimas 500 linhas (vem como String).
    try {
      final log = await PersistentLogger.readRecent(lines: 500);
      buf.writeln('## Log persistente (últimas 500 linhas)');
      buf.writeln('```');
      buf.writeln(log);
      buf.writeln('```');
    } catch (_) {}

    return buf.toString();
  }

  static int? _extrairVisitaId(
      String? entidadeId, Map<String, dynamic>? contextoExtra) {
    if (entidadeId != null) {
      final n = int.tryParse(entidadeId);
      if (n != null) return n;
    }
    if (contextoExtra != null) {
      final v = contextoExtra['visitaId'];
      if (v is int) return v;
      if (v is String) return int.tryParse(v);
    }
    return null;
  }

  /// Dump compacto das tabelas SQLite relativas a uma visita.
  static Future<void> _dumpVisitaContexto(
      AppDatabase db, int visitaId, StringBuffer buf) async {
    try {
      final v = await db.getVisitaById(visitaId);
      buf.writeln('## Visita (id=$visitaId)');
      if (v == null) {
        buf.writeln('- _NÃO encontrada no SQLite local — possível órfã._');
      } else {
        buf.writeln('```');
        buf.writeln('id=${v.id} serverId=${v.serverId}');
        buf.writeln('statusVisita=${v.statusVisita} syncStatus=${v.syncStatus}');
        buf.writeln('localState=${v.localState}');
        buf.writeln('titulo=${v.titulo}');
        buf.writeln('dia_hora_agendado=${v.diaHoraAgendado}');
        buf.writeln('id_pdv_associado=${v.idPdvAssociado}');
        buf.writeln('id_gabarito_associado=${v.idGabaritoAssociado}');
        buf.writeln('id_promotor_associado=${v.idPromotorAssociado}');
        buf.writeln('turno=${v.previsaoTurnoRealizada}');
        buf.writeln('dia_hora_abertura=${v.diaHoraAbertura}');
        buf.writeln('dia_hora_realizado=${v.diaHoraRealizado}');
        buf.writeln('fotosAntesJson_len=${v.fotosAntesJson?.length ?? 0}');
        buf.writeln('fotosDepoisJson_len=${v.fotosDepoisJson?.length ?? 0}');
        buf.writeln('syncedAt=${v.syncedAt}');
        buf.writeln('```');
      }
      buf.writeln();
    } catch (_) {}

    try {
      final fotos = await (db.select(db.pendingPhotos)
            ..where((p) => p.visitaId.equals(visitaId)))
          .get();
      buf.writeln('## pending_photos da visita ($visitaId): ${fotos.length} rows');
      if (fotos.isNotEmpty) {
        buf.writeln('```');
        for (final f in fotos) {
          buf.writeln(
              'id=${f.id} slot=${f.slot} n=${f.numero} status=${f.status} '
              'attempts=${f.attempts} nextRetry=${f.nextRetryAt}');
          if (f.storageUrl != null) buf.writeln('  url=${f.storageUrl}');
          buf.writeln('  localPath=${f.localPath}');
        }
        buf.writeln('```');
      }
      buf.writeln();
    } catch (_) {}

    try {
      final outbox = await (db.select(db.outboxItems)
            ..where((o) =>
                o.entityType.equals('visita') & o.entityId.equals(visitaId)))
          .get();
      buf.writeln(
          '## outbox_items da visita ($visitaId): ${outbox.length} rows');
      if (outbox.isNotEmpty) {
        buf.writeln('```');
        for (final o in outbox) {
          buf.writeln(
              'id=${o.id} op=${o.operation} status=${o.status} '
              'attempts=${o.attempts} nextRetry=${o.nextRetryAt}');
          if (o.lastError != null) {
            final le = o.lastError!;
            buf.writeln(
                '  lastError=${le.length > 300 ? "${le.substring(0, 300)}…" : le}');
          }
        }
        buf.writeln('```');
      }
      buf.writeln();
    } catch (_) {}
  }

  /// Dump compacto do estado geral quando não há visita específica.
  static Future<void> _dumpEstadoGeral(
      AppDatabase db, StringBuffer buf) async {
    try {
      final visitas = await db.select(db.visitas).get();
      final pending = visitas.where((v) => v.syncStatus == 'pending').length;
      buf.writeln('## Resumo geral');
      buf.writeln(
          '- visitas total: ${visitas.length} (pending: $pending)');
      final fotos = await db.select(db.pendingPhotos).get();
      buf.writeln('- pending_photos: ${fotos.length}');
      final outbox = await db.select(db.outboxItems).get();
      buf.writeln('- outbox_items: ${outbox.length}');
      buf.writeln();
    } catch (_) {}
  }

  static String _jsonPretty(Object o) {
    try {
      return const JsonEncoder.withIndent('  ').convert(o);
    } catch (_) {
      return o.toString();
    }
  }

  /// Igual `ErrorReporter._coletarContexto` mas standalone — copiado pra
  /// evitar acoplamento + porque essa func aqui é chamada do reporter
  /// silencioso, não do path do crash global.
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
          'modelo': info.utsname.machine,
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
        'buildNumberReal': AppConstants.buildNumber,
        'buildTime': AppConstants.buildTime,
        'appVersionDefine': AppConstants.appVersion,
      };
    } catch (_) {}
    return out;
  }
}
