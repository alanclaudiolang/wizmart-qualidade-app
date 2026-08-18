// test/login_flow_test.dart
//
// Simulador da LÓGICA do pós-login (compartilhada entre login por senha
// e ponte do magic link). Roda headless com `flutter test` — sem
// emulador, sem aparelho, sem Supabase/Drift. Cobre Android e iOS ao
// mesmo tempo porque essa lógica é Dart puro, idêntica nas duas
// plataformas.

import 'package:flutter_test/flutter_test.dart';
import 'package:wizmart_app/core/utils/login_flow.dart';

void main() {
  group('validarUsuario — mesmas regras do login por senha', () {
    test('usuário nulo → usuarioNaoEncontrado', () {
      final r = validarUsuario(null);
      expect(r.status, LoginValidacao.usuarioNaoEncontrado);
      expect(r.ok, isFalse);
    });

    test('ativo == false → contaDesativada (mesmo sendo promotor)', () {
      final r = validarUsuario({
        'id': 10,
        'nome': 'Fulano',
        'ativo': false,
        'tipo_user': 3,
      });
      expect(r.status, LoginValidacao.contaDesativada);
    });

    test('tipo_user != 3 → naoPromotor', () {
      final r = validarUsuario({
        'id': 10,
        'nome': 'Supervisor',
        'ativo': true,
        'tipo_user': 2,
      });
      expect(r.status, LoginValidacao.naoPromotor);
    });

    test('promotor ativo → ok, com userId e nome', () {
      final r = validarUsuario({
        'id': 42,
        'nome': 'Maria Promotora',
        'ativo': true,
        'tipo_user': 3,
      });
      expect(r.ok, isTrue);
      expect(r.userId, 42);
      expect(r.nome, 'Maria Promotora');
    });

    test('id ausente/não-inteiro → trata como não encontrado (defensivo)',
        () {
      final r = validarUsuario({
        'id': null,
        'nome': 'Sem id',
        'ativo': true,
        'tipo_user': 3,
      });
      expect(r.status, LoginValidacao.usuarioNaoEncontrado);
    });

    test('nome ausente → ok com nome vazio (não estoura)', () {
      final r = validarUsuario({
        'id': 7,
        'ativo': true,
        'tipo_user': 3,
      });
      expect(r.ok, isTrue);
      expect(r.nome, '');
    });
  });

  group('precisaConfirmarTrocaConta — guarda anti-mistura-de-contas', () {
    test('sem último e-mail → não limpa (primeiro login no aparelho)', () {
      expect(
        precisaConfirmarTrocaConta(
            ultimoEmail: null, emailNovo: 'a@x.com', pendencias: 5),
        isFalse,
      );
      expect(
        precisaConfirmarTrocaConta(
            ultimoEmail: '', emailNovo: 'a@x.com', pendencias: 5),
        isFalse,
      );
    });

    test('mesmo e-mail → retoma, nunca limpa (mesmo com pendências)', () {
      expect(
        precisaConfirmarTrocaConta(
            ultimoEmail: 'a@x.com', emailNovo: 'a@x.com', pendencias: 99),
        isFalse,
      );
    });

    test('e-mail diferente SEM pendências → não precisa confirmar', () {
      expect(
        precisaConfirmarTrocaConta(
            ultimoEmail: 'a@x.com', emailNovo: 'b@x.com', pendencias: 0),
        isFalse,
      );
    });

    test('e-mail diferente COM pendências → precisa confirmar (limpeza)', () {
      expect(
        precisaConfirmarTrocaConta(
            ultimoEmail: 'a@x.com', emailNovo: 'b@x.com', pendencias: 1),
        isTrue,
      );
    });
  });

  group('normalizarEmail', () {
    test('apara espaços e baixa caixa', () {
      expect(normalizarEmail('  Fulano@X.COM  '), 'fulano@x.com');
    });
  });

  group('deveProcessarPonte — idempotência da tela do magic link', () {
    test('sessão presente e ainda não processou → processa', () {
      expect(deveProcessarPonte(sessaoPresente: true, jaProcessou: false),
          isTrue);
    });
    test('já processou → nunca reprocessa (evita duplo disparo)', () {
      expect(deveProcessarPonte(sessaoPresente: true, jaProcessou: true),
          isFalse);
    });
    test('sem sessão ainda → espera (não age cedo demais)', () {
      expect(deveProcessarPonte(sessaoPresente: false, jaProcessou: false),
          isFalse);
    });
  });
}
