import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../../../core/utils/session_service.dart';
import '../../../core/utils/device_info_service.dart';
import '../../../core/utils/apk_updater_service.dart';
import '../../../core/utils/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/version_check_service.dart';
import '../../widgets/apk_download_dialog.dart';
import 'onboarding_permissoes_screen.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

enum _ConexaoStatus { verificando, online, offline, servidorInacessivel }

class _AuthScreenState extends ConsumerState<AuthScreen> {
  // Trava pra não abrir o modal de force-update várias vezes no mesmo
  // ciclo. Reseta no dispose.
  bool _bloqueioForceUpdateAberto = false;
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _loading = false;
  bool _senhaVisivel = false;
  bool _lembrarMe = true;
  String? _error;
  _ConexaoStatus _conexao = _ConexaoStatus.verificando;
  Timer? _pingTimer;

  static String get _versao =>
      'v${AppConstants.appVersion} (build ${AppConstants.buildNumber}) — ${AppConstants.buildTime}';

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
          .signInWithPassword(email: email, password: senha)
          .timeout(const Duration(seconds: 15));
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
      final userId = userData['id'] as int;
      await SessionService.saveSession(
        userId: userId,
        email: email,
        nome: userData['nome'] as String? ?? '',
        senhaHash: _lembrarMe ? senha : '',
      );
      // Atualiza device_info em background (igual FF antigo: match por
      // email, update direto na tabela users). Falha silenciosa.
      // ignore: discarded_futures
      DeviceInfoService.updateForEmail(email);
      // Se ainda não passou pelo onboarding de permissões (primeira
      // instalação), abre essa tela antes da home. Senão, vai direto.
      final onboardingFeito =
          await OnboardingPermissoesScreen.jaConcluido();
      if (!mounted) return;
      context.go(onboardingFeito ? '/home' : '/onboarding-permissoes');
    } on AuthException catch (e) {
      // Mensagens canônicas do Supabase em PT-BR.
      final msg = e.message.toLowerCase();
      String friendly;
      if (msg.contains('invalid login') ||
          msg.contains('invalid credentials')) {
        friendly = 'Email ou senha incorretos.';
      } else if (msg.contains('email not confirmed')) {
        friendly = 'Email ainda não confirmado.';
      } else {
        friendly = e.message;
      }
      setState(() { _error = friendly; _loading = false; });
    } catch (e) {
      final txt = e.toString().toLowerCase();
      String friendly;
      if (txt.contains('socketexception') ||
          txt.contains('failed host lookup') ||
          txt.contains('network is unreachable') ||
          txt.contains('connection refused') ||
          e is TimeoutException) {
        friendly =
            'Sem internet. Verifique sua conexão e tente novamente.';
      } else if (txt.contains('timeout')) {
        friendly =
            'O servidor demorou para responder. Tente novamente em alguns instantes.';
      } else {
        friendly = 'Não foi possível entrar agora. Tente novamente.';
      }
      setState(() { _error = friendly; _loading = false; });
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
    // Force-update OBRIGATÓRIO pra usuário deslogado quando há build
    // novo — não espera D+1. Quem ainda não fez login não tem dados
    // locais pra perder, então atualizar imediato é seguro e garante
    // que promotor novo SEMPRE entra pela versão mais recente.
    ref.listen<AsyncValue<AppVersionInfo>>(appVersionProvider, (_, next) {
      final info = next.asData?.value;
      if (info == null) return;
      if (!info.outdated) return;
      if (_bloqueioForceUpdateAberto) return;
      _bloqueioForceUpdateAberto = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mostrarForceUpdateDeslogado(info);
      });
    });

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
                  Image.asset(
                    'assets/images/logo_wizmart.webp',
                    height: 40,
                    fit: BoxFit.contain,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildConexaoIndicador(),
                    ],
                  ),
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
              Text(_versao, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Color(0xFF8892B0))),
            ],
          ),
        ),
      ),
    );
  }

  /// Bloqueia a tela de login com modal de atualização obrigatória
  /// quando há build novo disponível. Diferente do bloqueio da home,
  /// aqui NÃO espera D+1 — promotor ainda não tem dados locais, então
  /// pode/deve atualizar imediatamente.
  Future<void> _mostrarForceUpdateDeslogado(AppVersionInfo info) async {
    final url = info.apkDownloadUrl;
    if (url == null) {
      _bloqueioForceUpdateAberto = false;
      return;
    }
    final apkOk = await ApkUpdaterService.apkAcessivel(url);
    if (!apkOk) {
      _bloqueioForceUpdateAberto = false;
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            'Atualização obrigatória',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: Text(
            'Há uma nova versão do app. Atualize antes de entrar.\n\n'
            'Build novo: ${info.latestBuild ?? '?'}.',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38A169),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.of(dialogCtx).pop();
                if (mounted) {
                  final cancelToken = CancelToken();
                  await showDialog<void>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => ApkDownloadDialog(
                      url: url,
                      cancelToken: cancelToken,
                    ),
                  );
                }
                _bloqueioForceUpdateAberto = false;
                if (mounted) ref.invalidate(appVersionProvider);
              },
              child: const Text('Atualizar agora'),
            ),
          ],
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
