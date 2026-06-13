// lib/core/database/app_database.dart

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../constants/app_constants.dart';

part 'app_database.g.dart';

// ─── TABELAS ─────────────────────────────────────────────────────────────────

class Users extends Table {
  IntColumn get id => integer()();
  TextColumn get nome => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get foto => text().nullable()();
  IntColumn get tipoUser => integer().nullable()();
  BoolColumn get ativo => boolean().withDefault(const Constant(true))();
  TextColumn get areaAtuacao => text().nullable()();
  TextColumn get telefone => text().nullable()();
  TextColumn get syncedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Pdvs extends Table {
  IntColumn get id => integer()();
  TextColumn get apiLocalName => text().nullable()();
  TextColumn get apiLocalCustomerName => text().nullable()();
  TextColumn get endereco => text().nullable()();
  TextColumn get apiSpecificLocation => text().nullable()();
  RealColumn get lat => real().nullable()();
  RealColumn get lng => real().nullable()();
  BoolColumn get situacao => boolean().nullable()();
  TextColumn get syncedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Gabaritos extends Table {
  IntColumn get id => integer()();
  TextColumn get nome => text().nullable()();
  IntColumn get pdvAssociado => integer()();
  IntColumn get rotaAssociada => integer().nullable()();
  IntColumn get promotorAssociado => integer().nullable()();
  BoolColumn get ativo => boolean().withDefault(const Constant(true))();
  BoolColumn get padrao => boolean().withDefault(const Constant(false))();
  TextColumn get prazoValidade => text().nullable()();
  TextColumn get syncedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Visitas extends Table {
  IntColumn get id => integer()();
  IntColumn get idPdvAssociado => integer().nullable()();
  IntColumn get idPromotorAssociado => integer().nullable()();
  TextColumn get diaHoraAgendado => text().nullable()();
  TextColumn get diaHoraRealizado => text().nullable()();
  TextColumn get diaHoraAbertura => text().nullable()();

  // Status local: 1=agendada 2=andamento 3=realizada 5=falta
  IntColumn get statusVisita => integer().nullable()();
  IntColumn get rotaAssociada => integer().nullable()();
  IntColumn get idGabaritoAssociado => integer().nullable()();

  // Campos vindos da Edge Function / Supabase
  TextColumn get titulo => text().nullable()();
  TextColumn get previsaoTurnoRealizada => text().nullable()();
  BoolColumn get visitaAvulsa => boolean().nullable()();

  // ID no servidor (auth.users / supabase). null = visita ainda não foi
  // criada no servidor (offline ou aguardando primeiro INSERT). Quando
  // sync_engine fizer INSERT na tabela 'visitas', preenche esse campo
  // com o id retornado. O 'id' local nunca muda, evitando bugs de
  // referência (PendingPhotos, OutboxItems).
  IntColumn get serverId => integer().nullable()();

  // Localização
  TextColumn get localizacaoAbertura => text().nullable()();
  TextColumn get localizacaoEncerramento => text().nullable()();
  TextColumn get diaHoraFotosAntes => text().nullable()();
  TextColumn get diaHoraFotosDepois => text().nullable()();
  TextColumn get localizacaoFotosAntes => text().nullable()();
  TextColumn get localizacaoFotosDepois => text().nullable()();

  // Fotos
  TextColumn get fotosAntesJson => text().nullable()();
  TextColumn get fotosDepoisJson => text().nullable()();

  // Checklist
  BoolColumn get checkPergunta1 => boolean().nullable()();
  TextColumn get obsPergunta1 => text().nullable()();
  BoolColumn get checkPergunta2 => boolean().nullable()();
  TextColumn get obsPergunta2 => text().nullable()();
  BoolColumn get checkPergunta3 => boolean().nullable()();
  TextColumn get obsPergunta3 => text().nullable()();
  BoolColumn get checkPergunta4 => boolean().nullable()();
  TextColumn get obsPergunta4 => text().nullable()();
  BoolColumn get checkPergunta5 => boolean().nullable()();
  TextColumn get obsPergunta5 => text().nullable()();
  BoolColumn get checkPergunta6 => boolean().nullable()();
  TextColumn get obsPergunta6 => text().nullable()();
  BoolColumn get checkPergunta7 => boolean().nullable()();
  TextColumn get obsPergunta7 => text().nullable()();

  TextColumn get comentariosVisita => text().nullable()();

  // syncStatus: 'synced' | 'pending' | 'error'
  TextColumn get syncStatus => text().withDefault(const Constant('synced'))();
  TextColumn get syncedAt => text().nullable()();

  // localState: 'idle' | 'abertura' | 'fotos_antes' | 'em_reposicao' | 'fotos_depois' | 'checklist' | 'finalizada'
  TextColumn get localState => text().withDefault(const Constant('idle'))();

  @override
  Set<Column> get primaryKey => {id};
}

class OutboxItems extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text()();
  TextColumn get operation => text()();
  IntColumn get entityId => integer()();
  TextColumn get payloadJson => text()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get nextRetryAt => text()();
  TextColumn get lastError => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get createdAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class PendingPhotos extends Table {
  TextColumn get id => text()();
  IntColumn get visitaId => integer()();
  TextColumn get slot => text()();
  IntColumn get numero => integer()();
  TextColumn get localPath => text()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get storageUrl => text().nullable()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get nextRetryAt => text()();
  TextColumn get createdAt => text()();
  /// Última mensagem de erro do upload — populada quando status='error'.
  /// Adicionado no schema 5 pra ajudar diagnóstico via auto-issue.
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class SyncState extends Table {
  TextColumn get entityType => text()();
  TextColumn get lastPullAt => text().nullable()();
  TextColumn get lastPushAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {entityType};
}

/// Fila local de issues a enviar pro GitHub. Detectada anomalia (erro
/// real, NÃO rede transitória) grava aqui — envio acontece quando há
/// rede, com mesmo backoff exponencial do outbox.
class PendingIssues extends Table {
  TextColumn get id => text()();
  /// Tipo da anomalia (D1, D2, ..., manual). Usado pra cooldown +
  /// label no issue.
  TextColumn get tipo => text()();
  /// id da entidade alvo (visitaId, fotoId, outboxId). Combinado com
  /// `tipo` forma a chave de cooldown.
  TextColumn get entidadeId => text().nullable()();
  TextColumn get titulo => text()();
  /// Body completo já montado no momento da detecção (dump SQLite,
  /// log, sondas). Texto markdown pronto pra postar.
  TextColumn get bodyMd => text()();
  /// JSON array de labels (ex: ["auto","screen:home","build:215"]).
  TextColumn get labelsJson => text()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get nextRetryAt => text()();
  TextColumn get lastError => text().nullable()();
  TextColumn get createdAt => text()();
  /// Número do issue criado no GitHub depois de envio OK. Null enquanto
  /// pendente.
  IntColumn get githubIssueNumber => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Fila local de fotos físicas a subir pro bucket `bug-reports` quando
/// uma anomalia precisa anexar a foto pro recovery manual posterior.
/// Independente do upload normal — usa path separado.
class PendingBugPhotos extends Table {
  TextColumn get id => text()();
  /// id da `pending_photos` original (ref).
  TextColumn get fotoId => text()();
  /// Path local do arquivo (mesmo do pending_photos.localPath no
  /// momento da gravação).
  TextColumn get localPath => text()();
  /// Path destino no bucket bug-reports
  /// (ex: bug-reports/<promotor-id>/<visita-id>/<foto-id>.jpg).
  TextColumn get destStoragePath => text()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get nextRetryAt => text()();
  TextColumn get lastError => text().nullable()();
  TextColumn get createdAt => text()();
  /// URL pública final depois do upload OK.
  TextColumn get publicUrl => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ─── DATABASE ────────────────────────────────────────────────────────────────

@DriftDatabase(tables: [
  Users,
  Pdvs,
  Gabaritos,
  Visitas,
  OutboxItems,
  PendingPhotos,
  SyncState,
  PendingIssues,
  PendingBugPhotos,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Construtor para TESTES: recebe um executor (ex.: NativeDatabase.memory()).
  /// Não usado em produção — permite reproduzir bugs de lógica num banco
  /// SQLite em memória, sem celular nem servidor.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(visitas, visitas.titulo);
        await migrator.addColumn(visitas, visitas.previsaoTurnoRealizada);
        await migrator.addColumn(visitas, visitas.visitaAvulsa);
      }
      if (from < 3) {
        await migrator.addColumn(visitas, visitas.serverId);
        // Visitas com id positivo já vêm sincronizadas do servidor
        await customStatement(
          'UPDATE visitas SET server_id = id WHERE id > 0',
        );
      }
      if (from < 4) {
        // Limpa fotos pendentes e itens do outbox que apontam pra visitas
        // que não existem mais no SQLite (órfãs do bug pré-build 202 com
        // hash não-determinístico). Sem isso, o outbox fica em "Posterga
        // infinito" tentando processar visitas inexistentes.
        await customStatement(
          'DELETE FROM pending_photos WHERE visita_id NOT IN '
          '(SELECT id FROM visitas)',
        );
        await customStatement(
          "DELETE FROM outbox_items WHERE entity_type = 'visita' "
          'AND entity_id NOT IN (SELECT id FROM visitas)',
        );
      }
      if (from < 5) {
        // Cria as duas filas locais de anomalia: pending_issues e
        // pending_bug_photos. Drift cria automaticamente as tabelas
        // declaradas no @DriftDatabase quando ainda não existem.
        await migrator.createTable(pendingIssues);
        await migrator.createTable(pendingBugPhotos);
        // Adiciona coluna `last_error` em pending_photos pra rastrear
        // motivo da falha no auto-issue.
        await migrator.addColumn(pendingPhotos, pendingPhotos.lastError);
      }
    },
  );

  // ── Users ──────────────────────────────────────────────────────────────────

  Future<User?> getUserById(int id) =>
      (select(users)..where((u) => u.id.equals(id))).getSingleOrNull();

  // ── PDVs ───────────────────────────────────────────────────────────────────

  Future<List<Pdv>> getAllPdvs() => select(pdvs).get();

  Future<Pdv?> getPdvById(int id) =>
      (select(pdvs)..where((p) => p.id.equals(id))).getSingleOrNull();

  // ── Gabaritos ──────────────────────────────────────────────────────────────

  Future<Gabarito?> getGabaritoById(int id) =>
      (select(gabaritos)..where((g) => g.id.equals(id))).getSingleOrNull();

  Future<Gabarito?> getGabaritoByPdv(int pdvId) =>
      (select(gabaritos)
            ..where((g) => g.pdvAssociado.equals(pdvId) & g.ativo.equals(true))
            ..orderBy([(g) => OrderingTerm.desc(g.id)])
            ..limit(1))
          .getSingleOrNull();

  // ── Visitas ────────────────────────────────────────────────────────────────

  Stream<List<Visita>> watchVisitasHoje(int promotorId) {
    final hoje = DateTime.now();
    final inicioDia =
        DateTime(hoje.year, hoje.month, hoje.day).toIso8601String();
    final fimDia =
        DateTime(hoje.year, hoje.month, hoje.day, 23, 59, 59).toIso8601String();

    return (select(visitas)
          ..where((v) =>
              v.idPromotorAssociado.equals(promotorId) &
              v.diaHoraAgendado.isBetweenValues(inicioDia, fimDia) &
              v.statusVisita.isNotIn([5])))
        .watch();
  }

  Future<Visita?> getVisitaById(int id) =>
      (select(visitas)..where((v) => v.id.equals(id))).getSingleOrNull();

  Future<Visita?> getVisitaEmAndamento(int promotorId) =>
      (select(visitas)
            ..where((v) =>
                v.idPromotorAssociado.equals(promotorId) &
                v.statusVisita.equals(2)))
          .getSingleOrNull();

  /// Busca visita existente por gabarito+pdv+turno dentro de uma janela de data
  Future<Visita?> getVisitaByGabaritoTurnoData(
    int gabaritoId,
    int pdvId,
    String turno,
    String inicioDia,
    String fimDia,
  ) =>
      (select(visitas)
            ..where((v) =>
                v.idGabaritoAssociado.equals(gabaritoId) &
                v.idPdvAssociado.equals(pdvId) &
                v.previsaoTurnoRealizada.equals(turno) &
                v.diaHoraAgendado.isBetweenValues(inicioDia, fimDia)))
          .getSingleOrNull();

  /// Remove visitas agendadas do dia que não foram modificadas localmente
  Future<void> deleteVisitasAgendadasHojeNaoModificadas(int promotorId) {
    final hoje = DateTime.now();
    final inicioDia =
        DateTime(hoje.year, hoje.month, hoje.day).toIso8601String();
    final fimDia =
        DateTime(hoje.year, hoje.month, hoje.day, 23, 59, 59).toIso8601String();

    return (delete(visitas)
          ..where((v) =>
              v.idPromotorAssociado.equals(promotorId) &
              v.statusVisita.equals(1) &
              v.syncStatus.equals('synced') &
              v.diaHoraAgendado.isBetweenValues(inicioDia, fimDia)))
        .go();
  }

  /// Estratégia "destruir + re-baixar": apaga TODAS as visitas do
  /// promotor que já estão sincronizadas (`syncStatus='synced'`) E
  /// não têm pendências (nenhum outbox item nem pending photo
  /// referenciando-as). O pullAll subsequente vai recriar tudo a
  /// partir do servidor, garantindo que app e servidor fiquem
  /// idênticos. Visitas pending/em upload são preservadas pra serem
  /// enviadas no próximo push.
  Future<void> deleteVisitasSincronizadasSemPendencias(int promotorId) async {
    // IDs de visitas com outbox items ainda não finalizados.
    final outboxRows = await (select(outboxItems)
          ..where((o) =>
              o.status.equals('pending') | o.status.equals('processing')))
        .get();
    final naoApagar = <int>{};
    for (final o in outboxRows) {
      naoApagar.add(o.entityId);
    }

    // IDs de visitas com fotos ainda em fila — inclui 'watermark_pending'
    // (não só pending/uploading). Sem isso, se o INSERT 'open' fosse
    // processado por um _triggerSync da home ANTES da watermark queue
    // terminar, o pull subsequente apagava a row id=idTemp e recriava
    // com id=serverId. As pending_photos órfãs com visitaId=idTemp
    // depois tentavam enfileirar 'photos_antes' UPDATE que era
    // descartado por "visita não encontrada" — fotos subiam pro
    // Storage mas o array fotos_antes na tabela ficava vazio.
    // (Cleiton/Edilson 2026-05-19/20.)
    final photoRows = await (select(pendingPhotos)
          ..where((p) =>
              p.status.equals('watermark_pending') |
              p.status.equals('pending') |
              p.status.equals('uploading')))
        .get();
    for (final p in photoRows) {
      naoApagar.add(p.visitaId);
    }

    final query = delete(visitas)
      ..where((v) =>
          v.idPromotorAssociado.equals(promotorId) &
          v.syncStatus.equals('synced') &
          // PROTEÇÃO A2 (item 14 / regra do Alan): NUNCA purgar visita em
          // execução. Status 2 = Em Andamento; localState fora de
          // idle/finalizada = etapa em curso. Sem isso, depois que o
          // `open` sobe (visita vira synced) o pull apagava e recriava a
          // visita como "agendada" → promotor via "Iniciar" e perdia o
          // "antes" (caso Felipe 122556, 13/06; perda real no Thiago 121455).
          v.statusVisita.equals(AppConstants.statusEmAndamento).not() &
          v.localState.isIn(const ['idle', 'finalizada']));
    if (naoApagar.isNotEmpty) {
      query.where((v) => v.id.isNotIn(naoApagar.toList()));
    }
    await query.go();
  }

  Future<void> upsertVisita(VisitasCompanion visita) =>
      into(visitas).insertOnConflictUpdate(visita);

  /// Retorna o nº de linhas afetadas. 0 = a visita com aquele id não
  /// existe (id obsoleto/órfão) — o caller pode logar pra detectar o
  /// "write silenciosamente perdido" que o id pivotado causaria.
  Future<int> updateVisita(VisitasCompanion visita) =>
      (update(visitas)..where((v) => v.id.equals(visita.id.value)))
          .write(visita);

  Future<Visita?> getVisitaByServerId(int serverId) =>
      (select(visitas)..where((v) => v.serverId.equals(serverId)))
          .getSingleOrNull();

  /// Consolida uma visita recém-inserida no servidor sob a PK = serverId.
  ///
  /// CAUSA RAIZ histórica: a visita "vaga" nascia com PK = idTemp negativo
  /// (-hash). PendingPhotos.visitaId e OutboxItems.entityId apontavam pra
  /// esse idTemp. O INSERT setava só o campo serverId, mantendo a PK idTemp
  /// — mas o pull recriava a visita com PK = serverId (upsert). As duas
  /// premissas conflitavam: a row idTemp era deletada/duplicada e as fotos
  /// + outbox ficavam ÓRFÃS (getUploadedPhotoUrls não achava as URLs,
  /// _processOutboxItem descartava por "visita não encontrada"). Fotos
  /// iam pro bucket mas nunca eram vinculadas à tabela.
  ///
  /// Solução: ao receber o serverId no INSERT, migra a PK idTemp→serverId
  /// E re-vincula fotos e outbox na MESMA transação. A partir daí tudo
  /// referencia serverId — alinhado com o que o pull (upsert id=serverId)
  /// já espera. Sem órfãos, sem duplicatas, sem pivot.
  Future<void> consolidarVisitaNoServer(int idLocal, int serverId) async {
    final agora = DateTime.now().toIso8601String();
    if (idLocal == serverId) {
      // Já alinhado (re-edição de visita já sincronizada). Só marca synced.
      await (update(visitas)..where((v) => v.id.equals(idLocal))).write(
        VisitasCompanion(
          serverId: Value(serverId),
          syncStatus: const Value('synced'),
          syncedAt: Value(agora),
        ),
      );
      return;
    }
    await transaction(() async {
      // Mapa de migração (item 2): registra idLocal→serverId para a tela
      // de visita reapontar, via `idVigente`, escritas que ainda usem o
      // id antigo (Causa A — pivot com a tela aberta).
      await into(syncState).insertOnConflictUpdate(SyncStateCompanion(
        entityType: Value('migra:$idLocal'),
        lastPushAt: Value(serverId.toString()),
        lastPullAt: Value(agora),
      ));
      // CAUSA HISTÓRICA do bug "realizadas viram em andamento": a
      // implementação antiga deletava a row com PK=serverId (vinda do
      // pull, com dados frescos do servidor) e PRESERVAVA todos os
      // campos da row idLocal (idTemp negativo, dados velhos da semana
      // passada). Casos Jessica/Felipe/Thamara 09-10/06 onde uma vaga
      // do dia ganhava "Em andamento" ou perdia dia_hora_realizado.
      //
      // Agora: se já existe row local com PK=serverId, PRESERVAMOS os
      // campos dela (frescos do servidor) e migramos APENAS o trabalho
      // novo da row idLocal — pending_photos e outbox vinculados. Os
      // campos de execução (abertura/realizado/fotos/checks/obs) que
      // o promotor preencheu localmente já foram enviados pelo INSERT
      // que originou o serverId — o servidor é a fonte de verdade.
      final existenteServer = await (select(visitas)
            ..where((v) => v.id.equals(serverId)))
          .getSingleOrNull();
      if (existenteServer != null) {
        // Preserva campos da row do servidor — só atualiza sync state.
        await (update(visitas)..where((v) => v.id.equals(serverId))).write(
          VisitasCompanion(
            serverId: Value(serverId),
            syncStatus: const Value('synced'),
            syncedAt: Value(agora),
          ),
        );
        // Migra pending_photos e outbox da row idLocal pro serverId,
        // depois apaga a row idLocal.
        await (update(pendingPhotos)..where((p) => p.visitaId.equals(idLocal)))
            .write(PendingPhotosCompanion(visitaId: Value(serverId)));
        await (update(outboxItems)..where((o) => o.entityId.equals(idLocal)))
            .write(OutboxItemsCompanion(entityId: Value(serverId)));
        await (delete(visitas)..where((v) => v.id.equals(idLocal))).go();
        return;
      }
      // Não há row pré-existente com PK=serverId — migra a idLocal pra
      // ela (caso comum de visita avulsa nascida offline).
      await (update(visitas)..where((v) => v.id.equals(idLocal))).write(
        VisitasCompanion(
          id: Value(serverId),
          serverId: Value(serverId),
          syncStatus: const Value('synced'),
          syncedAt: Value(agora),
        ),
      );
      await (update(pendingPhotos)..where((p) => p.visitaId.equals(idLocal)))
          .write(PendingPhotosCompanion(visitaId: Value(serverId)));
      await (update(outboxItems)..where((o) => o.entityId.equals(idLocal)))
          .write(OutboxItemsCompanion(entityId: Value(serverId)));
    });
  }

  Future<Map<String, int>> getContadoresHoje(int promotorId) async {
    final hoje = DateTime.now();
    final inicioDia =
        DateTime(hoje.year, hoje.month, hoje.day).toIso8601String();
    final fimDia =
        DateTime(hoje.year, hoje.month, hoje.day, 23, 59, 59).toIso8601String();

    final todas = await (select(visitas)
          ..where((v) =>
              v.idPromotorAssociado.equals(promotorId) &
              v.diaHoraAgendado.isBetweenValues(inicioDia, fimDia)))
        .get();

    return {
      'agendadas': todas.length,
      'realizadas': todas.where((v) => v.statusVisita == 3).length,
      'faltas': todas.where((v) => v.statusVisita == 5).length,
    };
  }

  // ── Outbox ─────────────────────────────────────────────────────────────────

  Future<List<OutboxItem>> getPendingOutboxItems() {
    final agora = DateTime.now().toIso8601String();
    return (select(outboxItems)
          ..where((o) =>
              o.status.equals('pending') &
              o.nextRetryAt.isSmallerOrEqualValue(agora))
          ..orderBy([(o) => OrderingTerm.asc(o.createdAt)])
          ..limit(10))
        .get();
  }

  Future<void> insertOutboxItem(OutboxItemsCompanion item) =>
      into(outboxItems).insert(item);

  Future<void> updateOutboxItem(OutboxItemsCompanion item) =>
      (update(outboxItems)..where((o) => o.id.equals(item.id.value)))
          .write(item);

  Future<void> deleteOutboxItem(String id) =>
      (delete(outboxItems)..where((o) => o.id.equals(id))).go();

  // ── Recovery de estados intermediários no boot ──────────────────────────
  //
  // Estados `uploading` e `watermark_pending` só existem durante execução
  // ativa do app. Se o app foi morto (OOM, swipe-out, crash, bateria),
  // as fotos ficam congeladas nesses estados e travam o outbox da visita
  // pra sempre (countFotosEmProgresso retorna > 0).
  //
  // Estes dois métodos são chamados UMA VEZ no boot do app antes do
  // SyncEngine subir.

  /// Reseta fotos em `uploading` pra `pending`. O upload Storage é
  /// idempotente (x-upsert: true) — se foto já subiu mas o status ficou
  /// preso, retry sobrescreve mesmo arquivo. Loga quantas foram resetadas.
  Future<int> resetUploadingNoBoot() async {
    final agora = DateTime.now().toIso8601String();
    final n = await (update(pendingPhotos)
          ..where((p) => p.status.equals('uploading')))
        .write(PendingPhotosCompanion(
      status: const Value('pending'),
      nextRetryAt: Value(agora),
    ));
    return n;
  }

  /// Retorna pending_photos que estão em `watermark_pending` — caller
  /// usa pra re-enfileirar no WatermarkQueueService. Agrupado por
  /// (visitaId, slot) é responsabilidade do caller.
  Future<List<PendingPhoto>> getStaleWatermarkPending() {
    return (select(pendingPhotos)
          ..where((p) => p.status.equals('watermark_pending')))
        .get();
  }

  /// Conta itens não-sincronizados (qualquer status que não seja terminal).
  /// Usado para bloquear ações destrutivas (download de APK nova,
  /// logoff opcionalmente, etc.) enquanto há dados pendentes.
  Future<int> countPendentesParaSync() async {
    final outboxCount = await (select(outboxItems)
          ..where((o) =>
              o.status.equals('pending') | o.status.equals('processing')))
        .get()
        .then((r) => r.length);
    final photosCount = await (select(pendingPhotos)
          ..where((p) =>
              p.status.equals('pending') |
              p.status.equals('uploading') |
              p.status.equals('error')))
        .get()
        .then((r) => r.length);
    final visitasPending = await (select(visitas)
          ..where((v) => v.syncStatus.equals('pending')))
        .get()
        .then((r) => r.length);
    return outboxCount + photosCount + visitasPending;
  }

  /// Stream das visitas que estão sendo sincronizadas AGORA — não as que
  /// estão só na fila. "Agora" = tem foto com status='uploading' OU outbox
  /// com status='processing' apontando pra ela. O sync engine seta esses
  /// status só pelo tempo da operação, então o stream esvazia naturalmente
  /// quando o item termina. Cards na home filtram por id pra desenhar o
  /// ícone de setas circulares.
  Stream<Set<int>> watchVisitasSincronizandoAtivamente() {
    final q = customSelect(
      "SELECT DISTINCT v.id FROM visitas v "
      "WHERE EXISTS (SELECT 1 FROM pending_photos pp "
      "              WHERE pp.visita_id = v.id "
      "                AND pp.status = 'uploading') "
      "   OR EXISTS (SELECT 1 FROM outbox_items oi "
      "              WHERE oi.entity_id = v.id "
      "                AND oi.entity_type = 'visita' "
      "                AND oi.status = 'processing')",
      readsFrom: {visitas, pendingPhotos, outboxItems},
    );
    return q.watch().map((rows) =>
        rows.map((r) => r.read<int>('id')).toSet());
  }

  /// Conta visitas DISTINTAS que têm qualquer pendência de sincronismo
  /// (foto ainda não enviada OU outbox da visita ainda não processado OU
  /// a row da visita marcada como pending). Bate com a noção do usuário:
  /// "visita só deixa de ser pendente quando todas as fotos sobem". Stream
  /// reativo para que o badge na home atualize quando a fila esvazia.
  Stream<int> watchVisitasComPendencia() {
    final q = customSelect(
      "SELECT COUNT(DISTINCT v.id) AS c FROM visitas v "
      "WHERE v.sync_status = 'pending' "
      "OR EXISTS (SELECT 1 FROM pending_photos pp "
      "           WHERE pp.visita_id = v.id "
      "             AND pp.status IN ('watermark_pending','pending','uploading','error')) "
      "OR EXISTS (SELECT 1 FROM outbox_items oi "
      "           WHERE oi.entity_id = v.id "
      "             AND oi.entity_type = 'visita' "
      "             AND oi.status IN ('pending','processing'))",
      readsFrom: {visitas, pendingPhotos, outboxItems},
    );
    return q.watchSingle().map((row) => row.read<int>('c'));
  }

  // ── Pending Photos ─────────────────────────────────────────────────────────

  Future<List<PendingPhoto>> getPendingPhotos() {
    final agora = DateTime.now().toIso8601String();
    return (select(pendingPhotos)
          ..where((p) =>
              p.status.equals('pending') &
              p.nextRetryAt.isSmallerOrEqualValue(agora))
          ..orderBy([(p) => OrderingTerm.asc(p.createdAt)])
          ..limit(5))
        .get();
  }

  Future<void> insertPendingPhoto(PendingPhotosCompanion photo) =>
      into(pendingPhotos).insert(photo);

  Future<void> updatePendingPhoto(PendingPhotosCompanion photo) =>
      (update(pendingPhotos)..where((p) => p.id.equals(photo.id.value)))
          .write(photo);

  /// Busca fotos pendentes de uma visita+slot ordenadas por `numero`
  /// (mesma ordem do grid). Usado pra aplicar watermark em batch na
  /// hora de concluir uma etapa.
  Future<List<PendingPhoto>> getPendingPhotosByVisitaSlot(
          int visitaId, String slot) =>
      (select(pendingPhotos)
            ..where((p) =>
                p.visitaId.equals(visitaId) & p.slot.equals(slot))
            ..orderBy([(p) => OrderingTerm.asc(p.numero)]))
          .get();

  /// Apaga registros de upload pendente para a foto cujo path local foi
  /// removido pelo usuário no grid. Usado pelo botão "X" da grade de fotos.
  Future<void> deletePendingPhotosByPath(String localPath) =>
      (delete(pendingPhotos)..where((p) => p.localPath.equals(localPath)))
          .go();

  /// Apaga todas as pending_photos de uma visita. Usado pelo guard
  /// "descarte de visita-fantasma" do sync engine.
  Future<int> deletePendingPhotosByVisita(int visitaId) =>
      (delete(pendingPhotos)..where((p) => p.visitaId.equals(visitaId)))
          .go();

  /// Apaga a row da visita pelo id. Usado pelo guard de descarte.
  Future<int> deleteVisitaById(int id) =>
      (delete(visitas)..where((v) => v.id.equals(id))).go();

  /// Conta fotos da visita+slot que ainda estão EM PROGRESSO local
  /// (watermark_pending, pending, uploading). Usado pelo sync engine
  /// pra postergar operações que tocariam o servidor antes do
  /// processamento local terminar.
  ///
  /// 'error' NÃO conta como em-progresso: é estado terminal e
  /// irrecuperável (o arquivo local sumiu — ver _processPhotoUpload).
  /// Antes 'error' era contado e travava o outbox da visita PRA SEMPRE
  /// — a operação era postergada indefinidamente e a visita nunca
  /// sincronizava. Agora a visita sincroniza com as fotos que subiram;
  /// a que falhou (arquivo inexistente) fica de fora, sem bloquear.
  Future<int> countFotosEmProgresso(int visitaId, String slot) async {
    final rows = await (select(pendingPhotos)
          ..where((p) =>
              p.visitaId.equals(visitaId) &
              p.slot.equals(slot) &
              (p.status.equals('watermark_pending') |
                  p.status.equals('pending') |
                  p.status.equals('uploading'))))
        .get();
    return rows.length;
  }

  /// Retorna URLs públicas das fotos já uploadadas para uma visita+slot,
  /// ordenadas pelo número da foto. Usado pelo sync engine para preencher
  /// fotos_antes/fotos_depois no payload da visita.
  Future<List<String>> getUploadedPhotoUrls(int visitaId, String slot) async {
    final rows = await (select(pendingPhotos)
          ..where((p) =>
              p.visitaId.equals(visitaId) &
              p.slot.equals(slot) &
              p.status.equals('uploaded'))
          ..orderBy([(p) => OrderingTerm(expression: p.numero)]))
        .get();
    return rows
        .map((r) => r.storageUrl)
        .where((u) => u != null && u.isNotEmpty)
        .cast<String>()
        // DEDUP (item 4): se o promotor refez fotos após um reset/pivot,
        // pode haver 2+ pending_photos com a MESMA URL (nome de arquivo
        // determinístico + upsert no Storage). O Set (LinkedHashSet)
        // remove repetidas PRESERVANDO a ordem de inserção — sem isso o
        // array fotos_antes/depois do servidor subia com URLs duplicadas
        // (Diego 122527, Renato 122383/122384).
        .toSet()
        .toList();
  }

  // ── Sync State ─────────────────────────────────────────────────────────────

  Future<SyncStateData?> getSyncState(String entityType) =>
      (select(syncState)
            ..where((s) => s.entityType.equals(entityType)))
          .getSingleOrNull();

  Future<void> upsertSyncState(SyncStateCompanion state) =>
      into(syncState).insertOnConflictUpdate(state);

  // ── Lock de sync CROSS-PROCESS ───────────────────────────────────────────
  //
  // O app em foreground e o isolate do WorkManager abrem o MESMO arquivo
  // SQLite, mas são processos/isolates distintos — um lock em memória
  // (campo bool) NÃO é compartilhado entre eles. Sem lock real, os dois
  // rodavam push+pull ao mesmo tempo: o pull de um deletava local
  // (deleteVisitasSincronizadasSemPendencias) enquanto o push do outro
  // inseria, abrindo a janela de fotos/outbox órfãos que vinha causando
  // as visitas com fotos sumidas mesmo após os fixes em memória.
  //
  // Implementação: UPDATE condicional numa linha dedicada da SyncState
  // ('__sync_lock__'). O UPDATE é atômico no SQLite (serializado por
  // busy_timeout), então só UM processo consegue adquirir. lastPullAt
  // guarda o instante de expiração (millis, zero-pad pra comparação
  // lexicográfica == numérica) e lastPushAt guarda o dono.
  static const _lockRow = '__sync_lock__';

  static String _ts(int millis) => millis.toString().padLeft(15, '0');

  /// Tenta adquirir o lock. Retorna true se conseguiu. O lock expira
  /// sozinho após [ttlMs] — protege contra um isolate que morra segurando
  /// o lock (crash, kill do SO).
  Future<bool> tryAcquireSyncLock(
      {required String holder, required int ttlMs}) async {
    final agora = DateTime.now().millisecondsSinceEpoch;
    // Garante a existência da linha de lock sem sobrescrever um lock ativo.
    await into(syncState).insert(
      SyncStateCompanion(
        entityType: const Value(_lockRow),
        lastPullAt: Value(_ts(0)),
      ),
      mode: InsertMode.insertOrIgnore,
    );
    // Adquire só se o lock anterior já expirou (until < agora). UPDATE
    // condicional atômico: o 2º processo concorrente vê o until já no
    // futuro (escrito pelo 1º) e não casa o WHERE → 0 linhas.
    final rows = await (update(syncState)
          ..where((s) =>
              s.entityType.equals(_lockRow) &
              s.lastPullAt.isSmallerThanValue(_ts(agora))))
        .write(SyncStateCompanion(
      lastPullAt: Value(_ts(agora + ttlMs)),
      lastPushAt: Value(holder),
    ));
    return rows > 0;
  }

  /// Libera o lock apenas se [holder] for o dono atual (evita um processo
  /// liberar o lock que outro adquiriu depois da expiração).
  Future<void> releaseSyncLock(String holder) async {
    await (update(syncState)
          ..where((s) =>
              s.entityType.equals(_lockRow) & s.lastPushAt.equals(holder)))
        .write(SyncStateCompanion(lastPullAt: Value(_ts(0))));
  }

  /// Renova o prazo do lock SE [holder] for o dono atual. Usado durante um
  /// ciclo de sync longo (rede ruim) pra a trava NÃO expirar no meio e
  /// deixar o WorkManager (outro processo) entrar em paralelo rodando pull
  /// destrutivo — a Causa D. Retorna true se renovou (ainda é o dono).
  Future<bool> renewSyncLock(
      {required String holder, required int ttlMs}) async {
    final agora = DateTime.now().millisecondsSinceEpoch;
    final rows = await (update(syncState)
          ..where((s) =>
              s.entityType.equals(_lockRow) & s.lastPushAt.equals(holder)))
        .write(SyncStateCompanion(lastPullAt: Value(_ts(agora + ttlMs))));
    return rows > 0;
  }

  /// Mapa de migração idLocal→serverId (item 2). `consolidarVisitaNoServer`
  /// grava aqui quando troca a PK; a tela de visita consulta `idVigente`
  /// para reapontar escritas que cairiam no id antigo (Causa A — pivot com
  /// a tela aberta). Sem isso, foto/finalizar caíam num id morto.
  Future<int> idVigente(int id) async {
    final row = await (select(syncState)
          ..where((s) => s.entityType.equals('migra:$id')))
        .getSingleOrNull();
    return int.tryParse(row?.lastPushAt ?? '') ?? id;
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'wizmart.sqlite'));
    return NativeDatabase.createInBackground(
      file,
      setup: (rawDb) {
        // WAL permite leitura concorrente com escrita.
        // busy_timeout faz queries esperarem até 5s antes de retornar locked.
        // Necessário porque o callbackDispatcher do WorkManager pode abrir
        // conexão paralela com o app principal.
        rawDb.execute('PRAGMA journal_mode=WAL');
        rawDb.execute('PRAGMA busy_timeout=5000');
        rawDb.execute('PRAGMA synchronous=NORMAL');
      },
    );
  });
}
