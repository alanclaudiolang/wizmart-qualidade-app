// Item 1 (Causa A) — adiar a consolidação enquanto a visita está em uso,
// para a PK não trocar sob a tela aberta.
// Item 9 (Causa E) — nunca montar caminho de upload sem sessão (authUid).

import 'package:flutter_test/flutter_test.dart';
import 'package:wizmart_app/core/network/sync_engine.dart';

void main() {
  group('Item 1 — deveAdiarConsolidacao (Causa A)', () {
    const novinha = Duration(minutes: 1);

    test('tela aberta → ADIA (não troca o id sob os pés do promotor)', () {
      expect(
          SyncEngine.deveAdiarConsolidacao(
            telaAberta: true,
            processandoAtivo: false,
            fotosWatermarkPending: 0,
            idadeDesdeUltimaAtividade: novinha,
          ),
          isTrue);
    });

    test('foto em watermark pendente → ADIA', () {
      expect(
          SyncEngine.deveAdiarConsolidacao(
            telaAberta: false,
            processandoAtivo: false,
            fotosWatermarkPending: 2,
            idadeDesdeUltimaAtividade: novinha,
          ),
          isTrue);
    });

    test('nada em uso → NÃO adia (consolida normalmente)', () {
      expect(
          SyncEngine.deveAdiarConsolidacao(
            telaAberta: false,
            processandoAtivo: false,
            fotosWatermarkPending: 0,
            idadeDesdeUltimaAtividade: novinha,
          ),
          isFalse);
    });

    test('timeout de 2h → NÃO adia mesmo com tela aberta (anti-travamento)',
        () {
      expect(
          SyncEngine.deveAdiarConsolidacao(
            telaAberta: true,
            processandoAtivo: true,
            fotosWatermarkPending: 5,
            idadeDesdeUltimaAtividade: const Duration(hours: 3),
          ),
          isFalse);
    });
  });

  group('Item 9 — construirStoragePath (Causa E)', () {
    test('authUid vazio → null (não sobe com path quebrado /…//…)', () {
      expect(
          SyncEngine.construirStoragePath(
            authUid: '',
            dataSeg: '2026-06-13_05-00-00',
            nomeSeg: 'PDV',
            visitaHash: 123,
            slot: 'antes',
            numero: 1,
            extSeg: 'jpg',
          ),
          isNull,
          reason: 'BUG E: path com segmento vazio → 403 RLS, sync travado dias');
    });

    test('authUid presente → caminho correto', () {
      expect(
          SyncEngine.construirStoragePath(
            authUid: 'uid-1',
            dataSeg: '2026-06-13_05-00-00',
            nomeSeg: 'PDV',
            visitaHash: 123,
            slot: 'antes',
            numero: 1,
            extSeg: 'jpg',
          ),
          'abastecimentos/uid-1/2026-06-13_05-00-00/PDV-123-antes-1.jpg');
    });
  });
}
