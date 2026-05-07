// lib/presentation/screens/auth/auth_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/session_service.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _loading = false;
  bool _senhaVisivel = false;
  bool _lembrarMe = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _carregarEmailSalvo();
  }

  Future<void> _carregarEmailSalvo() async {
    final session = await SessionService.getSession();
    if (session != null && session.email.isNotEmpty) {
      _emailController.text = session.email;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    final email = _emailController.text.trim().toLowerCase();
    final senha = _senhaController.text;

    if (email.isEmpty || senha.isEmpty) {
      setState(() => _error = 'Preencha o email e a senha.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1. Verifica conexão tentando logar via Supabase Auth
      final authResponse = await Supabase.instance.client.auth
          .signInWithPassword(email: email, password: senha);

      if (authResponse.user == null) {
        setState(() {
          _error = 'Usuário ou senha incorretos.';
          _loading = false;
        });
        return;
      }

      // 2. Busca dados do usuário na tabela users
      final userData = await Supabase.instance.client
          .from('users')
          .select('id,nome,email,foto,ativo,tipo_user,supervisor_associado')
          .eq('uid', authResponse.user!.id)
          .maybeSingle();

      if (userData == null) {
        await Supabase.instance.client.auth.signOut();
        setState(() {
          _error = 'Usuário não encontrado. Contate seu supervisor.';
          _loading = false;
        });
        return;
      }

      // 3. Verifica se está ativo
      if (userData['ativo'] == false) {
        await Supabase.instance.client.auth.signOut();
        setState(() {
          _error = 'Sua conta está desativada. Contate seu supervisor.';
          _loading = false;
        });
        return;
      }

      // 4. Verifica se é promotor (tipo_user == 3)
      if (userData['tipo_user'] != 3) {
        await Supabase.instance.client.auth.signOut();
        setState(() {
          _error = 'Acesso apenas para Promotores.';
          _loading = false;
        });
        return;
      }

      // 5. Salva sessão persistente
      await SessionService.saveSession(
        userId: userData['id'] as int,
        email: email,
        nome: userData['nome'] as String? ?? '',
        senhaHash: _lembrarMe ? senha : '',
      );

      if (mounted) context.go('/home');
    } on AuthException catch (e) {
      setState(() {
        _error = e.message.contains('Invalid login')
            ? 'Usuário ou senha incorretos.'
            : 'Erro ao entrar. Verifique sua conexão.';
        _loading = false;
      });
    } catch (e) {
      // Tenta login offline se não há conexão
      final session = await SessionService.getSession();
      if (session != null &&
          session.email == email &&
          session.senhaHash == _senhaController.text &&
          session.senhaHash.isNotEmpty) {
        if (mounted) context.go('/home');
        return;
      }
      setState(() {
        _error = 'Erro ao conectar. Verifique sua internet.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),

              // Logo WizMart
              Image.asset(
                'assets/images/logo.png',
                height: 60,
                alignment: Alignment.centerLeft,
                errorBuilder: (_, __, ___) => const Text(
                  'WizMart',
                  style: TextStyle(
                    color: Color(0xFF38A169),
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Título
              const Text(
                'Bem vindo de volta!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A202C),
                ),
              ),

              const SizedBox(height: 24),

              // Campo Email
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                style: const TextStyle(fontSize: 16, color: Color(0xFF1A202C)),
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: const TextStyle(color: Color(0xFF718096)),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FA),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFF38A169), width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onSubmitted: (_) => FocusScope.of(context).nextFocus(),
              ),

              const SizedBox(height: 16),

              // Campo Senha
              TextField(
                controller: _senhaController,
                obscureText: !_senhaVisivel,
                style: const TextStyle(fontSize: 16, color: Color(0xFF1A202C)),
                decoration: InputDecoration(
                  labelText: 'Senha',
                  labelStyle: const TextStyle(color: Color(0xFF718096)),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FA),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFF38A169), width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _senhaVisivel ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: const Color(0xFF718096),
                    ),
                    onPressed: () => setState(() => _senhaVisivel = !_senhaVisivel),
                  ),
                ),
                onSubmitted: (_) => _entrar(),
              ),

              const SizedBox(height: 16),

              // Lembre de mim + Esqueceu a senha
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Switch.adaptive(
                        value: _lembrarMe,
                        onChanged: (v) => setState(() => _lembrarMe = v),
                        activeColor: const Color(0xFF38A169),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Lembre de mim',
                        style: TextStyle(fontSize: 12, color: Color(0xFF1A202C)),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => _mostrarRecuperarSenha(),
                    child: const Text(
                      'Esqueceu sua Senha?',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF38A169),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),

              // Erro
              if (_error != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF5F5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFC8181)),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFC53030), fontSize: 14),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Botão Entrar agora
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _loading ? null : _entrar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38A169),
                    disabledBackgroundColor: const Color(0xFF38A169).withOpacity(0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Entrar agora',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarRecuperarSenha() {
    final emailCtrl = TextEditingController(text: _emailController.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recuperar senha'),
        content: TextField(
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email cadastrado',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF38A169),
            ),
            onPressed: () async {
              final email = emailCtrl.text.trim();
              if (email.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await Supabase.instance.client.auth.resetPasswordForEmail(email);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Email de recuperação enviado!'),
                      backgroundColor: Color(0xFF38A169),
                    ),
                  );
                }
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Erro ao enviar email. Tente novamente.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Enviar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
