// lib/core/utils/app_router.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../presentation/screens/auth/auth_screen.dart';
import '../../presentation/screens/auth/onboarding_permissoes_screen.dart';
import '../../presentation/screens/faltas/faltas_screen.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/realizado/realizado_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/screens/visita/visita_screen.dart';
import '../../presentation/widgets/gps_guard.dart';
import '../../presentation/widgets/permissions_guard.dart';
import '../network/sync_engine.dart';
import 'current_screen.dart';
import 'device_info_service.dart';
import 'last_visita_service.dart';
import 'session_service.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  // Cada navegação atualiza o CurrentScreen — usado pelo ErrorReporter
  // pra rotular issues por tela (label `screen:<nome>`). Implementado
  // via redirect (que vê todas as navegações, inclusive `context.go`).
  redirect: (_, state) {
    CurrentScreen.setFromLocation(state.uri.toString());
    return null; // não redireciona, só observa
  },
  routes: [
    // ShellRoute envolve as rotas com PermissionsGuard apenas.
    // Apple guideline 5.1.5: app deve ser funcional mesmo com Location
    // Services desligado. Por isso GpsGuard SÓ entra na tela de visita
    // (única que precisa de GPS pra registrar localização da foto).
    // Login, home, faltas, etc. funcionam sem GPS.
    ShellRoute(
      builder: (context, state, child) => PermissionsGuard(child: child),
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
            return GpsGuard(child: VisitaScreen(visitaId: id));
          },
        ),
        GoRoute(
          path: '/realizado',
          builder: (_, __) => const RealizadoScreen(),
        ),
        GoRoute(
          path: '/faltas',
          builder: (_, __) => const FaltasScreen(),
        ),
        GoRoute(
          path: '/onboarding-permissoes',
          builder: (_, __) => const OnboardingPermissoesScreen(),
        ),
      ],
    ),
  ],
);

// Widget de splash que redireciona baseado na sessão
class _SplashRedirect extends ConsumerStatefulWidget {
  const _SplashRedirect();

  @override
  ConsumerState<_SplashRedirect> createState() => _SplashRedirectState();
}

class _SplashRedirectState extends ConsumerState<_SplashRedirect> {
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
    //
    // ANTES de restaurar, valida que a visita ainda existe no DB local.
    // O sync de início de dia pode ter limpado visitas antigas, ou o
    // idTemp pode ter sido reconciliado pelo servidor — nesses casos o
    // last_visita_id aponta pra um id morto e o usuário ficaria preso
    // numa tela "Visita não encontrada" sem botão de voltar. Caso da
    // reinstalação do Edilson em produção (2026-05).
    final lastVisitaId = await LastVisitaService.get();
    if (!mounted) return;
    if (lastVisitaId != null) {
      final db = ref.read(appDatabaseProvider);
      final visita = await db.getVisitaById(lastVisitaId);
      if (!mounted) return;
      if (visita != null) {
        context.go('/visita/$lastVisitaId');
        return;
      }
      // Visita morta — limpa o pref pra não cair aqui de novo no próximo
      // boot e segue pra home (onde o usuário vê a lista atual do dia).
      await LastVisitaService.clear();
      if (!mounted) return;
    }

    // Onboarding de permissões: na PRIMEIRA abertura após instalar,
    // o app pede TODAS as permissões críticas (GPS, câmera, galeria)
    // de uma só vez. Depois de concluído (flag em SharedPreferences),
    // pula direto pra home nas próximas aberturas. Se o promotor
    // revogar algo depois, os guards (GpsGuard/PermissionsGuard)
    // continuam ativos como rede de segurança.
    final onboardingFeito =
        await OnboardingPermissoesScreen.jaConcluido();
    if (!mounted) return;
    if (!onboardingFeito) {
      context.go('/onboarding-permissoes');
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

