// lib/core/network/sync_engine.dart

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/app_database.dart';
import '../constants/app_constants.dart';
import '../utils/sync_logger.dart';

class SyncEngine {
  final AppDatabase _db;
  final SupabaseClient _supabase;
  final SyncLoggerNotifier _logger;
  bool _running = false;

  SyncEngine(this._db, this._supabase, this._logger);

  Future<void> pullAll(int promotorId) async {
    _logger.clear();
    _logger.log('início', 'Iniciando sincronização para promotor $promotorId');
    await _pullPdvs(promotorId);
    await _pullGabaritos(promotorId);
    await _pullVisitasDia(promotorId);
    _logger.log('fim', 'Sincronização concluída');
  }

  Future<void> _pullVisitasDia(int promotorId) async {
    try {
      final hoje = DateTime.now();
      final inicioDia = DateTime(hoje.year, hoje.month, hoje.day)
          .toUtc().toIso8601String();
      final fimDia = DateTime(hoje.year, hoje.month, hoje.day, 23, 59, 59)
          .toUtc().toIso8601String();
      final dataHoje =
          '${hoje.year}-${hoje.month.toString().padLeft(2, '0')}-${hoje.day.toString().padLeft(2, '0')}';

      // ── 1. Busca rota ──────────────────────────────────────────────────────
      _logger.log('rota', 'Buscando rota do promotor...');
      final rotaRows = await _supabase
          .from('rotas')
          .select()
          .eq('promotor_associado', promotorId);

      if (rotaRows.isEmpty) {
        _logger.log('rota', 'Nenhuma rota encontrada para promotor $promotorId', erro: true);
        return;
      }
      final rota = rotaRows.first;
      final rotaId = rota['id'] as int;
      final gabaritosAssociados =
          (rota['gabaritos_associados'] as List?)?.cast<int>() ?? [];

      _logger.log('rota', 'Rota encontrada: id=$rotaId | gabaritos=${gabaritosAssociados.length} | ids=$gabaritosAssociados');

      if (gabaritosAssociados.isEmpty) {
        _logger.log('rota', 'Rota sem gabaritos associados', erro: true);
        return;
      }

      // ── 2. Edge Function ───────────────────────────────────────────────────
      _logger.log('edge_function', 'Chamando Edge Function gerar_datas_gabaritos_att...');
      _logger.log('edge_function', 'Payload: gabarito_ids=$gabaritosAssociados data=$dataHoje');

      final edgeFunctionUrl =
          '${AppConstants.supabaseUrl}/functions/v1/gerar_datas_gabaritos_att';

      final efResponse = await http.post(
        Uri.parse(edgeFunctionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AppConstants.supabaseAnonKey}',
        },
        body: jsonEncode({
          'gabarito_ids': gabaritosAssociados,
          'data_base': dataHoje,
          'data_final': dataHoje,
          'chunk_size': 20,
          'concurrency': 3,
        }),
      );

      _logger.log('edge_function', 'Status HTTP: ${efResponse.statusCode}');

      if (efResponse.statusCode != 200) {
        _logger.log('edge_function', 'Erro: ${efResponse.body}', erro: true);
      }

      final List<dynamic> visitasNormais = efResponse.statusCode == 200
          ? (jsonDecode(efResponse.body) as List? ?? [])
          : [];

      _logger.log('edge_function', '${visitasNormais.length} visitas normais retornadas');

      if (visitasNormais.isNotEmpty) {
        final primeiro = visitasNormais.first;
        _logger.log('edge_function', 'Exemplo 1º item: $primeiro');
      }

      // ── 3. Visitas avulsas ─────────────────────────────────────────────────
      _logger.log('avulsas', 'Buscando visitas avulsas do dia...');
      final avulsasRows = await _supabase
          .from('visitas')
          .select()
          .eq('id_promotor_associado', promotorId)
          .eq('rota_associada', rotaId)
          .eq('visita_avulsa', true)
          .gte('dia_hora_agendado', inicioDia)
          .lt('dia_hora_agendado', fimDia);

      _logger.log('avulsas', '${avulsasRows.length} visitas avulsas encontradas');

      // ── 4. Reconcilia realizadas/andamento ─────────────────────────────────
      _logger.log('reconcilia', 'Buscando visitas realizadas/em andamento...');
      final realizadasRows = await _supabase
          .from('visitas')
          .select()
          .eq('id_promotor_associado', promotorId)
          .gte('dia_hora_agendado', inicioDia)
          .lte('dia_hora_agendado', fimDia)
          .inFilter('status_visita', [1, 2]);

      _logger.log('reconcilia', '${realizadasRows.length} visitas com status 1 ou 2 no servidor');

      final Map<String, Map<String, dynamic>> realizadasMap = {};
      for (final r in realizadasRows) {
        final key =
            '${r['id_gabarito_associado']}|${r['id_pdv_associado']}|${r['previsao_turno_realizada']}';
        realizadasMap[key] = r;
      }

      // ── 5. Limpa agendadas não modificadas ─────────────────────────────────
      _logger.log('limpeza', 'Removendo visitas agendadas não modificadas localmente...');
      await _db.deleteVisitasAgendadasHojeNaoModificadas(promotorId);

      // ── 6. Salva visitas normais ───────────────────────────────────────────
      _logger.log('salvar', 'Salvando visitas normais no SQLite...');
      int salvas = 0;
      int puladas = 0;

      for (final item in visitasNormais) {
        final gabaritoId = item['gabarito_id'] as int? ?? 0;
        final pdvId = item['pdv_associado'] as int? ?? 0;
        final turno = item['turno'] as String? ?? '';
        final diaHoraAgendadoRaw = item['diaHoraAgendado'] as String? ?? item['dia_hora_agendado'] as String? ?? '';
        final diaHoraAgendado = diaHoraAgendadoRaw.isNotEmpty ? DateTime.tryParse(diaHoraAgendadoRaw)?.toUtc().toIso8601String() ?? diaHoraAgendadoRaw : diaHoraAgendadoRaw;
        final localExistente = await _db.getVisitaByGabaritoTurnoData(
          gabaritoId, pdvId, turno, inicioDia, fimDia,
        );
        if (localExistente != null && localExistente.syncStatus == 'pending') {
          puladas++;
          continue;
        }

        final key = '$gabaritoId|$pdvId|$turno';
        final realizadaServidor = realizadasMap[key];

        final int statusFinal = realizadaServidor != null
            ? (realizadaServidor['status_visita'] as int? ?? 1)
            : (item['status_visita'] as int? ?? 1);

        final int? idVisita = realizadaServidor != null
            ? realizadaServidor['id'] as int?
            : item['id_visita'] as int?;

        if (idVisita != null) {
          await _db.upsertVisita(VisitasCompanion(
            id: Value(idVisita),
            idPdvAssociado: Value(pdvId),
            idPromotorAssociado: Value(promotorId),
            rotaAssociada: Value(item['rota_associada'] as int? ?? rotaId),
            idGabaritoAssociado: Value(gabaritoId),
            diaHoraAgendado: Value(diaHoraAgendado),
            statusVisita: Value(statusFinal),
            titulo: Value(item['titulo'] as String?),
            previsaoTurnoRealizada: Value(turno),
            visitaAvulsa: const Value(false),
            diaHoraRealizado: Value(realizadaServidor?['dia_hora_realizado'] as String?),
            diaHoraAbertura: Value(realizadaServidor?['dia_hora_abertura'] as String?),
            syncStatus: const Value('synced'),
            syncedAt: Value(DateTime.now().toIso8601String()),
          ));
        } else {
          final idTemp = -(gabaritoId * 10000 + pdvId + turno.hashCode.abs() % 1000);
          await _db.upsertVisita(VisitasCompanion(
            id: Value(idTemp),
            idPdvAssociado: Value(pdvId),
            idPromotorAssociado: Value(promotorId),
            rotaAssociada: Value(item['rota_associada'] as int? ?? rotaId),
            idGabaritoAssociado: Value(gabaritoId),
            diaHoraAgendado: Value(diaHoraAgendado),
            statusVisita: const Value(1),
            titulo: Value(item['titulo'] as String?),
            previsaoTurnoRealizada: Value(turno),
            visitaAvulsa: const Value(false),
            syncStatus: const Value('synced'),
            syncedAt: Value(DateTime.now().toIso8601String()),
          ));
        }
        salvas++;
      }

      _logger.log('salvar', '$salvas visitas normais salvas, $puladas puladas (pending local)');

      // ── 7. Salva avulsas ───────────────────────────────────────────────────
      int avulsasSalvas = 0;
      for (final row in avulsasRows) {
        final id = row['id'] as int;
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
          titulo: Value(row['titulo'] as String?),
          previsaoTurnoRealizada: Value(row['previsao_turno_realizada'] as String?),
          visitaAvulsa: const Value(true),
          localizacaoAbertura: Value(row['localizacao_abertura'] as String?),
          localizacaoEncerramento: Value(row['localizacao_encerramento'] as String?),
          fotosAntesJson: Value(jsonEncode(row['fotos_antes'] ?? [])),
          fotosDepoisJson: Value(jsonEncode(row['fotos_depois'] ?? [])),
          syncStatus: const Value('synced'),
          syncedAt: Value(DateTime.now().toIso8601String()),
        ));
        avulsasSalvas++;
      }
      _logger.log('avulsas', '$avulsasSalvas visitas avulsas salvas');

      await _db.upsertSyncState(SyncStateCompanion(
        entityType: const Value('visitas'),
        lastPullAt: Value(DateTime.now().toIso8601String()),
      ));

    } catch (e, stack) {
      _logger.log('erro', 'Exceção: $e\n$stack', erro: true);
    }
  }

  Future<void> _pullPdvs(int promotorId) async {
    try {
      _logger.log('pdvs', 'Buscando PDVs...');
      final rows = await _supabase
          .from('pdv')
          .select('id,api_localName,api_localCustomerName,endereco,api_specificLocation,"Lat","Lng",situacao')
          .or('id_promotor_associado.eq.$promotorId');

      for (final row in rows) {
        await _db.into(_db.pdvs).insertOnConflictUpdate(PdvsCompanion(
          id: Value(row['id'] as int),
          apiLocalName: Value(row['api_localName'] as String?),
          apiLocalCustomerName: Value(row['api_localCustomerName'] as String?),
          endereco: Value(row['endereco'] as String?),
          apiSpecificLocation: Value(row['api_specificLocation'] as String?),
          lat: Value((row['Lat'] as num?)?.toDouble()),
          lng: Value((row['Lng'] as num?)?.toDouble()),
          situacao: Value(row['situacao'] as bool?),
          syncedAt: Value(DateTime.now().toIso8601String()),
        ));
      }
      _logger.log('pdvs', '${rows.length} PDVs sincronizados');
    } catch (e) {
      _logger.log('pdvs', 'Erro: $e', erro: true);
    }
  }

  Future<void> _pullGabaritos(int promotorId) async {
    try {
      _logger.log('gabaritos', 'Buscando gabaritos ativos...');
      final rows = await _supabase
          .from('gabarito')
          .select('id,nome,pdv_associado,rota_associada,promotor_associado,ativo,padrao,prazo_validade')
          .eq('ativo', true);

      for (final row in rows) {
        await _db.into(_db.gabaritos).insertOnConflictUpdate(GabaritosCompanion(
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
      _logger.log('gabaritos', '${rows.length} gabaritos sincronizados');
    } catch (e) {
      _logger.log('gabaritos', 'Erro: $e', erro: true);
    }
  }

  Future<void> processOutbox() async {
    if (_running) return;
    _running = true;
    try {
      final items = await _db.getPendingOutboxItems();
      for (final item in items) {
        await _processOutboxItem(item);
      }
      final photos = await _db.getPendingPhotos();
      for (final photo in photos) {
        await _processPhotoUpload(photo);
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _processOutboxItem(OutboxItem item) async {
    await _db.updateOutboxItem(OutboxItemsCompanion(
      id: Value(item.id),
      status: const Value('processing'),
    ));
    try {
      final payload = jsonDecode(item.payloadJson) as Map<String, dynamic>;
      final updatePayload = Map<String, dynamic>.from(payload)..remove('id');

      if (item.entityId < 0) {
        // ID negativo = visita criada offline. Faz INSERT pra obter ID real
        // e migra todas as referências locais para esse novo ID.
        _logger.log('outbox', 'INSERT visita local id=${item.entityId}');
        final res = await _supabase
            .from('visitas')
            .insert(updatePayload)
            .select()
            .single();
        final novoId = res['id'] as int;
        _logger.log('outbox', 'INSERT OK: novo id=$novoId (era ${item.entityId})');
        await _db.migrateVisitaId(item.entityId, novoId);
      } else {
        _logger.log('outbox', 'UPDATE visita id=${item.entityId} (op=${item.operation})');
        await _supabase
            .from('visitas')
            .update(updatePayload)
            .eq('id', item.entityId);
        await _db.updateVisita(VisitasCompanion(
          id: Value(item.entityId),
          syncStatus: const Value('synced'),
          syncedAt: Value(DateTime.now().toIso8601String()),
        ));
      }
      await _db.deleteOutboxItem(item.id);
    } catch (e) {
      _logger.log('outbox', 'Falha entityId=${item.entityId}: $e', erro: true);
      final attempts = item.attempts + 1;
      final delaySeconds = min(pow(2, attempts).toInt() * 30, 1800);
      final nextRetry =
          DateTime.now().add(Duration(seconds: delaySeconds)).toIso8601String();
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
      final storagePath = 'visitas/${photo.visitaId}/${photo.slot}_${photo.numero}_${photo.id}.$ext';
      await _supabase.storage.from('Arquivos').uploadBinary(
        storagePath, bytes,
        fileOptions: FileOptions(contentType: 'image/jpeg', upsert: true),
      );
      final url = _supabase.storage.from('Arquivos').getPublicUrl(storagePath);
      final fotosKey = photo.slot == 'antes' ? 'fotos_antes' : 'fotos_depois';
      final fotosAtuais = (await _supabase.from('visitas').select(fotosKey).eq('id', photo.visitaId).single())[fotosKey] as List? ?? [];
      await _supabase.from('visitas').update({fotosKey: [...fotosAtuais, url]}).eq('id', photo.visitaId);
      await _db.updatePendingPhoto(PendingPhotosCompanion(
        id: Value(photo.id),
        status: const Value('uploaded'),
        storageUrl: Value(url),
      ));
    } catch (e) {
      final attempts = photo.attempts + 1;
      final delaySeconds = min(pow(2, attempts).toInt() * 30, 1800);
      final nextRetry = DateTime.now().add(Duration(seconds: delaySeconds)).toIso8601String();
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
  final logger = ref.watch(syncLoggerProvider.notifier);
  return SyncEngine(db, Supabase.instance.client, logger);
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
