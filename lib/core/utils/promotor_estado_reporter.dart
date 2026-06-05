// lib/core/utils/promotor_estado_reporter.dart
//
// Registra/atualiza um issue no GitHub por promotor com info do build
// atual e último login. Serve pra mapear, sem visitar o Supabase, em
// qual versão cada promotor está.
//
// REGRA DE OURO: fire-and-forget total. Sem internet, token inválido,
// rate limit, qualquer falha — engole silenciosamente. Esse código NÃO
// pode afetar o fluxo de login, sync, ou qualquer parte funcional do
// app. É só sinal externo pra mim/dev.
//
// Gatilhos: chamado SÓ após login bem-sucedido em auth_screen. Como
// install/reinstall/expiração de sessão TODOS passam pela tela de
// auth, capturamos os 3 cenários sem heartbeat contínuo.
//
// Estrutura: 1 issue por promotor (identificado por email no título).
// Label dedicada `promotor-estado` separa visualmente dos bugs.
// SharedPreferences guarda o número do issue pra evitar criar duplicata
// em logins subsequentes. Reinstall zera prefs → busca por título antes
// de criar (search da API GitHub pode demorar a indexar issue novo,
// duplicata rara é aceitável).

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

class PromotorEstadoReporter {
  static const _repoOwner = 'alanclaudiolang';
  static const _repoName = 'wizmart-qualidade-app';
  static const _label = 'promotor-estado';

  static String _prefsKey(String email) =>
      'promotor_estado_issue_${email.toLowerCase()}';

  /// Registra ou atualiza o issue de estado do promotor. NUNCA lança.
  /// Falha silenciosa em qualquer ponto.
  static Future<void> registrar({
    required String email,
    required String nome,
  }) async {
    try {
      final token = AppConstants.githubBugReportToken;
      if (token.isEmpty) return;

      final emailNorm = email.trim().toLowerCase();
      if (emailNorm.isEmpty) return;

      final body = _montarBody(email: emailNorm, nome: nome);
      final titulo = '[ESTADO] $emailNorm';

      final prefs = await SharedPreferences.getInstance();
      final chave = _prefsKey(emailNorm);
      int? issueNumber = prefs.getInt(chave);

      // Caminho 1: temos número salvo → tenta PATCH direto.
      if (issueNumber != null) {
        final ok = await _patchIssue(token, issueNumber, body);
        if (ok) return;
        // PATCH falhou (404 — issue apagado, ou outro). Esquece o número
        // e cai pro fluxo de buscar/criar abaixo.
        await prefs.remove(chave);
        issueNumber = null;
      }

      // Caminho 2: sem número local. Busca por título exato pra
      // reaproveitar (caso de reinstall que zerou prefs).
      issueNumber = await _buscarPorTitulo(token, titulo);
      if (issueNumber != null) {
        await _patchIssue(token, issueNumber, body);
        await prefs.setInt(chave, issueNumber);
        return;
      }

      // Caminho 3: não existe ainda. Cria novo.
      final novo = await _criarIssue(token, titulo, body);
      if (novo != null) {
        await prefs.setInt(chave, novo);
      }
    } catch (_) {
      // Engole tudo. Nem loga — não vale poluir log local com algo
      // que não afeta o app.
    }
  }

  static String _montarBody({required String email, required String nome}) {
    final plataforma = Platform.isAndroid ? 'android' : 'ios';
    final agora = DateTime.now().toIso8601String();
    return '- **Promotor:** $nome\n'
        '- **Email:** $email\n'
        '- **Build:** ${AppConstants.buildNumber}\n'
        '- **App version:** ${AppConstants.appVersion}\n'
        '- **Plataforma:** $plataforma\n'
        '- **Último login:** $agora\n';
  }

  static Future<int?> _criarIssue(
      String token, String titulo, String body) async {
    try {
      final res = await http
          .post(
            Uri.parse(
                'https://api.github.com/repos/$_repoOwner/$_repoName/issues'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/vnd.github+json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'title': titulo,
              'body': body,
              'labels': [_label],
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      return j['number'] as int?;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> _patchIssue(
      String token, int issueNumber, String body) async {
    try {
      final res = await http
          .patch(
            Uri.parse(
                'https://api.github.com/repos/$_repoOwner/$_repoName/issues/$issueNumber'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/vnd.github+json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'body': body, 'state': 'open'}),
          )
          .timeout(const Duration(seconds: 8));
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  static Future<int?> _buscarPorTitulo(String token, String titulo) async {
    try {
      // Search API: busca title exato no repo com a label
      final query = Uri.encodeQueryComponent(
        'repo:$_repoOwner/$_repoName label:$_label in:title "$titulo"',
      );
      final res = await http.get(
        Uri.parse('https://api.github.com/search/issues?q=$query&per_page=1'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/vnd.github+json',
        },
      ).timeout(const Duration(seconds: 8));
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final items = j['items'] as List?;
      if (items == null || items.isEmpty) return null;
      // Confirma title exato (search da GitHub é fuzzy).
      for (final raw in items) {
        final it = raw as Map<String, dynamic>;
        if ((it['title'] as String?) == titulo) {
          return it['number'] as int?;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
