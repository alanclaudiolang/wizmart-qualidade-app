// lib/presentation/screens/auth/login_automatico_screen.dart
//
// Destino do deep link wizmartapp://wizmartapp.com/loginautomatico
// (magic link do e-mail). Quem valida o token do link é o próprio
// supabase_flutter (observador de deep link interno, getSessionFromUrl);
// esta tela só espera a sessão aparecer e completa o login local via
// LoginFlow (tabela users + SessionService), com a proteção de dados
// não sincronizados de outra conta.
//
// Estados possíveis:
//   - aguardando: espera curta pela sessão (token do link em validação)
//   - sucesso: navega pra /home ou /onboarding-permissoes
//   - falha: link expirado/aberto sem token, conta inválida ou login
//     cancelado por proteção — mensagem clara + botão pro login manual.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/sync_engine.dart' show appDatabaseProvider;
import '../../../core/utils/login_flow.dart';
import '../../../core/utils/persistent_logger.dart';
import 'onboarding_permissoes_screen.dart';

class LoginAutomaticoScreen extends ConsumerStatefulWidget {
  const LoginAutomaticoScreen({super.key});

  @override
  ConsumerState<LoginAutomaticoScreen> createState() =>
      _LoginAutomaticoScreenState();
}

class _LoginAutomaticoScreenState
    extends ConsumerState<LoginAutomaticoScreen> {
  String? _erro;
  StreamSubscription<AuthState>? _authSub;
  Timer? _timeout;
  bool _concluindo = false;

  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;

    // Caso 1: o supabase_flutter já processou o token do link antes da
    // tela montar (cold start rápido) — sessão já existe.
    if (client.auth.currentSession != null) {
      _concluir();
      return;
    }

    // Caso 2: o token ainda está sendo validado — espera o signedIn.
    _authSub = client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn) {
        _concluir();
      }
    });

    // Caso 3: tela aberta sem token válido (link expirado/reusado, ou
    // navegação direta). Sem sessão após a espera, mostra orientação.
    _timeout = Timer(const Duration(seconds: 12), () {
      if (!mounted || _concluindo) return;
      if (Supabase.instance.client.auth.currentSession == null) {
        setState(() =>
            _erro = 'O link expirou. Solicite um novo no login.');
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _timeout?.cancel();
    super.dispose();
  }

  Future<void> _concluir() async {
    if (_concluindo) return;
    _concluindo = true;
    _timeout?.cancel();
    await PersistentLogger.append(
        'auth', 'login automático: sessão recebida, validando usuário');
    final resultado = await LoginFlow.concluirLoginComSessao(
      db: ref.read(appDatabaseProvider),
      onboardingJaConcluido: OnboardingPermissoesScreen.jaConcluido,
    );
    if (!mounted) return;
    if (resultado.ok) {
      // Entra pelo /splash (e não direto pela rota final): o splash é
      // quem roda a recuperação de boot (fotos travadas em uploading/
      // watermark_pending) e a restauração da última visita aberta —
      // no cold start via deep link esses passos ainda não rodaram.
      context.go('/splash');
    } else {
      setState(() => _erro = resultado.erro);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: _erro == null
                ? const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF38A169)),
                      SizedBox(height: 24),
                      Text(
                        'Entrando automaticamente...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 16, color: Color(0xFF1A202C)),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.link_off,
                          size: 48, color: Colors.orange),
                      const SizedBox(height: 16),
                      Text(
                        _erro!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 15, color: Color(0xFF1A202C)),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 48,
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF38A169),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => context.go('/auth'),
                          child: const Text(
                            'Ir para o login',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
