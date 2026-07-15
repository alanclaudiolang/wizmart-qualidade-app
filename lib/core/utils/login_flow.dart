// lib/core/utils/login_flow.dart
//
// Conclusão de login compartilhada entre a AuthScreen (email+senha) e o
// login automático por magic link (deep link). A partir de uma sessão
// Supabase Auth já estabelecida, valida o usuário na tabela `users`,
// popula o SessionService local (o app depende dele, não só da sessão
// do Supabase) e decide a rota inicial (onboarding ou home).
//
// PROTEÇÃO DE DADOS (mesma regra do pré-check da AuthScreen): se o
// último e-mail logado neste aparelho é DIFERENTE do e-mail da sessão
// nova E ainda existem pendências de sincronismo (visitas/fotos/outbox),
// o login automático é CANCELADO — nunca apagamos dados não sincronizados
// sem confirmação explícita, e um clique em link de e-mail não é
// confirmação. O promotor é orientado a entrar com a senha (fluxo que
// mostra o diálogo de confirmação).

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/app_database.dart';
import 'auth_session_expired.dart';
import 'device_info_service.dart';
import 'logout_service.dart';
import 'persistent_logger.dart';
import 'promotor_estado_reporter.dart';
import 'session_service.dart';

/// Resultado da tentativa de concluir o login a partir de uma sessão
/// Supabase. `rota` preenchida somente em caso de sucesso.
class ResultadoLoginFlow {
  final bool ok;
  final String? rota;
  final String? erro;
  const ResultadoLoginFlow.sucesso(this.rota)
      : ok = true,
        erro = null;
  const ResultadoLoginFlow.falha(this.erro)
      : ok = false,
        rota = null;
}

class LoginFlow {
  LoginFlow._();

  /// Valida a sessão Supabase corrente contra a tabela `users` e popula a
  /// sessão local. [permitirTrocaDeConta] fica `false` no login automático
  /// (deep link): troca de conta com pendências locais cancela o login.
  static Future<ResultadoLoginFlow> concluirLoginComSessao({
    required AppDatabase db,
    required Future<bool> Function() onboardingJaConcluido,
    bool permitirTrocaDeConta = false,
  }) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      return const ResultadoLoginFlow.falha(
          'O link expirou. Solicite um novo no login.');
    }
    final email = (user.email ?? '').trim().toLowerCase();
    if (email.isEmpty) {
      return const ResultadoLoginFlow.falha(
          'O link expirou. Solicite um novo no login.');
    }

    // Proteção: troca de conta via link NÃO pode descartar trabalho
    // pendente de outro promotor neste aparelho.
    if (!permitirTrocaDeConta) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final ultimoEmail =
            prefs.getString(LogoutService.lastLoggedEmailKey)?.trim();
        if (ultimoEmail != null &&
            ultimoEmail.isNotEmpty &&
            ultimoEmail != email) {
          final pend = await db.countPendentesParaSync();
          if (pend > 0) {
            await client.auth.signOut();
            await PersistentLogger.append('auth',
                'login automático cancelado: troca de conta '
                '($ultimoEmail -> $email) com $pend pendência(s) local(is)');
            return ResultadoLoginFlow.falha(
                'Login cancelado para proteger os dados ainda não '
                'sincronizados da conta $ultimoEmail neste aparelho. '
                'Faça login com sua senha.');
          }
        }
      } catch (_) {
        // Pré-check falhou (prefs corrompido etc.) — segue o login,
        // mesmo comportamento tolerante da AuthScreen.
      }
    }

    try {
      final userData = await client
          .from('users')
          .select('id,nome,email,ativo,tipo_user')
          .eq('uid', user.id)
          .maybeSingle();
      if (userData == null) {
        await client.auth.signOut();
        return const ResultadoLoginFlow.falha(
            'Usuário não encontrado no banco de dados.');
      }
      if (userData['ativo'] == false) {
        await client.auth.signOut();
        return const ResultadoLoginFlow.falha(
            'Sua conta está desativada. Contate seu supervisor.');
      }
      if (userData['tipo_user'] != 3) {
        await client.auth.signOut();
        return const ResultadoLoginFlow.falha(
            'Acesso apenas para Promotores.');
      }

      final nome = userData['nome'] as String? ?? '';
      await SessionService.saveSession(
        userId: userData['id'] as int,
        email: email,
        nome: nome,
        // Login por link não tem senha digitada — nada a lembrar.
        senhaHash: '',
      );
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(LogoutService.lastLoggedEmailKey, email);
      } catch (_) {}
      AuthSessionExpired.reset();
      // ignore: discarded_futures
      DeviceInfoService.updateForEmail(email);
      // ignore: discarded_futures
      PromotorEstadoReporter.registrar(email: email, nome: nome);

      final onboardingFeito = await onboardingJaConcluido();
      return ResultadoLoginFlow.sucesso(
          onboardingFeito ? '/home' : '/onboarding-permissoes');
    } catch (e) {
      await PersistentLogger.append(
          'auth', 'login automático falhou na validação: $e');
      return const ResultadoLoginFlow.falha(
          'Não foi possível entrar agora. Tente novamente.');
    }
  }
}
