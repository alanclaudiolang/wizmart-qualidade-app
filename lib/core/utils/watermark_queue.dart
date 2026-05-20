// lib/core/utils/watermark_queue.dart
//
// Serviço singleton que aplica watermark + salva na galeria em
// background, sem bloquear o promotor. O fluxo de UI continua livre
// imediatamente depois de "Concluir fotos antes/depois".
//
// Etapas para cada foto pendente:
//   1. Aplica watermark via WatermarkUtil (Canvas nativo).
//   2. Atualiza PendingPhoto.localPath pro arquivo com watermark.
//   3. Muda status de 'watermark_pending' pra 'pending' (libera sync).
//   4. Salva o arquivo final na galeria do celular.
//   5. Apaga o arquivo cru original.
//
// Ao terminar uma fila, dispara fullSync — assim as fotos prontas
// sobem assim que o watermark fica pronto, sem precisar do promotor
// fazer nada.
//
// Status na tabela pending_photos:
//   - 'watermark_pending' → tirada, esperando watermark (sync NÃO pega).
//   - 'pending'           → pronta pra subir.
//   - 'uploading'         → em upload.
//   - 'uploaded'          → no servidor.
//   - 'error'             → falhou, vai retentar.

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';

import '../database/app_database.dart';
import '../network/sync_engine.dart';
import 'error_reporter.dart';
import 'performance_profile.dart';
import 'persistent_logger.dart';
import 'processing_tracker.dart';
import 'session_service.dart';
import 'watermark_util.dart';

class _QueueItem {
  final int visitaId;
  final String slot;
  final String pdvNome;
  final String promotorNome;
  _QueueItem({
    required this.visitaId,
    required this.slot,
    required this.pdvNome,
    required this.promotorNome,
  });
}

class WatermarkQueueService {
  final Ref _ref;
  bool _running = false;
  final List<_QueueItem> _pending = [];

  WatermarkQueueService(this._ref);

  /// Adiciona um lote (visita+slot) na fila. Roda assíncrono; retorna
  /// imediatamente — o trabalho real acontece em background.
  void enqueue({
    required int visitaId,
    required String slot,
    required String pdvNome,
    required String promotorNome,
  }) {
    _pending.add(_QueueItem(
      visitaId: visitaId,
      slot: slot,
      pdvNome: pdvNome,
      promotorNome: promotorNome,
    ));
    // Dispara sem await — o caller não espera.
    // ignore: discarded_futures
    _processNext();
  }

  Future<void> _processNext() async {
    if (_running) return;
    _running = true;
    try {
      while (_pending.isNotEmpty) {
        final item = _pending.removeAt(0);
        try {
          await _processarItem(item);
        } catch (e, stack) {
          // Erro num item não trava a fila — mas reporta pra debug.
          // ignore: discarded_futures
          ErrorReporter.reportar(
            contexto:
                'WatermarkQueue.processarItem visitaId=${item.visitaId} slot=${item.slot}',
            erro: e,
            stack: stack,
          );
        }
        // Pequeno respiro pra o UI thread renderizar entre fotos.
        await Future<void>.delayed(Duration.zero);
      }
    } finally {
      _running = false;
    }
    // Tudo processado: dispara sync pra subir as fotos prontas.
    await _dispararSync();
  }

  Future<void> _processarItem(_QueueItem item) async {
    ProcessingTracker.begin(item.visitaId);
    try {
      await _processarItemInner(item);
    } finally {
      ProcessingTracker.end(item.visitaId);
    }
  }

  Future<void> _processarItemInner(_QueueItem item) async {
    final db = _ref.read(appDatabaseProvider);
    final pendentes =
        await db.getPendingPhotosByVisitaSlot(item.visitaId, item.slot);
    await PersistentLogger.append('watermark',
        'Iniciando visitaId=${item.visitaId} slot=${item.slot} '
        'fotos=${pendentes.length}');
    if (pendentes.isEmpty) return;

    final novosCaminhos = <String>[];

    for (final p in pendentes) {
      // Pausa pra UI thread terminar transições/renderizar frames
      // antes do trabalho pesado. Sem isso, fotos em sequência
      // bloqueiam o UI thread ininterruptamente (Canvas + toByteData
      // são síncronos do ponto de vista do main isolate).
      await Future<void>.delayed(const Duration(milliseconds: 80));

      // Foto já com watermark (cenário: voltou do checklist e re-concluiu).
      final isRaw = p.localPath.contains('_raw.');
      if (!isRaw) {
        novosCaminhos.add(p.localPath);
        if (p.status == 'watermark_pending') {
          await db.updatePendingPhoto(PendingPhotosCompanion(
            id: drift.Value(p.id),
            status: const drift.Value('pending'),
          ));
        }
        continue;
      }

      try {
        final capturedAt =
            DateTime.tryParse(p.createdAt) ?? DateTime.now();
        // Tier atual (default mid se ainda não detectou).
        final profile = _ref
                .read(performanceProfileProvider)
                .asData
                ?.value ??
            PerformanceProfile.padraoCarregando;
        final wmPath = await WatermarkUtil.applyWatermark(
          sourcePath: p.localPath,
          pdvNome: item.pdvNome,
          promotorNome: item.promotorNome,
          slot: item.slot == 'antes' ? 'Antes' : 'Depois',
          capturedAt: capturedAt,
          numero: p.numero,
          finalJpegQuality: profile.watermarkQuality,
          imgQuality: profile.imageQuality,
          maxSide: profile.imageMaxSide,
          tierLabel: profile.tierLabel,
        ).timeout(const Duration(seconds: 30));

        // Foto pronta — substitui path e libera pra sync.
        await db.updatePendingPhoto(PendingPhotosCompanion(
          id: drift.Value(p.id),
          localPath: drift.Value(wmPath),
          status: const drift.Value('pending'),
        ));

        // Atualiza fotosXxxJson AGORA, antes de apagar o raw. Mantém o
        // DB consistente com o sistema de arquivos — se a UI rebuildar
        // (promotor volta do checklist), encontra wm_path no JSON e o
        // arquivo wm ainda existe. Sem isso, havia uma janela em que o
        // JSON ainda tinha raw_path mas o raw já estava deletado, e a
        // grid quebrava com PathNotFoundException.
        if (wmPath != p.localPath) {
          await _trocarPathNoJson(
            visitaId: item.visitaId,
            slot: item.slot,
            de: p.localPath,
            para: wmPath,
          );
        }

        // Galeria — falha silenciosa (não crítico).
        try {
          await Gal.putImage(wmPath).timeout(const Duration(seconds: 5));
        } catch (_) {}

        // Apaga o arquivo cru original — JSON já não aponta mais pra ele.
        if (wmPath != p.localPath) {
          try {
            await File(p.localPath).delete();
          } catch (_) {}
        }

        novosCaminhos.add(wmPath);
      } catch (_) {
        // Watermark falhou — libera mesmo assim com o caminho cru pra
        // que o sync suba pelo menos a foto original.
        await db.updatePendingPhoto(PendingPhotosCompanion(
          id: drift.Value(p.id),
          status: const drift.Value('pending'),
        ));
        novosCaminhos.add(p.localPath);
      }
    }

    // Atualiza o JSON da visita com os novos paths.
    if (item.slot == 'antes') {
      await db.updateVisita(VisitasCompanion(
        id: drift.Value(item.visitaId),
        fotosAntesJson: drift.Value(jsonEncode(novosCaminhos)),
      ));
    } else {
      await db.updateVisita(VisitasCompanion(
        id: drift.Value(item.visitaId),
        fotosDepoisJson: drift.Value(jsonEncode(novosCaminhos)),
      ));
    }
  }

  /// Lê o JSON atual de fotosXxxJson, substitui [de] por [para] e grava
  /// de volta. Mantém ordem original (importante — é o que o promotor vê
  /// na grid). Se [de] não estiver na lista, não faz nada.
  Future<void> _trocarPathNoJson({
    required int visitaId,
    required String slot,
    required String de,
    required String para,
  }) async {
    final db = _ref.read(appDatabaseProvider);
    final visita = await db.getVisitaById(visitaId);
    if (visita == null) return;
    final atualJson =
        slot == 'antes' ? visita.fotosAntesJson : visita.fotosDepoisJson;
    if (atualJson == null || atualJson.isEmpty) return;
    final lista = List<String>.from(jsonDecode(atualJson));
    var alterou = false;
    for (var i = 0; i < lista.length; i++) {
      if (lista[i] == de) {
        lista[i] = para;
        alterou = true;
      }
    }
    if (!alterou) return;
    final novoJson = jsonEncode(lista);
    if (slot == 'antes') {
      await db.updateVisita(VisitasCompanion(
        id: drift.Value(visitaId),
        fotosAntesJson: drift.Value(novoJson),
      ));
    } else {
      await db.updateVisita(VisitasCompanion(
        id: drift.Value(visitaId),
        fotosDepoisJson: drift.Value(novoJson),
      ));
    }
  }

  Future<void> _dispararSync() async {
    try {
      final engine = _ref.read(syncEngineProvider);
      final session = await SessionService.getSession();
      if (session != null) {
        await engine.fullSync(session.userId);
      } else {
        await engine.processOutbox();
      }
    } catch (_) {}
  }
}

final watermarkQueueProvider = Provider<WatermarkQueueService>((ref) {
  return WatermarkQueueService(ref);
});
