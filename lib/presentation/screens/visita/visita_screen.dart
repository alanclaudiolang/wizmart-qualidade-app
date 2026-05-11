// lib/presentation/screens/visita/visita_screen.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import 'package:gal/gal.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/network/sync_engine.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/utils/watermark_util.dart';
import '../../../core/utils/session_service.dart';
import '../../widgets/bug_report_button.dart';

const _uuid = Uuid();

class VisitaScreen extends ConsumerStatefulWidget {
  final int visitaId;
  const VisitaScreen({super.key, required this.visitaId});

  @override
  ConsumerState<VisitaScreen> createState() => _VisitaScreenState();
}

class _VisitaScreenState extends ConsumerState<VisitaScreen> {
  Visita? _visita;
  Pdv? _pdv;
  Gabarito? _gabarito;
  bool _loading = true;
  String? _error;
  bool _savingPhoto = false;

  // Estado local da visita (máquina de estados)
  String _localState = 'idle';

  // Fotos capturadas nesta sessão
  List<String> _fotosAntes = []; // paths locais
  List<String> _fotosDepois = [];

  // Nome do promotor (para watermark)
  String _promotorNome = '';

  // Localização
  String? _localizacaoAbertura;
  String? _localizacaoEncerramento;

  // Checklist
  final List<bool?> _checks = List.filled(7, null);
  final List<TextEditingController> _obsControllers =
      List.generate(7, (_) => TextEditingController());

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadVisita();
  }

  @override
  void dispose() {
    for (final c in _obsControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadVisita() async {
    final db = ref.read(appDatabaseProvider);
    final visita = await db.getVisitaById(widget.visitaId);
    if (visita == null) {
      setState(() {
        _error = 'Visita não encontrada';
        _loading = false;
      });
      return;
    }

    Pdv? pdv;
    if (visita.idPdvAssociado != null) {
      pdv = await db.getPdvById(visita.idPdvAssociado!);
    }

    Gabarito? gabarito;
    if (visita.idGabaritoAssociado != null) {
      gabarito = await db.getGabaritoById(visita.idGabaritoAssociado!);
    } else if (visita.idPdvAssociado != null) {
      gabarito = await db.getGabaritoByPdv(visita.idPdvAssociado!);
    }

    // Carrega nome do promotor para o watermark
    String promotorNome = '';
    final session = await SessionService.getSession();
    if (session != null) {
      final user = await db.getUserById(session.userId);
      promotorNome = user?.nome ?? session.nome;
    }

    // Restaura fotos já capturadas (caso retorne à visita)
    final fotosAntesJson = visita.fotosAntesJson;
    final fotosDepoisJson = visita.fotosDepoisJson;

    // Se a visita já está EM ANDAMENTO no servidor mas localState ainda
    // está em fase de fotos antes (ou pior, 'idle'/'abertura'),
    // significa que já passamos da etapa de antes. Pula direto pra fotos depois.
    String localState = visita.localState;
    if (visita.statusVisita == AppConstants.statusEmAndamento &&
        (localState == 'idle' ||
            localState == 'abertura' ||
            localState == 'fotos_antes' ||
            localState == 'em_reposicao')) {
      localState = 'fotos_depois';
      // Persiste pro DB local pra não voltar pra antes em próximos loads
      await db.updateVisita(VisitasCompanion(
        id: drift.Value(widget.visitaId),
        localState: const drift.Value('fotos_depois'),
      ));
    }

    setState(() {
      _promotorNome = promotorNome;
      _visita = visita;
      _pdv = pdv;
      _gabarito = gabarito;
      _localState = localState;
      _fotosAntes = fotosAntesJson != null
          ? List<String>.from(jsonDecode(fotosAntesJson))
          : [];
      _fotosDepois = fotosDepoisJson != null
          ? List<String>.from(jsonDecode(fotosDepoisJson))
          : [];

      // Restaura checklist se já preenchido
      _checks[0] = visita.checkPergunta1;
      _checks[1] = visita.checkPergunta2;
      _checks[2] = visita.checkPergunta3;
      _checks[3] = visita.checkPergunta4;
      _checks[4] = visita.checkPergunta5;
      _checks[5] = visita.checkPergunta6;
      _checks[6] = visita.checkPergunta7;
      _obsControllers[0].text = visita.obsPergunta1 ?? '';
      _obsControllers[1].text = visita.obsPergunta2 ?? '';
      _obsControllers[2].text = visita.obsPergunta3 ?? '';
      _obsControllers[3].text = visita.obsPergunta4 ?? '';
      _obsControllers[4].text = visita.obsPergunta5 ?? '';
      _obsControllers[5].text = visita.obsPergunta6 ?? '';
      _obsControllers[6].text = visita.obsPergunta7 ?? '';

      _loading = false;
    });
  }

  // ── Localização ────────────────────────────────────────────────────────────

  Future<String?> _capturarLocalizacao() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final req = await Geolocator.requestPermission();
        if (req == LocationPermission.denied ||
            req == LocationPermission.deniedForever) {
          _showError('GPS é obrigatório para registrar a visita.');
          return null;
        }
      }

      if (!await Geolocator.isLocationServiceEnabled()) {
        _showError(
            'Ative o GPS do seu celular para continuar.');
        return null;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return 'LatLng(lat: ${pos.latitude.toStringAsFixed(7)}, lng: ${pos.longitude.toStringAsFixed(7)})';
    } catch (e) {
      _showError('Não foi possível obter localização: $e');
      return null;
    }
  }

  // ── Câmera ─────────────────────────────────────────────────────────────────

  Future<void> _tirarFoto(String slot) async {
    final limite = slot == 'antes'
        ? AppConstants.maxFotosAntes
        : AppConstants.maxFotosDepois;
    final atual =
        slot == 'antes' ? _fotosAntes.length : _fotosDepois.length;

    if (atual >= limite) {
      _showError('Limite de $limite fotos atingido.');
      return;
    }

    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.rear,
    );

    if (picked == null) return;

    setState(() => _savingPhoto = true);

    try {
      // Captura localização da foto
      final loc = await _capturarLocalizacao();
      final capturedAt = DateTime.now();

      final pdvNome = _pdv?.apiLocalName ??
          _pdv?.apiLocalCustomerName ??
          'PDV ${_visita?.idPdvAssociado ?? '?'}';

      // Aplica watermark
      final watermarkedPath = await WatermarkUtil.applyWatermark(
        sourcePath: picked.path,
        pdvNome: pdvNome,
        promotorNome: _promotorNome,
        slot: slot == 'antes' ? 'Antes' : 'Depois',
        capturedAt: capturedAt,
      );

      // Salva cópia na galeria
      try {
        await Gal.putImage(watermarkedPath);
      } catch (_) {
        // Não critica se falhar — o path local é o importante
      }

      setState(() {
        if (slot == 'antes') {
          _fotosAntes.add(watermarkedPath);
        } else {
          _fotosDepois.add(watermarkedPath);
        }
      });

      // Salva no DB local
      await _salvarFotosLocalmente(slot, loc, capturedAt);

      // Enfileira upload
      await _enfileirarUploadFoto(
          watermarkedPath, slot, atual + 1, capturedAt);
    } catch (e, stack) {
      debugPrint('Erro ao registrar foto ($slot): $e\n$stack');
      if (mounted) {
        _showError('Falha ao registrar foto: $e');
      }
    } finally {
      if (mounted) setState(() => _savingPhoto = false);
    }
  }

  Future<void> _salvarFotosLocalmente(
      String slot, String? loc, DateTime capturedAt) async {
    final db = ref.read(appDatabaseProvider);

    if (slot == 'antes') {
      await db.updateVisita(VisitasCompanion(
        id: drift.Value(widget.visitaId),
        fotosAntesJson: drift.Value(jsonEncode(_fotosAntes)),
        diaHoraFotosAntes:
            drift.Value(capturedAt.toIso8601String()),
        localizacaoFotosAntes: drift.Value(loc),
        syncStatus: const drift.Value('pending'),
      ));
    } else {
      await db.updateVisita(VisitasCompanion(
        id: drift.Value(widget.visitaId),
        fotosDepoisJson: drift.Value(jsonEncode(_fotosDepois)),
        diaHoraFotosDepois:
            drift.Value(capturedAt.toIso8601String()),
        localizacaoFotosDepois: drift.Value(loc),
        syncStatus: const drift.Value('pending'),
      ));
    }
  }

  Future<void> _enfileirarUploadFoto(
      String path, String slot, int numero, DateTime capturedAt) async {
    final db = ref.read(appDatabaseProvider);

    final id = _uuid.v4();
    await db.insertPendingPhoto(PendingPhotosCompanion(
      id: drift.Value(id),
      visitaId: drift.Value(widget.visitaId),
      slot: drift.Value(slot),
      numero: drift.Value(numero),
      localPath: drift.Value(path),
      status: const drift.Value('pending'),
      attempts: const drift.Value(0),
      nextRetryAt: drift.Value(DateTime.now().toIso8601String()),
      createdAt: drift.Value(capturedAt.toIso8601String()),
    ));

    // Tenta sync imediato se online
    final isOnline = ref.read(connectivityProvider);
    if (isOnline) {
      ref.read(syncEngineProvider).processOutbox();
    }
  }

  // ── Reordenar e remover fotos do grid ─────────────────────────────────────

  Future<void> _moverFoto(String slot, int from, int to) async {
    final lista = slot == 'antes' ? _fotosAntes : _fotosDepois;
    if (to < 0 || to >= lista.length) return;
    setState(() {
      final item = lista.removeAt(from);
      lista.insert(to, item);
    });
    await _persistirOrdemFotos(slot);
  }

  Future<void> _removerFoto(String slot, int index) async {
    final confirma = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Remover foto?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'A foto será apagada deste celular e do envio para o servidor.',
          style: TextStyle(color: Color(0xFF8892B0)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar',
                style: TextStyle(color: Color(0xFF8892B0))),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remover',
                style: TextStyle(color: Color(0xFFFF5252))),
          ),
        ],
      ),
    );
    if (confirma != true) return;

    final lista = slot == 'antes' ? _fotosAntes : _fotosDepois;
    final path = lista[index];

    setState(() => lista.removeAt(index));
    await _persistirOrdemFotos(slot);

    // Cancela upload pendente desta foto, se ainda não foi enviado
    final db = ref.read(appDatabaseProvider);
    await db.deletePendingPhotosByPath(path);

    // Remove arquivo local
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  Future<void> _persistirOrdemFotos(String slot) async {
    final db = ref.read(appDatabaseProvider);
    if (slot == 'antes') {
      await db.updateVisita(VisitasCompanion(
        id: drift.Value(widget.visitaId),
        fotosAntesJson: drift.Value(jsonEncode(_fotosAntes)),
        syncStatus: const drift.Value('pending'),
      ));
    } else {
      await db.updateVisita(VisitasCompanion(
        id: drift.Value(widget.visitaId),
        fotosDepoisJson: drift.Value(jsonEncode(_fotosDepois)),
        syncStatus: const drift.Value('pending'),
      ));
    }
  }

  // ── Ações da máquina de estados ────────────────────────────────────────────

  Future<void> _iniciarVisita() async {
    final loc = await _capturarLocalizacao();
    if (loc == null) return;

    final agora = DateTime.now();
    final db = ref.read(appDatabaseProvider);
    final session = await SessionService.getSession();

    // Atualiza local
    await db.updateVisita(VisitasCompanion(
      id: drift.Value(widget.visitaId),
      statusVisita: const drift.Value(AppConstants.statusEmAndamento),
      diaHoraAbertura: drift.Value(agora.toIso8601String()),
      localizacaoAbertura: drift.Value(loc),
      localState: const drift.Value('fotos_antes'),
      syncStatus: const drift.Value('pending'),
    ));

    // Enfileira no outbox
    await _enfileirarVisita('open', {
      'id': widget.visitaId,
      'status_visita': AppConstants.statusEmAndamento,
      'dia_hora_abertura': agora.toIso8601String(),
      'localizacao_abertura': loc,
      'id_promotor_associado': session?.userId,
    });

    setState(() {
      _localizacaoAbertura = loc;
      _localState = 'fotos_antes';
    });

    // Dispara envio imediato pro servidor
    if (ref.read(connectivityProvider)) {
      ref.read(syncEngineProvider).processOutbox();
    }
  }

  Future<void> _concluirFotosAntes() async {
    if (_fotosAntes.isEmpty) {
      _showError('Tire pelo menos uma foto antes da reposição.');
      return;
    }

    final db = ref.read(appDatabaseProvider);
    // Vai direto para 'fotos_depois': quando o usuário voltar à visita,
    // verá a tela de fotos DEPOIS sem passar por uma tela intermediária.
    await db.updateVisita(VisitasCompanion(
      id: drift.Value(widget.visitaId),
      localState: const drift.Value('fotos_depois'),
      syncStatus: const drift.Value('pending'),
    ));

    // Enfileira atualização das fotos antes pro servidor
    await _enfileirarVisita('photos_antes', {
      'id': widget.visitaId,
      'fotos_antes_count': _fotosAntes.length,
    });

    if (ref.read(connectivityProvider)) {
      ref.read(syncEngineProvider).processOutbox();
    }

    if (mounted) context.go('/home');
  }


  Future<void> _concluirFotosDepois() async {
    if (_fotosDepois.isEmpty) {
      _showError('Tire pelo menos uma foto depois da reposição.');
      return;
    }

    final loc = await _capturarLocalizacao();

    final agora = DateTime.now();
    final db = ref.read(appDatabaseProvider);

    await db.updateVisita(VisitasCompanion(
      id: drift.Value(widget.visitaId),
      localizacaoEncerramento: drift.Value(loc),
      localState: const drift.Value('checklist'),
      syncStatus: const drift.Value('pending'),
    ));

    setState(() {
      _localizacaoEncerramento = loc;
      _localState = 'checklist';
    });
  }

  Future<void> _finalizarVisita() async {
    // Valida que todas as 7 perguntas foram respondidas
    for (int i = 0; i < 7; i++) {
      if (_checks[i] == null) {
        _showError('Responda todas as 7 perguntas do checklist.');
        return;
      }
    }

    final agora = DateTime.now();
    final db = ref.read(appDatabaseProvider);

    await db.updateVisita(VisitasCompanion(
      id: drift.Value(widget.visitaId),
      statusVisita: const drift.Value(AppConstants.statusRealizada),
      diaHoraRealizado: drift.Value(agora.toIso8601String()),
      checkPergunta1: drift.Value(_checks[0]),
      obsPergunta1: drift.Value(_obsControllers[0].text),
      checkPergunta2: drift.Value(_checks[1]),
      obsPergunta2: drift.Value(_obsControllers[1].text),
      checkPergunta3: drift.Value(_checks[2]),
      obsPergunta3: drift.Value(_obsControllers[2].text),
      checkPergunta4: drift.Value(_checks[3]),
      obsPergunta4: drift.Value(_obsControllers[3].text),
      checkPergunta5: drift.Value(_checks[4]),
      obsPergunta5: drift.Value(_obsControllers[4].text),
      checkPergunta6: drift.Value(_checks[5]),
      obsPergunta6: drift.Value(_obsControllers[5].text),
      checkPergunta7: drift.Value(_checks[6]),
      obsPergunta7: drift.Value(_obsControllers[6].text),
      localState: const drift.Value('finalizada'),
      syncStatus: const drift.Value('pending'),
    ));

    await _enfileirarVisita('close', {
      'id': widget.visitaId,
      'status_visita': AppConstants.statusRealizada,
      'dia_hora_realizado': agora.toIso8601String(),
      'localizacao_encerramento': _localizacaoEncerramento,
      'check_pergunta_1': _checks[0],
      'obs_pergunta_1': _obsControllers[0].text,
      'check_pergunta_2': _checks[1],
      'obs_pergunta_2': _obsControllers[1].text,
      'check_pergunta_3': _checks[2],
      'obs_pergunta_3': _obsControllers[2].text,
      'check_pergunta_4': _checks[3],
      'obs_pergunta_4': _obsControllers[3].text,
      'check_pergunta_5': _checks[4],
      'obs_pergunta_5': _obsControllers[4].text,
      'check_pergunta_6': _checks[5],
      'obs_pergunta_6': _obsControllers[5].text,
      'check_pergunta_7': _checks[6],
      'obs_pergunta_7': _obsControllers[6].text,
    });

    // Tenta sync imediato
    final isOnline = ref.read(connectivityProvider);
    if (isOnline) {
      ref.read(syncEngineProvider).processOutbox();
    }

    if (mounted) {
      _showSuccess('Visita finalizada com sucesso!');
      await Future.delayed(const Duration(seconds: 1));
      context.go('/home');
    }
  }

  Future<void> _enfileirarVisita(
      String operation, Map<String, dynamic> payload) async {
    final db = ref.read(appDatabaseProvider);
    final id = _uuid.v4();
    await db.insertOutboxItem(OutboxItemsCompanion(
      id: drift.Value(id),
      entityType: const drift.Value('visita'),
      operation: drift.Value(operation),
      entityId: drift.Value(widget.visitaId),
      payloadJson: drift.Value(jsonEncode(payload)),
      attempts: const drift.Value(0),
      nextRetryAt: drift.Value(DateTime.now().toIso8601String()),
      status: const drift.Value('pending'),
      createdAt: drift.Value(DateTime.now().toIso8601String()),
    ));
  }

  // ── UI Helpers ─────────────────────────────────────────────────────────────

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFFFF5252),
    ));
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFF4CAF50),
    ));
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A2E),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        appBar: AppBar(backgroundColor: const Color(0xFF16213E)),
        body: Center(
            child: Text(_error!,
                style: const TextStyle(color: Colors.white))),
      );
    }

    final pdvNome = _pdv?.apiLocalName ??
        _pdv?.apiLocalCustomerName ??
        'PDV ${_visita?.idPdvAssociado ?? '?'}';

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/home'),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pdvNome,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            if (_pdv?.endereco != null)
              Text(
                _pdv!.endereco!,
                style: const TextStyle(
                    color: Color(0xFF8892B0), fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: BugReportButton(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // SafeArea bottom protege os botões verdes da barra de
          // navegação nativa do Android (gestos / 3 botões).
          SafeArea(
            top: false,
            left: false,
            right: false,
            child: _buildBody(),
          ),
          if (_savingPhoto)
            Positioned.fill(
              child: AbsorbPointer(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.7),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: Color(0xFF4CAF50),
                          strokeWidth: 3,
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Salvando foto...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Aguarde, não toque na tela.',
                          style: TextStyle(
                            color: Color(0xFF8892B0),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_localState) {
      case 'idle':
        return _buildIniciar();
      case 'fotos_antes':
        return _buildFotos('antes');
      case 'em_reposicao':
        // Estado legado de visitas criadas antes do refactor.
        // Trata como fotos_depois pra não travar o usuário.
        return _buildFotos('depois');
      case 'fotos_depois':
        return _buildFotos('depois');
      case 'checklist':
        return _buildChecklist();
      case 'finalizada':
        return _buildFinalizada();
      default:
        return _buildIniciar();
    }
  }

  // ── Tela: Iniciar visita ───────────────────────────────────────────────────

  Widget _buildIniciar() {
    final horario = _visita?.diaHoraAgendado != null
        ? DateFormat('HH:mm').format(
            DateTime.parse(_visita!.diaHoraAgendado!).toLocal())
        : '--:--';

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.store, size: 64, color: Color(0xFF4CAF50)),
          const SizedBox(height: 24),
          const Text(
            'Iniciar visita',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Horário previsto: $horario',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Color(0xFF8892B0), fontSize: 16),
          ),
          const SizedBox(height: 48),
          const Text(
            '📍 GPS será capturado ao iniciar',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Color(0xFF8892B0), fontSize: 14),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _iniciarVisita,
            icon: const Icon(Icons.play_arrow, color: Colors.white),
            label: const Text('Iniciar visita',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tela: Fotos ───────────────────────────────────────────────────────────

  Widget _buildFotos(String slot) {
    final fotos = slot == 'antes' ? _fotosAntes : _fotosDepois;
    final limite = slot == 'antes'
        ? AppConstants.maxFotosAntes
        : AppConstants.maxFotosDepois;
    final label = slot == 'antes' ? 'ANTES' : 'DEPOIS';
    final cor = slot == 'antes'
        ? const Color(0xFF64B5F6)
        : const Color(0xFF4CAF50);

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFF16213E),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: cor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Foto $label',
                  style: TextStyle(
                      color: cor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ),
              const Spacer(),
              Text(
                '${fotos.length}/$limite',
                style: const TextStyle(
                    color: Color(0xFF8892B0), fontSize: 14),
              ),
            ],
          ),
        ),

        // Grid de fotos
        Expanded(
          child: fotos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.camera_alt,
                          size: 64, color: cor.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      Text(
                        'Tire a(s) foto(s) $label',
                        style: const TextStyle(
                            color: Color(0xFF4A5568), fontSize: 16),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: fotos.length,
                  itemBuilder: (_, i) => _PhotoTile(
                    path: fotos[i],
                    numero: i + 1,
                    canMoveLeft: i > 0,
                    canMoveRight: i < fotos.length - 1,
                    onRemove: () => _removerFoto(slot, i),
                    onMoveLeft: () => _moverFoto(slot, i, i - 1),
                    onMoveRight: () => _moverFoto(slot, i, i + 1),
                  ),
                ),
        ),

        // Botões
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Botão tirar foto
              if (fotos.length < limite)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _tirarFoto(slot),
                    icon: Icon(Icons.camera_alt, color: cor),
                    label: Text('Tirar foto $label',
                        style: TextStyle(color: cor, fontSize: 16)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: cor),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              const SizedBox(height: 12),

              // Botão concluir
              if (fotos.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: slot == 'antes'
                        ? _concluirFotosAntes
                        : _concluirFotosDepois,
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: Text(
                      slot == 'antes'
                          ? 'Concluir'
                          : 'Concluir — ir para checklist',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Tela: Checklist ────────────────────────────────────────────────────────

  // Perguntas padrão (fallback se não tiver gabarito)
  static const _perguntasPadrao = [
    'Produtos estão dentro da validade?',
    'A precificação está correta?',
    'O espaço está limpo e organizado?',
    'Os produtos estão bem expostos?',
    'Estoque mínimo respeitado?',
    'Material de PDV está em bom estado?',
    'Equipamento funcionando corretamente?',
  ];

  Widget _buildChecklist() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFF16213E),
          child: const Row(
            children: [
              Icon(Icons.checklist, color: Color(0xFF4CAF50)),
              SizedBox(width: 12),
              Text(
                'Checklist de encerramento',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: 7,
            itemBuilder: (_, i) => _buildPergunta(i),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _finalizarVisita,
              icon: const Icon(Icons.flag, color: Colors.white),
              label: const Text('Finalizar visita',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPergunta(int index) {
    final pergunta = _perguntasPadrao[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _checks[index] == null
              ? Colors.transparent
              : _checks[index]!
                  ? const Color(0xFF4CAF50).withOpacity(0.4)
                  : const Color(0xFFFF5252).withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${index + 1}. $pergunta',
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // OK
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _checks[index] = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _checks[index] == true
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFF2D3748),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check, size: 18, color: Colors.white),
                        SizedBox(width: 6),
                        Text('OK',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // NOK
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _checks[index] = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _checks[index] == false
                          ? const Color(0xFFFF5252)
                          : const Color(0xFF2D3748),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.close, size: 18, color: Colors.white),
                        SizedBox(width: 6),
                        Text('NOK',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Observação opcional
          const SizedBox(height: 8),
          TextField(
            controller: _obsControllers[index],
            style: const TextStyle(
                color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'Observação (opcional)',
              hintStyle: TextStyle(
                  color: Color(0xFF4A5568), fontSize: 13),
              filled: true,
              fillColor: Color(0xFF0F0F23),
              border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius:
                      BorderRadius.all(Radius.circular(8))),
              contentPadding: EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  // ── Tela: Finalizada ───────────────────────────────────────────────────────

  Widget _buildFinalizada() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle,
                size: 80, color: Color(0xFF4CAF50)),
            const SizedBox(height: 24),
            const Text(
              'Visita finalizada!',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => context.go('/home'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                padding: const EdgeInsets.symmetric(
                    horizontal: 40, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Voltar para a lista',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final String path;
  final int numero;
  final bool canMoveLeft;
  final bool canMoveRight;
  final VoidCallback onRemove;
  final VoidCallback onMoveLeft;
  final VoidCallback onMoveRight;

  const _PhotoTile({
    required this.path,
    required this.numero,
    required this.canMoveLeft,
    required this.canMoveRight,
    required this.onRemove,
    required this.onMoveLeft,
    required this.onMoveRight,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(File(path), fit: BoxFit.cover),
        ),

        // Botão X (deletar) - canto superior direito
        Positioned(
          top: 4,
          right: 4,
          child: _CircleButton(
            icon: Icons.close,
            onTap: onRemove,
            background: const Color(0xFFE53E3E),
          ),
        ),

        // Número da foto - canto superior esquerdo
        Positioned(
          top: 4,
          left: 4,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$numero',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        // Setas de mover - canto inferior, lado a lado
        Positioned(
          bottom: 4,
          left: 4,
          right: 4,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Opacity(
                opacity: canMoveLeft ? 1.0 : 0.3,
                child: _CircleButton(
                  icon: Icons.arrow_back,
                  onTap: canMoveLeft ? onMoveLeft : null,
                  background: Colors.black.withValues(alpha: 0.65),
                ),
              ),
              Opacity(
                opacity: canMoveRight ? 1.0 : 0.3,
                child: _CircleButton(
                  icon: Icons.arrow_forward,
                  onTap: canMoveRight ? onMoveRight : null,
                  background: Colors.black.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color background;
  const _CircleButton({
    required this.icon,
    required this.onTap,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}
