// lib/core/network/sync_engine.dart

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/app_database.dart';

class SyncEngine {
  final AppDatabase _db;
  final SupabaseClient _supabase;
  bool _running = false;

  SyncEngine(this._db, this._supabase);

  // ── PULL (Supabase → Local) ───────────────────────────────────────────────

  Future<void> pullAll(int promotorId) async {
    await _pullVisitas(promotorId);
    await _pullPdvs(promotorId);
    await _pullGabaritos(promotorId);
  }

  Future<void> _pullVisitas(int promotorId) async {
    try {
      final syncState = await _db.getSyncState('visitas');
      final hoje = DateTime.now();
      final inicioDia = DateTime(hoje.year, hoje.month, hoje.day)
          .toUtc()
          .toIso8601String();

      var query = _supabase
          .from('visitas')
          .select()
          .eq('id_promotor_associado', promotorId)
          .gte('dia_hora_agendado', inicioDia);

      final rows = await query;

      for (final row in rows) {
        final id = row['id'] as int;

        // Não sobrescreve visitas locais com estado pendente de sync
        final local = await _db.getVisitaById(id);
        if (local != null && local.syncStatus == 'pending') continue;

        await _db.upsertVisita(VisitasCompanion(
          id: Value(id),
          idPdvAssociado: Value(row['id_pdv_associado'] as int?),
          idPromotorAssociado: Value(row['id_promotor_associado'] as int?),
          diaHoraAgendado: Value(row['dia_hora_agendado'] as String?),
          diaHoraRealizado: Value(row['dia_hora_realizado'] as String?),
          diaHoraAbertura: Value(row['dia_hora_abertura'] as String?),
          statusVisita: Value(row['status_visita'] as int?),
          rotaAssociada: Value(row['rota_associada'] as int?),
          idGabaritoAssociado: Value(row['id_gabarito_associado'] as int?),
          localizacaoAbertura: Value(row['localizacao_abertura'] as String?),
          localizacaoEncerramento:
              Value(row['localizacao_encerramento'] as String?),
          diaHoraFotosAntes: Value(row['dia_hora_fotos_antes'] as String?),
          diaHoraFotosDepois: Value(row['dia_hora_fotos_depois'] as String?),
          localizacaoFotosAntes:
              Value(row['localizacao_fotos_antes'] as String?),
          localizacaoFotosDepois:
              Value(row['localizacao_fotos_depois'] as String?),
          fotosAntesJson:
              Value(jsonEncode(row['fotos_antes'] ?? [])),
          fotosDepoisJson:
              Value(jsonEncode(row['fotos_depois'] ?? [])),
          checkPergunta1: Value(row['check_pergunta_1'] as bool?),
          obsPergunta1: Value(row['obs_pergunta_1'] as String?),
          checkPergunta2: Value(row['check_pergunta_2'] as bool?),
          obsPergunta2: Value(row['obs_pergunta_2'] as String?),
          checkPergunta3: Value(row['check_pergunta_3'] as bool?),
          obsPergunta3: Value(row['obs_pergunta_3'] as String?),
          checkPergunta4: Value(row['check_pergunta_4'] as bool?),
          obsPergunta4: Value(row['obs_pergunta_4'] as String?),
          checkPergunta5: Value(row['check_pergunta_5'] as bool?),
          obsPergunta5: Value(row['obs_pergunta_5'] as String?),
          checkPergunta6: Value(row['check_pergunta_6'] as bool?),
          obsPergunta6: Value(row['obs_pergunta_6'] as String?),
          checkPergunta7: Value(row['check_pergunta_7'] as bool?),
          obsPergunta7: Value(row['obs_pergunta_7'] as String?),
          comentariosVisita:
              Value(row['comentarios_visita'] as String?),
          syncStatus: const Value('synced'),
          syncedAt: Value(DateTime.now().toIso8601String()),
        ));
      }

      await _db.upsertSyncState(SyncStateCompanion(
        entityType: const Value('visitas'),
        lastPullAt: Value(DateTime.now().toIso8601String()),
      ));
    } catch (e) {
      // Log silencioso — não quebra o app
    }
  }

  Future<void> _pullPdvs(int promotorId) async {
    try {
      final rows = await _supabase
          .from('pdv')
          .select(
              'id,api_localName,api_localCustomerName,endereco,api_specificLocation,"Lat","Lng",situacao')
          .or('id_promotor_associado.eq.$promotorId');

      for (final row in rows) {
        await _db
            .into(_db.pdvs)
            .insertOnConflictUpdate(PdvsCompanion(
              id: Value(row['id'] as int),
              apiLocalName: Value(row['api_localName'] as String?),
              apiLocalCustomerName:
                  Value(row['api_localCustomerName'] as String?),
              endereco: Value(row['endereco'] as String?),
              apiSpecificLocation:
                  Value(row['api_specificLocation'] as String?),
              lat: Value((row['Lat'] as num?)?.toDouble()),
              lng: Value((row['Lng'] as num?)?.toDouble()),
              situacao: Value(row['situacao'] as bool?),
              syncedAt: Value(DateTime.now().toIso8601String()),
            ));
      }
    } catch (e) {
      // silencioso
    }
  }

  Future<void> _pullGabaritos(int promotorId) async {
    try {
      final rows = await _supabase
          .from('gabarito')
          .select(
              'id,nome,pdv_associado,rota_associada,promotor_associado,ativo,padrao,prazo_validade')
          .eq('ativo', true);

      for (final row in rows) {
        await _db
            .into(_db.gabaritos)
            .insertOnConflictUpdate(GabaritosCompanion(
              id: Value(row['id'] as int),
              nome: Value(row['nome'] as String?),
              pdvAssociado: Value(row['pdv_associado'] as int),
              rotaAssociada: Value(row['rota_associada'] as int?),
              promotorAssociado: Value(row['promotor_associado'] as int?),
              ativo: Value(row['ativo'] as bool? ?? true),
              padrao: Value(row['padrao'] as bool? ?? false),
              prazoValidade: Value(row['prazo_validade'] as String?),
              syncedAt: Value(DateTime.now().toIso8601String()),
            ));
      }
    } catch (e) {
      // silencioso
    }
  }

  // ── PUSH (Local → Supabase) ───────────────────────────────────────────────

  Future<void> processOutbox() async {
    if (_running) return;
    _running = true;

    try {
      final items = await _db.getPendingOutboxItems();
      for (final item in items) {
        await _processOutboxItem(item);
      }

      // Processa fotos pendentes
      final photos = await _db.getPendingPhotos();
      for (final photo in photos) {
        await _processPhotoUpload(photo);
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _processOutboxItem(OutboxItem item) async {
    // Marca como processing
    await _db.updateOutboxItem(OutboxItemsCompanion(
      id: Value(item.id),
      status: const Value('processing'),
    ));

    try {
      final payload =
          jsonDecode(item.payloadJson) as Map<String, dynamic>;

      // Sempre UPDATE por id — visitas já existem no Supabase
      // Remove o campo 'id' do payload para não conflitar
      final updatePayload = Map<String, dynamic>.from(payload)
        ..remove('id');

      await _supabase
          .from('visitas')
          .update(updatePayload)
          .eq('id', item.entityId);

      // Sucesso: remove do outbox e marca visita como synced
      await _db.deleteOutboxItem(item.id);
      await _db.updateVisita(VisitasCompanion(
        id: Value(item.entityId),
        syncStatus: const Value('synced'),
        syncedAt: Value(DateTime.now().toIso8601String()),
      ));
    } catch (e) {
      // Falha: backoff exponencial
      final attempts = item.attempts + 1;
      final delaySeconds = min(pow(2, attempts).toInt() * 30, 1800);
      final nextRetry = DateTime.now()
          .add(Duration(seconds: delaySeconds))
          .toIso8601String();

      await _db.updateOutboxItem(OutboxItemsCompanion(
        id: Value(item.id),
        status: const Value('pending'),
        attempts: Value(attempts),
        nextRetryAt: Value(nextRetry),
        lastError: Value(e.toString()),
      ));
    }
  }

  Future<void> _processPhotoUpload(PendingPhoto photo) async {
    await _db.updatePendingPhoto(PendingPhotosCompanion(
      id: Value(photo.id),
      status: const Value('uploading'),
    ));

    try {
      final file = File(photo.localPath);
      if (!await file.exists()) {
        await _db.updatePendingPhoto(PendingPhotosCompanion(
          id: Value(photo.id),
          status: const Value('error'),
        ));
        return;
      }

      final bytes = await file.readAsBytes();
      final ext = photo.localPath.split('.').last;
      final storagePath =
          'visitas/${photo.visitaId}/${photo.slot}_${photo.numero}_${photo.id}.$ext';

      await _supabase.storage
          .from('Arquivos')
          .uploadBinary(storagePath, bytes,
              fileOptions: FileOptions(
                  contentType: 'image/jpeg', upsert: true));

      final url = _supabase.storage
          .from('Arquivos')
          .getPublicUrl(storagePath);

      // Atualiza foto no Supabase
      final visita = await _db.getVisitaById(photo.visitaId);
      if (visita != null) {
        final fotosKey = photo.slot == 'antes' ? 'fotos_antes' : 'fotos_depois';
        final fotosAtuais = (await _supabase
                .from('visitas')
                .select(fotosKey)
                .eq('id', photo.visitaId)
                .single())[fotosKey] as List? ??
            [];

        final novaLista = [...fotosAtuais, url];
        await _supabase
            .from('visitas')
            .update({fotosKey: novaLista}).eq('id', photo.visitaId);
      }

      await _db.updatePendingPhoto(PendingPhotosCompanion(
        id: Value(photo.id),
        status: const Value('uploaded'),
        storageUrl: Value(url),
      ));
    } catch (e) {
      final attempts = photo.attempts + 1;
      final delaySeconds = min(pow(2, attempts).toInt() * 30, 1800);
      final nextRetry = DateTime.now()
          .add(Duration(seconds: delaySeconds))
          .toIso8601String();

      await _db.updatePendingPhoto(PendingPhotosCompanion(
        id: Value(photo.id),
        status: const Value('pending'),
        attempts: Value(attempts),
        nextRetryAt: Value(nextRetry),
      ));
    }
  }
}

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return SyncEngine(db, Supabase.instance.client);
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
