// lib/core/database/app_database.dart

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

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

// ─── DATABASE ────────────────────────────────────────────────────────────────

@DriftDatabase(tables: [
  Users,
  Pdvs,
  Gabaritos,
  Visitas,
  OutboxItems,
  PendingPhotos,
  SyncState,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(visitas, visitas.titulo);
        await migrator.addColumn(visitas, visitas.previsaoTurnoRealizada);
        await migrator.addColumn(visitas, visitas.visitaAvulsa);
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

  Future<void> upsertVisita(VisitasCompanion visita) =>
      into(visitas).insertOnConflictUpdate(visita);

  Future<void> updateVisita(VisitasCompanion visita) =>
      (update(visitas)..where((v) => v.id.equals(visita.id.value)))
          .write(visita);

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

  /// Apaga registros de upload pendente para a foto cujo path local foi
  /// removido pelo usuário no grid. Usado pelo botão "X" da grade de fotos.
  Future<void> deletePendingPhotosByPath(String localPath) =>
      (delete(pendingPhotos)..where((p) => p.localPath.equals(localPath)))
          .go();

  /// Migra todas as referências de uma visita criada offline (id negativo)
  /// para o id real recebido do servidor após o primeiro INSERT.
  /// Atualiza: Visitas (PK), OutboxItems.entityId, PendingPhotos.visitaId.
  Future<void> migrateVisitaId(int oldId, int newId) async {
    await transaction(() async {
      // Não dá para fazer UPDATE em coluna PK no SQLite via Drift.
      // Estratégia: insere nova linha com id real, depois apaga a antiga.
      final old = await (select(visitas)..where((v) => v.id.equals(oldId)))
          .getSingleOrNull();
      if (old != null) {
        await into(visitas).insertOnConflictUpdate(
          VisitasCompanion.insert(
            id: Value(newId),
            idPdvAssociado: Value(old.idPdvAssociado),
            idPromotorAssociado: Value(old.idPromotorAssociado),
            diaHoraAgendado: Value(old.diaHoraAgendado),
            diaHoraRealizado: Value(old.diaHoraRealizado),
            diaHoraAbertura: Value(old.diaHoraAbertura),
            statusVisita: Value(old.statusVisita),
            rotaAssociada: Value(old.rotaAssociada),
            idGabaritoAssociado: Value(old.idGabaritoAssociado),
            titulo: Value(old.titulo),
            previsaoTurnoRealizada: Value(old.previsaoTurnoRealizada),
            visitaAvulsa: Value(old.visitaAvulsa),
            localizacaoAbertura: Value(old.localizacaoAbertura),
            localizacaoEncerramento: Value(old.localizacaoEncerramento),
            localizacaoFotosAntes: Value(old.localizacaoFotosAntes),
            localizacaoFotosDepois: Value(old.localizacaoFotosDepois),
            diaHoraFotosAntes: Value(old.diaHoraFotosAntes),
            diaHoraFotosDepois: Value(old.diaHoraFotosDepois),
            fotosAntesJson: Value(old.fotosAntesJson),
            fotosDepoisJson: Value(old.fotosDepoisJson),
            checkPergunta1: Value(old.checkPergunta1),
            obsPergunta1: Value(old.obsPergunta1),
            checkPergunta2: Value(old.checkPergunta2),
            obsPergunta2: Value(old.obsPergunta2),
            checkPergunta3: Value(old.checkPergunta3),
            obsPergunta3: Value(old.obsPergunta3),
            checkPergunta4: Value(old.checkPergunta4),
            obsPergunta4: Value(old.obsPergunta4),
            checkPergunta5: Value(old.checkPergunta5),
            obsPergunta5: Value(old.obsPergunta5),
            checkPergunta6: Value(old.checkPergunta6),
            obsPergunta6: Value(old.obsPergunta6),
            checkPergunta7: Value(old.checkPergunta7),
            obsPergunta7: Value(old.obsPergunta7),
            localState: Value(old.localState),
            syncStatus: const Value('synced'),
            syncedAt: Value(DateTime.now().toIso8601String()),
          ),
        );
        await (delete(visitas)..where((v) => v.id.equals(oldId))).go();
      }
      // Migra fotos pendentes
      await (update(pendingPhotos)..where((p) => p.visitaId.equals(oldId)))
          .write(PendingPhotosCompanion(visitaId: Value(newId)));
      // Migra outbox items
      await (update(outboxItems)
            ..where((o) => o.entityId.equals(oldId)))
          .write(OutboxItemsCompanion(entityId: Value(newId)));
    });
  }

  // ── Sync State ─────────────────────────────────────────────────────────────

  Future<SyncStateData?> getSyncState(String entityType) =>
      (select(syncState)
            ..where((s) => s.entityType.equals(entityType)))
          .getSingleOrNull();

  Future<void> upsertSyncState(SyncStateCompanion state) =>
      into(syncState).insertOnConflictUpdate(state);
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
