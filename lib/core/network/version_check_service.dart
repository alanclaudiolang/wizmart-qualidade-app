// lib/core/network/version_check_service.dart
//
// Consulta o release "v-latest" no GitHub para descobrir se há um build
// mais novo que o local. O CI publica a APK em
//   github.com/alanclaudiolang/wizmart-qualidade-app/releases/tag/v-latest
// com nome de asset no formato:
//   wizmart-app-v<version>-build<NN>-<timestamp>.apk
//
// Comparamos o build number do asset com o build number local
// (vindo do dart-define BUILD_NUMBER). Falha silenciosa offline.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';

class AppVersionInfo {
  final bool outdated;
  final String? latestBuild;
  final String? apkDownloadUrl;

  const AppVersionInfo({
    required this.outdated,
    this.latestBuild,
    this.apkDownloadUrl,
  });

  static const upToDate = AppVersionInfo(outdated: false);
}

class VersionCheckService {
  VersionCheckService._();

  static const _releaseApi =
      'https://api.github.com/repos/alanclaudiolang/wizmart-qualidade-app/releases/tags/v-latest';

  /// Retorna [AppVersionInfo.upToDate] em qualquer falha (offline, rate
  /// limit, parsing). O usuário não pode ser alarmado por instabilidade
  /// da API do GitHub.
  static Future<AppVersionInfo> check() async {
    try {
      final res = await http
          .get(Uri.parse(_releaseApi), headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return AppVersionInfo.upToDate;

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final assets = (json['assets'] as List?) ?? const [];
      if (assets.isEmpty) return AppVersionInfo.upToDate;

      // Pega o primeiro asset .apk
      final apkAsset = assets.cast<Map<String, dynamic>>().firstWhere(
            (a) => (a['name'] as String?)?.endsWith('.apk') ?? false,
            orElse: () => const {},
          );
      if (apkAsset.isEmpty) return AppVersionInfo.upToDate;

      final name = apkAsset['name'] as String? ?? '';
      final url = apkAsset['browser_download_url'] as String?;
      // Extrai "buildNN" do nome
      final match = RegExp(r'build(\d+)').firstMatch(name);
      if (match == null || url == null) return AppVersionInfo.upToDate;

      final latestBuild = match.group(1)!;
      final localBuild = AppConstants.buildNumber;

      // Builds numéricos: compara como int. Se local for 'dev' ou similar,
      // considera desatualizado.
      final latestNum = int.tryParse(latestBuild);
      final localNum = int.tryParse(localBuild);
      final outdated = (latestNum != null &&
          (localNum == null || latestNum > localNum));

      return AppVersionInfo(
        outdated: outdated,
        latestBuild: latestBuild,
        apkDownloadUrl: url,
      );
    } catch (_) {
      return AppVersionInfo.upToDate;
    }
  }
}

/// Provider — checa uma vez ao montar e expõe o resultado. Usar
/// `ref.invalidate(appVersionProvider)` para forçar nova checagem.
final appVersionProvider = FutureProvider<AppVersionInfo>((ref) async {
  return VersionCheckService.check();
});
