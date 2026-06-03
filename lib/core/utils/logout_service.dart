// lib/core/utils/logout_service.dart
//
// Dois modos de logout:
//
//   - softLogout: padrão pro botão "Sair" e pra detecção automática de
//     sessão expirada. Apaga só a sessão Supabase Auth + SessionService
//     local. PRESERVA visitas, fotos pendentes, outbox, PDVs, gabaritos
//     e arquivos físicos. Marca o e-mail do usuário em
//     `last_logged_email` pra o próximo login decidir o caminho:
//        • mesmo e-mail → retoma de onde parou, sem perder nada
//        • e-mail diferente → AuthScreen detecta e pede confirmação;
//          se o usuário confirmar, aí sim chama logoutCompletely
//          pra apagar tudo do dono anterior antes de logar o novo.
//
//   - logoutCompletely: limpeza destrutiva total — só roda quando a
//     AuthScreen detecta troca de conta (e o usuário confirmou) ou
//     quando explicitamente solicitado (caso especial). Apaga: sessão
//     Supabase, SecureStorage, SharedPreferences (inclusive
//     last_logged_email), todas as tabelas Drift, arquivos de fotos
//     e bugs, e cancela WorkManager.
//
// Falhas individuais não interrompem a limpeza — o promotor precisa
// poder sair mesmo se uma das etapas falhar (offline, arquivo já
// apagado, etc.).

import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../database/app_database.dart';
import 'last_visita_service.dart';
import 'session_service.dart';

class LogoutService {
  LogoutService._();

  /// Chave em SharedPreferences que guarda o e-mail do último usuário
  /// logado. Usada pelo AuthScreen pra decidir se um novo login no mesmo
  /// dispositivo herda os dados locais (mesmo e-mail) ou requer limpeza
  /// completa (e-mail diferente).
  static const String lastLoggedEmailKey = 'last_logged_email';

  /// Logout "soft": preserva tudo que é dado do promotor no dispositivo,
  /// só termina a sessão Auth. Pra ser usado quando o promotor toca em
  /// "Sair" no menu OU quando o app detecta auth.uid morto e precisa
  /// mandar o usuário pro /auth — em ambos os casos, se ele logar de
  /// volta com o mesmo e-mail, retoma de onde parou.
  static Future<void> softLogout({String? email}) async {
    // 1) Marca o e-mail antes de qualquer limpeza, pra sobreviver mesmo
    //    se a sessão Auth já estiver morta. Aceita opcional pra cobrir
    //    casos onde currentUser já é null mas o caller ainda sabe quem
    //    estava logado (vindo de SessionService).
    try {
      final prefs = await SharedPreferences.getInstance();
      final emailParaSalvar = email ??
          Supabase.instance.client.auth.currentUser?.email;
      if (emailParaSalvar != null && emailParaSalvar.isNotEmpty) {
        await prefs.setString(
            lastLoggedEmailKey, emailParaSalvar.toLowerCase().trim());
      }
    } catch (_) {}

    // 2) Supabase auth — invalida token no servidor (timeout curto
    //    pra não travar offline).
    try {
      await Supabase.instance.client.auth
          .signOut()
          .timeout(const Duration(seconds: 5));
    } catch (_) {}

    // 3) SecureStorage — limpa credenciais salvas pra forçar nova
    //    digitação de senha (segurança).
    try {
      await SessionService.clearSession();
    } catch (_) {}

    // NÃO mexe em: SharedPreferences gerais, Drift, arquivos físicos,
    // WorkManager. Tudo permanece pra ser reaproveitado no próximo
    // login com o mesmo e-mail.
  }

  /// Limpeza COMPLETA — apaga qualquer vestígio do promotor anterior.
  /// Usar SÓ quando o AuthScreen detectar troca de conta (e o usuário
  /// confirmar) ou em casos especiais explícitos.
  static Future<void> logoutCompletely(AppDatabase db) async {
    // 1) Supabase auth — invalida token no servidor. Timeout pra não
    //    travar offline; ignora erro (continuamos a limpeza local).
    try {
      await Supabase.instance.client.auth
          .signOut()
          .timeout(const Duration(seconds: 5));
    } catch (_) {}

    // 2) SecureStorage — credenciais persistidas (lembrar senha).
    try {
      await SessionService.clearSession();
    } catch (_) {}

    // 3) SharedPreferences — flags do app (sync_paused, last_visita_id,
    //    last_logged_email — agora vai mesmo, é troca real).
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (_) {}
    try {
      await LastVisitaService.clear();
    } catch (_) {}

    // 4) Drift — apaga TODAS as tabelas com dados do promotor anterior.
    //    Mantém a instância do DB aberta (não deleta o arquivo, só os
    //    rows) — assim Streams ativos não quebram.
    try {
      await db.transaction(() async {
        await db.delete(db.pendingPhotos).go();
        await db.delete(db.outboxItems).go();
        await db.delete(db.visitas).go();
        await db.delete(db.pdvs).go();
        await db.delete(db.gabaritos).go();
        await db.delete(db.users).go();
        await db.delete(db.syncState).go();
      });
    } catch (_) {}

    // 5) Arquivos locais — fotos com watermark e bug reports.
    try {
      final docs = await getApplicationDocumentsDirectory();
      for (final sub in ['wizmart_fotos', 'wizmart_bugs']) {
        final dir = Directory('${docs.path}/$sub');
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      }
    } catch (_) {}

    // 6) WorkManager — cancela tarefas pendentes pra não acordar com a
    //    sessão antiga (mesmo após signOut, o callbackDispatcher tentaria
    //    rodar sync com a auth nova ou nenhuma).
    try {
      await Workmanager().cancelAll();
    } catch (_) {}
  }
}
