// lib/presentation/screens/auth/recuperar_senha_screen.dart
//
// Destino do deep link wizmartapp://wizmartapp.com/recoverpassword
// (e-mail "Reset de Senha" do Supabase) e do evento passwordRecovery
// do Auth. O token do link é validado pelo supabase_flutter; com a
// sessão de recuperação ativa, o promotor define a senha nova via
// auth.updateUser. Ao salvar, encerra a sessão e volta pro login —
// o promotor entra com a senha nova (e o fluxo normal popula o
// SessionService, checagens de conta, etc.).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/persistent_logger.dart';

class RecuperarSenhaScreen extends StatefulWidget {
  const RecuperarSenhaScreen({super.key});

  @override
  State<RecuperarSenhaScreen> createState() => _RecuperarSenhaScreenState();
}

class _RecuperarSenhaScreenState extends State<RecuperarSenhaScreen> {
  final _senhaController = TextEditingController();
  final _confirmarController = TextEditingController();
  bool _senhaVisivel = false;
  bool _salvando = false;
  bool _semSessao = false;
  String? _erro;
  StreamSubscription<AuthState>? _authSub;
  Timer? _timeout;

  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;
    // A sessão de recuperação pode ainda estar sendo criada a partir do
    // token do link (cold start). Espera curta antes de declarar que a
    // tela foi aberta sem o link.
    if (client.auth.currentSession == null) {
      _authSub = client.auth.onAuthStateChange.listen((data) {
        if (data.event == AuthChangeEvent.passwordRecovery ||
            data.event == AuthChangeEvent.signedIn) {
          _timeout?.cancel();
          if (mounted && _semSessao) setState(() => _semSessao = false);
        }
      });
      _timeout = Timer(const Duration(seconds: 12), () {
        if (!mounted) return;
        if (Supabase.instance.client.auth.currentSession == null) {
          setState(() => _semSessao = true);
        }
      });
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _timeout?.cancel();
    _senhaController.dispose();
    _confirmarController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final senha = _senhaController.text;
    final confirmar = _confirmarController.text;
    if (senha.length < 6) {
      setState(() => _erro = 'A senha deve ter pelo menos 6 caracteres.');
      return;
    }
    if (senha != confirmar) {
      setState(() => _erro = 'A nova senha não confere com a confirmação.');
      return;
    }
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      await Supabase.instance.client.auth
          .updateUser(UserAttributes(password: senha))
          .timeout(const Duration(seconds: 15));
      await PersistentLogger.append('auth', 'senha redefinida via deep link');
      // Sessão de recuperação encerrada — o promotor entra com a senha
      // nova pelo fluxo normal (que valida a conta e popula a sessão
      // local).
      try {
        await Supabase.instance.client.auth
            .signOut()
            .timeout(const Duration(seconds: 5));
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Senha alterada! Entre com a nova senha.'),
        backgroundColor: Color(0xFF38A169),
      ));
      context.go('/auth');
    } on AuthWeakPasswordException {
      setState(() {
        _erro = 'A senha deve ter pelo menos 6 caracteres.';
        _salvando = false;
      });
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      setState(() {
        _erro = msg.contains('expired') || msg.contains('invalid')
            ? 'O link expirou. Solicite um novo no login.'
            : 'Não foi possível alterar a senha agora. Tente novamente.';
        _salvando = false;
      });
    } catch (e) {
      await PersistentLogger.append('auth', 'falha ao redefinir senha: $e');
      setState(() {
        _erro = 'Não foi possível alterar a senha agora. Tente novamente.';
        _salvando = false;
      });
    }
  }

  InputDecoration _decoracao(String label, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFF8F9FA),
      enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 2),
          borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF38A169), width: 2),
          borderRadius: BorderRadius.circular(12)),
      suffixIcon: suffix,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Definir nova senha',
            style: TextStyle(color: Color(0xFF1A202C), fontSize: 18)),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: _semSessao ? _buildSemSessao() : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildSemSessao() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 48),
        const Icon(Icons.mark_email_read_outlined,
            size: 48, color: Color(0xFF38A169)),
        const SizedBox(height: 16),
        const Text(
          'Abra esta tela pelo link enviado no seu e-mail. '
          'Se demorou, solicite um novo link no login.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: Color(0xFF1A202C)),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF38A169),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => context.go('/auth'),
            child: const Text('Ir para o login',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        const Text('Crie uma nova senha para sua conta.',
            style: TextStyle(fontSize: 15, color: Color(0xFF4A5568))),
        const SizedBox(height: 24),
        TextField(
          controller: _senhaController,
          obscureText: !_senhaVisivel,
          decoration: _decoracao(
            'Nova senha',
            suffix: IconButton(
              icon: Icon(
                  _senhaVisivel
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: const Color(0xFF718096)),
              onPressed: () =>
                  setState(() => _senhaVisivel = !_senhaVisivel),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmarController,
          obscureText: !_senhaVisivel,
          decoration: _decoracao('Confirmar nova senha'),
          onSubmitted: (_) => _salvar(),
        ),
        if (_erro != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: const Color(0xFFFFF5F5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFC8181))),
            child: SelectableText(_erro!,
                style: const TextStyle(
                    color: Color(0xFFC53030), fontSize: 13)),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF38A169),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _salvando ? null : _salvar,
            child: _salvando
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Salvar nova senha',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}
