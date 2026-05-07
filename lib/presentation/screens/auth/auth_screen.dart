// lib/presentation/screens/auth/auth_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _phoneController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'Digite seu número de celular');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Busca usuário pelo telefone no Supabase
      // Tenta vários formatos para ser tolerante com dados inconsistentes
      final phoneVariants = _getPhoneVariants(phone);

      Map<String, dynamic>? user;
      for (final variant in phoneVariants) {
        final result = await Supabase.instance.client
            .from('users')
            .select('id,nome,telefone,ativo,tipo_user')
            .eq('telefone', variant)
            .eq('ativo', true)
            .maybeSingle();

        if (result != null) {
          user = result;
          break;
        }
      }

      if (user == null) {
        setState(() {
          _error =
              'Número não encontrado. Contate seu supervisor.';
          _loading = false;
        });
        return;
      }

      // Verifica se está ativo
      if (user['ativo'] == false) {
        setState(() {
          _error = 'Acesso desativado. Contate seu supervisor.';
          _loading = false;
        });
        return;
      }

      // Salva sessão persistente
      await SessionService.saveSession(
        userId: user['id'] as int,
        phone: phone,
        nome: user['nome'] as String? ?? '',
      );

      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      setState(() {
        _error = 'Erro ao verificar número. Verifique sua conexão.';
        _loading = false;
      });
    }
  }

  // Gera variantes do número para tolerar formatos diferentes no banco
  List<String> _getPhoneVariants(String phone) {
    // Remove tudo que não é dígito
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return [
      phone, // exato como digitado
      digits, // só dígitos
      '($digits)', // com parênteses
      if (digits.length == 11)
        '(${digits.substring(0, 2)}) ${digits.substring(2, 7)}-${digits.substring(7)}',
      if (digits.length == 11)
        '(${digits.substring(0, 2)}) ${digits.substring(2)}',
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo / título
              const SizedBox(height: 40),
              Center(
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 80,
                  errorBuilder: (_, __, ___) => const Text(
                    'WizMart',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'App do Promotor',
                  style: TextStyle(
                    color: Color(0xFF8892B0),
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 60),

              // Campo de telefone
              const Text(
                'Número de celular',
                style: TextStyle(
                  color: Color(0xFF8892B0),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'[\d\s\(\)\-\+]')),
                ],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
                decoration: InputDecoration(
                  hintText: '(21) 99999-9999',
                  hintStyle:
                      const TextStyle(color: Color(0xFF4A5568)),
                  filled: true,
                  fillColor: const Color(0xFF16213E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color(0xFF4CAF50), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 18),
                  prefixIcon: const Icon(Icons.phone,
                      color: Color(0xFF4CAF50)),
                ),
                onSubmitted: (_) => _entrar(),
              ),

              // Erro
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B1F1F),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFFFF6B6B),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Botão entrar
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _loading ? null : _entrar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    disabledBackgroundColor:
                        const Color(0xFF4CAF50).withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Entrar',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
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
}
