// lib/main.dart

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';
import 'core/constants/app_constants.dart';
import 'core/utils/app_router.dart';
import 'core/database/app_database.dart';
import 'core/network/connectivity_service.dart';
import 'core/network/sync_engine.dart';
import 'core/network/sync_pause.dart';
import 'core/network/version_check_service.dart';
import 'core/utils/session_service.dart';
import 'core/utils/gps_status_service.dart';
import 'core/utils/permissions_status_service.dart';
import 'core/utils/persistent_logger.dart';
import 'core/utils/photo_error_reporter.dart';
import 'core/utils/sync_logger.dart';
import 'presentation/screens/home/home_screen.dart'
    show contadoresProvider, pdvsProvider, visitasHojeProvider;
import 'presentation/widgets/bug_report_overlay.dart';
import 'presentation/widgets/gps_guard.dart';
import 'presentation/widgets/permissions_guard.dart';

const _bgSyncTask = 'wizmart_bg_sync';

/// Heurística pra decidir se um erro vem do fluxo de foto. Usado pelos
/// handlers globais (FlutterError + PlatformDispatcher) pra acionar
/// auto-report sem inundar com erros não-relacionados.
bool _relacionadoAFoto(String stackStr) {
  final s = stackStr.toLowerCase();
  return s.contains('tirarfoto') ||
      s.contains('watermark') ||
      s.contains('concluirfotos') ||
      s.contains('finalizarvisita') ||
      s.contains('aplicarwatermark') ||
      s.contains('image_picker') ||
      s.contains('gal.');
}
const _oneOffSyncName = 'wizmart_oneoff_sync';

/// Enfileira uma tentativa de sync com constraint de rede. O Android dispara
/// quando houver conectividade — mesmo com app fechado ou em Doze Mode.
/// Pequeno custo, granted pelo SO. Único gatilho de background dependável
/// quando o app não está rodando.
Future<void> scheduleOneOffSync() async {
  try {
    await Workmanager().registerOneOffTask(
      _oneOffSyncName,
      _bgSyncTask,
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.keep,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(seconds: 30),
    );
  } catch (_) {}
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == _bgSyncTask) {
      // Pausado durante captura — independe de rede.
      if (await SyncPause.isPaused()) {
        return Future.value(true);
      }
      // Ping real no Supabase: "ter rede" no Android não significa que o
      // servidor responde (captive portal, DNS quebrado, etc). Se o ping
      // falha, não inicializa nada — fica leve.
      if (!await pingSupabase()) {
        return Future.value(true);
      }
      try {
        await Supabase.initialize(
          url: AppConstants.supabaseUrl,
          anonKey: AppConstants.supabaseAnonKey,
        );
        final db = AppDatabase();
        final logger = SyncLoggerNotifier();
        final syncEngine = SyncEngine(db, Supabase.instance.client, logger);
        // fullSync = push + pull. Precisa do userId da sessão atual; se
        // não houver sessão (deslogado), só faz push do que sobrou.
        final session = await SessionService.getSession();
        if (session != null) {
          await syncEngine.fullSync(session.userId);
        } else {
          await syncEngine.processOutbox();
        }
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

  // Captura erros Flutter não tratados e exibe na tela. Também
  // reporta automaticamente como issue se for relacionado ao flow
  // de foto (heurística: stack contém "tirarFoto" / "watermark" /
  // "concluirFotos" / "finalizarVisita").
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    final stackStr = details.stack?.toString() ?? '';
    if (_relacionadoAFoto(stackStr)) {
      // ignore: discarded_futures
      PhotoErrorReporter.reportar(
        contexto: 'FlutterError não tratado',
        erro: details.exception,
        stack: details.stack,
      );
    }
    // ignore: discarded_futures
    PersistentLogger.append('flutter-error',
        '${details.exceptionAsString()} ($stackStr)',
        erro: true);
  };

  // Erros assíncronos não tratados (Future sem catch, isolates).
  PlatformDispatcher.instance.onError = (error, stack) {
    if (_relacionadoAFoto(stack.toString())) {
      // ignore: discarded_futures
      PhotoErrorReporter.reportar(
        contexto: 'PlatformDispatcher erro assíncrono',
        erro: error,
        stack: stack,
      );
    }
    // ignore: discarded_futures
    PersistentLogger.append('platform-error', '$error\n$stack', erro: true);
    return true;
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
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
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

class WizMartApp extends ConsumerStatefulWidget {
  final String? initError;
  const WizMartApp({super.key, this.initError});

  @override
  ConsumerState<WizMartApp> createState() => _WizMartAppState();
}

class _WizMartAppState extends ConsumerState<WizMartApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Gatilho universal — dispara fullSync (push + pull) e invalida os
  /// providers da home pra refletir mudanças. O `processOutbox` checa
  /// `SyncPause` internamente, então durante captura este kick é
  /// absorvido sem efeito.
  Future<void> _kickSync() async {
    if (!mounted) return;
    if (!ref.read(connectivityProvider)) return;
    final session = await SessionService.getSession();
    final engine = ref.read(syncEngineProvider);
    if (session != null) {
      await engine.fullSync(session.userId);
      if (!mounted) return;
      // Invalida providers da home pra UI buscar dados recém atualizados.
      // Inclui o caso de sync via WorkManager periódico que mexe no DB
      // em isolate separado — Stream do Drift pode não notificar.
      ref.invalidate(contadoresProvider(session.userId));
      ref.invalidate(pdvsProvider);
      ref.invalidate(visitasHojeProvider(session.userId));
      // Re-checa se há build novo no GitHub Releases. Sem isso o
      // FutureProvider ficava cacheado pra sempre — promotor instalava
      // a versão N e nunca via o badge 'atualizar' quando a N+1 saía.
      ref.invalidate(appVersionProvider);
    } else {
      await engine.processOutbox();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // App voltou pro foreground (de configs, câmera, painel rápido,
      // outro app, etc.). Re-checa GPS e permissões — não há stream
      // nativa pra essas mudanças; precisa polling no lifecycle.
      ref.read(gpsStatusProvider.notifier).refresh();
      ref.read(permissionsStatusProvider.notifier).refresh();
      _kickSync();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.initError != null) {
      return MaterialApp(
        home: _ErrorScreen(
            title: 'Erro de inicialização', error: widget.initError!),
      );
    }

    // Gatilho: conectividade ficou online → tenta sincronizar.
    ref.listen<bool>(connectivityProvider, (prev, next) {
      if (prev == false && next == true) {
        _kickSync();
      }
    });

    return MaterialApp.router(
      title: 'Promotor Wizmart',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF38A169),
        ),
        useMaterial3: true,
      ),
      routerConfig: appRouter,
      builder: (context, child) {
        // PermissionsGuard (câmera/galeria) + GpsGuard envolvem TUDO.
        // Se qualquer permissão crítica for negada ou o GPS desligar,
        // um overlay bloqueia a UI até resolver.
        return PermissionsGuard(
          child: GpsGuard(
            child: BugReportOverlay(child: child ?? const SizedBox.shrink()),
          ),
        );
      },
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
