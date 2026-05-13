// lib/core/utils/logout_service.dart
//
// Limpeza COMPLETA ao deslogar — apaga qualquer vestígio do promotor:
//  - Supabase auth (signOut)
//  - SecureStorage (credenciais)
//  - SharedPreferences (flags do app)
//  - Tabelas Drift (visitas, pdvs, gabaritos, fotos, outbox etc.)
//  - Arquivos locais (fotos com watermark, bug reports)
//  - WorkManager (cancela tarefas pendentes)
//
// Falhas individuais não interrompem a limpeza — o promotor precisa
// poder sair mesmo se uma das limpezas falhar (offline, arquivo
// já apagado, etc.).

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

    // 3) SharedPreferences — flags do app (sync_paused, last_visita_id).
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
