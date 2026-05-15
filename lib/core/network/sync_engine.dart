// lib/core/network/sync_engine.dart

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../constants/app_constants.dart';
import '../utils/processing_tracker.dart';
import '../utils/sync_logger.dart';
import 'sync_pause.dart';

class SyncEngine {
  final AppDatabase _db;
  final SupabaseClient _supabase;
  final SyncLoggerNotifier _logger;
  bool _running = false;

  SyncEngine(this._db, this._supabase, this._logger);

  Future<void> pullAll(int promotorId) async {
    // pullAll é trabalho global (não relacionado a visita específica),
    // então não toca o ProcessingTracker (que é por-visita).
    _logger.log(
        'início', 'Iniciando sincronização para promotor $promotorId');
    await _pullPdvs(promotorId);
    await _pullGabaritos(promotorId);
    await _pullVisitasDia(promotorId);
    _logger.log('fim', 'Sincronização concluída');
  }

  /// Ciclo completo de sincronização usado por todos os gatilhos:
  ///   1) PUSH: envia tudo que está pendente local pro servidor
  ///   2) PULL: apaga local sincronizado e re-baixa do servidor
  /// Garante que app e servidor fiquem idênticos após cada execução.
  /// Push antes de pull pra não perder dados locais que ainda não
  /// foram enviados.
  Future<void> fullSync(int promotorId) async {
    await processOutbox();
    await pullAll(promotorId);
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

      // ── 5. Limpa local antes do refetch ────────────────────────────────────
      // Estratégia "destruir + re-baixar": apaga TODAS as visitas synced
      // do promotor (preservando as com pendências). O loop seguinte
      // recria tudo a partir do servidor — garantindo que app e
      // servidor fiquem idênticos a cada pull, sem duplicação possível.
      _logger.log('limpeza',
          'Apagando visitas synced sem pendências (re-baixa do servidor)...');
      await _db.deleteVisitasSincronizadasSemPendencias(promotorId);

      // ── 6. Salva visitas normais ───────────────────────────────────────────
      _logger.log('salvar', 'Salvando visitas normais no SQLite...');
      int salvas = 0;
      int puladas = 0;
      // Marca quais entradas do realizadasMap já foram aproveitadas no
      // loop da edge function — as que sobrarem são órfãs (gabarito
      // removido da rota mas visita já realizada/em andamento existe
      // no servidor) e precisam ser recriadas no passo 6b.
      final keysConsumidas = <String>{};

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
        if (realizadaServidor != null) keysConsumidas.add(key);

        // Se há row no servidor (realizada/andamento), usa esse status
        // convertido. Senão é uma "vaga" gerada pela edge function —
        // ainda agendada no app.
        final int statusFinal = realizadaServidor != null
            ? _fromServerStatus(realizadaServidor['status_visita'] as int?)
            : AppConstants.statusAgendada;

        final int? idVisita = realizadaServidor != null
            ? realizadaServidor['id'] as int?
            : item['id_visita'] as int?;

        if (idVisita != null) {
          await _db.upsertVisita(VisitasCompanion(
            id: Value(idVisita),
            serverId: Value(idVisita),
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
            // serverId fica null — sync_engine vai criar no servidor depois
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

      // ── 6b. Recria visitas realizadas/andamento órfãs ─────────────────────
      // Visitas que estão no servidor com status 1 ou 2 mas cujo
      // gabarito NÃO aparece mais na rota atual (supervisor removeu
      // depois que o promotor já tinha começado/realizado). Sem este
      // passo, elas seriam apagadas pelo deleteVisitasSincronizadas...
      // e não voltariam pela edge function.
      int orfas = 0;
      for (final entry in realizadasMap.entries) {
        if (keysConsumidas.contains(entry.key)) continue;
        final row = entry.value;
        final idVisita = row['id'] as int?;
        if (idVisita == null) continue;
        await _db.upsertVisita(VisitasCompanion(
          id: Value(idVisita),
          serverId: Value(idVisita),
          idPdvAssociado: Value(row['id_pdv_associado'] as int?),
          idPromotorAssociado: Value(promotorId),
          rotaAssociada: Value(row['rota_associada'] as int? ?? rotaId),
          idGabaritoAssociado: Value(row['id_gabarito_associado'] as int?),
          diaHoraAgendado: Value(row['dia_hora_agendado'] as String?),
          statusVisita:
              Value(_fromServerStatus(row['status_visita'] as int?)),
          titulo: Value(row['titulo'] as String?),
          previsaoTurnoRealizada:
              Value(row['previsao_turno_realizada'] as String?),
          visitaAvulsa: const Value(false),
          diaHoraRealizado: Value(row['dia_hora_realizado'] as String?),
          diaHoraAbertura: Value(row['dia_hora_abertura'] as String?),
          localizacaoAbertura:
              Value(row['localizacao_abertura'] as String?),
          localizacaoEncerramento:
              Value(row['localizacao_encerramento'] as String?),
          syncStatus: const Value('synced'),
          syncedAt: Value(DateTime.now().toIso8601String()),
        ));
        orfas++;
      }
      if (orfas > 0) {
        _logger.log(
            'salvar',
            '$orfas visitas órfãs preservadas '
            '(gabarito fora da rota mas visita já estava em andamento/realizada)');
      }

      // ── 7. Salva avulsas ───────────────────────────────────────────────────
      int avulsasSalvas = 0;
      for (final row in avulsasRows) {
        final id = row['id'] as int;
        final local = await _db.getVisitaById(id);
        if (local != null && local.syncStatus == 'pending') continue;

        await _db.upsertVisita(VisitasCompanion(
          id: Value(id),
          serverId: Value(id),
          idPdvAssociado: Value(row['id_pdv_associado'] as int?),
          idPromotorAssociado: Value(row['id_promotor_associado'] as int?),
          diaHoraAgendado: Value(row['dia_hora_agendado'] as String?),
          diaHoraRealizado: Value(row['dia_hora_realizado'] as String?),
          diaHoraAbertura: Value(row['dia_hora_abertura'] as String?),
          statusVisita: Value(_fromServerStatus(row['status_visita'] as int?)),
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
    // Bloqueio único pra TODOS os gatilhos: durante captura (grid de fotos
    // ou câmera aberta), nada sincroniza, independentemente da origem
    // do trigger (foreground, WorkManager, listener, etc.).
    if (await SyncPause.isPaused()) {
      _logger.log('sync', 'Pausado (captura ativa) — pulando ciclo.');
      return;
    }
    _running = true;
    try {
      // FOTOS PRIMEIRO: o upload em Storage gera URLs públicas e grava
      // em pending_photos.storageUrl. Quando o INSERT/UPDATE da visita
      // rodar a seguir, o _buildVisitaPayload lê essas URLs e envia
      // tudo num único request — em vez de 1 INSERT + N UPDATEs.
      final photos = await _db.getPendingPhotos();
      for (final photo in photos) {
        ProcessingTracker.begin(photo.visitaId);
        try {
          await _processPhotoUpload(photo);
        } finally {
          ProcessingTracker.end(photo.visitaId);
        }
      }
      // Reler outbox: o upload das fotos pode ter enfileirado UPDATEs
      // pra visitas com serverId já existente (fluxo de re-edição).
      final items = await _db.getPendingOutboxItems();
      for (final item in items) {
        ProcessingTracker.begin(item.entityId);
        try {
          await _processOutboxItem(item);
        } finally {
          ProcessingTracker.end(item.entityId);
        }
      }
    } finally {
      _running = false;
    }
  }

  /// Converte status interno do app novo para o status_visita do Supabase
  /// (mesmos códigos do app FlutterFlow antigo).
  ///
  /// App novo: 1=agendada, 2=andamento, 3=realizada, 5=falta
  /// Servidor: 1=realizada, 2=andamento, 5=falta (não há 'agendada' no servidor)
  int _toServerStatus(int? appStatus) {
    if (appStatus == AppConstants.statusRealizada) return 1; // 3 -> 1
    return appStatus ?? AppConstants.statusEmAndamento;
  }

  /// Inverso de `_toServerStatus`. Servidor → App.
  ///   Servidor 1 (realizada) → App 3 (statusRealizada)
  ///   Servidor 2 (andamento) → App 2 (statusEmAndamento)
  ///   Servidor 5 (falta)     → App 5 (statusFalta)
  ///   null/outro             → App 1 (statusAgendada)
  /// Sem essa conversão, uma visita realizada no servidor (status 1)
  /// chegava no app como "agendada" (status 1), reabrindo visitas já
  /// finalizadas — bug visto após 15 min de sync periódico.
  int _fromServerStatus(int? serverStatus) {
    if (serverStatus == 1) return AppConstants.statusRealizada;
    if (serverStatus == 2) return AppConstants.statusEmAndamento;
    if (serverStatus == AppConstants.statusFalta) {
      return AppConstants.statusFalta;
    }
    return AppConstants.statusAgendada;
  }

  /// Monta o payload completo da visita para enviar ao Supabase, replicando
  /// fielmente o que o app FlutterFlow antigo enviava em insert/update.
  Future<Map<String, dynamic>> _buildVisitaPayload(Visita v,
      {required String operation}) async {
    // URLs vêm de PendingPhotos.storageUrl (preenchido pelo upload).
    final fotosAntesUrls = await _db.getUploadedPhotoUrls(v.id, 'antes');
    final fotosDepoisUrls = await _db.getUploadedPhotoUrls(v.id, 'depois');

    final payload = <String, dynamic>{
      'status_visita': _toServerStatus(v.statusVisita),
      'id_pdv_associado': v.idPdvAssociado,
      'id_promotor_associado': v.idPromotorAssociado,
      'dia_hora_agendado': v.diaHoraAgendado,
      'rota_associada': v.rotaAssociada,
      'id_gabarito_associado': v.idGabaritoAssociado,
      'titulo': v.titulo,
      'previsao_turno_realizada': v.previsaoTurnoRealizada,
      'visita_avulsa': v.visitaAvulsa ?? false,
      'dia_hora_abertura': v.diaHoraAbertura,
      'localizacao_abertura': v.localizacaoAbertura,
      'dia_hora_fotos_antes': v.diaHoraFotosAntes,
      'localizacao_fotos_antes': v.localizacaoFotosAntes,
      // Array de URLs públicas — só inclui se houver pelo menos uma
      if (fotosAntesUrls.isNotEmpty) 'fotos_antes': fotosAntesUrls,
    };

    if (operation == 'close') {
      payload.addAll(<String, dynamic>{
        'dia_hora_realizado': v.diaHoraRealizado,
        'dia_hora_fotos_depois': v.diaHoraFotosDepois,
        'localizacao_fotos_depois': v.localizacaoFotosDepois,
        'localizacao_encerramento': v.localizacaoEncerramento,
        'comentarios_visita': v.comentariosVisita,
        'check_pergunta_1': v.checkPergunta1,
        'obs_pergunta_1': v.obsPergunta1,
        'check_pergunta_2': v.checkPergunta2,
        'obs_pergunta_2': v.obsPergunta2,
        'check_pergunta_3': v.checkPergunta3,
        'obs_pergunta_3': v.obsPergunta3,
        'check_pergunta_4': v.checkPergunta4,
        'obs_pergunta_4': v.obsPergunta4,
        'check_pergunta_5': v.checkPergunta5,
        'obs_pergunta_5': v.obsPergunta5,
        'check_pergunta_6': v.checkPergunta6,
        'obs_pergunta_6': v.obsPergunta6,
        'check_pergunta_7': v.checkPergunta7,
        'obs_pergunta_7': v.obsPergunta7,
        if (fotosDepoisUrls.isNotEmpty) 'fotos_depois': fotosDepoisUrls,
      });
    }

    // Remove campos null para não sobrescrever dados existentes no UPDATE
    payload.removeWhere((key, value) => value == null);
    return payload;
  }

  Future<void> _processOutboxItem(OutboxItem item) async {
    await _db.updateOutboxItem(OutboxItemsCompanion(
      id: Value(item.id),
      status: const Value('processing'),
    ));
    try {
      // Lê estado completo e atual da visita no SQLite e monta payload com
      // todos os campos relevantes (replicando o app FlutterFlow antigo).
      final visita = await _db.getVisitaById(item.entityId);
      if (visita == null) {
        _logger.log('outbox',
            'Visita local id=${item.entityId} não encontrada — descartando outbox',
            erro: true);
        await _db.deleteOutboxItem(item.id);
        return;
      }

      final payload =
          await _buildVisitaPayload(visita, operation: item.operation);

      // Log do payload completo pra debug
      final fotosAntesNoPayload = payload['fotos_antes'];
      final fotosDepoisNoPayload = payload['fotos_depois'];
      _logger.log(
          'outbox',
          'Payload visita id=${item.entityId} op=${item.operation} '
          'campos=${payload.keys.length} '
          'fotos_antes=${fotosAntesNoPayload is List ? fotosAntesNoPayload.length : 0}urls '
          'fotos_depois=${fotosDepoisNoPayload is List ? fotosDepoisNoPayload.length : 0}urls');

      // Decide INSERT vs UPDATE pelo serverId, não pelo id local.
      // - serverId == null: visita ainda não existe no servidor → INSERT
      // - serverId != null: já existe → UPDATE eq('id', serverId)
      // O id local NUNCA muda — PendingPhotos/OutboxItems sempre referenciam
      // o mesmo id estável.
      if (visita.serverId == null) {
        _logger.log('outbox',
            'INSERT visita local id=${item.entityId} (sem serverId)');
        final res = await _supabase
            .from('visitas')
            .insert(payload)
            .select()
            .single();
        final novoServerId = res['id'] as int;
        _logger.log('outbox',
            'INSERT OK: serverId=$novoServerId pra local id=${item.entityId}');
        await _db.updateVisita(VisitasCompanion(
          id: Value(item.entityId),
          serverId: Value(novoServerId),
          syncStatus: const Value('synced'),
          syncedAt: Value(DateTime.now().toIso8601String()),
        ));
      } else {
        final res = await _supabase
            .from('visitas')
            .update(payload)
            .eq('id', visita.serverId!)
            .select();
        _logger.log(
            'outbox',
            'UPDATE OK localId=${item.entityId} serverId=${visita.serverId} '
            'op=${item.operation} rowsAfetadas=${res.length}');
        if (res.isEmpty) {
          _logger.log(
              'outbox',
              'AVISO: UPDATE 0 rows. serverId=${visita.serverId} pode não existir no servidor.',
              erro: true);
        }
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

  /// Limpa texto pra usar em nome de arquivo. Mais restritivo que o app antigo:
  /// remove acentos e caracteres especiais que o Supabase Storage rejeita
  /// com "Invalid key". Mantém apenas a-z, A-Z, 0-9, espaço, hifen.
  String _limparNomeArquivo(String texto) {
    // Tabela de equivalentes ASCII (acentos comuns em pt-BR)
    const mapa = {
      'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
      'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
      'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
      'ç': 'c', 'ñ': 'n',
      'Á': 'A', 'À': 'A', 'Â': 'A', 'Ã': 'A', 'Ä': 'A',
      'É': 'E', 'È': 'E', 'Ê': 'E', 'Ë': 'E',
      'Í': 'I', 'Ì': 'I', 'Î': 'I', 'Ï': 'I',
      'Ó': 'O', 'Ò': 'O', 'Ô': 'O', 'Õ': 'O', 'Ö': 'O',
      'Ú': 'U', 'Ù': 'U', 'Û': 'U', 'Ü': 'U',
      'Ç': 'C', 'Ñ': 'N',
    };
    var s = texto;
    mapa.forEach((k, v) => s = s.replaceAll(k, v));
    s = s
        .replaceAll(RegExp(r'[^a-zA-Z0-9\s-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final palavras =
        s.split(' ').where((p) => p.trim().isNotEmpty).take(6).join(' ');
    return palavras.isEmpty ? 'foto' : palavras;
  }

  /// Sanitiza um segmento do storage path (sem espaços, sem `:`, sem acentos).
  String _sanitizePathSegment(String s) {
    const mapa = {
      'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
      'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
      'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
      'ç': 'c', 'ñ': 'n',
      'Á': 'A', 'À': 'A', 'Â': 'A', 'Ã': 'A', 'Ä': 'A',
      'É': 'E', 'È': 'E', 'Ê': 'E', 'Ë': 'E',
      'Í': 'I', 'Ì': 'I', 'Î': 'I', 'Ï': 'I',
      'Ó': 'O', 'Ò': 'O', 'Ô': 'O', 'Õ': 'O', 'Ö': 'O',
      'Ú': 'U', 'Ù': 'U', 'Û': 'U', 'Ü': 'U',
      'Ç': 'C', 'Ñ': 'N',
    };
    var r = s;
    mapa.forEach((k, v) => r = r.replaceAll(k, v));
    return r
        .replaceAll(':', '-')
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
  }

  Future<void> _processPhotoUpload(PendingPhoto photo) async {
    await _db.updatePendingPhoto(PendingPhotosCompanion(
      id: Value(photo.id),
      status: const Value('uploading'),
    ));
    try {
      final file = File(photo.localPath);
      if (!await file.exists()) {
        _logger.log('photo',
            'Arquivo local sumiu: ${photo.localPath}', erro: true);
        await _db.updatePendingPhoto(PendingPhotosCompanion(
          id: Value(photo.id),
          status: const Value('error'),
        ));
        return;
      }

      // Reconstrói path no padrão do app antigo FF:
      //   abastecimentos/{currentUserUid}/{dataAgendadoBrasil}/{nomePDV}-{slot}-{numero}.{ext}
      // currentUserUid = auth.users.id (UUID) — necessário pra passar policies
      // do bucket que comparam com auth.uid().
      final visita = await _db.getVisitaById(photo.visitaId);
      final authUid = _supabase.auth.currentUser?.id ?? '';
      if (authUid.isEmpty) {
        _logger.log('photo',
            'Sem auth.uid — upload vai falhar (faça login Supabase Auth)',
            erro: true);
      }
      // Converte dia_hora_agendado UTC -> Brasil e formata 'yyyy-MM-dd HH:mm:ss'
      String dataAgendadoBr;
      try {
        final dtUtc =
            DateTime.parse(visita?.diaHoraAgendado ?? '').toUtc();
        final dtBr = dtUtc.subtract(const Duration(hours: 3));
        dataAgendadoBr =
            '${dtBr.year.toString().padLeft(4, '0')}-${dtBr.month.toString().padLeft(2, '0')}-${dtBr.day.toString().padLeft(2, '0')} '
            '${dtBr.hour.toString().padLeft(2, '0')}:${dtBr.minute.toString().padLeft(2, '0')}:${dtBr.second.toString().padLeft(2, '0')}';
      } catch (_) {
        dataAgendadoBr = visita?.diaHoraAgendado ?? '';
      }
      final nomeBase = _limparNomeArquivo(visita?.titulo ?? 'visita');
      final ext = photo.localPath.split('.').last.toLowerCase();
      // Sanitiza cada segmento — Supabase Storage rejeita :, espaços e acentos
      final dataSeg = _sanitizePathSegment(dataAgendadoBr);
      final nomeSeg = _sanitizePathSegment(nomeBase);
      final extSeg = _sanitizePathSegment(ext);
      final storagePath =
          'abastecimentos/$authUid/$dataSeg/$nomeSeg-${photo.slot}-${photo.numero}.$extSeg';

      _logger.log('photo',
          'Upload photo id=${photo.id} path=$storagePath bytes=${(await file.length())}');

      final bytes = await file.readAsBytes();
      await _supabase.storage.from('Arquivos').uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: _contentTypeFromExt(ext),
              upsert: true,
            ),
          );
      final url =
          _supabase.storage.from('Arquivos').getPublicUrl(storagePath);
      _logger.log('photo', 'Upload OK url=$url');

      // IMPORTANTE: NÃO mexe em fotosAntesJson/fotosDepoisJson local.
      // Aquele JSON é a fonte de verdade dos PATHS LOCAIS pro app exibir
      // no grid (Image.file). As URLs do servidor ficam em
      // PendingPhotos.storageUrl e são lidas via getUploadedPhotoUrls()
      // ao montar o payload da visita.
      await _db.updatePendingPhoto(PendingPhotosCompanion(
        id: Value(photo.id),
        status: const Value('uploaded'),
        storageUrl: Value(url),
      ));

      // Marca visita como pending pra sync engine enviar UPDATE com fotos
      await _db.updateVisita(VisitasCompanion(
        id: Value(photo.visitaId),
        syncStatus: const Value('pending'),
      ));

      // Enfileira UPDATE da visita pra que o array fotos_antes/depois
      // chegue no servidor no próximo processOutbox.
      final outboxId = const Uuid().v4();
      await _db.insertOutboxItem(OutboxItemsCompanion(
        id: Value(outboxId),
        entityType: const Value('visita'),
        operation:
            Value(photo.slot == 'antes' ? 'photos_antes' : 'photos_depois'),
        entityId: Value(photo.visitaId),
        payloadJson: const Value('{}'),
        attempts: const Value(0),
        nextRetryAt: Value(DateTime.now().toIso8601String()),
        status: const Value('pending'),
        createdAt: Value(DateTime.now().toIso8601String()),
      ));
    } catch (e, st) {
      _logger.log('photo',
          'Falha upload photo id=${photo.id}: $e\n$st', erro: true);
      final attempts = photo.attempts + 1;
      final delaySeconds = min(pow(2, attempts).toInt() * 30, 1800);
      final nextRetry =
          DateTime.now().add(Duration(seconds: delaySeconds)).toIso8601String();
      await _db.updatePendingPhoto(PendingPhotosCompanion(
        id: Value(photo.id),
        status: const Value('pending'),
        attempts: Value(attempts),
        nextRetryAt: Value(nextRetry),
      ));
    }
  }

  String _contentTypeFromExt(String ext) {
    switch (ext.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'heic':
        return 'image/heic';
      case 'png':
      default:
        return 'image/png';
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
