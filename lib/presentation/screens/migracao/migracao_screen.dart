// lib/presentation/screens/migracao/migracao_screen.dart
//
// BUILD TRANSITÓRIO (299) — existe SÓ no canal GitHub (v-latest), para
// migrar a frota 257/262 para a Play Store (a assinatura da loja é
// outra, então não há update por cima: o caminho é sincronizar →
// desinstalar → instalar da loja).
//
// O app inteiro vira esta tela:
//   - Enquanto houver pendências locais (visitas/fotos não enviadas),
//     mantém o sync rodando e pede pra aguardar com o app aberto.
//   - Quando zera (ou não há sessão), mostra o passo a passo com o
//     link clicável da loja.

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

  @override
  Widget build(BuildContext context) {
    final db = ref.read(appDatabaseProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: StreamBuilder<int>(
          stream: db.watchVisitasComPendencia(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(
                  child:
                      CircularProgressIndicator(color: AppColors.primary));
            }
            final pend = snap.data!;
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 32),
              child: pend > 0 ? _telaAguarde(pend) : _telaMigrar(),
            );
          },
        ),
      ),
    );
  }

  Widget _telaAguarde(int pend) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.cloud_upload_outlined,
            size: 64, color: AppColors.primary),
        const SizedBox(height: 24),
        const Text(
          'Enviando seus dados...',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Text(
          'Falta enviar $pend visita(s) para o servidor.\n\n'
          'Mantenha o app ABERTO e com internet até este número zerar. '
          'Quando terminar, esta tela vai mostrar como instalar o novo '
          'aplicativo da loja.',
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 15, height: 1.5),
        ),
        const SizedBox(height: 32),
        const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ],
    );
  }

  Widget _telaMigrar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        const Icon(Icons.celebration_outlined,
            size: 56, color: AppColors.primary),
        const SizedBox(height: 16),
        const Text(
          'O Promotor Wizmart agora está na Play Store!',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 21,
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Seus dados já foram todos enviados. Siga os 3 passos abaixo '
          'para trocar para o aplicativo novo (leva 2 minutos):',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: AppColors.textSecondary, fontSize: 15, height: 1.4),
        ),
        const SizedBox(height: 28),
        _passo(
          numero: '1',
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                try {
                  await launchUrl(Uri.parse(_lojaUrl),
                      mode: LaunchMode.externalApplication);
                } catch (_) {}
              },
              icon: const Icon(Icons.shop),
              label: const Text('Abrir a página do app na loja',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
        const SizedBox(height: 18),
        _passo(
          numero: '2',
          child: const Text(
            'Desinstale ESTE aplicativo.\nSuas fotos com marca d\'água '
            'continuam salvas na galeria do celular.',
            style: TextStyle(
                color: AppColors.textPrimary, fontSize: 15, height: 1.4),
          ),
        ),
        const SizedBox(height: 18),
        _passo(
          numero: '3',
          child: const Text(
            'Na página da loja, toque em INSTALAR e entre com seu '
            'e-mail e senha de sempre.',
            style: TextStyle(
                color: AppColors.textPrimary, fontSize: 15, height: 1.4),
          ),
        ),
        const SizedBox(height: 28),
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
      crossAxisAlignment: CrossAxisAlignment.center,
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
