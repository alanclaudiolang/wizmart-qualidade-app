// lib/core/utils/apk_updater_service.dart
//
// Baixa a APK nova diretamente, salva em diretório do app e chama o
// instalador nativo do Android via FileProvider + Intent.
//
// O promotor não vê navegador externo, não vê URL do GitHub, não
// precisa achar pasta Downloads. O Android pede uma vez "Permitir
// instalar apps de fontes desconhecidas" — depois disso a instalação
// é direta.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class ApkDownloadResult {
  final bool success;
  final String? error;
  const ApkDownloadResult({required this.success, this.error});
}

class ApkUpdaterService {
  ApkUpdaterService._();

  /// Testa se a URL da APK responde (HEAD em <4s). Usado pelo bloqueio
  /// obrigatório pra evitar mostrar o dialog se a APK não vai conseguir
  /// baixar de qualquer jeito (captive portal, DNS quebrado, GitHub fora).
  static Future<bool> apkAcessivel(String url) async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 4),
        followRedirects: true,
      ));
      final res = await dio.head(url,
          options: Options(
            validateStatus: (_) => true,
            // HEAD em GitHub redirect = 302 → segue pra objects.gh — tudo OK.
          ));
      return res.statusCode != null &&
          res.statusCode! >= 200 &&
          res.statusCode! < 400;
    } catch (_) {
      return false;
    }
  }

  /// Baixa a APK, salva localmente e chama o instalador. O callback
  /// `onProgress` recebe 0.0..1.0 conforme bytes recebidos.
  static Future<ApkDownloadResult> downloadAndInstall({
    required String url,
    required void Function(double progress) onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      // Diretório dedicado pra APKs baixadas (separado das fotos).
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/wizmart_apks');
      await dir.create(recursive: true);

      // Sempre sobrescreve um arquivo único — não acumula APKs antigas.
      final apkPath = '${dir.path}/promotor-wizmart-latest.apk';
      final apkFile = File(apkPath);
      if (await apkFile.exists()) {
        try {
          await apkFile.delete();
        } catch (_) {}
      }

      final dio = Dio();
      await dio.download(
        url,
        apkPath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) onProgress(received / total);
        },
        options: Options(
          followRedirects: true,
          // GitHub redirect leva pra objects.githubusercontent.com —
          // mantém o follow ligado.
          receiveTimeout: const Duration(minutes: 5),
          sendTimeout: const Duration(seconds: 30),
        ),
      );

      // Abre o instalador nativo do Android (Package Installer).
      // No Android 8+ vai aparecer um prompt "Permitir instalar apps
      // de fontes desconhecidas" da primeira vez — usuário aceita e
      // a instalação roda. Próximas vezes vai direto pra confirmação.
      final result = await OpenFilex.open(apkPath);
      if (result.type != ResultType.done) {
        return ApkDownloadResult(
          success: false,
          error: result.message,
        );
      }
      return const ApkDownloadResult(success: true);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        return const ApkDownloadResult(
          success: false,
          error: 'cancelado',
        );
      }
      return ApkDownloadResult(success: false, error: e.message);
    } catch (e) {
      return ApkDownloadResult(success: false, error: e.toString());
    }
  }
}
