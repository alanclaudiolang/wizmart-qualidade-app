// lib/main.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';
import 'core/constants/app_constants.dart';
import 'core/utils/app_router.dart';
import 'core/database/app_database.dart';
import 'core/network/sync_engine.dart';

const _bgSyncTask = 'wizmart_bg_sync';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == _bgSyncTask) {
      try {
        await Supabase.initialize(
          url: AppConstants.supabaseUrl,
          anonKey: AppConstants.supabaseAnonKey,
        );
        final db = AppDatabase();
        final syncEngine = SyncEngine(db, Supabase.instance.client);
        await syncEngine.processOutbox();
        await db.close();
      } catch (_) {}
    }
    return Future.value(true);
  });
}

// Armazena o erro de inicialização para exibir na tela
String? _initError;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Captura erros Flutter não tratados e exibe na tela
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  await runZonedGuarded(() async {
    try {
      await Supabase.initialize(
        url: AppConstants.supabaseUrl,
        anonKey: AppConstants.supabaseAnonKey,
      );
    } catch (e) {
      _initError = 'Supabase.initialize falhou:\n$e';
    }

    try {
      await Workmanager().initialize(callbackDispatcher);
      await Workmanager().registerPeriodicTask(
        _bgSyncTask,
        _bgSyncTask,
        frequency: const Duration(minutes: AppConstants.syncIntervalMinutes),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingWorkPolicy.keep,
      );
    } catch (e) {
      _initError ??= 'WorkManager falhou:\n$e';
    }

    runApp(ProviderScope(child: WizMartApp(initError: _initError)));
  }, (error, stack) {
    // Erros assíncronos não capturados — reinicia app mostrando erro
    runApp(MaterialApp(
      home: _ErrorScreen(
        title: 'Erro inesperado',
        error: '$error',
        stack: '$stack',
      ),
    ));
  });
}

class WizMartApp extends StatelessWidget {
  final String? initError;
  const WizMartApp({super.key, this.initError});

  @override
  Widget build(BuildContext context) {
    // Se houve erro de inicialização, mostra tela de erro em vez do app
    if (initError != null) {
      return MaterialApp(
        home: _ErrorScreen(title: 'Erro de inicialização', error: initError!),
      );
    }

    return MaterialApp.router(
      title: 'WizMart',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF38A169),
        ),
        useMaterial3: true,
      ),
      routerConfig: appRouter,
    );
  }
}

// Tela de erro que exibe o problema exato
class _ErrorScreen extends StatelessWidget {
  final String title;
  final String error;
  final String? stack;

  const _ErrorScreen({
    required this.title,
    required this.error,
    this.stack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F5),
      appBar: AppBar(
        backgroundColor: Colors.red,
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⚠️ O app encontrou um erro ao iniciar.\n'
              'Tire um print desta tela e envie ao desenvolvedor.',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: SelectableText(
                error,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Color(0xFFC53030),
                ),
              ),
            ),
            if (stack != null) ...[
              const SizedBox(height: 16),
              const Text('Stack trace:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  stack!.length > 2000 ? '${stack!.substring(0, 2000)}...' : stack!,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
