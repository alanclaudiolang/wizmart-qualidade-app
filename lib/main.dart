// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';
import 'core/constants/app_constants.dart';
import 'core/utils/app_router.dart';
import 'core/database/app_database.dart';
import 'core/network/sync_engine.dart';

// Background task name
const _bgSyncTask = 'wizmart_bg_sync';

// Callback executado pelo WorkManager em background
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
      } catch (_) {
        // Silencioso em background
      }
    }
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa Supabase
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  // Inicializa WorkManager para sync em background
  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(
    _bgSyncTask,
    _bgSyncTask,
    frequency: Duration(minutes: AppConstants.syncIntervalMinutes),
    constraints: Constraints(
      networkType: NetworkType.connected,
    ),
    existingWorkPolicy: ExistingWorkPolicy.keep,
  );

  runApp(const ProviderScope(child: WizMartApp()));
}

class WizMartApp extends StatelessWidget {
  const WizMartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'WizMart',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF4CAF50),
          secondary: const Color(0xFF64B5F6),
          surface: const Color(0xFF1A1A2E),
        ),
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF16213E),
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 18),
        ),
        useMaterial3: true,
      ),
      routerConfig: appRouter,
    );
  }
}
