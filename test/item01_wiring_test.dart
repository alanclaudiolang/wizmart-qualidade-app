// Item 1 (Causa A) — FIAÇÃO no fluxo real do outbox.
//
// Reproduz o #4135 (Thiago, build 251): o pivô idTemp→serverId acontecia
// ENQUANTO o promotor ainda capturava fotos "depois" com a tela aberta;
// a foto seguinte apontava pro idTemp morto e era descartada como órfã
// (D7). `consolidacaoDeveEsperar` lê o DB + sinais de UI e decide ADIAR o
// pivô nesse cenário — fechando a brecha que o `Posterga` (que só olha o
// slot da operação) não cobria.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wizmart_app/core/database/app_database.dart';
import 'package:wizmart_app/core/network/sync_engine.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  const idTemp = -1031635450; // o mesmo idTemp do #4135

  Future<void> inserirVisita({String? abertura}) async {
    await db.into(db.visitas).insert(VisitasCompanion(
          id: const Value(idTemp),
          idPromotorAssociado: const Value(115),
          serverId: const Value(null), // ainda não consolidada → pivô pendente
          statusVisita: const Value(2),
          localState: const Value('fotos_depois'),
          diaHoraAbertura: Value(abertura),
        ));
  }

  Future<void> inserirFotoDepois(
      {required String status, required String createdAt, int n = 5}) async {
    await db.into(db.pendingPhotos).insert(PendingPhotosCompanion.insert(
          id: 'f$n-$status',
          visitaId: idTemp,
          slot: 'depois',
          numero: n,
          localPath: '/f$n.jpg',
          status: Value(status),
          nextRetryAt: 'x',
          createdAt: createdAt,
        ));
  }

  String agora() => DateTime.now().toIso8601String();
  String haHoras(int h) =>
      DateTime.now().subtract(Duration(hours: h)).toIso8601String();

  test('#4135: tela aberta + foto "depois" em voo → ADIA o pivô (não vira órfã)',
      () async {
    await inserirVisita(abertura: agora());
    await inserirFotoDepois(status: 'watermark_pending', createdAt: agora());

    final esperar = await SyncEngine.consolidacaoDeveEsperar(
      db, idTemp,
      telaAberta: true, // promotor dentro da tela capturando "depois"
      processandoAtivo: false,
    );
    expect(esperar, isTrue,
        reason: 'pivô durante captura = foto órfã descartada (D7 #4135)');
  });

  test('tela aberta, mas TODAS as fotos já subiram e nada processando '
      '→ ainda ADIA enquanto a tela está aberta (só consolida ao sair)',
      () async {
    await inserirVisita(abertura: agora());
    await inserirFotoDepois(status: 'uploaded', createdAt: agora());

    final esperar = await SyncEngine.consolidacaoDeveEsperar(
      db, idTemp,
      telaAberta: true,
      processandoAtivo: false,
    );
    expect(esperar, isTrue,
        reason: 'tela aberta = visita em uso; pivô espera ela ficar ociosa');
  });

  test('visita ociosa (tela fechada, sem foto em voo) → NÃO adia '
      '(consolida normalmente ao finalizar)', () async {
    await inserirVisita(abertura: agora());
    await inserirFotoDepois(status: 'uploaded', createdAt: agora());

    final esperar = await SyncEngine.consolidacaoDeveEsperar(
      db, idTemp,
      telaAberta: false,
      processandoAtivo: false,
    );
    expect(esperar, isFalse,
        reason: 'sem sinal de uso, o pivô deve rodar e a visita sincronizar');
  });

  test('anti-trava: foto presa em voo há mais de 2h → NÃO adia '
      '(não trava a visita pra sempre)', () async {
    await inserirVisita(abertura: haHoras(3));
    await inserirFotoDepois(status: 'watermark_pending', createdAt: haHoras(3));

    final esperar = await SyncEngine.consolidacaoDeveEsperar(
      db, idTemp,
      telaAberta: true,
      processandoAtivo: true,
    );
    expect(esperar, isFalse,
        reason: 'timeout de 2h libera o pivô mesmo com flags presas');
  });
}
