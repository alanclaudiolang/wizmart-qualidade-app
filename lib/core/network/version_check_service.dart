// lib/core/network/version_check_service.dart
//
// Android: consulta o `latest.json` publicado no Supabase Storage pelo
// pipeline `build-apk-android` (Azure DevOps) para descobrir se há um
// build mais novo que o local:
//   {versoes-apk}/latest.json =
//     { "buildNumber": "264", "apkUrl": "<URL fixa do APK>",
//       "forceUpdate": false, "publishedAt": "<ISO-8601>" }
//
// Até o build 263 a fonte era o release `v-latest` no GitHub — morto
// desde a suspensão da conta (24/06/2026); ver
// docs/contexto/contexto-migracao-azure-2026-07-15.md. A lógica de
// obrigatoriedade (D+1 pelo BUILD_TIME local, forceUpdate imediato) é a
// MESMA de antes — só mudou a fonte consultada.
//
// Comparamos o buildNumber do JSON com o build number local
// (vindo do dart-define BUILD_NUMBER). Falha silenciosa offline.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';

class AppVersionInfo {
  final bool outdated;
  final String? latestBuild;
  final String? apkDownloadUrl;
  /// Timestamp `published_at` do release no GitHub. Mantido pra
  /// telemetria/log — não é usado pra decidir D+1 (a referência é o
  /// BUILD_TIME local, que viaja com o APK e não reseta a cada CI run).
  final DateTime? publishedAt;
  /// `true` quando o `latest.json` traz `"forceUpdate": true`. Faz a
  /// atualização ser obrigatória IMEDIATAMENTE (sem esperar o dia
  /// seguinte). Pra ativar: rodar o pipeline com FORCE_UPDATE=true (ou
  /// editar o latest.json no bucket).
  final bool forceUpdate;

  /// URL da página do app na App Store (preenchida só no iOS). Quando
  /// presente, o botão de atualizar abre a loja em vez de baixar APK.
  final String? appStoreUrl;

  const AppVersionInfo({
    required this.outdated,
    this.latestBuild,
    this.apkDownloadUrl,
    this.publishedAt,
    this.forceUpdate = false,
    this.appStoreUrl,
  });

  static const upToDate = AppVersionInfo(outdated: false);

  /// Atualização obrigatória em 2 cenários:
  ///   1) Release marcado com `[FORCE-UPDATE]` no body — força agora;
  ///   2) Hoje é dia POSTERIOR à data em que o APK INSTALADO foi
  ///      compilado pela CI. Usa AppConstants.buildTime (vem do
  ///      `--dart-define=BUILD_TIME=...`) — info de servidor que viaja
  ///      com o binário e nunca reseta. Antes usávamos publishedAt do
  ///      v-latest, mas o workflow apaga/recria a release a cada push
  ///      e o timestamp resetava — promotor ficava sem ser forçado
  ///      mesmo estando 2+ dias atrasado.
  bool get atualizacaoObrigatoria {
    if (!outdated) return false;
    if (forceUpdate) return true;
    final localBuildDate = _parseBuildTime(AppConstants.buildTime);
    if (localBuildDate == null) return false;
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final diaBuild = DateTime(
      localBuildDate.year,
      localBuildDate.month,
      localBuildDate.day,
    );
    return hoje.isAfter(diaBuild);
  }

  /// Parseia `BUILD_TIME` no formato `dd/MM/yyyy HH:mm` (BR) gerado
  /// pelo workflow. Em dev (defaultValue='local') ou formato
  /// inesperado, retorna null — D+1 não dispara.
  static DateTime? _parseBuildTime(String s) {
    final m = RegExp(r'^(\d{2})/(\d{2})/(\d{4}) (\d{2}):(\d{2})$')
        .firstMatch(s);
    if (m == null) return null;
    return DateTime(
      int.parse(m.group(3)!),
      int.parse(m.group(2)!),
      int.parse(m.group(1)!),
      int.parse(m.group(4)!),
      int.parse(m.group(5)!),
    );
  }
}

class VersionCheckService {
  VersionCheckService._();

  /// Arquivo de controle publicado pelo pipeline a cada build (com
  /// `x-upsert`, sempre no mesmo endereço).
  static const latestJsonUrl =
      '${AppConstants.supabaseUrl}/storage/v1/object/public/Arquivos/versoes-apk/latest.json';

  /// Retorna [AppVersionInfo.upToDate] em qualquer falha (offline,
  /// arquivo ausente, parsing). O usuário não pode ser alarmado por
  /// instabilidade de rede/CDN.
  static Future<AppVersionInfo> check() async {
    try {
      // Query única a cada chamada fura o cache do CDN do Storage —
      // sem isso o promotor poderia ficar até 1h vendo o JSON antigo.
      final cb = DateTime.now().millisecondsSinceEpoch;
      final res = await http
          .get(Uri.parse('$latestJsonUrl?cb=$cb'),
              headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return AppVersionInfo.upToDate;

      final json = jsonDecode(res.body);
      if (json is! Map<String, dynamic>) return AppVersionInfo.upToDate;
      return parseLatestJson(json);
    } catch (_) {
      return AppVersionInfo.upToDate;
    }
  }

  /// Transforma o conteúdo do `latest.json` em [AppVersionInfo].
  /// Separado do fetch para ser testável. Campos ausentes/inválidos →
  /// [AppVersionInfo.upToDate] (fail-open, nunca bloqueia por engano).
  static AppVersionInfo parseLatestJson(Map<String, dynamic> json) {
    final latestBuild = (json['buildNumber'] ?? '').toString().trim();
    final url = (json['apkUrl'] as String?)?.trim();
    if (latestBuild.isEmpty || url == null || url.isEmpty) {
      return AppVersionInfo.upToDate;
    }

    // Builds numéricos: compara como int. Se local for 'dev' ou similar,
    // considera desatualizado (mesma regra da era GitHub).
    final latestNum = int.tryParse(latestBuild);
    final localNum = int.tryParse(AppConstants.buildNumber);
    final outdated =
        latestNum != null && (localNum == null || latestNum > localNum);

    return AppVersionInfo(
      outdated: outdated,
      latestBuild: latestBuild,
      apkDownloadUrl: url,
      publishedAt:
          DateTime.tryParse((json['publishedAt'] ?? '').toString()),
      forceUpdate: json['forceUpdate'] == true,
    );
  }

  // ---- iOS: comparação com a versão publicada na App Store ----
  //
  // A Apple proíbe instalar IPA por fora da loja, então não há
  // auto-update OTA como no Android. Aqui consultamos a API pública de
  // lookup da Apple (sem login, sem Supabase) para descobrir qual versão
  // está PUBLICADA na App Store e comparamos com a versão instalada.

  static const _appStoreId = '6774250898';
  static const _iosLookupApi =
      'https://itunes.apple.com/lookup?id=$_appStoreId&country=br';
  static const _appStorePage =
      'https://apps.apple.com/br/app/id$_appStoreId';

  /// Consulta a versão publicada na App Store e marca atualização
  /// obrigatória se a versão instalada ([AppConstants.appVersion]) for
  /// MENOR que a da loja. Fail-open: qualquer falha (offline, app ainda
  /// não indexado na loja, parsing, versão não-numérica como 'dev') →
  /// [AppVersionInfo.upToDate], NUNCA bloqueia.
  static Future<AppVersionInfo> checkIOS() async {
    try {
      final res = await http
          .get(Uri.parse(_iosLookupApi),
              headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return AppVersionInfo.upToDate;

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final results = (json['results'] as List?) ?? const [];
      if (results.isEmpty) return AppVersionInfo.upToDate;

      final storeVersion =
          (results.first as Map<String, dynamic>)['version'] as String?;
      if (storeVersion == null) return AppVersionInfo.upToDate;

      final installed = AppConstants.appVersion;
      if (!_versionIsOlder(installed, storeVersion)) {
        return AppVersionInfo.upToDate;
      }

      return AppVersionInfo(
        outdated: true,
        latestBuild: storeVersion,
        forceUpdate: true,
        appStoreUrl: _appStorePage,
      );
    } catch (_) {
      return AppVersionInfo.upToDate;
    }
  }

  /// `true` se [installed] é estritamente menor que [store], comparando
  /// versões no formato "x.y.z" numericamente, segmento a segmento.
  /// Se qualquer um não for parseável (ex.: 'dev'), retorna `false`
  /// (fail-open: não bloqueia).
  static bool _versionIsOlder(String installed, String store) {
    final a = _parseVersion(installed);
    final b = _parseVersion(store);
    if (a == null || b == null) return false;
    final len = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < len; i++) {
      final ai = i < a.length ? a[i] : 0;
      final bi = i < b.length ? b[i] : 0;
      if (ai != bi) return ai < bi;
    }
    return false;
  }

  static List<int>? _parseVersion(String v) {
    final parts = v.trim().split('.');
    final out = <int>[];
    for (final p in parts) {
      final n = int.tryParse(p.trim());
      if (n == null) return null;
      out.add(n);
    }
    return out.isEmpty ? null : out;
  }
}

/// Provider — checa uma vez ao montar e expõe o resultado. Usar
/// `ref.invalidate(appVersionProvider)` para forçar nova checagem.
///
/// Android: consulta o `latest.json` no Supabase Storage (auto-update
/// por APK hospedado na URL fixa do bucket).
/// iOS: consulta a versão PUBLICADA na App Store (API pública da Apple,
/// sem Supabase) e força atualização se a instalada for menor — o botão
/// de atualizar abre a App Store, pois a Apple não permite instalar
/// IPA/APK por fora da loja.
final appVersionProvider = FutureProvider<AppVersionInfo>((ref) async {
  if (Platform.isAndroid) return VersionCheckService.check();
  if (Platform.isIOS) return VersionCheckService.checkIOS();
  return AppVersionInfo.upToDate;
});
