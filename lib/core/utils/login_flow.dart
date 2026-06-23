// lib/core/utils/login_flow.dart
//
// Lógica PURA e compartilhada do pós-login, extraída de
// `auth_screen._entrar` para ser:
//   1. fonte única da verdade (login por senha E login por deep link
//      magic link usam o MESMO código de validação/guarda); e
//   2. testável headless (sem BuildContext, sem Supabase, sem Drift,
//      sem canais de plataforma) — é o "simulador" do banco de testes.
//
// Nada aqui faz I/O. As telas injetam os dados (registro de `users`,
// contagem de pendências, último e-mail logado) e estas funções decidem.
// Assim a MESMA decisão de risco roda no login por senha e na ponte do
// magic link, e os testes exercitam exatamente esse caminho.

/// Resultado da validação do registro `users` retornado do Supabase,
/// nas MESMAS regras do login por senha (`auth_screen._entrar`).
enum LoginValidacao {
  ok,

  /// `signInWithPassword`/`getSessionFromUrl` autenticou no Auth, mas não
  /// há linha correspondente em `users` (uid sem cadastro).
  usuarioNaoEncontrado,

  /// `users.ativo == false` — conta desativada pelo supervisor.
  contaDesativada,

  /// `users.tipo_user != 3` — acesso é só para Promotores.
  naoPromotor,
}

/// Saída da validação. Quando [status] == ok, [userId] e [nome] vêm
/// preenchidos para gravar no SessionService.
class ResultadoValidacaoLogin {
  final LoginValidacao status;
  final int? userId;
  final String? nome;

  const ResultadoValidacaoLogin(this.status, {this.userId, this.nome});

  bool get ok => status == LoginValidacao.ok;
}

/// Mensagens amigáveis (PT-BR) idênticas às já usadas no login por senha,
/// para a UI exibir sem duplicar texto.
String mensagemValidacao(LoginValidacao v) {
  switch (v) {
    case LoginValidacao.ok:
      return '';
    case LoginValidacao.usuarioNaoEncontrado:
      return 'Usuário não encontrado no banco de dados.';
    case LoginValidacao.contaDesativada:
      return 'Sua conta está desativada. Contate seu supervisor.';
    case LoginValidacao.naoPromotor:
      return 'Acesso apenas para Promotores.';
  }
}

/// Normaliza e-mail do mesmo jeito que o login por senha
/// (`trim().toLowerCase()`), para a comparação de troca de conta e a
/// gravação da sessão baterem byte a byte com o fluxo existente.
String normalizarEmail(String email) => email.trim().toLowerCase();

/// PURA — valida o registro `users` (vindo de
/// `from('users').select('id,nome,email,ativo,tipo_user').eq('uid', ...)`).
/// Replica EXATAMENTE as checagens de `auth_screen._entrar` (linhas
/// 182-197): null → não encontrado; ativo==false → desativada;
/// tipo_user!=3 → não promotor; senão ok.
ResultadoValidacaoLogin validarUsuario(Map<String, dynamic>? userData) {
  if (userData == null) {
    return const ResultadoValidacaoLogin(LoginValidacao.usuarioNaoEncontrado);
  }
  if (userData['ativo'] == false) {
    return const ResultadoValidacaoLogin(LoginValidacao.contaDesativada);
  }
  if (userData['tipo_user'] != 3) {
    return const ResultadoValidacaoLogin(LoginValidacao.naoPromotor);
  }
  final id = userData['id'];
  if (id is! int) {
    // Defensivo: sem id inteiro não há como gravar sessão. Trata como
    // "não encontrado" em vez de estourar (o login por senha assumia
    // `userData['id'] as int` direto; aqui somos mais robustos).
    return const ResultadoValidacaoLogin(LoginValidacao.usuarioNaoEncontrado);
  }
  return ResultadoValidacaoLogin(
    LoginValidacao.ok,
    userId: id,
    nome: (userData['nome'] as String?) ?? '',
  );
}

/// PURA — decide se é preciso limpar TUDO do promotor anterior antes de
/// logar o novo. Replica a guarda anti-mistura-de-contas de
/// `auth_screen._entrar` (linhas 117-124): só limpa quando o último
/// e-mail logado neste aparelho é DIFERENTE do que está entrando E ainda
/// há pendências de sincronismo locais.
///
/// [ultimoEmail] já deve vir normalizado (ou null); [emailNovo] também.
bool precisaConfirmarTrocaConta({
  required String? ultimoEmail,
  required String emailNovo,
  required int pendencias,
}) {
  if (ultimoEmail == null || ultimoEmail.isEmpty) return false;
  if (ultimoEmail == emailNovo) return false;
  return pendencias > 0;
}

/// PURA — dado o estado do listener de auth da TELA do deep link, decide
/// se deve rodar a ponte agora. Garante idempotência (roda UMA vez) e que
/// só age quando a sessão do Supabase já existe. Como o listener é
/// escopado à tela do link (criado no initState, cancelado no dispose),
/// ele NÃO dispara no boot nem no login por senha — esta função é a trava
/// final de "rodar exatamente uma vez".
bool deveProcessarPonte({
  required bool sessaoPresente,
  required bool jaProcessou,
}) {
  if (jaProcessou) return false;
  return sessaoPresente;
}
