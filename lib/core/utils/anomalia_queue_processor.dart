// lib/core/utils/anomalia_queue_processor.dart
//
// Drena as filas locais de anomalia:
//   - pending_issues  → POST pro GitHub Issues
//   - pending_bug_photos → upload pra bucket `bug-reports` no Supabase
//
// Roda como uma tarefa do SyncEngine — sem timer próprio. Quando há
// rede, drena tudo. Sem rede, falha silenciosa com backoff exponencial
// igual ao outbox.
//
// Nada do que esse processor faz é crítico — qualquer falha vira retry
// futuro. O app não pode quebrar por causa de telemetria. Tudo em
// try/catch defensivo.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' as drift;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_constants.dart';
import '../database/app_database.dart';
import 'persistent_logger.dart';

class AnomaliaQueueProcessor {
  static const _repoOwner = 'alanclaudiolang';
  static const _repoName = 'wizmart-qualidade-app';
  static const _bucket = 'bug-reports';
  static const _maxBodyChars = 60000;

  final AppDatabase _db;
  final SupabaseClient _supabase;
  bool _draining = false;

  AnomaliaQueueProcessor(this._db, this._supabase);

  /// Drena as duas filas. Reentrant-safe (return early se já rodando).
  /// Nunca lança.
  Future<void> drenar() async {
    if (_draining) return;
    _draining = true;
    try {
      await _drenarBugPhotos();
      await _drenarIssues();
    } catch (e) {
      try {
        await PersistentLogger.append(
            'anomalia', 'Erro inesperado em drenar: $e',
            erro: true);
      } catch (_) {}
    } finally {
      _draining = false;
    }
  }

  // ── Bug photos ────────────────────────────────────────────────────────────

  Future<void> _drenarBugPhotos() async {
    final agora = DateTime.now();
    final pendentes = await (_db.select(_db.pendingBugPhotos)
          ..where((p) =>
              p.status.equals('pending') &
              p.nextRetryAt.isSmallerOrEqualValue(agora.toIso8601String())))
        .get();
    for (final p in pendentes) {
      try {
        final url = await _uploadBugPhoto(p);
        if (url != null) {
          await _db.update(_db.pendingBugPhotos).replace(p.copyWith(
                status: 'uploaded',
                publicUrl: drift.Value(url),
              ));
        } else {
          await _marcarRetryBugPhoto(p, 'upload retornou null');
        }
      } catch (e) {
        await _marcarRetryBugPhoto(p, e.toString());
      }
    }
  }

  Future<String?> _uploadBugPhoto(PendingBugPhoto p) async {
    final f = File(p.localPath);
    if (!await f.exists()) {
      // Arquivo sumiu — sem o que subir. Marca como error pra não tentar
      // de novo eternamente.
      await _db.update(_db.pendingBugPhotos).replace(p.copyWith(
            status: 'error',
            lastError: const drift.Value('arquivo local não existe'),
          ));
      return null;
    }
    final bytes = await f.readAsBytes();
    await _supabase.storage.from(_bucket).uploadBinary(
          p.destStoragePath,
          bytes,
          fileOptions:
              const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
    return _supabase.storage.from(_bucket).getPublicUrl(p.destStoragePath);
  }

  Future<void> _marcarRetryBugPhoto(PendingBugPhoto p, String erro) async {
    final attempts = p.attempts + 1;
    final delay = min(pow(2, attempts).toInt() * 30, 1800);
    final next =
        DateTime.now().add(Duration(seconds: delay)).toIso8601String();
    await _db.update(_db.pendingBugPhotos).replace(p.copyWith(
          attempts: attempts,
          nextRetryAt: next,
          lastError: drift.Value(erro.length > 500
              ? '${erro.substring(0, 500)}…'
              : erro),
        ));
  }

  // ── Issues ────────────────────────────────────────────────────────────────

  Future<void> _drenarIssues() async {
    final token = AppConstants.githubBugReportToken;
    if (token.isEmpty) return;
    final agora = DateTime.now();
    final pendentes = await (_db.select(_db.pendingIssues)
          ..where((p) =>
              p.status.equals('pending') &
              p.nextRetryAt.isSmallerOrEqualValue(agora.toIso8601String())))
        .get();
    for (final p in pendentes) {
      try {
        final issueNumber = await _postarIssue(token, p);
        if (issueNumber != null) {
          await _db.update(_db.pendingIssues).replace(p.copyWith(
                status: 'sent',
                githubIssueNumber: drift.Value(issueNumber),
              ));
        } else {
          await _marcarRetryIssue(p, 'POST retornou null');
        }
      } catch (e) {
        await _marcarRetryIssue(p, e.toString());
      }
    }
  }

  /// Pega URLs das fotos do bug-report já enviadas e injeta no final do
  /// body antes de POST. Assim o issue tem links públicos pras fotos
  /// físicas — eu baixo direto sem pedir nada ao promotor.
  Future<String> _injetarUrlsFotos(PendingIssue p) async {
    if (p.entidadeId == null) return p.bodyMd;
    final visitaId = int.tryParse(p.entidadeId!);
    if (visitaId == null) return p.bodyMd;
    final fotos = await (_db.select(_db.pendingPhotos)
          ..where((x) => x.visitaId.equals(visitaId)))
        .get();
    final urls = <String>[];
    for (final f in fotos) {
      final bug = await (_db.select(_db.pendingBugPhotos)
            ..where((b) =>
                b.fotoId.equals(f.id) & b.publicUrl.isNotNull()))
          .getSingleOrNull();
      if (bug?.publicUrl != null) {
        urls.add(
            '- ${f.slot}-${f.numero} (foto ${f.id.substring(0, 8)}): ${bug!.publicUrl}');
      }
    }
    if (urls.isEmpty) return p.bodyMd;
    return '${p.bodyMd}\n\n## Fotos no bug-report bucket\n${urls.join("\n")}\n';
  }

  Future<int?> _postarIssue(String token, PendingIssue p) async {
    final bodyComUrls = await _injetarUrlsFotos(p);
    final partes = _dividirBody(bodyComUrls, _maxBodyChars);
    final n = partes.length;
    final titulo = n > 1 ? '${p.titulo} [1/$n]' : p.titulo;
    final corpoPrimeiro = n > 1
        ? '${partes[0]}\n\n_⚠️ Continua nos comentários (parte 1 de $n)._'
        : partes[0];
    final labels = (jsonDecode(p.labelsJson) as List).cast<String>();

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
            'title': titulo,
            'body': corpoPrimeiro,
            'labels': labels,
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      await PersistentLogger.append(
        'anomalia',
        'POST issue falhou status=${res.statusCode} body=${res.body}',
        erro: true,
      );
      return null;
    }
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final issueNumber = j['number'] as int?;
    if (issueNumber == null || n == 1) return issueNumber;

    for (var i = 1; i < n; i++) {
      try {
        final corpo = '## Parte ${i + 1} de $n\n\n${partes[i]}';
        await http
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
      } catch (_) {/* comment falhar não invalida o issue */}
    }
    return issueNumber;
  }

  Future<void> _marcarRetryIssue(PendingIssue p, String erro) async {
    final attempts = p.attempts + 1;
    final delay = min(pow(2, attempts).toInt() * 30, 1800);
    final next =
        DateTime.now().add(Duration(seconds: delay)).toIso8601String();
    await _db.update(_db.pendingIssues).replace(p.copyWith(
          attempts: attempts,
          nextRetryAt: next,
          lastError: drift.Value(erro.length > 500
              ? '${erro.substring(0, 500)}…'
              : erro),
        ));
  }

  /// Divide o body markdown em pedaços de no máx [maxChars] chars,
  /// preservando linhas inteiras e blocos de código.
  static List<String> _dividirBody(String body, int maxChars) {
    if (body.length <= maxChars) return [body];
    final partes = <String>[];
    final linhas = body.split('\n');
    final buf = StringBuffer();
    var emCodeFence = false;
    for (final l in linhas) {
      if (l.startsWith('```')) emCodeFence = !emCodeFence;
      if (buf.length + l.length + 1 > maxChars && !emCodeFence) {
        partes.add(buf.toString());
        buf.clear();
      }
      buf.writeln(l);
    }
    if (buf.isNotEmpty) partes.add(buf.toString());
    return partes;
  }
}
