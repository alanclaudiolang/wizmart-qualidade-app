// lib/core/network/github_bug_reporter.dart
//
// Publica bug reports diretamente no GitHub:
//   1. Commita o GIF e o JSON em bug-reports/<data>/<uuid>.{gif,json}
//   2. Cria uma issue automaticamente com a descrição + GIF embutido
//
// SETUP (uma vez):
//   1. Criar PAT fine-grained em https://github.com/settings/personal-access-tokens
//      - Repository access: only this repo (wizmart-qualidade-app)
//      - Permissions: Contents = Read and write, Issues = Read and write
//   2. Adicionar como GitHub Secret BUG_REPORT_PAT no repo
//      (Settings > Secrets and variables > Actions > New repository secret)
//   3. O workflow de build passa automaticamente como --dart-define
//
// O token é embutido no APK em build time. Risco controlado: o PAT é
// fine-grained e só permite escrever neste repo (sem acesso a outros).

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

class GithubBugReportResult {
  final bool success;
  final String? issueUrl;
  final String? gifRawUrl;
  final int? issueNumber;
  final String? error;

  const GithubBugReportResult({
    required this.success,
    this.issueUrl,
    this.gifRawUrl,
    this.issueNumber,
    this.error,
  });
}

class GithubBugReporter {
  static const _apiBase = 'https://api.github.com';

  static Future<GithubBugReportResult> publish({
    required String reportId,
    required String gifLocalPath,
    required Map<String, dynamic> metadata,
  }) async {
    final token = AppConstants.githubBugReportToken;
    if (token.isEmpty) {
      return const GithubBugReportResult(
        success: false,
        error:
            'Token não configurado (build sem --dart-define=GITHUB_BUG_TOKEN).',
      );
    }

    final owner = AppConstants.githubRepoOwner;
    final repo = AppConstants.githubRepoName;
    final dateFolder =
        DateTime.now().toIso8601String().substring(0, 10); // YYYY-MM-DD

    final gifFile = File(gifLocalPath);
    if (!await gifFile.exists()) {
      return const GithubBugReportResult(
        success: false,
        error: 'GIF local não encontrado.',
      );
    }

    final gifPath = 'bug-reports/$dateFolder/$reportId.gif';
    final jsonPath = 'bug-reports/$dateFolder/$reportId.json';

    try {
      // 1. Upload do GIF (PUT /repos/.../contents/{path})
      final gifBytes = await gifFile.readAsBytes();
      await _putContents(
        token: token,
        owner: owner,
        repo: repo,
        path: gifPath,
        contentBase64: base64Encode(gifBytes),
        commitMessage: 'bug-report: gif $reportId',
      );

      // 2. Upload do JSON
      final jsonBytes = utf8.encode(jsonEncode(metadata));
      await _putContents(
        token: token,
        owner: owner,
        repo: repo,
        path: jsonPath,
        contentBase64: base64Encode(jsonBytes),
        commitMessage: 'bug-report: meta $reportId',
      );

      // 3. URL raw do GIF (GitHub serve binary direto)
      final rawUrl =
          'https://raw.githubusercontent.com/$owner/$repo/main/$gifPath';

      // 4. Cria a issue
      final descricao = (metadata['descricao'] ?? '').toString();
      final promotor = (metadata['promotor_nome'] ?? 'desconhecido').toString();
      final createdAt = (metadata['created_at'] ?? '').toString();

      final issueBody = '''
## Descrição
$descricao

## Gravação
![bug-$reportId]($rawUrl)

## Metadados
- **ID:** `$reportId`
- **Promotor:** $promotor
- **Quando:** $createdAt
- **Arquivos:** [`$gifPath`]($rawUrl) · [`$jsonPath`](https://github.com/$owner/$repo/blob/main/$jsonPath)

_Issue criada automaticamente pelo botão "Reportar bug" do app._
''';

      final issueRes = await http
          .post(
            Uri.parse('$_apiBase/repos/$owner/$repo/issues'),
            headers: _headers(token),
            body: jsonEncode({
              'title':
                  '[BUG] ${descricao.length > 60 ? '${descricao.substring(0, 60)}…' : descricao}',
              'body': issueBody,
              'labels': ['bug', 'auto-reportado'],
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (issueRes.statusCode < 200 || issueRes.statusCode >= 300) {
        return GithubBugReportResult(
          success: false,
          gifRawUrl: rawUrl,
          error: 'Falha ao criar issue: ${issueRes.statusCode} ${issueRes.body}',
        );
      }

      final issueJson = jsonDecode(issueRes.body) as Map<String, dynamic>;
      return GithubBugReportResult(
        success: true,
        issueUrl: issueJson['html_url'] as String?,
        issueNumber: issueJson['number'] as int?,
        gifRawUrl: rawUrl,
      );
    } catch (e, st) {
      debugPrint('GithubBugReporter erro: $e\n$st');
      return GithubBugReportResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  static Future<void> _putContents({
    required String token,
    required String owner,
    required String repo,
    required String path,
    required String contentBase64,
    required String commitMessage,
  }) async {
    final res = await http
        .put(
          Uri.parse('$_apiBase/repos/$owner/$repo/contents/$path'),
          headers: _headers(token),
          body: jsonEncode({
            'message': commitMessage,
            'content': contentBase64,
            'branch': 'main',
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
          'PUT /contents/$path falhou: ${res.statusCode} ${res.body}');
    }
  }

  static Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'Content-Type': 'application/json',
      };
}
