// lib/core/utils/app_router.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../presentation/screens/auth/auth_screen.dart';
import '../../presentation/screens/bug_report/bug_report_screen.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/sync_logs/sync_logs_screen.dart';
import '../../presentation/screens/visita/visita_screen.dart';
import 'device_info_service.dart';
import 'last_visita_service.dart';
import 'session_service.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (_, __) => const _SplashRedirect(),
    ),
    GoRoute(
      path: '/auth',
      builder: (_, __) => const AuthScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (_, __) => const HomeScreen(),
    ),
    GoRoute(
      path: '/visita/:id',
      builder: (_, state) {
        final id = int.parse(state.pathParameters['id']!);
        return VisitaScreen(visitaId: id);
      },
    ),
    GoRoute(
      path: '/bug-report',
      builder: (_, state) {
        final gif = state.uri.queryParameters['gif'] ?? '';
        return BugReportScreen(gifPath: gif);
      },
    ),
    GoRoute(
      path: '/sync-logs',
      builder: (_, __) => const SyncLogsScreen(),
    ),
  ],
);

// Widget de splash que redireciona baseado na sessão
class _SplashRedirect extends StatefulWidget {
  const _SplashRedirect();

  @override
  State<_SplashRedirect> createState() => _SplashRedirectState();
}

class _SplashRedirectState extends State<_SplashRedirect> {
  @override
  void initState() {
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    final hasSession = await SessionService.hasSession();
    if (!hasSession) {
      if (mounted) context.go('/auth');
      return;
    }

    final session = await SessionService.getSession();
    if (!mounted) return;
    if (session == null) {
      context.go('/auth');
      return;
    }

    // Atualiza device_info da sessão restaurada em background — não
    // bloqueia o splash. Próxima vez tenta de novo se falhar agora.
    // ignore: discarded_futures
    DeviceInfoService.updateForEmail(session.email);

    // Se o Android matou o app enquanto a câmera estava aberta (low memory)
    // ou o usuário trocou de app no meio da visita, restaura a tela onde
    // estava — não joga ele pra home perdido.
    final lastVisitaId = await LastVisitaService.get();
    if (!mounted) return;
    if (lastVisitaId != null) {
      context.go('/visita/$lastVisitaId');
      return;
    }

    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF1A1A2E),
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
      ),
    );
  }
}
