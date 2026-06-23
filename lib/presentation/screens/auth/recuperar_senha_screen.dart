// lib/presentation/screens/auth/recuperar_senha_screen.dart
//
// Tela que recebe o deep link de REDEFINIÇÃO DE SENHA:
//   wizmartapp://wizmartapp.com/recoverpassword#access_token=...&type=recovery
//
// O SDK do Supabase (fluxo implícito) estabelece a sessão de recuperação
// a partir do link. Aqui o promotor digita a nova senha, que é gravada
// via updateUser. Depois encerramos a sessão e voltamos pro login, para
// ele entrar com a senha nova (mesmo desfecho do app FlutterFlow antigo).
//
// Observação: NÃO populamos o SessionService aqui — recuperação de senha
// não é "login". O promotor loga normalmente com a senha nova depois.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/app_colors.dart';

class RecuperarSenhaScreen extends ConsumerStatefulWidget {
  const RecuperarSenhaScreen({super.key});

  @override
  ConsumerState<RecuperarSenhaScreen> createState() =>
      _RecuperarSenhaScreenState();
}

class _RecuperarSenhaScreenState extends ConsumerState<RecuperarSenhaScreen> {
  final _senha1 = TextEditingController();
  final _senha2 = TextEditingController();
  bool _ver1 = false;
  bool _ver2 = false;
  bool _loading = false;
  String? _error;

  StreamSubscription<AuthState>? _sub;
  // A sessão de recuperação pode chegar logo após a tela montar.
  bool _temSessao = false;

  @override
  void initState() {
    super.initState();
    _temSessao = Supabase.instance.client.auth.currentSession != null;
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      final tem = Supabase.instance.client.auth.currentSession != null;
      if (mounted && tem != _temSessao) setState(() => _temSessao = tem);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _senha1.dispose();
    _senha2.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final s1 = _senha1.text;
    final s2 = _senha2.text;
    if (s1.length < 6) {
      setState(() => _error = 'A senha deve ter pelo menos 6 caracteres.');
      return;
    }
    if (s1 != s2) {
      setState(() => _error = 'As senhas não conferem.');
      return;
    }
    if (Supabase.instance.client.auth.currentSession == null) {
      setState(() => _error =
          'O link de recuperação expirou. Solicite um novo no login.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth
          .updateUser(UserAttributes(password: s1))
          .timeout(const Duration(seconds: 15));
      // Sessão de recuperação cumpriu o papel — encerra e manda logar com
      // a senha nova.
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Senha alterada! Entre com a nova senha.'),
        backgroundColor: AppColors.primary,
      ));
      context.go('/auth');
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      String amigavel;
      if (msg.contains('same') || msg.contains('different from the old')) {
        amigavel = 'A nova senha não pode ser igual à anterior.';
      } else if (msg.contains('expired') || msg.contains('invalid')) {
        amigavel =
            'O link de recuperação expirou. Solicite um novo no login.';
      } else {
        amigavel = e.message;
      }
      setState(() {
        _error = amigavel;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Não foi possível alterar a senha agora. Tente novamente.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Definir nova senha'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              const Text(
                'Crie uma nova senha para sua conta.',
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _senha1,
                obscureText: !_ver1,
                decoration: InputDecoration(
                  labelText: 'Nova senha',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_ver1
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _ver1 = !_ver1),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _senha2,
                obscureText: !_ver2,
                onSubmitted: (_) => _salvar(),
                decoration: InputDecoration(
                  labelText: 'Confirmar nova senha',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_ver2
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _ver2 = !_ver2),
                  ),
                ),
              ),
              if (!_temSessao) ...[
                const SizedBox(height: 12),
                const Text(
                  'Abra esta tela pelo link enviado no seu e-mail. '
                  'Se demorou, solicite um novo link no login.',
                  style: TextStyle(color: AppColors.warning, fontSize: 12),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.dangerBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.dangerLight),
                  ),
                  child: Text(_error!,
                      style: const TextStyle(
                          color: AppColors.dangerText, fontSize: 13)),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _loading ? null : _salvar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
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
          ),
        ),
      ),
    );
  }
}
