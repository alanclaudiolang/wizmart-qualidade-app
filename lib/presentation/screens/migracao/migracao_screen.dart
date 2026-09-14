// lib/presentation/screens/migracao/migracao_screen.dart
//
// BUILD DE BLOQUEIO (299) — existe SÓ no canal antigo (release v-latest),
// para tirar a frota do build 262 e levá-la à Play Store (a assinatura
// da loja é outra, então não há update por cima: o caminho é
// desinstalar → instalar da loja).
//
// O app inteiro vira esta tela. Decisão do Alan (14/09/2026): o bloqueio
// vale MESMO com pendências locais — o botão da loja aparece sempre. O
// sync continua rodando em segundo plano (melhor esforço) enquanto a
// tela estiver aberta, e um aviso discreto mostra quantas visitas ainda
// faltam enviar, pedindo para manter o app aberto alguns minutos antes
// de apagar. Nenhuma outra rota do app é alcançável.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/sync_engine.dart';
import '../../../core/utils/app_colors.dart';
import '../../../core/utils/session_service.dart';

class MigracaoScreen extends ConsumerStatefulWidget {
  const MigracaoScreen({super.key});

  @override
  ConsumerState<MigracaoScreen> createState() => _MigracaoScreenState();
}

class _MigracaoScreenState extends ConsumerState<MigracaoScreen> {
  static const _lojaUrl =
      'https://play.google.com/store/apps/details?id=com.wizmart.wizmart_app';
  Timer? _syncTimer;
  bool _syncRodando = false;

  @override
  void initState() {
    super.initState();
    _kickSync();
    _syncTimer =
        Timer.periodic(const Duration(seconds: 45), (_) => _kickSync());
  }

  /// Sync de melhor esforço: nunca bloqueia a tela nem o botão da loja.
  Future<void> _kickSync() async {
    if (_syncRodando) return;
    _syncRodando = true;
    try {
      final session = await SessionService.getSession();
      final engine = ref.read(syncEngineProvider);
      if (session != null) {
        await engine.fullSync(session.userId);
      } else {
        await engine.processOutbox();
      }
    } catch (_) {} finally {
      _syncRodando = false;
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _abrirLoja() async {
    try {
      await launchUrl(Uri.parse(_lojaUrl),
          mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.read(appDatabaseProvider);
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: StreamBuilder<int>(
            stream: db.watchVisitasComPendencia(),
            builder: (context, snap) {
              final pend = snap.data ?? 0;
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 28),
                child: _telaBloqueio(pend),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _telaBloqueio(int pend) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        const Icon(Icons.warning_amber_rounded,
            size: 60, color: AppColors.danger),
        const SizedBox(height: 14),
        const Text(
          'Urgente: esta versão do app foi desativada',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        const Text(
          'Você está em uma versão muito antiga do app Promotor Wizmart e '
          'ela não funciona mais. Para continuar registrando suas '
          'visitas, instale o aplicativo novo pela Play Store '
          '(leva 2 minutos):',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: AppColors.textSecondary, fontSize: 15, height: 1.45),
        ),
        const SizedBox(height: 24),
        _passo(
          numero: '1',
          child: const Text(
            'Apague ESTE aplicativo do celular.\nSuas fotos com marca '
            'd\'água continuam salvas na galeria.',
            style: TextStyle(
                color: AppColors.textPrimary, fontSize: 15, height: 1.4),
          ),
        ),
        const SizedBox(height: 16),
        _passo(
          numero: '2',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Instale pelo Google Play:',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    height: 1.4),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _abrirLoja,
                  icon: const Icon(Icons.shop),
                  label: const Text('Atualizar pela Play Store',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _passo(
          numero: '3',
          child: const Text(
            'Abra o app novo e entre com seu e-mail e senha de sempre.',
            style: TextStyle(
                color: AppColors.textPrimary, fontSize: 15, height: 1.4),
          ),
        ),
        if (pend > 0) ...[
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Ainda enviando $pend visita(s) ao servidor em segundo '
                    'plano. Se puder, deixe o app aberto com internet por '
                    'alguns minutos antes de apagar.',
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        const Text(
          'Dúvidas? Fale com seu supervisor.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ],
    );
  }

  Widget _passo({required String numero, required Widget child}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(17),
          ),
          child: Text(numero,
              style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 14),
        Expanded(child: child),
      ],
    );
  }
}
