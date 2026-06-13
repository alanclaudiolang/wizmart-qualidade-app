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
import '../utils/anomalia_queue_processor.dart';
import '../utils/anomalia_reporter.dart';
import '../utils/auth_session_expired.dart';
import '../utils/error_classifier.dart';
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

  /// Decide se uma visita LOCAL é fantasma/lixo a ser descartada no outbox
  /// (Causa C). SÓ é fantasma quando NÃO tem NENHUM sinal de trabalho:
  /// não-avulsa, sem serverId, sem abertura, sem realizado, sem status em
  /// execução E sem fotos no JSON. Antes faltava checar status/fotos —
  /// uma visita rebaixada (Causa A2) com fotos mas sem abertura era
  /// apagada por engano (caso Mauro 12/06).
  static bool visitaEhFantasma({
    required bool isAvulsa,
    required int? serverId,
    required String? diaHoraAbertura,
    required String? diaHoraRealizado,
    required int? statusVisita,
    required String? fotosAntesJson,
  }) {
    if (isAvulsa) return false;
    if (serverId != null) return false;
    if (diaHoraAbertura != null) return false;
    if (diaHoraRealizado != null) return false;
    if (statusVisita == AppConstants.statusEmAndamento ||
        statusVisita == AppConstants.statusRealizada) {
      return false;
    }
    final temFotos = fotosAntesJson != null &&
        fotosAntesJson.isNotEmpty &&
        fotosAntesJson != '[]';
    if (temFotos) return false;
    return true;
  }

  /// Decide se a CONSOLIDAÇÃO de uma visita (INSERT idTemp→serverId) deve
  /// ser ADIADA porque a visita está em uso (Causa A — item 1). Enquanto
  /// adiada, a PK não muda sob os pés da tela aberta, então foto não some
  /// nem Finalizar cai no vácuo. Timeout de segurança de 2h evita que uma
  /// flag presa (crash da tela) trave a visita para sempre.
  static bool deveAdiarConsolidacao({
    required bool telaAberta,
    required bool processandoAtivo,
    required int fotosWatermarkPending,
    required Duration idadeDesdeUltimaAtividade,
  }) {
    if (idadeDesdeUltimaAtividade > const Duration(hours: 2)) return false;
    return telaAberta || processandoAtivo || fotosWatermarkPending > 0;
  }

  /// Monta o caminho da foto no Storage. Retorna null se [authUid] estiver
  /// vazio (sessão morta) — item 9: sem isso, o path virava
  /// `abastecimentos//…/` (segmento vazio) e o RLS recusava com 403,
  /// travando o sync por dias (Adonias 25/05→12/06).
  static String? construirStoragePath({
    required String authUid,
    required String dataSeg,
    required String nomeSeg,
    required int visitaHash,
    required String slot,
    required int numero,
    required String extSeg,
  }) {
    if (authUid.isEmpty) return null;
    return 'abastecimentos/$authUid/$dataSeg/$nomeSeg-$visitaHash-$slot-$numero.$extSeg';
  }

  /// `true` se a visita tem QUALQUER sinal de execução. Usado pelo reset do
  /// pull (Causa B) para NUNCA zerar uma visita que o promotor iniciou —
  /// protege contra a corrida "clicar Iniciar no instante do sync".
  static bool visitaTemTrabalho({
    required int? serverId,
    required String? diaHoraAbertura,
    required int? statusVisita,
  }) {
    return serverId != null ||
        diaHoraAbertura != null ||
        statusVisita == AppConstants.statusEmAndamento ||
        statusVisita == AppConstants.statusRealizada;
  }

  /// Detecta o "0 rows" do PostgREST (PGRST116) de forma ROBUSTA. A lib às
  /// vezes coloca o código em `e.code` ('PGRST116'), e às vezes deixa em
  /// `e.code` o HTTP status ('406') com o 'PGRST116' SÓ no `message` —
  /// foi esse o caso da Camila (13/06, build 249): o tratamento antigo
  /// checava só `e.code=='PGRST116'`, então o INSERT que batia em conflito
  /// fazia `rethrow` e a visita COMPLETA (4 antes/5 depois) entrava em
  /// LOOP INFINITO de INSERT, sem nunca consolidar. Checa código E mensagem.
  static bool ehErroZeroRows({required String? code, required String message}) {
    if (code == 'PGRST116') return true;
    final m = message.toLowerCase();
    return m.contains('pgrst116') ||
        m.contains('cannot coerce') ||
        m.contains('contains 0 rows');
  }

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
    // Limpeza D-1: apaga do celular os rascunhos de fotos JÁ CONFIRMADAS
    // no servidor (dias anteriores). try/catch próprio: a limpeza nunca
    // pode quebrar o sync.
    try {
      await _limparD1Sincronizada(promotorId);
    } catch (e) {
      _logger.log('limpeza-d1', 'Limpeza falhou (ignorado): $e');
    }
    _logger.log('fim', 'Sincronização concluída');
  }

  /// LIMPEZA D-1 (Propostas 1+2, aprovadas pelo Alan em 11/06/2026).
  /// Apaga do celular os rascunhos de fotos de DIAS ANTERIORES já
  /// confirmadas no servidor: a linha em `pending_photos` e o arquivo
  /// interno em `wizmart_fotos/`. Regras (CLAUDE.md, regras 5/6 + regra
  /// do Alan "uma vez sincronizados no Supabase, os registros D-1 do app
  /// devem ser excluídos"):
  ///
  ///   - Candidatas: fotos `uploaded` capturadas ANTES de hoje. Trabalho
  ///     de hoje, em andamento ou não enviado fica fora por definição.
  ///   - Conferência OBRIGATÓRIA antes de apagar: a URL da foto precisa
  ///     constar em `fotos_antes`/`fotos_depois` da visita NO SERVIDOR
  ///     (bucket + tabela). Sem confirmação = não apaga (tenta amanhã).
  ///   - Se a visita ainda existe local e NÃO está concluída+synced
  ///     (ex.: visita de ontem em aberto), não apaga — o grid ainda
  ///     exibe os arquivos locais (lição do caso José/PAYTEC 11/06).
  ///   - GALERIA DO CELULAR: fora do escopo SEMPRE — backup do promotor;
  ///     o app nem possui chamada de exclusão de galeria (só Gal.putImage).
  ///   - Roda 1x por dia (gate em `sync_state`), teto de consultas por
  ///     rodada pra não pesar a rede; o que não couber é avaliado amanhã.
  Future<void> _limparD1Sincronizada(int promotorId) async {
    const gate = 'limpeza_d1';
    final hoje = DateTime.now().toIso8601String().substring(0, 10);
    final estado = await _db.getSyncState(gate);
    if ((estado?.lastPullAt ?? '').startsWith(hoje)) return; // já rodou hoje

    final fotos = await (_db.select(_db.pendingPhotos)
          ..where((p) => p.status.equals('uploaded')))
        .get();
    final antigas = fotos.where((p) {
      final c = p.createdAt;
      return c.length >= 10 && c.substring(0, 10).compareTo(hoje) < 0;
    }).toList();

    // Tetos por rodada: o que não couber hoje é avaliado amanhã.
    const tetoVisitasConsultadas = 15;

    final porVisita = <int, List<PendingPhoto>>{};
    for (final p in antigas) {
      porVisita.putIfAbsent(p.visitaId, () => []).add(p);
    }

    var visitasConsultadas = 0;
    var apagadas = 0;
    var naoConfirmadas = 0;
    var semComoConfirmar = 0;
    var visitaEmUso = 0;

    for (final entry in porVisita.entries) {
      final vid = entry.key;
      final visita = await _db.getVisitaById(vid);

      // Visita ainda em uso local (não concluída/sincronizada): o grid
      // exibe esses arquivos — apagar quebraria a tela. Pula.
      if (visita != null &&
          !(visita.syncStatus == 'synced' &&
              visita.localState == 'finalizada')) {
        visitaEmUso += entry.value.length;
        continue;
      }

      // serverId: da row local; ou o próprio id quando positivo (visita
      // já consolidada cuja row local foi purgada).
      final serverId = visita?.serverId ?? (vid > 0 ? vid : null);
      if (serverId == null) {
        semComoConfirmar += entry.value.length;
        continue;
      }
      if (visitasConsultadas >= tetoVisitasConsultadas) break;
      visitasConsultadas++;

      Set<String> urlsServidor;
      try {
        final row = await _supabase
            .from('visitas')
            .select('fotos_antes,fotos_depois')
            .eq('id', serverId)
            .maybeSingle();
        final fa = (row?['fotos_antes'] as List?)?.cast<String>() ?? [];
        final fd = (row?['fotos_depois'] as List?)?.cast<String>() ?? [];
        urlsServidor = {...fa, ...fd};
      } catch (e) {
        _logger.log('limpeza-d1',
            'Falha ao consultar visita $serverId — pulando (tenta amanhã)');
        continue;
      }

      for (final p in entry.value) {
        final url = p.storageUrl ?? '';
        final confirmada = url.isNotEmpty && urlsServidor.contains(url);
        if (!confirmada) {
          naoConfirmadas++;
          _logger.log(
              'limpeza-d1',
              'NÃO apagada (URL não consta na visita $serverId do '
              'servidor): foto=${p.id} slot=${p.slot} n=${p.numero}');
          continue;
        }
        // Confirmada no servidor: apaga arquivo interno + linha do banco.
        // Só toca em arquivo DENTRO do app (wizmart_fotos/) — a cópia da
        // galeria do promotor não passa por aqui.
        try {
          final f = File(p.localPath);
          if (await f.exists()) await f.delete();
        } catch (_) {/* arquivo já ausente — segue */}
        await (_db.delete(_db.pendingPhotos)
              ..where((t) => t.id.equals(p.id)))
            .go();
        apagadas++;
        _logger.log(
            'limpeza-d1',
            'APAGADA (confirmada no servidor): visita=$vid '
            'server=$serverId foto=${p.id} slot=${p.slot} n=${p.numero} '
            'criada=${p.createdAt.length >= 10 ? p.createdAt.substring(0, 10) : p.createdAt}');
      }
    }

    _logger.log(
        'limpeza-d1',
        'Resumo: ${antigas.length} foto(s) uploaded de dias anteriores; '
        'apagadas=$apagadas, nãoConfirmadas=$naoConfirmadas, '
        'semComoConfirmar=$semComoConfirmar, visitaEmUso=$visitaEmUso');

    await _db.upsertSyncState(SyncStateCompanion(
      entityType: const Value(gate),
      lastPullAt: Value(DateTime.now().toIso8601String()),
    ));
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
      //
      // GUARD (caso Thamara 11/06, tela "Nenhuma visita agendada"): a
      // purga SÓ roda se a Edge Function respondeu 200. Antes, quando a
      // function falhava (timeout/erro no celular), a purga apagava as
      // visitas do dia e o loop seguinte não recriava nada — home vazia
      // até o próximo pull bem-sucedido. Falhou a function = mantém o
      // que está na tela e tenta de novo no próximo ciclo.
      if (efResponse.statusCode == 200) {
        _logger.log('limpeza',
            'Apagando visitas synced sem pendências (re-baixa do servidor)...');
        await _db.deleteVisitasSincronizadasSemPendencias(promotorId);
      } else {
        _logger.log('limpeza',
            'Edge Function falhou (HTTP ${efResponse.statusCode}) — purga '
            'PULADA pra não esvaziar a home sem reposição',
            erro: true);
      }

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
          // GUARD (caso Gabriel/KIAN 12/06, build 245): NUNCA zerar uma
          // visita de HOJE com evidência de trabalho. O snapshot do
          // passo 4 (reconcilia) pode ser mais velho que um INSERT que
          // acabou de acontecer — o comentário antigo dizia "qualquer
          // trabalho legítimo já chegou no servidor", o que é FALSO na
          // janela da corrida: o trabalho chegou, mas o snapshot não o
          // viu. Zerar aqui jogava o promotor de volta pro início e o
          // refazer gerava as fotos duplicadas nos arrays. A reciclagem
          // legítima (sobra de outra semana com o mesmo idTemp) não é
          // afetada: o lookup acima é restrito a HOJE, e sobra antiga
          // nunca tem row de hoje — segue caindo no upsert por PK.
          final temTrabalho = existente != null &&
              visitaTemTrabalho(
                serverId: existente.serverId,
                diaHoraAbertura: existente.diaHoraAbertura,
                statusVisita: existente.statusVisita,
              );
          if (temTrabalho) {
            puladas++;
            continue;
          }
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

    // D5: visita marcada como realizada localmente (statusVisita=3)
    // mas syncStatus continua 'pending' há mais de 1h. Pode ser que
    // o servidor não chegou a receber e ela vai virar FALTA. Enfileira
    // anomalia pra eu olhar. Não muda o estado.
    try {
      final agoraIso = DateTime.now()
          .subtract(const Duration(hours: 1))
          .toIso8601String();
      final travadas = await _db.customSelect(
        "SELECT id FROM visitas WHERE sync_status = 'pending' "
        "AND status_visita = ${AppConstants.statusRealizada} "
        "AND (synced_at IS NULL OR synced_at < ?)",
        variables: [Variable<String>(agoraIso)],
      ).get();
      for (final row in travadas) {
        final vid = row.read<int>('id');
        // ANTI-RUÍDO (C1, enxurrada Jessica 10-11/06: 1 falha de rede
        // virou 6+ issues): se o ÚLTIMO erro registrado no outbox desta
        // visita é rede transitória (DNS, timeout, conexão), o retry com
        // backoff já está cuidando — re-reportar a cada ciclo é só ruído.
        // Reporta apenas erro real ou pendência sem erro registrado
        // (situação inexplicada, essa sim merece olhar).
        final outboxDaVisita = await (_db.select(_db.outboxItems)
              ..where((o) => o.entityId.equals(vid)))
            .get();
        final ultimoErro = outboxDaVisita
            .where((o) => (o.lastError ?? '').isNotEmpty)
            .fold<String?>(null, (acc, o) => o.lastError);
        if (ultimoErro != null &&
            ErrorClassifier.textoPareceRedeTransitoria(ultimoErro)) {
          _logger.log('anomalia',
              'D5 silenciado p/ visita $vid: último erro é rede '
              'transitória (retry em curso)');
          continue;
        }
        // ignore: discarded_futures
        AnomaliaReporter.enfileirar(
          db: _db,
          tipo: 'D5-visita-realizada-pending',
          entidadeId: vid.toString(),
          resumo: 'Visita marcada como realizada localmente mas '
              'syncStatus=pending há mais de 1h.',
        );
      }
    } catch (_) {/* não crítico */}

    // Drena fila de anomalias (issues + bug photos) — só faz HTTP
    // se houver rede; tudo backoffeado e silencioso.
    try {
      await AnomaliaQueueProcessor(_db, _supabase).drenar();
    } catch (_) {/* silencioso */}
  }

  /// Converte status interno do app novo para o status_visita do Supabase
  /// (mesmos códigos do app FlutterFlow antigo).
  ///
  /// App novo: 1=agendada, 2=andamento, 3=realizada, 5=falta
  /// Servidor: 1=realizada, 2=andamento, 5=falta (não há 'agendada' no servidor)
  ///
  /// IMPORTANTE: o default anterior retornava 2 (em andamento) pra
  /// status local 1 (Agendada). Era fábrica de fantasma — qualquer
  /// caminho que enviasse INSERT/UPDATE de visita Agendada marcava
  /// o servidor como "Em andamento sem clique" (casos Felipe/Mauro/
  /// Thamara/Thiago 09-10/06). Agora lança StateError: visita
  /// Agendada NÃO deve chegar ao servidor — o guard de fantasma
  /// upstream em _processOutboxItem já descarta antes do payload.
  /// Se cair aqui é bug — queremos ver o erro em vez de silenciar.
  int _toServerStatus(int? appStatus) {
    if (appStatus == AppConstants.statusRealizada) return 1; // 3 -> 1
    if (appStatus == AppConstants.statusEmAndamento) return 2; // 2 -> 2
    if (appStatus == AppConstants.statusFalta) return 5; // 5 -> 5
    throw StateError(
        'Visita com status local Agendada (1) ou null NÃO deve virar '
        'payload pro servidor. Indica falha do guard upstream em '
        '_processOutboxItem. appStatus=$appStatus');
  }

  /// Filtra `payload` mantendo APENAS os campos que representam trabalho
  /// novo do promotor — fotos uploadadas, abertura/realizado, checks e
  /// observações. NÃO inclui `status_visita` (a menos que seja real:
  /// Realizada=1 ou Falta=5), NÃO inclui `dia_hora_agendado`, NÃO inclui
  /// identidade (promotor/gabarito/pdv/turno/título).
  ///
  /// Usado por DOIS caminhos de UPDATE no outbox:
  ///   1. UPSERT-merge (INSERT bate em conflict → busca por chave natural
  ///      → UPDATE). Antes mandava payload completo, sobrescrevendo o
  ///      status do servidor (caso Thamara 10/06).
  ///   2. UPDATE direto (row local já tem serverId). Antes mandava payload
  ///      completo — recriava fantasma da visita 120437 do Thiago toda vez
  ///      que limpeza no servidor era feita.
  ///
  /// Status_visita só sobe se for legítimo (1 Realizada / 5 Falta). Status=2
  /// (Em andamento) é bloqueado nesse filtro porque a única forma do app
  /// gerar payload com status=2 partindo de visita virgem é via fantasma —
  /// o status real "Em andamento" só existe enquanto promotor está com a
  /// tela aberta, e nesse momento ele NÃO está disparando outbox.
  Map<String, dynamic> _filtrarPayloadMinimo(Map<String, dynamic> payload) {
    const camposPermitidos = {
      'fotos_antes',
      'fotos_depois',
      'dia_hora_abertura',
      'dia_hora_realizado',
      'dia_hora_fotos_antes',
      'dia_hora_fotos_depois',
      'localizacao_abertura',
      'localizacao_encerramento',
      'localizacao_fotos_antes',
      'localizacao_fotos_depois',
      'comentarios_visita',
      'check_pergunta_1',
      'obs_pergunta_1',
      'check_pergunta_2',
      'obs_pergunta_2',
      'check_pergunta_3',
      'obs_pergunta_3',
      'check_pergunta_4',
      'obs_pergunta_4',
      'check_pergunta_5',
      'obs_pergunta_5',
      'check_pergunta_6',
      'obs_pergunta_6',
      'check_pergunta_7',
      'obs_pergunta_7',
    };
    final out = <String, dynamic>{};
    for (final k in camposPermitidos) {
      if (payload.containsKey(k)) out[k] = payload[k];
    }
    // Status só sobe se for legítimo (1=Realizada ou 5=Falta).
    // 2=Em andamento é bloqueado — só pode vir de fantasma.
    final status = payload['status_visita'];
    if (status == 1 || status == 5) {
      out['status_visita'] = status;
    }
    return out;
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
      // D4: enfileira anomalia (não muda fluxo — visita já vai subir).
      // ignore: discarded_futures
      AnomaliaReporter.enfileirar(
        db: _db,
        tipo: 'D4-discrepancia-fotos',
        entidadeId: v.id.toString(),
        resumo:
            'Visita vai subir com fotos faltando: $slot capturadas=$capturadas uploaded=$uploaded',
        contextoExtra: {
          'visitaId': v.id,
          'serverId': v.serverId,
          'operation': operation,
          'slot': slot,
          'capturadas': capturadas,
          'uploaded': uploaded,
          'faltam': capturadas - uploaded,
        },
      );
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
        // TELEMETRIA item 13: se há fotos penduradas no id morto, houve
        // PERDA por pivot (Causa A) — emite anomalia para nunca mais passar
        // invisível (o detector D4 não enxerga esse caso).
        if (fotosOrfas.isNotEmpty || fotosOrfasDepois.isNotEmpty) {
          // ignore: discarded_futures
          AnomaliaReporter.enfileirar(
            db: _db,
            tipo: 'D7-fotos-orfas-descartadas',
            entidadeId: entityId.toString(),
            resumo: 'Outbox órfão descartado com fotos penduradas: '
                'antes=${fotosOrfas.length} depois=${fotosOrfasDepois.length} '
                '(perda por pivot — Causa A)',
            contextoExtra: {
              'visitaId': entityId,
              'itemEntityId': item.entityId,
              'operation': item.operation,
              'orfasAntes': fotosOrfas.length,
              'orfasDepois': fotosOrfasDepois.length,
            },
          );
        }
        await _db.deleteOutboxItem(item.id);
        return;
      }

      // ── Guard contra "INSERT-fantasma" ──────────────────────────────────
      // Row LOCAL não-avulsa, sem serverId, sem nenhuma marca de execução
      // (abertura/realizado) é LIXO. INSERT dela criaria duplicata-fantasma
      // no servidor com status_visita=2 ("Em andamento"), porque
      // _toServerStatus(1=Agendada) retorna 2 por default — o promotor vê
      // "Em andamento sem clique" no card.
      //
      // Casos atendidos:
      //   - Felipe 222 09/06: vaga antiga 04/06, sem serverId, sem exec
      //   - Thamara 224 10/06: vaga reciclada pelo pull (dia_hora_agendado
      //     sobrescrito pra HOJE pelo upsert do pull, idTemp determinístico
      //     colidiu com row antiga), mas semanticamente é fantasma.
      //
      // Avulsa NUNCA descarta: foi o promotor que criou, dados são reais.
      // Visita com abertura OU realizado preenchidos NUNCA descarta:
      // execução offline legítima atrasada.
      final isAvulsa = visita.visitaAvulsa ?? false;
      if (visitaEhFantasma(
        isAvulsa: isAvulsa,
        serverId: visita.serverId,
        diaHoraAbertura: visita.diaHoraAbertura,
        diaHoraRealizado: visita.diaHoraRealizado,
        statusVisita: visita.statusVisita,
        fotosAntesJson: visita.fotosAntesJson,
      )) {
        _logger.log(
            'outbox',
            'DESCARTANDO fantasma: visita id=$entityId '
            'agendado=${visita.diaHoraAgendado} sem nenhum sinal de trabalho '
            '(sem serverId/abertura/realizado/status-execução/fotos)',
            erro: true);
        await _db.deletePendingPhotosByVisita(entityId);
        await _db.deleteVisitaById(entityId);
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
        // .maybeSingle (não .single): servidor pode retornar 0 rows quando
        // o INSERT bate em ON CONFLICT DO NOTHING — significa que já
        // existe uma row pra mesma chave natural (gabarito|pdv|turno|
        // dia_hora_agendado) no servidor. Antes, .single jogava PGRST116
        // e o item ficava em retry-loop infinito (caso Thiago/Luís
        // 09/06: 60+ issues D5-realizada-pending, build 220→223).
        // CUIDADO (caso Camila/Thiago 11-12/06): nesta versão da lib,
        // `.maybeSingle()` LANÇA PostgrestException PGRST116 ("Cannot
        // coerce the result to a single JSON object / result contains
        // 0 rows") quando o INSERT bate em ON CONFLICT DO NOTHING — em
        // vez de retornar null. Resultado: o UPSERT-merge abaixo era
        // CÓDIGO MORTO e o item caía em retry eterno (assinatura nos
        // logs: PGRST116 em loop + D3/D5). Tratamos a exceção como
        // "0 rows" pra que o merge finalmente rode.
        Map<String, dynamic>? res;
        try {
          res = await _supabase
              .from('visitas')
              .insert(payload)
              .select()
              .maybeSingle();
        } on PostgrestException catch (e) {
          if (ehErroZeroRows(code: e.code, message: e.message)) {
            _logger.log(
                'outbox',
                'INSERT 0 rows (PGRST116 via code OU message) — tratando '
                'como conflito e seguindo pro UPSERT-merge');
            res = null;
          } else {
            rethrow;
          }
        }
        int novoServerId;
        if (res != null) {
          novoServerId = res['id'] as int;
        } else {
          // INSERT virou no-op (conflict). Busca a row existente pela
          // chave natural e faz UPDATE em vez disso.
          _logger.log(
              'outbox',
              'INSERT 0 rows (conflict) — buscando row existente '
              'por chave natural pra fazer UPDATE');
          final existentes = await _supabase
              .from('visitas')
              .select('id')
              .eq('id_promotor_associado', visita.idPromotorAssociado as Object)
              .eq('id_gabarito_associado', visita.idGabaritoAssociado as Object)
              .eq('id_pdv_associado', visita.idPdvAssociado as Object)
              .eq('previsao_turno_realizada',
                  visita.previsaoTurnoRealizada ?? '')
              .eq('dia_hora_agendado', visita.diaHoraAgendado as Object)
              .limit(1);
          if (existentes.isEmpty) {
            // Não achou pela chave exata. Lança pra cair no catch e
            // retentar com backoff — pode ser problema transitório.
            throw Exception(
                'INSERT retornou 0 rows e SELECT por chave natural não '
                'encontrou (entityId=$entityId, gab=${visita.idGabaritoAssociado}, '
                'pdv=${visita.idPdvAssociado}, turno=${visita.previsaoTurnoRealizada}, '
                'dia=${visita.diaHoraAgendado})');
          }
          novoServerId = existentes.first['id'] as int;
          // Payload MÍNIMO: NÃO sobrescreve status nem dia_hora_agendado
          // do servidor. Só trabalho novo do promotor. Ver
          // _filtrarPayloadMinimo() pra critérios.
          final payloadMinimo = _filtrarPayloadMinimo(payload);
          if (payloadMinimo.isNotEmpty) {
            await _supabase
                .from('visitas')
                .update(payloadMinimo)
                .eq('id', novoServerId);
          }
          _logger.log(
              'outbox',
              'UPSERT-merge: row existente serverId=$novoServerId '
              'recebeu UPDATE com ${payloadMinimo.length} campos (payload mínimo, '
              'preserva status do servidor)');
        }
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
        // UPDATE direto: payload MÍNIMO, igual ao UPSERT-merge.
        // Caso Thiago 120437 (10/06): a row tinha serverId=120437 do
        // pull anterior, outbox tinha item pendente das fotos 08/06
        // antigas. O UPDATE mandava payload completo com status=2
        // (via _toServerStatus do app, antes do Conserto 1) — re-criava
        // o fantasma toda vez que a limpeza no servidor era feita.
        // Agora o UPDATE também só envia trabalho do promotor.
        final payloadMinimo = _filtrarPayloadMinimo(payload);
        if (payloadMinimo.isEmpty) {
          _logger.log(
              'outbox',
              'UPDATE skip: payload mínimo vazio (nenhum trabalho '
              'novo pra enviar). serverId=${visita.serverId} op=${item.operation}');
        } else {
          final res = await _supabase
              .from('visitas')
              .update(payloadMinimo)
              .eq('id', visita.serverId!)
              .select();
          _logger.log(
              'outbox',
              'UPDATE OK localId=$entityId serverId=${visita.serverId} '
              'op=${item.operation} rowsAfetadas=${res.length} '
              '(payload mínimo, ${payloadMinimo.length} campos)');
          if (res.isEmpty) {
            _logger.log(
                'outbox',
                'AVISO: UPDATE 0 rows. serverId=${visita.serverId} pode não existir no servidor.',
                erro: true);
          }
        }
        await _db.updateVisita(VisitasCompanion(
          id: Value(entityId),
          syncStatus: const Value('synced'),
          syncedAt: Value(DateTime.now().toIso8601String()),
        ));
      }
      await _db.deleteOutboxItem(item.id);
    } catch (e, st) {
      _logger.log('outbox', 'Falha entityId=$entityId: $e', erro: true);
      final attempts = item.attempts + 1;
      final delaySeconds = min(pow(2, attempts).toInt() * 30, 1800);
      final nextRetry =
          DateTime.now().add(Duration(seconds: delaySeconds)).toIso8601String();
      // D3: outbox item travado há > 2h E erro classificado como real
      // (4xx, payload bad, constraint violado etc) → enfileira anomalia.
      // Mantém o item em pending (não vira error — outbox semântica é
      // diferente da photo), e o backoff continua tentando.
      try {
        final criado = DateTime.tryParse(item.createdAt);
        final classe = ErrorClassifier.classificar(e,
            statusCode: _extrairHttpStatus(e));
        if (criado != null &&
            DateTime.now().difference(criado) > const Duration(hours: 2) &&
            (classe == ClassificacaoErro.erroReal || attempts > 5)) {
          // ignore: discarded_futures
          AnomaliaReporter.enfileirar(
            db: _db,
            tipo: 'D3-outbox-stuck',
            entidadeId: entityId.toString(),
            resumo: 'Outbox travado: $attempts tentativas, '
                'classe=${classe.name}',
            contextoExtra: {
              'visitaId': entityId,
              'outboxId': item.id,
              'operation': item.operation,
              'attempts': attempts,
              'classe': classe.name,
              'criadoEm': item.createdAt,
            },
            erro: e,
            stack: st,
          );
        }
      } catch (_) {/* não crítico */}
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
      // Classifica: rede transitória → pending com backoff (atual);
      // erro real (4xx, file apagado, formato inválido) → vira 'error' +
      // anomalia enfileirada + upload pro bug-reports bucket.
      final statusCode = _extrairHttpStatus(e);
      final classe =
          ErrorClassifier.classificar(e, statusCode: statusCode);
      if (classe == ClassificacaoErro.erroReal) {
        // Marca como error pra destravar o outbox dessa visita.
        await _db.updatePendingPhoto(PendingPhotosCompanion(
          id: Value(photo.id),
          status: const Value('error'),
          attempts: Value(photo.attempts + 1),
          lastError: Value(e.toString()),
        ));
        // D1: enfileira anomalia + upload pro bucket de bug-report.
        final visita = await _db.getVisitaById(photo.visitaId);
        final promotorId = visita?.idPromotorAssociado ?? 0;
        // ignore: discarded_futures
        AnomaliaReporter.enfileirarBugPhoto(
          db: _db,
          fotoId: photo.id,
          localPath: photo.localPath,
          promotorId: promotorId,
          visitaId: photo.visitaId,
        );
        // ignore: discarded_futures
        AnomaliaReporter.enfileirar(
          db: _db,
          tipo: 'D1-upload-erro-real',
          entidadeId: photo.visitaId.toString(),
          resumo: 'Upload de foto falhou com erro real (${classe.name}): $e',
          contextoExtra: {
            'fotoId': photo.id,
            'slot': photo.slot,
            'numero': photo.numero,
            'visitaId': photo.visitaId,
            'httpStatus': statusCode,
            'attempts': photo.attempts + 1,
          },
          erro: e,
          stack: st,
        );
        return;
      }
      // Rede transitória / desconhecido → comportamento atual (backoff).
      final attempts = photo.attempts + 1;
      final delaySeconds = min(pow(2, attempts).toInt() * 30, 1800);
      final nextRetry =
          DateTime.now().add(Duration(seconds: delaySeconds)).toIso8601String();
      await _db.updatePendingPhoto(PendingPhotosCompanion(
        id: Value(photo.id),
        status: const Value('pending'),
        attempts: Value(attempts),
        nextRetryAt: Value(nextRetry),
        lastError: Value(e.toString()),
      ));
    }
  }

  /// Tenta extrair HTTP status code da exceção. Retorna null se não
  /// for um erro de HTTP/Supabase com código.
  int? _extrairHttpStatus(Object e) {
    if (e is StorageException) {
      return int.tryParse(e.statusCode ?? '');
    }
    if (e is PostgrestException) {
      return int.tryParse(e.code ?? '');
    }
    return null;
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
