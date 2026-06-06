// lib/core/network/sync_engine.dart

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart' show sha1;
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../utils/auth_session_expired.dart';
import '../constants/app_constants.dart';
import '../utils/sync_logger.dart';
import 'sync_pause.dart';

/// Hash determinístico ENTRE RUNS pra usar como idTemp local e como
/// fragmento estável no nome do arquivo no Storage.
///
/// O `Object.hash(int, int, String)` que era usado antes mistura
/// `String.hashCode`, que em Dart é RANDOMIZADO por inicialização de
/// isolate (defesa contra hash flooding). Cada relançamento do app
/// produzia idTemp diferente pra mesma chave natural (gabarito|pdv|turno),
/// criando linhas duplicadas em `visitas` e órfãs em `pending_photos`/
/// `outbox_items` — pendências se acumulavam até o promotor ficar com
/// 150+ itens travados (caso Gabriel/335 em 2026-05-29, confirmado por
/// 11 arquivos órfãos no bucket dele em path
/// `abastecimentos/<uid>/visita-<hash>-<slot>-N.jpg` — exatamente o que
/// `_processPhotoUpload` gera quando `getVisitaById(visitaId)` retorna
/// null porque a row foi pivotada pra outro idTemp).
///
/// SHA-1 dos bytes UTF-8 da chave dá mesmo resultado em qualquer isolate
/// / qualquer run / qualquer device.
int _hashDeterministico(int gabaritoId, int pdvId, String turno) {
  final bytes = utf8.encode('$gabaritoId|$pdvId|$turno');
  final digest = sha1.convert(bytes).bytes;
  // 4 primeiros bytes como int32 positivo (cabe em SQLite INTEGER).
  return ((digest[0] << 24) |
          (digest[1] << 16) |
          (digest[2] << 8) |
          digest[3]) &
      0x7FFFFFFF;
}

class SyncEngine {
  final AppDatabase _db;
  final SupabaseClient _supabase;
  final SyncLoggerNotifier _logger;

  /// Lock de re-entrância DESTE isolate. Cobre o caso de dois gatilhos
  /// do mesmo app dispararem sync ao mesmo tempo. NÃO basta sozinho: o
  /// WorkManager roda noutro isolate, com outra instância de SyncEngine
  /// e outro `_syncing`. Por isso o lock real é o cross-process do
  /// SQLite (tryAcquireSyncLock) — sem ele, push de um processo e pull
  /// do outro concorriam e deixavam fotos/outbox órfãos (a recorrência
  /// que persistia mesmo após os fixes anteriores).
  bool _syncing = false;

  /// `true` quando há um ciclo de sincronização em andamento neste
  /// isolate. Usado por consumidores que precisam evitar ações
  /// destrutivas durante o sync (ex: gatilho de force-update).
  bool get isSyncing => _syncing;

  /// Identidade desta instância pra dono do lock cross-process.
  final String _instanceId = const Uuid().v4();

  /// TTL do lock cross-process. Folgado vs. a duração real de um ciclo
  /// (~10-30s) mas curto o bastante pra liberar se um isolate morrer
  /// segurando o lock.
  static const _lockTtlMs = 240000;

  /// Migrações idTemp→serverId feitas durante a rodada atual de
  /// processOutbox. O snapshot do outbox é lido de uma vez no início;
  /// quando o 1º item (open) consolida a visita em serverId, os demais
  /// itens do snapshot ainda carregam o entityId antigo em memória —
  /// este mapa resolve isso sem precisar re-ler a fila a cada item.
  final Map<int, int> _idsMigradosNaRodada = {};

  SyncEngine(this._db, this._supabase, this._logger);

  /// Executa [action] sob exclusão mútua: re-entrância no mesmo isolate
  /// (_syncing) + lock cross-process no SQLite (app ↔ WorkManager).
  /// Se já houver sync rodando em qualquer processo, pula o ciclo.
  Future<void> _runExclusive(String label, Future<void> Function() action) async {
    if (_syncing) {
      _logger.log('sync', '$label ignorado (sync em andamento neste app)');
      return;
    }
    final adquiriu = await _db.tryAcquireSyncLock(
        holder: _instanceId, ttlMs: _lockTtlMs);
    if (!adquiriu) {
      _logger.log('sync', '$label ignorado (outro processo sincronizando)');
      return;
    }
    _syncing = true;
    try {
      await action();
    } finally {
      _syncing = false;
      await _db.releaseSyncLock(_instanceId);
    }
  }

  Future<void> pullAll(int promotorId) =>
      _runExclusive('pullAll', () => _pullAllImpl(promotorId));

  Future<void> _pullAllImpl(int promotorId) async {
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
  /// Push e pull rodam sob o MESMO lock — são uma unidade atômica, sem
  /// outro processo entrando entre o push e o pull. Push antes de pull
  /// pra não perder dados locais que ainda não foram enviados.
  Future<void> fullSync(int promotorId) async {
    if (await SyncPause.isPaused()) {
      _logger.log('sync', 'fullSync pausado (captura ativa).');
      return;
    }
    await _runExclusive('fullSync', () async {
      await _processOutboxImpl();
      await _pullAllImpl(promotorId);
    });
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
      // SEM filtro de rota_associada: o supervisor pode criar a avulsa
      // sem rota vinculada (ou com outra rota) — a visita ainda é do
      // promotor e deve aparecer pra ele.
      _logger.log('avulsas', 'Buscando visitas avulsas do dia...');
      final avulsasRows = await _supabase
          .from('visitas')
          .select()
          .eq('id_promotor_associado', promotorId)
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
          // idTemp DETERMINÍSTICO entre runs do app (SHA-1 da chave natural).
          // Antes era Object.hash que mudava a cada relançamento do isolate
          // (String.hashCode randomizado), causando duplicação de linhas
          // locais e órfãos em pending_photos/outbox — ver comentário do
          // _hashDeterministico.
          final idTemp = -_hashDeterministico(gabaritoId, pdvId, turno);
          // Lookup por chave natural ANTES de inserir: cobre upgrade vindo
          // de builds com idTemp não-determinístico (Object.hash, build
          // <182). Se já existe row local pra (gabarito, pdv, turno, dia)
          // com id diferente do idTemp atual, preserva o id antigo e só
          // atualiza os campos do servidor — sem isso o upgrade duplicaria
          // visitas que ainda têm foto/outbox pendente apontando pro id
          // antigo.
          final existente = await _db.getVisitaByGabaritoTurnoData(
              gabaritoId, pdvId, turno, inicioDia, fimDia);
          final idAlvo = existente?.id ?? idTemp;
          // Reseta campos de execução da rodada anterior. Sem isso, em
          // PDVs recorrentes (mesmo gabarito|pdv|turno em semanas
          // diferentes) o `idTemp` determinístico colide com a visita
          // antiga e `localState='finalizada'` vaza pra visita nova —
          // promotor clica no card "Agendada" e cai direto na tela
          // "Visita finalizada!". Esse bloco só roda quando a visita
          // está synced (passou o filtro de pending acima) E o servidor
          // não tem ela como realizada/em-andamento hoje, então é
          // seguro zerar — qualquer trabalho legítimo já chegou no
          // servidor.
          await _db.upsertVisita(VisitasCompanion(
            id: Value(idAlvo),
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
            localState: const Value('idle'),
            fotosAntesJson: const Value(null),
            fotosDepoisJson: const Value(null),
            diaHoraAbertura: const Value(null),
            diaHoraRealizado: const Value(null),
            diaHoraFotosAntes: const Value(null),
            diaHoraFotosDepois: const Value(null),
            localizacaoAbertura: const Value(null),
            localizacaoEncerramento: const Value(null),
            localizacaoFotosAntes: const Value(null),
            localizacaoFotosDepois: const Value(null),
            comentariosVisita: const Value(null),
            checkPergunta1: const Value(null),
            checkPergunta2: const Value(null),
            checkPergunta3: const Value(null),
            checkPergunta4: const Value(null),
            checkPergunta5: const Value(null),
            checkPergunta6: const Value(null),
            checkPergunta7: const Value(null),
            obsPergunta1: const Value(null),
            obsPergunta2: const Value(null),
            obsPergunta3: const Value(null),
            obsPergunta4: const Value(null),
            obsPergunta5: const Value(null),
            obsPergunta6: const Value(null),
            obsPergunta7: const Value(null),
          ));
        }
        salvas++;
      }

      _logger.log('salvar', '$salvas visitas normais salvas, $puladas puladas (pending local)');

      // ── 6b. Recria QUALQUER visita realizada/andamento do servidor
      //     que não foi criada pelo loop principal ──────────────────────────
      // Itera TODAS as rows com status 1 ou 2 do servidor (não só as
      // que sobraram do realizadasMap). Cobre:
      //   - Visitas órfãs (gabarito removido da rota pelo supervisor);
      //   - Colisões de chave gabarito|pdv|turno (2 visitas no mesmo
      //     trio, ex: 1 realizada + 1 avulsa nova do mesmo PDV) — antes,
      //     o map sobrescrevia uma com a outra e o passo 6 só salvava 1.
      // Upsert por ID: visitas já criadas no passo 6 (com mesmo ID)
      // ficam idempotentes. Visitas com syncStatus='pending' local são
      // PULADAS (não sobrescreve trabalho não sincronizado).
      int orfas = 0;
      for (final row in realizadasRows) {
        final idVisita = row['id'] as int?;
        if (idVisita == null) continue;
        final localExistente = await _db.getVisitaById(idVisita);
        if (localExistente != null &&
            localExistente.syncStatus == 'pending') {
          continue;
        }
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
          visitaAvulsa: Value(row['visita_avulsa'] as bool? ?? false),
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
    // Bloqueio durante captura (grid de fotos ou câmera aberta): nada
    // sincroniza, independentemente da origem do trigger (foreground,
    // WorkManager, listener, etc.).
    if (await SyncPause.isPaused()) {
      _logger.log('sync', 'Pausado (captura ativa) — pulando ciclo.');
      return;
    }
    await _runExclusive('processOutbox', _processOutboxImpl);
  }

  Future<void> _processOutboxImpl() async {
    _idsMigradosNaRodada.clear();
    // FOTOS PRIMEIRO: o upload em Storage gera URLs públicas e grava
    // em pending_photos.storageUrl. Quando o INSERT/UPDATE da visita
    // rodar a seguir, o _buildVisitaPayload lê essas URLs e envia
    // tudo num único request — em vez de 1 INSERT + N UPDATEs.
    // Upload e outbox NÃO marcam ProcessingTracker — engrenagem reflete
    // só processamento interno (watermark + galeria), que é rápido
    // e independe de internet. Sincronismo com servidor roda
    // silenciosamente em background; bloquear a home por ele
    // amarraria o promotor à conexão.
    final photos = await _db.getPendingPhotos();
    for (final photo in photos) {
      await _processPhotoUpload(photo);
    }
    // Reler outbox: o upload das fotos pode ter enfileirado UPDATEs
    // pra visitas com serverId já existente (fluxo de re-edição).
    final items = await _db.getPendingOutboxItems();
    for (final item in items) {
      await _processOutboxItem(item);
    }
  }

  /// Converte status interno do app novo para o status_visita do Supabase
  /// (mesmos códigos do app FlutterFlow antigo).
  ///
  /// App novo: 1=agendada, 2=andamento, 3=realizada, 5=falta
  /// Servidor: 1=realizada, 2=andamento, 5=falta (não há 'agendada' no servidor)
  int _toServerStatus(int? appStatus) {
    if (appStatus == AppConstants.statusRealizada) return 1; // 3 -> 1
    if (appStatus == AppConstants.statusEmAndamento) return 2; // 2 -> 2
    if (appStatus == AppConstants.statusFalta) return 5; // 5 -> 5
    // Local=agendada (1) ou null: NÃO existe equivalente "agendada" no
    // servidor. Default seguro: 2 (em andamento). Antes caía no fallback
    // `appStatus ?? statusEmAndamento` que retornava 1 — e 1 no servidor
    // significa REALIZADA. Resultado: qualquer UPDATE com local=1 marcava
    // a visita como realizada no servidor sem dia_hora_realizado nem
    // fotos_depois (caso Jessica/visita-113248 2026-05-26).
    return 2;
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

    // INSTRUMENTAÇÃO: compara o que o promotor CAPTUROU (fotosAntesJson/
    // fotosDepoisJson = paths locais, fonte de verdade do grid) com o que
    // está pronto pra subir (URLs uploaded). Discrepância = a visita vai
    // pro servidor com MENOS fotos do que tirou — exatamente o sintoma
    // dos casos Jessica/Leandro, mas que antes passava silencioso. Loga
    // ERRO (vai pro auto-issue) com os números, pra detecção proativa.
    _logDiscrepanciaFotos(v, operation, 'antes', fotosAntesUrls.length);
    if (operation == 'close') {
      _logDiscrepanciaFotos(v, operation, 'depois', fotosDepoisUrls.length);
    }

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
      // Arrays de URLs públicas — incluídos em QUALQUER operação que
      // tenha URLs. Antes fotos_depois só ia no `close`, então se o
      // close demorasse (ou falhasse) as URLs ficavam órfãs no bucket
      // sem chegar à tabela (caso Jessica 2026-05-26).
      if (fotosAntesUrls.isNotEmpty) 'fotos_antes': fotosAntesUrls,
      if (fotosDepoisUrls.isNotEmpty) 'fotos_depois': fotosDepoisUrls,
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
      });
    }

    // Remove campos null para não sobrescrever dados existentes no UPDATE
    payload.removeWhere((key, value) => value == null);
    return payload;
  }

  /// Loga ERRO quando o nº de fotos capturadas localmente (paths no
  /// fotosAntesJson/fotosDepoisJson) é MAIOR que o nº de URLs prontas pra
  /// subir. Sinal de fotos que ficaram pra trás (upload incompleto, id
  /// órfão, watermark travado). Vai pro auto-issue — detecção proativa
  /// do sintoma "visita sincronizou com fotos faltando".
  void _logDiscrepanciaFotos(
      Visita v, String operation, String slot, int uploaded) {
    final json = slot == 'antes' ? v.fotosAntesJson : v.fotosDepoisJson;
    if (json == null || json.isEmpty) return;
    int capturadas;
    try {
      capturadas = (jsonDecode(json) as List).length;
    } catch (_) {
      return;
    }
    if (capturadas > uploaded) {
      _logger.log(
          'integridade',
          'DISCREPÂNCIA fotos $slot visitaId=${v.id} serverId=${v.serverId} '
          'op=$operation: capturadas=$capturadas uploaded=$uploaded '
          '(faltam ${capturadas - uploaded}) titulo=${v.titulo}',
          erro: true);
    }
  }

  Future<void> _processOutboxItem(OutboxItem item) async {
    // Resolve o entityId pela migração da rodada: se um item anterior
    // (open) consolidou a visita idTemp→serverId, o entityId deste item
    // no snapshot ainda é o idTemp. Sem isso, getVisitaById(idTemp) daria
    // null e o item seria descartado — fotos órfãs de novo.
    final entityId = _idsMigradosNaRodada[item.entityId] ?? item.entityId;

    // Princípio: não tocar no servidor sobre uma visita enquanto houver
    // foto da mesma visita+slot ainda EM PROGRESSO local (watermark_pending,
    // pending, uploading). Sem isso, o INSERT 'open' subia com
    // fotos_antes=[] e o servidor ficava com array vazio enquanto o app
    // já considerava 'synced' (Cleiton/Edilson, 2026-05-20/21).
    //
    // 'error' (arquivo local sumiu — irrecuperável) NÃO posterga: antes
    // travava o outbox da visita pra sempre e ela nunca sincronizava.
    // Agora a visita vai pro servidor com as fotos que subiram.
    //
    // Pra cada operação, identifica os slots que ela exige completos:
    //   - open / photos_antes  →  antes (visita ainda em fase antes)
    //   - close / photos_depois → antes + depois (payload inclui ambos
    //     os arrays, então qualquer envio nessa fase precisa dos dois
    //     completos pra não subir parcial — caso Alexsandra 2026-05-28
    //     issue #23: rede ruim deixou 2 antes em pending, photos_depois
    //     rodou só checando 'depois' e subiu a visita com 2 antes
    //     faltando. DISCREPÂNCIA capturou no log).
    // Se algum slot ainda tem foto em progresso, sai sem mexer no
    // outbox item. O próximo ciclo de sync (disparado pela watermark
    // queue ao terminar) re-tenta — em geral em segundos.
    final slotsRequeridos = <String>[];
    switch (item.operation) {
      case 'open':
      case 'photos_antes':
        slotsRequeridos.add('antes');
        break;
      case 'close':
      case 'photos_depois':
        slotsRequeridos.add('antes');
        slotsRequeridos.add('depois');
        break;
    }
    for (final slot in slotsRequeridos) {
      final emProgresso =
          await _db.countFotosEmProgresso(entityId, slot);
      if (emProgresso > 0) {
        _logger.log(
            'outbox',
            'Posterga ${item.operation} visitaId=$entityId: '
            '$emProgresso foto(s) $slot ainda em processamento');
        return;
      }
    }

    await _db.updateOutboxItem(OutboxItemsCompanion(
      id: Value(item.id),
      status: const Value('processing'),
    ));
    try {
      // Lê estado completo e atual da visita no SQLite e monta payload com
      // todos os campos relevantes (replicando o app FlutterFlow antigo).
      final visita = await _db.getVisitaById(entityId);
      if (visita == null) {
        // Sinal de id órfão: a fila aponta pra uma visita que não existe
        // mais (pivot mal resolvido, delete prematuro). Loga contexto rico
        // — se houver fotos uploaded penduradas nesse entityId, elas vão
        // virar órfãs no bucket. Detecção proativa do bug-classe.
        final fotosOrfas = await _db.getUploadedPhotoUrls(entityId, 'antes');
        final fotosOrfasDepois =
            await _db.getUploadedPhotoUrls(entityId, 'depois');
        _logger.log(
            'outbox',
            'ÓRFÃO: visita id=$entityId (item.entityId=${item.entityId}) '
            'não encontrada — descartando outbox op=${item.operation}. '
            'Fotos penduradas: antes=${fotosOrfas.length} '
            'depois=${fotosOrfasDepois.length}',
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
          'Payload visita id=$entityId op=${item.operation} '
          'campos=${payload.keys.length} '
          'fotos_antes=${fotosAntesNoPayload is List ? fotosAntesNoPayload.length : 0}urls '
          'fotos_depois=${fotosDepoisNoPayload is List ? fotosDepoisNoPayload.length : 0}urls');

      // Decide INSERT vs UPDATE pelo serverId, não pelo id local.
      // - serverId == null: visita ainda não existe no servidor → INSERT
      // - serverId != null: já existe → UPDATE eq('id', serverId)
      if (visita.serverId == null) {
        _logger.log('outbox',
            'INSERT visita local id=$entityId (sem serverId)');
        final res = await _supabase
            .from('visitas')
            .insert(payload)
            .select()
            .single();
        final novoServerId = res['id'] as int;
        // Consolida a PK local em serverId E re-vincula fotos+outbox na
        // mesma transação. Sem isso, idTemp e serverId divergiam e as
        // fotos/outbox ficavam órfãos (causa raiz das fotos sumindo).
        await _db.consolidarVisitaNoServer(entityId, novoServerId);
        // Registra a migração pra resolver os demais itens DESTA rodada
        // (o snapshot do outbox foi lido com o entityId antigo).
        if (entityId != novoServerId) {
          _idsMigradosNaRodada[entityId] = novoServerId;
          _logger.log('outbox',
              'PIVOT idTemp=$entityId → serverId=$novoServerId consolidado '
              '(fotos+outbox re-vinculados)');
        } else {
          _logger.log('outbox', 'INSERT OK serverId=$novoServerId');
        }
      } else {
        final res = await _supabase
            .from('visitas')
            .update(payload)
            .eq('id', visita.serverId!)
            .select();
        _logger.log(
            'outbox',
            'UPDATE OK localId=$entityId serverId=${visita.serverId} '
            'op=${item.operation} rowsAfetadas=${res.length}');
        if (res.isEmpty) {
          _logger.log(
              'outbox',
              'AVISO: UPDATE 0 rows. serverId=${visita.serverId} pode não existir no servidor.',
              erro: true);
        }
        await _db.updateVisita(VisitasCompanion(
          id: Value(entityId),
          syncStatus: const Value('synced'),
          syncedAt: Value(DateTime.now().toIso8601String()),
        ));
      }
      await _db.deleteOutboxItem(item.id);
    } catch (e) {
      _logger.log('outbox', 'Falha entityId=$entityId: $e', erro: true);
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
      // Sessão Supabase Auth pode expirar enquanto o app está aberto.
      // Sem authUid, o path do storage fica `abastecimentos//…/` e o
      // RLS rejeita com 403, travando o sync. Antes de tentar upload,
      // se currentUser=null, tenta refreshSession (renova access via
      // refresh token salvo). Se refresh falhar, marca sessão como
      // expirada — o caller (processOutbox) propaga pra UI mostrar o
      // login. Não logamos o promotor à força aqui pra não corromper
      // o estado se houver visita em andamento na tela.
      var authUid = _supabase.auth.currentUser?.id ?? '';
      if (authUid.isEmpty) {
        _logger.log('photo',
            'Sem auth.uid — tentando refreshSession antes do upload');
        try {
          final res = await _supabase.auth
              .refreshSession()
              .timeout(const Duration(seconds: 6));
          authUid = res.user?.id ?? '';
        } catch (_) {}
        if (authUid.isEmpty) {
          _logger.log(
              'photo',
              'Refresh falhou: sessão Supabase Auth expirou. Marcando '
              'sessão expirada — UI será notificada pra forçar login.',
              erro: true);
          AuthSessionExpired.set();
          // Deixa a foto como pending pra reenvio depois do relogin —
          // não marca error, não consome a tentativa.
          await _db.updatePendingPhoto(PendingPhotosCompanion(
            id: Value(photo.id),
            status: const Value('pending'),
          ));
          return;
        }
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
      // Hash DETERMINÍSTICO da chave natural — mesma foto física gera
      // mesmo nome de arquivo entre runs. Antes, Object.hash com String
      // gerava nomes diferentes a cada relançamento, poluindo o bucket
      // com N cópias da mesma foto e dificultando recuperação de dados.
      final visitaHash = _hashDeterministico(
        visita?.idGabaritoAssociado ?? 0,
        visita?.idPdvAssociado ?? 0,
        visita?.previsaoTurnoRealizada ?? '',
      );
      // Sanitiza cada segmento — Supabase Storage rejeita :, espaços e acentos
      final dataSeg = _sanitizePathSegment(dataAgendadoBr);
      final nomeSeg = _sanitizePathSegment(nomeBase);
      final extSeg = _sanitizePathSegment(ext);
      final storagePath =
          'abastecimentos/$authUid/$dataSeg/$nomeSeg-$visitaHash-${photo.slot}-${photo.numero}.$extSeg';

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
