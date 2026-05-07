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
  IntColumn get statusVisita => integer().nullable()();
  IntColumn get rotaAssociada => integer().nullable()();
  IntColumn get idGabaritoAssociado => integer().nullable()();

  // Localização
  TextColumn get localizacaoAbertura => text().nullable()();
  TextColumn get localizacaoEncerramento => text().nullable()();
  TextColumn get diaHoraFotosAntes => text().nullable()();
  TextColumn get diaHoraFotosDepois => text().nullable()();
  TextColumn get localizacaoFotosAntes => text().nullable()();
  TextColumn get localizacaoFotosDepois => text().nullable()();

  // Fotos (JSON array de paths locais ou URLs)
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

  // Comentários
  TextColumn get comentariosVisita => text().nullable()();

  // Controle de sync
  // syncStatus: 'synced' | 'pending' | 'error' | 'rejected'
  TextColumn get syncStatus => text().withDefault(const Constant('synced'))();
  TextColumn get syncedAt => text().nullable()();

  // Estado local da visita (para máquina de estados)
  // localState: 'idle' | 'abertura' | 'fotos_antes' | 'em_reposicao' | 'fotos_depois' | 'checklist' | 'finalizada'
  TextColumn get localState => text().withDefault(const Constant('idle'))();

  @override
  Set<Column> get primaryKey => {id};
}

// Fila de operações pendentes de sync
class OutboxItems extends Table {
  TextColumn get id => text()(); // UUID gerado no cliente
  TextColumn get entityType => text()(); // 'visita'
  TextColumn get operation => text()(); // 'open' | 'fotos_antes' | 'fotos_depois' | 'checklist' | 'close'
  IntColumn get entityId => integer()(); // id da visita no Supabase
  TextColumn get payloadJson => text()(); // JSON do payload
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get nextRetryAt => text()();
  TextColumn get lastError => text().nullable()();
  // status: 'pending' | 'processing' | 'done' | 'dead'
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get createdAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

// Fotos pendentes de upload
class PendingPhotos extends Table {
  TextColumn get id => text()(); // UUID
  IntColumn get visitaId => integer()();
  TextColumn get slot => text()(); // 'antes' | 'depois'
  IntColumn get numero => integer()(); // 1..8
  TextColumn get localPath => text()(); // path no disco
  // status: 'pending' | 'uploading' | 'uploaded' | 'error'
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get storageUrl => text().nullable()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get nextRetryAt => text()();
  TextColumn get createdAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

// Estado de sync por entidade (para pull incremental)
class SyncState extends Table {
  TextColumn get entityType => text()(); // 'visitas' | 'pdvs' | 'gabaritos'
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
  int get schemaVersion => 1;

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
              v.statusVisita.isNotIn([5]))) // exclui faltas
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

  Future<void> upsertVisita(VisitasCompanion visita) =>
      into(visitas).insertOnConflictUpdate(visita);

  Future<void> updateVisita(VisitasCompanion visita) =>
      (update(visitas)..where((v) => v.id.equals(visita.id.value)))
          .write(visita);

  // Contadores para o totalizador da home
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
              o.status.equals('pending') & o.nextRetryAt.isSmallerOrEqualValue(agora))
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
    return NativeDatabase.createInBackground(file);
  });
}
