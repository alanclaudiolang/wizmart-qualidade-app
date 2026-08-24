// test/caso_brenda_colisao_entre_dias_test.dart
//
// Caso Brenda (21/08/2026, build 262): o idTemp determinístico
// (gabarito|pdv|turno, SEM data) repete entre dias. A vaga de hoje,
// criada por upsert na MESMA PK, sobrescrevia a visita de ONTEM ainda
// não consolidada (zerava execução); o guard de fantasma então apagava
// row + outbox — o trabalho de 20/08 nunca chegou ao servidor (visita
// 138520 ficou Incompleta vazia) e as fotos foram sobrescritas no
// bucket pelas de hoje (mesmo nome de arquivo).
//
// Correções testadas aqui (build 273):
//   1. SyncEngine.vagaColideComVisitaDeOutroDia — pula a vaga de hoje
//      enquanto a PK estiver ocupada por visita de outro dia com
//      trabalho/pendências.
//   2. SyncEngine.fantasmaDeveSerPreservado — fantasma com fotos em
//      pending_photos é preservado (estaciona) em vez de apagado.
//   3. AppDatabase.countFotosNaoErroDaVisita — a contagem que alimenta
//      o item 2 (inclui 'uploaded', exclui 'error').
//   4. SyncEngine.nomeArquivoFoto — data da CAPTURA no nome do arquivo:
//      dias diferentes nunca dividem o mesmo nome no bucket.

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wizmart_app/core/database/app_database.dart';
import 'package:wizmart_app/core/network/sync_engine.dart';

void main() {
  // Janela de HOJE nos mesmos moldes do _pullVisitasDia (UTC ISO).
  final hoje = DateTime(2026, 8, 21);
  final inicioDia = hoje.toUtc().toIso8601String();
  final fimDia =
      DateTime(2026, 8, 21, 23, 59, 59).toUtc().toIso8601String();

  group('vagaColideComVisitaDeOutroDia (guard cross-day do pull)', () {
    test('row de HOJE nunca é colisão, mesmo com trabalho/pendências', () {
      expect(
        SyncEngine.vagaColideComVisitaDeOutroDia(
          diaHoraAgendadoRow:
              DateTime(2026, 8, 21, 5).toUtc().toIso8601String(),
          inicioDiaUtc: inicioDia,
          fimDiaUtc: fimDia,
          temTrabalho: true,
          syncPending: true,
          fotosEmVoo: 3,
          outboxPendentes: 2,
        ),
        isFalse,
      );
    });

    test('row de ONTEM com trabalho (caso Brenda: status 2 + abertura) '
        '→ pula a vaga', () {
      expect(
        SyncEngine.vagaColideComVisitaDeOutroDia(
          diaHoraAgendadoRow:
              DateTime(2026, 8, 20, 8).toUtc().toIso8601String(),
          inicioDiaUtc: inicioDia,
          fimDiaUtc: fimDia,
          temTrabalho: true,
          syncPending: false,
          fotosEmVoo: 0,
          outboxPendentes: 0,
        ),
        isTrue,
      );
    });

    test('row de ONTEM sem trabalho mas com syncStatus pending → pula', () {
      expect(
        SyncEngine.vagaColideComVisitaDeOutroDia(
          diaHoraAgendadoRow:
              DateTime(2026, 8, 20, 8).toUtc().toIso8601String(),
          inicioDiaUtc: inicioDia,
          fimDiaUtc: fimDia,
          temTrabalho: false,
          syncPending: true,
          fotosEmVoo: 0,
          outboxPendentes: 0,
        ),
        isTrue,
      );
    });

    test('row de ONTEM com foto em voo → pula', () {
      expect(
        SyncEngine.vagaColideComVisitaDeOutroDia(
          diaHoraAgendadoRow:
              DateTime(2026, 8, 20, 8).toUtc().toIso8601String(),
          inicioDiaUtc: inicioDia,
          fimDiaUtc: fimDia,
          temTrabalho: false,
          syncPending: false,
          fotosEmVoo: 1,
          outboxPendentes: 0,
        ),
        isTrue,
      );
    });

    test('row de ONTEM com outbox pendente → pula', () {
      expect(
        SyncEngine.vagaColideComVisitaDeOutroDia(
          diaHoraAgendadoRow:
              DateTime(2026, 8, 20, 8).toUtc().toIso8601String(),
          inicioDiaUtc: inicioDia,
          fimDiaUtc: fimDia,
          temTrabalho: false,
          syncPending: false,
          fotosEmVoo: 0,
          outboxPendentes: 1,
        ),
        isTrue,
      );
    });

    test('row de ONTEM LIMPA (sobra reciclável) → NÃO pula '
        '(comportamento antigo preservado)', () {
      expect(
        SyncEngine.vagaColideComVisitaDeOutroDia(
          diaHoraAgendadoRow:
              DateTime(2026, 8, 14, 8).toUtc().toIso8601String(),
          inicioDiaUtc: inicioDia,
          fimDiaUtc: fimDia,
          temTrabalho: false,
          syncPending: false,
          fotosEmVoo: 0,
          outboxPendentes: 0,
        ),
        isFalse,
      );
    });

    test('data no formato do servidor (-03:00) de ontem → pula com trabalho',
        () {
      expect(
        SyncEngine.vagaColideComVisitaDeOutroDia(
          diaHoraAgendadoRow: '2026-08-20T05:00:00-03:00',
          inicioDiaUtc: inicioDia,
          fimDiaUtc: fimDia,
          temTrabalho: true,
          syncPending: false,
          fotosEmVoo: 0,
          outboxPendentes: 0,
        ),
        isTrue,
      );
    });

    test('data não-parseável: protege se houver sinal, recicla se limpa', () {
      expect(
        SyncEngine.vagaColideComVisitaDeOutroDia(
          diaHoraAgendadoRow: 'lixo-nao-data',
          inicioDiaUtc: inicioDia,
          fimDiaUtc: fimDia,
          temTrabalho: true,
          syncPending: false,
          fotosEmVoo: 0,
          outboxPendentes: 0,
        ),
        isTrue,
      );
      expect(
        SyncEngine.vagaColideComVisitaDeOutroDia(
          diaHoraAgendadoRow: null,
          inicioDiaUtc: inicioDia,
          fimDiaUtc: fimDia,
          temTrabalho: false,
          syncPending: false,
          fotosEmVoo: 0,
          outboxPendentes: 0,
        ),
        isFalse,
      );
    });
  });

  group('fantasmaDeveSerPreservado (endurecimento do guard)', () {
    test('sem nenhuma foto → descarta como antes', () {
      expect(
          SyncEngine.fantasmaDeveSerPreservado(fotosNaoErro: 0), isFalse);
    });
    test('com foto (qualquer status exceto error) → preserva', () {
      expect(SyncEngine.fantasmaDeveSerPreservado(fotosNaoErro: 1), isTrue);
      expect(
          SyncEngine.fantasmaDeveSerPreservado(fotosNaoErro: 16), isTrue);
    });
  });

  group('espelho do caso Brenda no banco (in-memory)', () {
    late AppDatabase db;
    const idTemp = -573155151;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> seedVisitaDeOntemComTrabalho() async {
      // Estado da Brenda em 21/08 08:43: visita de ONTEM sob idTemp,
      // status 2 (Em Andamento), abertura preenchida, syncStatus
      // pending, foto uploaded + foto em watermark_pending, outbox
      // open/close pendentes.
      await db.upsertVisita(VisitasCompanion(
        id: const Value(idTemp),
        idPdvAssociado: const Value(1667),
        idPromotorAssociado: const Value(612),
        idGabaritoAssociado: const Value(14252),
        previsaoTurnoRealizada: const Value('manha'),
        diaHoraAgendado:
            Value(DateTime(2026, 8, 20, 8).toUtc().toIso8601String()),
        diaHoraAbertura:
            Value(DateTime(2026, 8, 20, 8, 5).toIso8601String()),
        statusVisita: const Value(2),
        localState: const Value('fotos_depois'),
        syncStatus: const Value('pending'),
        fotosAntesJson: const Value('["/a/f1.jpg"]'),
      ));
      await db.insertPendingPhoto(PendingPhotosCompanion(
        id: const Value('foto-uploaded'),
        visitaId: const Value(idTemp),
        slot: const Value('antes'),
        numero: const Value(1),
        localPath: const Value('/a/f1.jpg'),
        status: const Value('uploaded'),
        storageUrl: const Value('https://x/f1.jpg'),
        nextRetryAt: Value(DateTime(2026, 8, 20).toIso8601String()),
        createdAt: Value(DateTime(2026, 8, 20, 8, 10).toIso8601String()),
      ));
      await db.insertPendingPhoto(PendingPhotosCompanion(
        id: const Value('foto-travada'),
        visitaId: const Value(idTemp),
        slot: const Value('depois'),
        numero: const Value(1),
        localPath: const Value('/a/d1_raw.jpg'),
        status: const Value('watermark_pending'),
        nextRetryAt: Value(DateTime(2026, 8, 20).toIso8601String()),
        createdAt: Value(DateTime(2026, 8, 20, 11, 16).toIso8601String()),
      ));
      await db.insertOutboxItem(OutboxItemsCompanion(
        id: const Value('op-open'),
        entityType: const Value('visita'),
        operation: const Value('open'),
        entityId: const Value(idTemp),
        payloadJson: const Value('{}'),
        nextRetryAt: Value(DateTime(2026, 8, 20).toIso8601String()),
        createdAt: Value(DateTime(2026, 8, 20).toIso8601String()),
      ));
    }

    test('a decisão composta (mesma fiação do pull) PULA a vaga de hoje',
        () async {
      await seedVisitaDeOntemComTrabalho();

      // Fiação idêntica ao _pullVisitasDia pós-correção:
      final rowMesmoPk = await db.getVisitaById(idTemp);
      expect(rowMesmoPk, isNotNull);
      final fotosEmVoo = await db.getPendingPhotosEmVoo(idTemp);
      final outboxPend = await (db.select(db.outboxItems)
            ..where((o) =>
                o.entityId.equals(idTemp) &
                (o.status.equals('pending') |
                    o.status.equals('processing'))))
          .get();

      final pula = SyncEngine.vagaColideComVisitaDeOutroDia(
        diaHoraAgendadoRow: rowMesmoPk!.diaHoraAgendado,
        inicioDiaUtc: inicioDia,
        fimDiaUtc: fimDia,
        temTrabalho: SyncEngine.visitaTemTrabalho(
          serverId: rowMesmoPk.serverId,
          diaHoraAbertura: rowMesmoPk.diaHoraAbertura,
          statusVisita: rowMesmoPk.statusVisita,
        ),
        syncPending: rowMesmoPk.syncStatus == 'pending',
        fotosEmVoo: fotosEmVoo.length,
        outboxPendentes: outboxPend.length,
      );
      expect(pula, isTrue,
          reason: 'a vaga de hoje NÃO pode sobrescrever a visita de ontem');

      // E a visita de ontem permanece intacta no banco.
      final aposDecisao = await db.getVisitaById(idTemp);
      expect(aposDecisao!.diaHoraAbertura, isNotNull);
      expect(aposDecisao.statusVisita, 2);
    });

    test('countFotosNaoErroDaVisita conta uploaded + travada, ignora error',
        () async {
      await seedVisitaDeOntemComTrabalho();
      await db.insertPendingPhoto(PendingPhotosCompanion(
        id: const Value('foto-error'),
        visitaId: const Value(idTemp),
        slot: const Value('antes'),
        numero: const Value(9),
        localPath: const Value('/a/morta.jpg'),
        status: const Value('error'),
        nextRetryAt: Value(DateTime(2026, 8, 20).toIso8601String()),
        createdAt: Value(DateTime(2026, 8, 20).toIso8601String()),
      ));
      expect(await db.countFotosNaoErroDaVisita(idTemp), 2);
      // E portanto o fantasma seria preservado:
      expect(
        SyncEngine.fantasmaDeveSerPreservado(
            fotosNaoErro: await db.countFotosNaoErroDaVisita(idTemp)),
        isTrue,
      );
    });

    test('sobra antiga LIMPA continua reciclável (decisão composta = não pular)',
        () async {
      // Sobra de semana passada: mesma PK, sem trabalho, synced, sem
      // fotos, sem outbox — o upsert por PK pode reusar (comportamento
      // antigo preservado).
      await db.upsertVisita(VisitasCompanion(
        id: const Value(idTemp),
        idPdvAssociado: const Value(1667),
        idPromotorAssociado: const Value(612),
        idGabaritoAssociado: const Value(14252),
        previsaoTurnoRealizada: const Value('manha'),
        diaHoraAgendado:
            Value(DateTime(2026, 8, 14, 8).toUtc().toIso8601String()),
        statusVisita: const Value(1),
        localState: const Value('idle'),
        syncStatus: const Value('synced'),
      ));
      final row = await db.getVisitaById(idTemp);
      final fotosEmVoo = await db.getPendingPhotosEmVoo(idTemp);
      final outboxPend = await (db.select(db.outboxItems)
            ..where((o) =>
                o.entityId.equals(idTemp) &
                (o.status.equals('pending') |
                    o.status.equals('processing'))))
          .get();
      final pula = SyncEngine.vagaColideComVisitaDeOutroDia(
        diaHoraAgendadoRow: row!.diaHoraAgendado,
        inicioDiaUtc: inicioDia,
        fimDiaUtc: fimDia,
        temTrabalho: SyncEngine.visitaTemTrabalho(
          serverId: row.serverId,
          diaHoraAbertura: row.diaHoraAbertura,
          statusVisita: row.statusVisita,
        ),
        syncPending: row.syncStatus == 'pending',
        fotosEmVoo: fotosEmVoo.length,
        outboxPendentes: outboxPend.length,
      );
      expect(pula, isFalse);
    });
  });

  group('colisaoPodeRealocar (2ª decisão do guard cross-day)', () {
    test('nada em uso/em voo → pode realocar (libera a vaga JÁ)', () {
      expect(
        SyncEngine.colisaoPodeRealocar(
          telaAberta: false,
          processandoAtivo: false,
          fotosEmVoo: 0,
          outboxPendentes: 0,
        ),
        isTrue,
      );
    });
    test('qualquer coisa em uso/em voo → NÃO realoca (só adia a vaga)', () {
      expect(
        SyncEngine.colisaoPodeRealocar(
          telaAberta: true,
          processandoAtivo: false,
          fotosEmVoo: 0,
          outboxPendentes: 0,
        ),
        isFalse,
      );
      expect(
        SyncEngine.colisaoPodeRealocar(
          telaAberta: false,
          processandoAtivo: true,
          fotosEmVoo: 0,
          outboxPendentes: 0,
        ),
        isFalse,
      );
      expect(
        SyncEngine.colisaoPodeRealocar(
          telaAberta: false,
          processandoAtivo: false,
          fotosEmVoo: 2,
          outboxPendentes: 0,
        ),
        isFalse,
      );
      expect(
        SyncEngine.colisaoPodeRealocar(
          telaAberta: false,
          processandoAtivo: false,
          fotosEmVoo: 0,
          outboxPendentes: 1,
        ),
        isFalse,
      );
    });
  });

  group('realocarVisitaLocalParaIdLivre (preserva tudo, libera a PK)', () {
    late AppDatabase db;
    const idTemp = -573155151;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('move a row inteira e re-vincula fotos + outbox', () async {
      await db.upsertVisita(VisitasCompanion(
        id: const Value(idTemp),
        idPdvAssociado: const Value(1667),
        idPromotorAssociado: const Value(612),
        idGabaritoAssociado: const Value(14252),
        previsaoTurnoRealizada: const Value('manha'),
        titulo: const Value('MM RJ - VOLKSWAGEN CONTEINER'),
        diaHoraAgendado:
            Value(DateTime(2026, 8, 20, 8).toUtc().toIso8601String()),
        diaHoraAbertura:
            Value(DateTime(2026, 8, 20, 8, 5).toIso8601String()),
        statusVisita: const Value(2),
        localState: const Value('fotos_depois'),
        syncStatus: const Value('pending'),
        fotosAntesJson: const Value('["/a/f1.jpg"]'),
        checkPergunta1: const Value(true),
        obsPergunta1: const Value('obs preservada'),
      ));
      await db.insertPendingPhoto(PendingPhotosCompanion(
        id: const Value('foto-1'),
        visitaId: const Value(idTemp),
        slot: const Value('antes'),
        numero: const Value(1),
        localPath: const Value('/a/f1.jpg'),
        status: const Value('uploaded'),
        storageUrl: const Value('https://x/f1.jpg'),
        nextRetryAt: Value(DateTime(2026, 8, 20).toIso8601String()),
        createdAt: Value(DateTime(2026, 8, 20).toIso8601String()),
      ));
      await db.insertOutboxItem(OutboxItemsCompanion(
        id: const Value('op-estacionada'),
        entityType: const Value('visita'),
        operation: const Value('open'),
        entityId: const Value(idTemp),
        payloadJson: const Value('{}'),
        status: const Value('error'),
        nextRetryAt: Value(DateTime(2026, 8, 20).toIso8601String()),
        createdAt: Value(DateTime(2026, 8, 20).toIso8601String()),
      ));

      final novoId = await db.realocarVisitaLocalParaIdLivre(idTemp);

      expect(novoId, isNot(equals(idTemp)));
      expect(novoId, lessThan(idTemp)); // negativo livre abaixo
      // PK antiga liberada:
      expect(await db.getVisitaById(idTemp), null);
      // Row inteira preservada sob o novo id:
      final movida = await db.getVisitaById(novoId);
      expect(movida, isNotNull);
      expect(movida!.diaHoraAbertura, isNotNull);
      expect(movida.statusVisita, 2);
      expect(movida.titulo, 'MM RJ - VOLKSWAGEN CONTEINER');
      expect(movida.obsPergunta1, 'obs preservada');
      expect(movida.fotosAntesJson, '["/a/f1.jpg"]');
      // Fotos e outbox re-vinculados:
      final fotos =
          await db.getPendingPhotosByVisitaSlot(novoId, 'antes');
      expect(fotos, hasLength(1));
      expect(fotos.first.storageUrl, 'https://x/f1.jpg');
      final outbox = await (db.select(db.outboxItems)
            ..where((o) => o.entityId.equals(novoId)))
          .get();
      expect(outbox, hasLength(1));
      final outboxAntigo = await (db.select(db.outboxItems)
            ..where((o) => o.entityId.equals(idTemp)))
          .get();
      expect(outboxAntigo, isEmpty);
    });

    test('procura id livre quando o candidato imediato está ocupado',
        () async {
      // Ocupa idTemp e idTemp-1 — a realocação deve pular pro -2.
      for (final id in [idTemp, idTemp - 1]) {
        await db.upsertVisita(VisitasCompanion(
          id: Value(id),
          idPromotorAssociado: const Value(612),
          diaHoraAgendado:
              Value(DateTime(2026, 8, 20, 8).toUtc().toIso8601String()),
          statusVisita: const Value(2),
          syncStatus: const Value('pending'),
        ));
      }
      final novoId = await db.realocarVisitaLocalParaIdLivre(idTemp);
      expect(novoId, idTemp - 2);
      expect(await db.getVisitaById(idTemp), null);
      expect(await db.getVisitaById(idTemp - 1), isNotNull); // intocada
      expect(await db.getVisitaById(idTemp - 2), isNotNull);
    });
  });

  group('nomeArquivoFoto (data da captura no nome)', () {
    test('dias diferentes → nomes diferentes (fim da sobrescrita)', () {
      final ontem = SyncEngine.nomeArquivoFoto(
        nomeSeg: 'MM_RJ_-_VOLKSWAGEN_CONTEINER_',
        visitaHash: 573155151,
        createdAt: DateTime(2026, 8, 20, 11, 16).toIso8601String(),
        slot: 'depois',
        numero: 1,
        extSeg: 'jpg',
      );
      final hojeNome = SyncEngine.nomeArquivoFoto(
        nomeSeg: 'MM_RJ_-_VOLKSWAGEN_CONTEINER_',
        visitaHash: 573155151,
        createdAt: DateTime(2026, 8, 21, 10, 40).toIso8601String(),
        slot: 'depois',
        numero: 1,
        extSeg: 'jpg',
      );
      expect(ontem, isNot(equals(hojeNome)));
      expect(ontem, contains('20260820'));
      expect(hojeNome, contains('20260821'));
    });

    test('mesma foto (mesmo createdAt) → nome determinístico entre retries',
        () {
      String gera() => SyncEngine.nomeArquivoFoto(
            nomeSeg: 'PDV',
            visitaHash: 123,
            createdAt: '2026-08-21T10:40:00.000',
            slot: 'antes',
            numero: 3,
            extSeg: 'jpg',
          );
      expect(gera(), gera());
      expect(gera(), 'PDV-123-20260821-antes-3.jpg');
    });

    test('createdAt inválido → formato antigo (sem segmento de data)', () {
      expect(
        SyncEngine.nomeArquivoFoto(
          nomeSeg: 'PDV',
          visitaHash: 123,
          createdAt: 'nao-e-data',
          slot: 'antes',
          numero: 1,
          extSeg: 'jpg',
        ),
        'PDV-123-antes-1.jpg',
      );
    });

    test('segmentoDataCaptura aceita ISO com e sem offset', () {
      expect(SyncEngine.segmentoDataCaptura('2026-08-21T10:40:00.000'),
          '20260821');
      expect(
          SyncEngine.segmentoDataCaptura('2026-01-05T00:01:00Z'), '20260105');
      expect(SyncEngine.segmentoDataCaptura(''), '');
    });
  });
}
