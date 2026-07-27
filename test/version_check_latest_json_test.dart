// Auto-update via Supabase (build 264): o Android passou a consultar o
// `latest.json` do Storage em vez do release v-latest do GitHub (morto
// com a suspensão da conta em 24/06). Testa o parsing/decisão
// (`parseLatestJson`) — fail-open em tudo que for inválido.
//
// Nota: em teste, AppConstants.buildNumber = '0' (defaultValue do
// dart-define), então qualquer buildNumber numérico > 0 no JSON deve
// marcar desatualizado.

import 'package:flutter_test/flutter_test.dart';
import 'package:wizmart_app/core/network/version_check_service.dart';

void main() {
  test('build mais novo → outdated, com URL e flag do JSON', () {
    final info = VersionCheckService.parseLatestJson({
      'buildNumber': '264',
      'apkUrl': 'https://x/promotor-wizmart.apk',
      'forceUpdate': false,
      'publishedAt': '2026-07-21T18:00:00Z',
    });
    expect(info.outdated, true);
    expect(info.latestBuild, '264');
    expect(info.apkDownloadUrl, 'https://x/promotor-wizmart.apk');
    expect(info.forceUpdate, false);
    expect(info.publishedAt, isNotNull);
    // Sem forceUpdate e sem BUILD_TIME local válido ('local' em teste),
    // a obrigatoriedade D+1 NÃO dispara (mesma regra da era GitHub).
    expect(info.atualizacaoObrigatoria, false);
  });

  test('forceUpdate=true no JSON → obrigatória imediatamente', () {
    final info = VersionCheckService.parseLatestJson({
      'buildNumber': '264',
      'apkUrl': 'https://x/promotor-wizmart.apk',
      'forceUpdate': true,
    });
    expect(info.outdated, true);
    expect(info.atualizacaoObrigatoria, true);
  });

  test('fail-open: campos ausentes/ inválidos nunca marcam outdated', () {
    for (final json in <Map<String, dynamic>>[
      {},
      {'buildNumber': '264'}, // sem apkUrl
      {'apkUrl': 'https://x/a.apk'}, // sem buildNumber
      {'buildNumber': '', 'apkUrl': ''},
      {'buildNumber': 'abc', 'apkUrl': 'https://x/a.apk'}, // não numérico
    ]) {
      final info = VersionCheckService.parseLatestJson(json);
      expect(info.outdated, false, reason: 'json: $json');
      expect(info.atualizacaoObrigatoria, false, reason: 'json: $json');
    }
  });

  test('buildNumber numérico igual/menor não marca outdated', () {
    // Local é '0' em teste; simula latest '0' (igual).
    final info = VersionCheckService.parseLatestJson({
      'buildNumber': '0',
      'apkUrl': 'https://x/a.apk',
    });
    expect(info.outdated, false);
  });
}
