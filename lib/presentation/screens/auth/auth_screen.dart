import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../../../core/utils/session_service.dart';
import '../../../core/constants/app_constants.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

enum _ConexaoStatus { verificando, online, offline, servidorInacessivel }

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _loading = false;
  bool _senhaVisivel = false;
  bool _lembrarMe = true;
  String? _error;
  _ConexaoStatus _conexao = _ConexaoStatus.verificando;
  Timer? _pingTimer;

  static const _versao = 'v0.6';

  @override
  void initState() {
    super.initState();
    _carregarEmailSalvo();
    _ping();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) => _ping());
  }

  Future<void> _ping() async {
    setState(() => _conexao = _ConexaoStatus.verificando);
    try {
      final res = await http.head(
        Uri.parse('${AppConstants.supabaseUrl}/rest/v1/'),
        headers: {'apikey': AppConstants.supabaseAnonKey},
      ).timeout(const Duration(seconds: 5));
      setState(() => _conexao = res.statusCode < 500
          ? _ConexaoStatus.online
          : _ConexaoStatus.servidorInacessivel);
    } on TimeoutException {
      setState(() => _conexao = _ConexaoStatus.servidorInacessivel);
    } catch (_) {
      setState(() => _conexao = _ConexaoStatus.offline);
    }
  }

  Future<void> _carregarEmailSalvo() async {
    final session = await SessionService.getSession();
    if (session != null && session.email.isNotEmpty) {
      _emailController.text = session.email;
    }
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
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
    setState(() { _loading = true; _error = null; });
    try {
      final authResponse = await Supabase.instance.client.auth
          .signInWithPassword(email: email, password: senha);
      if (authResponse.user == null) {
        setState(() { _error = 'Usuário ou senha incorretos.'; _loading = false; });
        return;
      }
      final userData = await Supabase.instance.client
          .from('users')
          .select('id,nome,email,ativo,tipo_user')
          .eq('uid', authResponse.user!.id)
          .maybeSingle();
      if (userData == null) {
        await Supabase.instance.client.auth.signOut();
        setState(() { _error = 'Usuário não encontrado no banco de dados.'; _loading = false; });
        return;
      }
      if (userData['ativo'] == false) {
        await Supabase.instance.client.auth.signOut();
        setState(() { _error = 'Sua conta está desativada. Contate seu supervisor.'; _loading = false; });
        return;
      }
      if (userData['tipo_user'] != 3) {
        await Supabase.instance.client.auth.signOut();
        setState(() { _error = 'Acesso apenas para Promotores.'; _loading = false; });
        return;
      }
      await SessionService.saveSession(
        userId: userData['id'] as int,
        email: email,
        nome: userData['nome'] as String? ?? '',
        senhaHash: _lembrarMe ? senha : '',
      );
      if (mounted) context.go('/home');
    } on AuthException catch (e) {
      setState(() { _error = 'AuthException: ${e.message}'; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Erro: ${e.runtimeType}: $e'; _loading = false; });
    }
  }

  Widget _buildConexaoIndicador() {
    Color cor;
    String texto;
    IconData icone;
    switch (_conexao) {
      case _ConexaoStatus.verificando:
        cor = Colors.orange;
        texto = 'Verificando...';
        icone = Icons.sync;
        break;
      case _ConexaoStatus.online:
        cor = const Color(0xFF38A169);
        texto = 'Online';
        icone = Icons.wifi;
        break;
      case _ConexaoStatus.offline:
        cor = Colors.red;
        texto = 'Offline';
        icone = Icons.wifi_off;
        break;
      case _ConexaoStatus.servidorInacessivel:
        cor = Colors.orange;
        texto = 'Servidor inacessível';
        icone = Icons.cloud_off;
        break;
    }
    return GestureDetector(
      onTap: _ping,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, color: cor, size: 14),
          const SizedBox(width: 4),
          Text(texto, style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('WizMart', style: TextStyle(color: Color(0xFF38A169), fontSize: 32, fontWeight: FontWeight.bold)),
                  _buildConexaoIndicador(),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Bem vindo de volta!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A202C))),
              const SizedBox(height: 24),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(
                  labelText: 'Email',
                  filled: true, fillColor: const Color(0xFFF8F9FA),
                  enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 2), borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF38A169), width: 2), borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _senhaController,
                obscureText: !_senhaVisivel,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: 'Senha',
                  filled: true, fillColor: const Color(0xFFF8F9FA),
                  enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 2), borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF38A169), width: 2), borderRadius: BorderRadius.circular(12)),
                  suffixIcon: IconButton(
                    icon: Icon(_senhaVisivel ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: const Color(0xFF718096)),
                    onPressed: () => setState(() => _senhaVisivel = !_senhaVisivel),
                  ),
                ),
                onSubmitted: (_) => _entrar(),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Switch.adaptive(value: _lembrarMe, onChanged: (v) => setState(() => _lembrarMe = v), activeColor: const Color(0xFF38A169)),
                    const SizedBox(width: 8),
                    const Text('Lembre de mim', style: TextStyle(fontSize: 12)),
                  ]),
                  TextButton(
                    onPressed: _mostrarRecuperarSenha,
                    child: const Text('Esqueceu sua Senha?', style: TextStyle(fontSize: 12, color: Color(0xFF38A169))),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFFFF5F5), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFC8181))),
                  child: SelectableText(_error!, style: const TextStyle(color: Color(0xFFC53030), fontSize: 13)),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _loading ? null : _entrar,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38A169), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _loading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Entrar agora', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 40),
              Text(_versao, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Color(0xFF38A169))),
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
        content: TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email cadastrado', border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38A169)),
            onPressed: () async {
              final email = emailCtrl.text.trim();
              if (email.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await Supabase.instance.client.auth.resetPasswordForEmail(email);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email de recuperação enviado!'), backgroundColor: Color(0xFF38A169)));
              } catch (_) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao enviar email.'), backgroundColor: Colors.red));
              }
            },
            child: const Text('Enviar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
