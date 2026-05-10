// lib/core/network/bug_report_uploader.dart
//
// Sobe o GIF + metadata do bug report pro Supabase Storage.
// Bucket esperado: 'bug-reports' (público, com policy de insert anon).
//
// SETUP NO PAINEL DO SUPABASE (uma vez):
//   1. Storage > New bucket > nome "bug-reports" > marcar "Public bucket"
//   2. Em Policies do bucket, criar:
//      - INSERT: USING (true) — qualquer um pode upar
//      - SELECT: USING (true) — qualquer um pode baixar (já vem com Public)

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BugReportUploadResult {
  final bool success;
  final String? gifUrl;
  final String? jsonUrl;
  final String? error;

  const BugReportUploadResult({
    required this.success,
    this.gifUrl,
    this.jsonUrl,
    this.error,
  });
}

class BugReportUploader {
  static const _bucket = 'bug-reports';

  /// Sobe o GIF e o JSON de metadata. Retorna URLs públicas.
  static Future<BugReportUploadResult> upload({
    required String reportId,
    required String gifLocalPath,
    required Map<String, dynamic> metadata,
  }) async {
    try {
      final client = Supabase.instance.client;
      final storage = client.storage.from(_bucket);

      final gifFile = File(gifLocalPath);
      if (!await gifFile.exists()) {
        return const BugReportUploadResult(
          success: false,
          error: 'GIF local não encontrado',
        );
      }

      final dateFolder =
          DateTime.now().toIso8601String().substring(0, 10); // YYYY-MM-DD
      final gifPath = '$dateFolder/$reportId.gif';
      final jsonPath = '$dateFolder/$reportId.json';

      // Upload do GIF
      await storage.upload(
        gifPath,
        gifFile,
        fileOptions: const FileOptions(
          contentType: 'image/gif',
          upsert: false,
        ),
      );

      // Upload do JSON
      final jsonBytes = utf8.encode(jsonEncode(metadata));
      await storage.uploadBinary(
        jsonPath,
        Uint8List.fromList(jsonBytes),
        fileOptions: const FileOptions(
          contentType: 'application/json',
          upsert: false,
        ),
      );

      return BugReportUploadResult(
        success: true,
        gifUrl: storage.getPublicUrl(gifPath),
        jsonUrl: storage.getPublicUrl(jsonPath),
      );
    } catch (e, st) {
      debugPrint('Falha no upload do bug report: $e\n$st');
      return BugReportUploadResult(
        success: false,
        error: e.toString(),
      );
    }
  }
}
