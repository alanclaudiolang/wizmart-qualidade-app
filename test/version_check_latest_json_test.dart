// Auto-update (build 267): Android consulta o Google Play diretamente
// (API oficial de in-app updates) — a decisão em si vive no plugin/Play
// e não é testável em unit test. Aqui cobrimos o que é nosso: a página
// fixa da loja e a regra de obrigatoriedade D+1 sobre AppVersionInfo.
//
// História: 264-266 usavam um latest.json no Supabase (havia testes de
// parsing aqui); aposentado em 28/07 — frota 100% Play.

import 'package:flutter_test/flutter_test.dart';
import 'package:wizmart_app/core/network/version_check_service.dart';

void main() {
  test('página da Play é derivada do pacote (fixa, conhecida antes da '
      'publicação)', () {
    expect(VersionCheckService.playStorePage,
        'https://play.google.com/store/apps/details?id=com.wizmart.wizmart_app');
  });

  test('outdated com appStoreUrl e sem forceUpdate → obrigatoriedade só '
      'via D+1 (BUILD_TIME local; em teste é "local" → não dispara)', () {
    const info = AppVersionInfo(
      outdated: true,
      latestBuild: '267',
      appStoreUrl: VersionCheckService.playStorePage,
    );
    expect(info.forceUpdate, false);
    expect(info.atualizacaoObrigatoria, false);
  });

  test('forceUpdate=true continua forçando imediato (usado pelo iOS)', () {
    const info = AppVersionInfo(outdated: true, forceUpdate: true);
    expect(info.atualizacaoObrigatoria, true);
  });

  test('não desatualizado nunca obriga', () {
    expect(AppVersionInfo.upToDate.atualizacaoObrigatoria, false);
  });
}
