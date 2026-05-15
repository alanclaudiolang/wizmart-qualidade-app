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
  /// Timestamp `published_at` do release no GitHub.
  final DateTime? publishedAt;
  /// `true` quando o body do release contém o marker `[FORCE-UPDATE]`.
  /// Faz a atualização ser obrigatória IMEDIATAMENTE (sem esperar
  /// o dia seguinte). Pra ativar: editar o release no GitHub e
  /// incluir `[FORCE-UPDATE]` em qualquer lugar da descrição.
  final bool forceUpdate;

  const AppVersionInfo({
    required this.outdated,
    this.latestBuild,
    this.apkDownloadUrl,
    this.publishedAt,
    this.forceUpdate = false,
  });

  static const upToDate = AppVersionInfo(outdated: false);

  /// Atualização obrigatória em 2 cenários:
  ///   1) Release marcado com `[FORCE-UPDATE]` no body — força agora;
  ///   2) Release foi publicado em dia ANTERIOR a hoje — regra padrão
  ///      "primeiro acesso no dia seguinte".
  bool get atualizacaoObrigatoria {
    if (!outdated) return false;
    if (forceUpdate) return true;
    if (publishedAt == null) return false;
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final pubLocal = publishedAt!.toLocal();
    final diaPub = DateTime(pubLocal.year, pubLocal.month, pubLocal.day);
    return hoje.isAfter(diaPub);
  }
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

      final assetList = assets.cast<Map<String, dynamic>>();

      // Extrai o build number do asset variável (nome contém "buildNN").
      final assetComBuild = assetList.firstWhere(
        (a) {
          final n = (a['name'] as String?) ?? '';
          return n.contains(RegExp(r'build\d+')) && n.endsWith('.apk');
        },
        orElse: () => const {},
      );
      if (assetComBuild.isEmpty) return AppVersionInfo.upToDate;
      final nameVar = assetComBuild['name'] as String? ?? '';
      final match = RegExp(r'build(\d+)').firstMatch(nameVar);
      if (match == null) return AppVersionInfo.upToDate;

      // Pra download usamos o asset com nome fixo (promotor-wizmart.apk)
      // — URL estável que serve qualquer release. Cai pro asset variável
      // se por algum motivo o fixo não existir.
      final assetFixo = assetList.firstWhere(
        (a) => (a['name'] as String?) == 'promotor-wizmart.apk',
        orElse: () => assetComBuild,
      );
      final url = assetFixo['browser_download_url'] as String?;
      if (url == null) return AppVersionInfo.upToDate;

      final latestBuild = match.group(1)!;
      final localBuild = AppConstants.buildNumber;

      // Builds numéricos: compara como int. Se local for 'dev' ou similar,
      // considera desatualizado.
      final latestNum = int.tryParse(latestBuild);
      final localNum = int.tryParse(localBuild);
      final outdated = (latestNum != null &&
          (localNum == null || latestNum > localNum));

      DateTime? publishedAt;
      final pubRaw = json['published_at'] as String?;
      if (pubRaw != null) {
        publishedAt = DateTime.tryParse(pubRaw);
      }

      // Marker `[FORCE-UPDATE]` no body do release dispara atualização
      // obrigatória imediata (sem aguardar regra "dia seguinte").
      final body = (json['body'] as String?) ?? '';
      final forceUpdate =
          body.toUpperCase().contains('[FORCE-UPDATE]');

      return AppVersionInfo(
        outdated: outdated,
        latestBuild: latestBuild,
        apkDownloadUrl: url,
        publishedAt: publishedAt,
        forceUpdate: forceUpdate,
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
