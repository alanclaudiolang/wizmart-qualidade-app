// lib/presentation/screens/auth/login_automatico_screen.dart
//
// Tela que recebe o deep link de LOGIN AUTOMÁTICO (magic link):
//   wizmartapp://wizmartapp.com/loginautomatico#access_token=...
//
// Quando o link abre o app, o SDK do Supabase (fluxo implícito) detecta
// os tokens no fragmento e estabelece a sessão sozinho. Esta tela faz a
// PONTE para o modelo do app novo: valida o promotor na tabela `users`,
// replica a guarda anti-mistura-de-contas e popula o SessionService
// local (a fonte da verdade de "logado" aqui) — exatamente o mesmo que
// o login por senha faz em auth_screen._entrar.
//
// IMPORTANTE (risco discutido): o listener de onAuthStateChange é
// ESCOPADO a esta tela (criado no initState, cancelado no dispose). Ele
// NÃO dispara no boot nem no login por senha — só quando o promotor
// realmente chega aqui pelo link. A trava `_jaProcessou` garante uma
// única execução.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/sync_engine.dart' show appDatabaseProvider;
import '../../../core/utils/app_colors.dart';
import '../../../core/utils/auth_session_expired.dart';
import '../../../core/utils/device_info_service.dart';
import '../../../core/utils/login_flow.dart';
import '../../../core/utils/logout_service.dart';
import '../../../core/utils/promotor_estado_reporter.dart';
import '../../../core/utils/session_service.dart';
import 'onboarding_permissoes_screen.dart';

class LoginAutomaticoScreen extends ConsumerStatefulWidget {
  const LoginAutomaticoScreen({super.key});

  @override
  ConsumerState<LoginAutomaticoScreen> createState() =>
      _LoginAutomaticoScreenState();
}

class _LoginAutomaticoScreenState
    extends ConsumerState<LoginAutomaticoScreen> {
  StreamSubscription<AuthState>? _sub;
  bool _jaProcessou = false;
  String _msg = 'Entrando pelo link...';

  @override
  void initState() {
    super.initState();
    // A sessão pode já estar pronta (SDK processou o link antes da tela
    // montar) ou chegar logo em seguida. Cobrimos os dois: checagem
    // imediata + listener escopado. O onAuthStateChange reentrega o
    // estado atual a novos ouvintes, então o caso "já pronto" também
    // cai aqui.
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      _tentarPonte();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _tentarPonte());

    // Salvaguarda: se em alguns segundos não veio sessão (link expirado
    // ou inválido), volta pro login em vez de ficar preso no spinner.
    Future.delayed(const Duration(seconds: 12), () {
      if (!mounted || _jaProcessou) return;
      if (Supabase.instance.client.auth.currentSession == null) {
        _falhar('Não foi possível entrar pelo link. '
            'Faça login com sua senha.');
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _tentarPonte() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (!deveProcessarPonte(
        sessaoPresente: session != null, jaProcessou: _jaProcessou)) {
      return;
    }
    _jaProcessou = true;
    await _executarPonte(session!);
  }

  Future<void> _executarPonte(Session session) async {
    try {
      final email = normalizarEmail(session.user.email ?? '');

      // 1) Mesma query do login por senha.
      final userData = await Supabase.instance.client
          .from('users')
          .select('id,nome,email,ativo,tipo_user')
          .eq('uid', session.user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 15));

      final val = validarUsuario(userData);
      if (!val.ok) {
        await Supabase.instance.client.auth.signOut();
        _falhar(mensagemValidacao(val.status));
        return;
      }

      // 2) Guarda anti-mistura-de-contas (idêntica ao login por senha),
      //    com UMA diferença: NÃO derruba a sessão recém-criada pelo link
      //    (signOutSupabase: false) — só apaga os dados locais do
      //    promotor anterior.
      final db = ref.read(appDatabaseProvider);
      String? ultimoEmail;
      try {
        final prefs = await SharedPreferences.getInstance();
        ultimoEmail = prefs.getString(LogoutService.lastLoggedEmailKey);
      } catch (_) {}
      if (ultimoEmail != null &&
          ultimoEmail.isNotEmpty &&
          normalizarEmail(ultimoEmail) != email) {
        final pend = await db.countPendentesParaSync();
        if (precisaConfirmarTrocaConta(
            ultimoEmail: normalizarEmail(ultimoEmail),
            emailNovo: email,
            pendencias: pend)) {
          if (!mounted) return;
          final ok = await _confirmarTroca(pend, ultimoEmail, email);
          if (ok != true) {
            await Supabase.instance.client.auth.signOut();
            _falhar('Login cancelado para proteger os dados '
                'ainda não enviados.');
            return;
          }
          await LogoutService.logoutCompletely(db, signOutSupabase: false);
        }
      }

      // 3) Popula a sessão LOCAL (fonte da verdade de "logado"). Login por
      //    link não tem senha — senhaHash fica vazio (não "lembra senha").
      await SessionService.saveSession(
        userId: val.userId!,
        email: email,
        nome: val.nome ?? '',
      );
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(LogoutService.lastLoggedEmailKey, email);
      } catch (_) {}
      AuthSessionExpired.reset();
      // ignore: discarded_futures
      DeviceInfoService.updateForEmail(email);
      // ignore: discarded_futures
      PromotorEstadoReporter.registrar(email: email, nome: val.nome ?? '');

      final onboardingFeito =
          await OnboardingPermissoesScreen.jaConcluido();
      if (!mounted) return;
      context.go(onboardingFeito ? '/home' : '/onboarding-permissoes');
    } on TimeoutException {
      _falhar('O servidor demorou para responder. '
          'Faça login com sua senha.');
    } catch (_) {
      _falhar('Não foi possível entrar agora. Tente novamente.');
    }
  }

  void _falhar(String msg) {
    if (!mounted) return;
    setState(() => _msg = msg);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) context.go('/auth');
    });
  }

  Future<bool?> _confirmarTroca(int pend, String anterior, String novo) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Conta diferente neste dispositivo',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Este celular tem $pend pendência${pend == 1 ? '' : 's'} de '
          'sincronismo da conta $anterior. Se você entrar como $novo, '
          'essas pendências (visitas e fotos não enviadas) serão apagadas. '
          'Tem certeza?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Apagar e entrar',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _msg,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
