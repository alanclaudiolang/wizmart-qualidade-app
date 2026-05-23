// lib/presentation/screens/visita/visita_screen.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import 'package:gal/gal.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/network/sync_engine.dart';
import '../../../core/network/sync_pause.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../main.dart' show scheduleOneOffSync;
import '../../../core/utils/watermark_util.dart';
import '../../../core/utils/session_service.dart';
import 'package:disk_space_plus/disk_space_plus.dart';
import '../../../core/utils/current_screen.dart';
import '../../../core/utils/last_visita_service.dart';
import '../../../core/utils/watermark_queue.dart';
import '../../../core/utils/gps_status_service.dart';
import '../../../core/utils/performance_profile.dart';
import '../../../core/utils/error_reporter.dart';
import '../../../core/utils/sync_logger.dart';
import '../../../core/utils/app_colors.dart';

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

  // Loading durante transições assíncronas (GPS, salvar etc.)
  bool _busy = false;
  String _busyLabel = '';

  // Nome do promotor (para watermark)
  String _promotorNome = '';

  // Localização
  String? _localizacaoAbertura;
  String? _localizacaoEncerramento;

  // Checklist
  final List<bool?> _checks = List.filled(7, null);
  final List<TextEditingController> _obsControllers =
      List.generate(7, (_) => TextEditingController());
  // Comentário geral da visita (mapeia pra coluna comentarios_visita)
  final TextEditingController _comentarioGeralCtrl = TextEditingController();

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Marca esta visita como "atualmente aberta" para o SplashRedirect
    // restaurar o usuário aqui caso o Android mate o app durante a
    // captura (low memory + câmera aberta = caso comum em devices fracos).
    LastVisitaService.set(widget.visitaId);
    _loadVisita();
  }

  @override
  void dispose() {
    for (final c in _obsControllers) {
      c.dispose();
    }
    _comentarioGeralCtrl.dispose();
    // Garante resume ao sair da tela, mesmo se ainda estiver em estado
    // de captura (defensivo — em fluxo normal já foi resumido).
    SyncPause.resume();
    super.dispose();
  }

  /// Pausa sync apenas em estados de captura (grid de fotos antes/depois).
  /// Em outros estados (idle, checklist, finalizada) o sync roda normal.
  /// Também atualiza CurrentScreen pra que o ErrorReporter rotule
  /// issues com sub-estado da visita (visita-fotos-antes, etc).
  void _updateSyncPause(String localState) {
    if (localState == 'fotos_antes' || localState == 'fotos_depois') {
      SyncPause.pause();
    } else {
      SyncPause.resume();
    }
    _atualizarCurrentScreen(localState);
  }

  /// Mapeia o `_localState` interno da visita pra um label de screen
  /// granular usado nos labels do issue no GitHub.
  void _atualizarCurrentScreen(String localState) {
    switch (localState) {
      case 'fotos_antes':
        CurrentScreen.nome = 'visita-fotos-antes';
        break;
      case 'fotos_depois':
        CurrentScreen.nome = 'visita-fotos-depois';
        break;
      case 'checklist':
        CurrentScreen.nome = 'visita-checklist';
        break;
      case 'finalizada':
        CurrentScreen.nome = 'visita-finalizada';
        break;
      default:
        CurrentScreen.nome = 'visita';
    }
  }

  /// Botão voltar / back do sistema. Comportamento depende da etapa:
  ///   - checklist → volta pra grid de fotos depois (não home)
  ///   - fotos_antes/fotos_depois com fotos → dialog "descartar?"
  ///   - demais → vai direto pra home
  Future<void> _sairParaHome() async {
    // No checklist, voltar = volta uma etapa (grid de fotos depois),
    // não pra home. Promotor pode estar revisando ou tirando mais
    // fotos antes de finalizar.
    if (_localState == 'checklist') {
      final db = ref.read(appDatabaseProvider);
      await db.updateVisita(VisitasCompanion(
        id: drift.Value(widget.visitaId),
        localState: const drift.Value('fotos_depois'),
      ));
      // Recarrega fotosDepoisJson — watermark queue pode ter trocado
      // _raw.jpg por _watermark.jpg e apagado os crus. Sem isso, a grid
      // tenta renderizar paths mortos e cai no errorBuilder com
      // placeholder em vez de mostrar as fotos reais.
      final visitaAtualizada = await db.getVisitaById(widget.visitaId);
      final fotosJson = visitaAtualizada?.fotosDepoisJson;
      final fotosAtuais = fotosJson != null
          ? List<String>.from(jsonDecode(fotosJson))
          : <String>[];
      if (!mounted) return;
      setState(() {
        _localState = 'fotos_depois';
        _fotosDepois = fotosAtuais;
      });
      _updateSyncPause('fotos_depois');
      return;
    }

    final temFotosAntes =
        _localState == 'fotos_antes' && _fotosAntes.isNotEmpty;
    final temFotosDepois =
        _localState == 'fotos_depois' && _fotosDepois.isNotEmpty;

    // Sempre sai do estado de captura ao voltar pra home — garante
    // que o sync engine esteja liberado pra processar.
    await SyncPause.resume();

    if (temFotosAntes || temFotosDepois) {
      final qtd = temFotosAntes ? _fotosAntes.length : _fotosDepois.length;
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text(
            'Descartar fotos?',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: Text(
            'Você tem $qtd foto${qtd == 1 ? '' : 's'} desta etapa. '
            'Voltar agora vai apagá-las do aplicativo. Tem certeza?',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Descartar',
                  style: TextStyle(color: AppColors.danger)),
            ),
          ],
        ),
      );
      if (ok != true) return;
      await _descartarFotosDaEtapa();
    }

    // Captura referências ANTES de qualquer await — se o widget for
    // descartado durante os awaits, ref.read joga "Bad state: Cannot
    // use ref after the widget was disposed" e o ErrorReporter pega
    // como crash (issues #10 e #12, 2026-05-22).
    final isOnline = ref.read(connectivityProvider);
    final syncEngine = isOnline ? ref.read(syncEngineProvider) : null;

    await LastVisitaService.clear();

    // Sempre dispara fullSync ao voltar pra home (push + pull). Mesmo
    // sem pendências locais, o pull pode trazer alterações que o
    // supervisor fez no servidor (nova visita, gabarito mudado etc).
    // Roda sem await pra não travar a navegação.
    if (syncEngine != null) {
      final session = await SessionService.getSession();
      if (session != null) {
        // ignore: discarded_futures
        syncEngine.fullSync(session.userId);
      } else {
        // ignore: discarded_futures
        syncEngine.processOutbox();
      }
    }
    if (mounted) context.go('/home');
  }

  /// Apaga os arquivos locais das fotos da etapa atual, remove as
  /// entradas de PendingPhotos e limpa o JSON na visita. Se for
  /// 'fotos_antes', também reverte a abertura (volta a 'idle'), pra que
  /// a próxima abertura da visita comece do zero.
  Future<void> _descartarFotosDaEtapa() async {
    final db = ref.read(appDatabaseProvider);
    final paths = _localState == 'fotos_antes'
        ? List<String>.from(_fotosAntes)
        : List<String>.from(_fotosDepois);

    // Arquivos locais (a galeria não foi tocada — só recebe ao concluir).
    for (final p in paths) {
      try {
        final f = File(p);
        if (await f.exists()) await f.delete();
      } catch (_) {}
      try {
        await db.deletePendingPhotosByPath(p);
      } catch (_) {}
    }

    if (_localState == 'fotos_antes') {
      // Reverte a abertura: como se nunca tivesse clicado em iniciar.
      // syncStatus volta a 'synced' — não há mais nada pra enviar
      // (o início era SOMENTE local, ainda não tinha sido enfileirado).
      await db.updateVisita(VisitasCompanion(
        id: drift.Value(widget.visitaId),
        fotosAntesJson: const drift.Value(null),
        diaHoraAbertura: const drift.Value(null),
        localizacaoAbertura: const drift.Value(null),
        diaHoraFotosAntes: const drift.Value(null),
        localizacaoFotosAntes: const drift.Value(null),
        localState: const drift.Value('idle'),
        syncStatus: const drift.Value('synced'),
      ));
    } else {
      // Mantém status 2 (em andamento) e localState 'fotos_depois':
      // próxima vez já volta direto pra grid de fotos depois vazio.
      // syncStatus volta a 'synced' — fotos descartadas eram só locais.
      await db.updateVisita(VisitasCompanion(
        id: drift.Value(widget.visitaId),
        fotosDepoisJson: const drift.Value(null),
        diaHoraFotosDepois: const drift.Value(null),
        localizacaoFotosDepois: const drift.Value(null),
        syncStatus: const drift.Value('synced'),
      ));
    }
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
      _comentarioGeralCtrl.text = visita.comentariosVisita ?? '';

      _loading = false;
    });
    _updateSyncPause(localState);
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

      // Tenta accuracy alta com timeout curto. Se demorar, cai pra última
      // posição conhecida — em modo avião / GPS frio o `getCurrentPosition`
      // pode travar indefinidamente. Offline-first não pode esperar GPS.
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 8),
        );
      } catch (_) {
        pos = await Geolocator.getLastKnownPosition();
      }
      if (pos == null) {
        // Sem GPS atual nem histórico: deixa registrar sem coordenadas.
        // O servidor aceita null e o promotor não fica travado.
        return null;
      }

      return 'LatLng(lat: ${pos.latitude.toStringAsFixed(7)}, lng: ${pos.longitude.toStringAsFixed(7)})';
    } catch (e) {
      _showError('Não foi possível obter localização: $e');
      return null;
    }
  }

  // ── Câmera ─────────────────────────────────────────────────────────────────

  Future<void> _tirarFoto(String slot) async {
    final logger = ref.read(syncLoggerProvider.notifier);
    final limite = slot == 'antes'
        ? AppConstants.maxFotosAntes
        : AppConstants.maxFotosDepois;
    final atual =
        slot == 'antes' ? _fotosAntes.length : _fotosDepois.length;

    if (atual >= limite) {
      _showError('Limite de $limite fotos atingido.');
      return;
    }

    // GPS é obrigatório pra registrar foto. Se não está ok, o overlay
    // global do GpsGuard já está cobrindo a tela — não tem como o user
    // chegar aqui via toque normal. Mas se ele chegou via race
    // (overlay ainda aparecendo), nem abre a câmera.
    if (ref.read(gpsStatusProvider) != GpsState.ok) {
      ref.read(gpsStatusProvider.notifier).refresh();
      return;
    }

    // ── (C) Pré-check de storage livre. Mínimo de 100MB pra ter
    //    folga pra foto + watermark + processamento. Bloqueia com
    //    diálogo claro pra promotor liberar espaço antes de tirar.
    try {
      final freeMb = await DiskSpacePlus().getFreeDiskSpace ?? 9999;
      if (freeMb < 100) {
        logger.log('foto', 'Storage baixo: ${freeMb.toStringAsFixed(0)}MB',
            erro: true);
        await _avisoBloqueante(
          'Armazenamento cheio',
          'Você tem apenas ${freeMb.toStringAsFixed(0)} MB livres. '
              'Libere espaço no celular (apague fotos, vídeos ou apps '
              'não usados) antes de tirar mais fotos.',
        );
        return;
      }
    } catch (_) {/* sem disk_space, segue */}

    // ── Perfil de performance (tier) ─────────────────────────────────
    final profileAsync = ref.read(performanceProfileProvider);
    final profile =
        profileAsync.asData?.value ?? PerformanceProfile.padraoCarregando;
    logger.log('foto',
        'Captura iniciada slot=$slot tier=${profile.tierLabel} q=${profile.imageQuality} maxSide=${profile.imageMaxSide}');

    // Pausa sync enquanto a câmera estiver aberta — câmera consome CPU/RAM
    // e qualquer upload concorrente em device de baixa memória pode travar.
    await SyncPause.pause();
    XFile? picked;
    try {
      picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: profile.imageQuality,
        maxWidth: profile.imageMaxSide.toDouble(),
        maxHeight: profile.imageMaxSide.toDouble(),
        preferredCameraDevice: CameraDevice.rear,
      );
    } on PlatformException catch (e) {
      _updateSyncPause(_localState);
      final code = e.code.toLowerCase();
      if (code.contains('denied') || code.contains('permission')) {
        await _avisoBloqueante('Permissão negada',
            'Permissão de câmera negada. Ative nas configurações do app.');
      } else {
        await _avisoBloqueante('Erro na câmera',
            'Não foi possível abrir a câmera. Tente novamente.');
      }
      return;
    }

    if (picked == null) {
      // Cancelamento normal (usuário fechou a câmera sem foto).
      _updateSyncPause(_localState);
      return;
    }

    setState(() => _savingPhoto = true);

    try {
      // Captura localização da foto
      final loc = await _capturarLocalizacao();
      final capturedAt = DateTime.now();

      // Copia o arquivo da câmera pro diretório do app pra ter caminho
      // estável. A foto já vem da câmera com quality+resize do tier
      // aplicados — pronta pra entrar no grid. O watermark é desenhado
      // depois, quando o promotor concluir a etapa.
      final docs = await getApplicationDocumentsDirectory();
      final outDir = '${docs.path}/wizmart_fotos';
      await Directory(outDir).create(recursive: true);
      final ext = picked.path.split('.').last;
      final rawPath = '$outDir/${const Uuid().v4()}_raw.$ext';
      await File(picked.path).copy(rawPath);

      // ── (B) Valida que o arquivo realmente foi gravado e tem
      //    conteúdo. Sem isso, copy "silencioso" deixava grid com
      //    referência pra arquivo inexistente/zerado.
      final f = File(rawPath);
      final exists = await f.exists();
      final size = exists ? await f.length() : 0;
      if (!exists || size <= 0) {
        logger.log('foto',
            'Cópia falhou: exists=$exists size=$size path=$rawPath',
            erro: true);
        throw FileSystemException(
            'Arquivo da foto vazio ou ausente após cópia', rawPath);
      }
      logger.log('foto', 'Cópia OK ${(size / 1024).toStringAsFixed(0)}KB');

      // ── (A) Atomicidade: GRAVA no DB ANTES de adicionar no grid.
      //    Se DB falhar, foto não vai pro grid (consistência forte).
      //    Construímos a nova lista localmente sem mutar a state ainda.
      final novaLista = slot == 'antes'
          ? [..._fotosAntes, rawPath]
          : [..._fotosDepois, rawPath];
      await _persistirListaEMetadados(
          slot, novaLista, loc, capturedAt);
      await _enfileirarUploadFoto(rawPath, slot, atual + 1, capturedAt);
      // Galeria só recebe a foto com watermark, ao concluir a etapa.
      // Não duplicamos: nada vai pro carretel agora.

      // DB OK → AGORA atualiza o grid em memória.
      setState(() {
        if (slot == 'antes') {
          _fotosAntes = novaLista;
        } else {
          _fotosDepois = novaLista;
        }
      });
      logger.log('foto', 'Foto registrada total=${novaLista.length}');
    } catch (e, stack) {
      logger.log('foto', 'Erro: $e', erro: true);
      debugPrint('Erro ao registrar foto ($slot): $e\n$stack');
      // Auto-report assíncrono: cria issue no GitHub com contexto
      // completo (promotor, device, RAM, storage, bateria, log).
      // ignore: discarded_futures
      ErrorReporter.reportar(
        contexto: '_tirarFoto slot=$slot',
        erro: e,
        stack: stack,
      );
      if (mounted) {
        await _avisoBloqueante(
          'Foto não foi salva',
          'Tente novamente. Se o problema persistir, libere espaço '
              'no celular ou reinicie o app.',
        );
      }
    } finally {
      if (mounted) setState(() => _savingPhoto = false);
    }
  }

  /// (D) Dialog bloqueante em vez de SnackBar pra erros críticos. O
  /// promotor precisa ver e confirmar — SnackBar somia em 4s e ele
  /// não entendia o que perdeu.
  Future<void> _avisoBloqueante(String titulo, String mensagem) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(titulo,
            style: const TextStyle(color: AppColors.textPrimary)),
        content: Text(mensagem,
            style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendi',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  /// Persiste a nova lista de fotos + horários/localização no DB.
  /// Reuso pra que o `_tirarFoto` faça DB write antes do setState do grid.
  Future<void> _persistirListaEMetadados(String slot, List<String> lista,
      String? loc, DateTime capturedAt) async {
    final db = ref.read(appDatabaseProvider);
    if (slot == 'antes') {
      await db.updateVisita(VisitasCompanion(
        id: drift.Value(widget.visitaId),
        fotosAntesJson: drift.Value(jsonEncode(lista)),
        diaHoraFotosAntes: drift.Value(capturedAt.toIso8601String()),
        localizacaoFotosAntes: drift.Value(loc),
        syncStatus: const drift.Value('pending'),
      ));
    } else {
      await db.updateVisita(VisitasCompanion(
        id: drift.Value(widget.visitaId),
        fotosDepoisJson: drift.Value(jsonEncode(lista)),
        diaHoraFotosDepois: drift.Value(capturedAt.toIso8601String()),
        localizacaoFotosDepois: drift.Value(loc),
        syncStatus: const drift.Value('pending'),
      ));
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
      // 'watermark_pending': bloqueia o sync engine (que só pega
      // 'pending'). A WatermarkQueueService aplica o watermark em
      // background quando o promotor concluir a etapa e muda o
      // status pra 'pending', liberando o upload.
      status: const drift.Value('watermark_pending'),
      attempts: const drift.Value(0),
      nextRetryAt: drift.Value(DateTime.now().toIso8601String()),
      createdAt: drift.Value(capturedAt.toIso8601String()),
    ));
    // Sem trigger de sync aqui — não há nada pra subir ainda. O
    // gatilho de background será disparado pela WatermarkQueueService
    // quando o watermark estiver pronto.
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
        backgroundColor: AppColors.card,
        title: const Text('Remover foto?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'A foto será apagada deste celular e do envio para o servidor.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remover',
                style: TextStyle(color: AppColors.danger)),
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
    setState(() {
      _busy = true;
      _busyLabel = 'Obtendo localização...';
    });
    // GPS é "best effort" — se falhar (modo avião, sinal fraco, timeout),
    // segue em frente com loc = null. O servidor aceita null.
    final loc = await _capturarLocalizacao();

    final agora = DateTime.now();
    final db = ref.read(appDatabaseProvider);

    // Persiste apertura SOMENTE local. Status fica 1 (agendada) e nada
    // entra na outbox: se o promotor desistir antes de concluir as fotos
    // antes, a visita continua "agendada" no servidor — sem fantasma.
    await db.updateVisita(VisitasCompanion(
      id: drift.Value(widget.visitaId),
      diaHoraAbertura: drift.Value(agora.toIso8601String()),
      localizacaoAbertura: drift.Value(loc),
      localState: const drift.Value('fotos_antes'),
    ));

    setState(() {
      _localizacaoAbertura = loc;
      _localState = 'fotos_antes';
      _busy = false;
    });
    _updateSyncPause('fotos_antes');
  }

  String _pdvNomeParaWatermark() {
    final titulo = _visita?.titulo;
    if (titulo != null && titulo.trim().isNotEmpty) return titulo;
    return _pdv?.apiLocalName ??
        _pdv?.apiLocalCustomerName ??
        'PDV ${_visita?.idPdvAssociado ?? '?'}';
  }

  /// Dialog de confirmação antes de concluir a etapa de fotos.
  /// Necessário porque o botão "Concluir" fica perto do "Tirar foto"
  /// e o promotor estava clicando por engano. Só é chamado quando
  /// o mínimo de fotos já foi atingido (botão fica desabilitado abaixo).
  Future<void> _confirmarConcluirFotos(String slot) async {
    final fotos = slot == 'antes' ? _fotosAntes : _fotosDepois;
    final etapa = slot == 'antes' ? 'antes' : 'depois';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(
          'Concluir fotos $etapa?',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Você tirou ${fotos.length} foto(s). Confirma que terminou '
          'as fotos $etapa da reposição?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sim, concluir',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (slot == 'antes') {
      await _concluirFotosAntes();
    } else {
      await _concluirFotosDepois();
    }
  }

  Future<void> _concluirFotosAntes() async {
    if (_fotosAntes.isEmpty) {
      _showError('Tire pelo menos uma foto antes da reposição.');
      return;
    }

    try {
      // Captura tudo o que vai precisar pro enqueue ANTES do context.go
      // (depois disso o widget é descartado e `ref` fica inválido).
      final wmQueue = ref.read(watermarkQueueProvider);
      final pdvNome = _pdvNomeParaWatermark();
      final promotorNome = _promotorNome;

      final db = ref.read(appDatabaseProvider);
      final session = await SessionService.getSession();
      final atual = await db.getVisitaById(widget.visitaId);

      // Transição 1→2 (agendada → em andamento) acontece AQUI: só depois
      // que o promotor concluiu as fotos antes. Se ele desistir no meio,
      // o status no servidor continua "agendada" — sem fantasma.
      await db.updateVisita(VisitasCompanion(
        id: drift.Value(widget.visitaId),
        statusVisita: const drift.Value(AppConstants.statusEmAndamento),
        localState: const drift.Value('fotos_depois'),
        syncStatus: const drift.Value('pending'),
      ));

      await _enfileirarVisita(db, 'open', {
        'id': widget.visitaId,
        'status_visita': AppConstants.statusEmAndamento,
        'dia_hora_abertura': atual?.diaHoraAbertura,
        'localizacao_abertura': atual?.localizacaoAbertura,
        'id_promotor_associado': session?.userId,
        'fotos_antes_count': _fotosAntes.length,
      });

      // Sai do estado de captura. O sync vai ser disparado pelo
      // WatermarkQueueService quando o watermark da etapa terminar
      // (lá ele dispara fullSync com fotos já prontas pra upload).
      await SyncPause.resume();

      await LastVisitaService.clear();
      if (mounted) context.go('/home');

      // SÓ AGORA enfileira o watermark. Importante fazer DEPOIS do
      // context.go pra que o trabalho pesado do Canvas/encode (que
      // bloqueia o UI thread) aconteça enquanto o promotor já está
      // navegando na home, não na tela de visita.
      wmQueue.enqueue(
        visitaId: widget.visitaId,
        slot: 'antes',
        pdvNome: pdvNome,
        promotorNome: promotorNome,
      );
    } catch (e, stack) {
      // ignore: discarded_futures
      ErrorReporter.reportar(
        contexto: '_concluirFotosAntes visitaId=${widget.visitaId}',
        erro: e,
        stack: stack,
      );
      if (mounted) {
        _showError('Não foi possível salvar. Tente novamente.');
      }
    }
  }


  Future<void> _concluirFotosDepois() async {
    if (_fotosDepois.isEmpty) {
      _showError('Tire pelo menos uma foto depois da reposição.');
      return;
    }

    setState(() {
      _busy = true;
      _busyLabel = 'Obtendo localização...';
    });

    // Captura tudo o que o queue precisa ANTES (depois o widget vai
    // pra outro estado e setState não vai mais ser confiável).
    final wmQueue = ref.read(watermarkQueueProvider);
    final pdvNome = _pdvNomeParaWatermark();
    final promotorNome = _promotorNome;

    final loc = await _capturarLocalizacao();

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
      _busy = false;
    });
    // Saída do estado de captura → libera sync.
    _updateSyncPause('checklist');

    // SÓ AGORA enfileira o watermark — depois que a UI já transicionou
    // pro checklist. O processamento pesado roda enquanto o promotor
    // responde o checklist, sem aparecer como "tela travada".
    wmQueue.enqueue(
      visitaId: widget.visitaId,
      slot: 'depois',
      pdvNome: pdvNome,
      promotorNome: promotorNome,
    );
  }

  Future<void> _finalizarVisita() async {
    // Valida que todas as 7 perguntas foram respondidas
    for (int i = 0; i < 7; i++) {
      if (_checks[i] == null) {
        _showError('Responda todas as 7 perguntas do checklist.');
        return;
      }
    }
    // Valida obs obrigatórias (1-5 quando NÃO, 6-7 quando SIM)
    for (int i = 0; i < 7; i++) {
      if (_obsObrigatoria(i, _checks[i]) &&
          _obsControllers[i].text.trim().isEmpty) {
        _showError('Justificativa obrigatória na pergunta ${i + 1}.');
        return;
      }
    }

    setState(() {
      _busy = true;
      _busyLabel = 'Finalizando...';
    });

    try {
      final agora = DateTime.now();
      // Captura tudo do ref ANTES de qualquer await — proteção contra
      // "Bad state: Cannot use ref after disposed" (issues #10/#12).
      final db = ref.read(appDatabaseProvider);
      final isOnline = ref.read(connectivityProvider);
      final syncEngine = ref.read(syncEngineProvider);

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
        comentariosVisita: drift.Value(_comentarioGeralCtrl.text),
        localState: const drift.Value('finalizada'),
        syncStatus: const drift.Value('pending'),
      ));

      await _enfileirarVisita(db, 'close', {
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

      // _finalizarVisita vem do 'checklist' (não captura), então o
      // SyncPause já está liberado — mas garantimos defensivamente.
      await SyncPause.resume();
      // AGUARDA o push terminar antes de ir pra home. Sem o await, a
      // home montava com a visita ainda em syncStatus='pending' local
      // e o pullAll subsequente pulava ela (regra do "não sobrescrever
      // pending"), deixando o status visualmente sem mudar.
      if (isOnline) {
        try {
          await syncEngine.processOutbox();
        } catch (_) {}
      }

      await LastVisitaService.clear();
      if (mounted) {
        _showSuccess('Visita finalizada com sucesso!');
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) context.go('/home');
      }
    } catch (e, stack) {
      // ignore: discarded_futures
      ErrorReporter.reportar(
        contexto: '_finalizarVisita visitaId=${widget.visitaId}',
        erro: e,
        stack: stack,
      );
      if (mounted) {
        setState(() => _busy = false);
        _showError('Não foi possível finalizar. Tente novamente.');
      }
    }
  }

  /// Recebe o `db` como parâmetro pra não precisar chamar `ref.read`
  /// aqui dentro — os callers (_concluirFotosAntes, _finalizarVisita)
  /// têm awaits anteriores e podem chegar com o widget descartado.
  /// Sem isso, "Bad state: Cannot use ref after disposed" crashava o
  /// app na conclusão de visita (issue #10, 2026-05-22).
  Future<void> _enfileirarVisita(
      AppDatabase db,
      String operation,
      Map<String, dynamic> payload) async {
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
    // Gatilho de background: o sistema executa esta task quando houver
    // rede, mesmo se o app for fechado.
    scheduleOneOffSync();
  }

  // ── UI Helpers ─────────────────────────────────────────────────────────────

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.danger,
    ));
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.primary,
    ));
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      // Caminho de escape obrigatório: se a visita sumiu do DB (idTemp
      // reconciliado, sync de novo dia, etc.) o promotor ficava preso aqui
      // sem botão de voltar e tinha que reinstalar o app. Limpa o
      // last_visita_id pra splash não trazer de volta no próximo boot.
      Future<void> sairDoErro() async {
        final router = GoRouter.of(context);
        await LastVisitaService.clear();
        router.go('/home');
      }
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          await sairDoErro();
        },
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.card,
            iconTheme: const IconThemeData(color: AppColors.textPrimary),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
              onPressed: sairDoErro,
            ),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textPrimary)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: sairDoErro,
                    child: const Text('Voltar para o início'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Mesma hierarquia do app antigo: visita.titulo é a fonte preferida
    final pdvNome = (_visita?.titulo?.isNotEmpty ?? false)
        ? _visita!.titulo!
        : _pdv?.apiLocalName ??
            _pdv?.apiLocalCustomerName ??
            'PDV ${_visita?.idPdvAssociado ?? '?'}';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // Back do sistema: mesmo comportamento da seta do AppBar.
        await _sairParaHome();
      },
      child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: _sairParaHome,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pdvNome,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            if (_pdv?.endereco != null)
              Text(
                _pdv!.endereco!,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
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
          if (_busy)
            Positioned.fill(
              child: AbsorbPointer(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.6),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 3,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _busyLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
                          color: AppColors.primary,
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
                            color: Colors.white70,
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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.store, size: 64, color: AppColors.primary),
          const SizedBox(height: 24),
          const Text(
            'Iniciar visita',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 48),
          const Text(
            '📍 GPS será capturado ao iniciar',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppColors.textSecondary, fontSize: 14),
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
              backgroundColor: AppColors.primary,
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
    final minimo = slot == 'antes'
        ? AppConstants.minFotosAntes
        : AppConstants.minFotosDepois;
    final cor = slot == 'antes'
        ? AppColors.statusAgendada
        : AppColors.primary;
    final atingiuMinimo = fotos.length >= minimo;

    final tituloLabel = slot == 'antes' ? 'Foto Antes' : 'Foto Depois';

    return Column(
      children: [
        // Header com título centralizado + destacado e contador no canto
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          color: AppColors.card,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: Text(
                  tituloLabel,
                  style: TextStyle(
                    color: cor,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                child: Text(
                  '${fotos.length}/$limite',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 14),
                ),
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
                        slot == 'antes'
                            ? 'Tire a(s) foto(s) antes da reposição'
                            : 'Tire a(s) foto(s) depois da reposição',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 16),
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
                    label: Text('Tirar foto',
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

              // Botão concluir — sempre visível, esmaecido quando ainda
              // não atingiu o mínimo de fotos (4). Confirma com dialog
              // antes de prosseguir pra evitar clique acidental no
              // botão de "Concluir" (que fica perto do "Tirar foto").
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: atingiuMinimo
                      ? () => _confirmarConcluirFotos(slot)
                      : null,
                  icon: Icon(
                    atingiuMinimo ? Icons.check : Icons.camera_alt,
                    color: Colors.white,
                  ),
                  label: Text(
                    atingiuMinimo
                        ? (slot == 'antes'
                            ? 'Concluir'
                            : 'Concluir — ir para checklist')
                        : 'Faltam ${minimo - fotos.length} foto(s) — mínimo $minimo',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor:
                        AppColors.primary.withValues(alpha: 0.35),
                    disabledForegroundColor:
                        Colors.white.withValues(alpha: 0.7),
                    padding: const EdgeInsets.symmetric(vertical: 14),
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

  // Perguntas do checklist (mesma ordem do app antigo FF):
  // - Perguntas 1..5: resposta esperada é SIM. NÃO → obs obrigatória.
  // - Perguntas 6 e 7: resposta esperada é NÃO. SIM → obs obrigatória.
  static const _perguntasPadrao = [
    'Você atualizou a máquina de pagamento?',
    'Você verificou validades?',
    'As sacolas estão adequadas?',
    'TOP10 bem abastecido?',
    'Foi feito inventário no TOP10?',
    'Faltou algum produto?',
    'Produto em excesso?',
  ];

  /// Para qual resposta (true=SIM ou false=NÃO) a observação é obrigatória
  /// em cada pergunta. Perguntas 1-5 (índices 0-4): obs obrigatória quando NÃO.
  /// Perguntas 6-7 (índices 5-6): obs obrigatória quando SIM.
  bool _obsObrigatoria(int index, bool? resposta) {
    if (resposta == null) return false;
    if (index >= 5) return resposta == true; // 6 e 7: SIM → obrigatória
    return resposta == false; // 1-5: NÃO → obrigatória
  }

  Widget _buildChecklist() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: AppColors.card,
          child: const Row(
            children: [
              Icon(Icons.checklist, color: AppColors.primary),
              SizedBox(width: 12),
              Text(
                'Checklist de encerramento',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (var i = 0; i < 7; i++) _buildPergunta(i),
              const SizedBox(height: 8),
              // Comentário geral da visita (opcional)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Comentário geral sobre a visita',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _comentarioGeralCtrl,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 13),
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Opcional',
                        hintStyle: TextStyle(
                            color: AppColors.textMuted, fontSize: 13),
                        filled: true,
                        fillColor: AppColors.inputBg,
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
              ),
            ],
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
                backgroundColor: AppColors.primary,
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
    final resposta = _checks[index];
    final obsObrigatoria = _obsObrigatoria(index, resposta);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: resposta == null
              ? AppColors.border
              : resposta
                  ? AppColors.primary.withOpacity(0.4)
                  : AppColors.danger.withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${index + 1}. $pergunta',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // SIM
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _checks[index] = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: resposta == true
                          ? AppColors.primary
                          : AppColors.inputBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: resposta == true
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check,
                            size: 18,
                            color: resposta == true
                                ? Colors.white
                                : AppColors.textMuted),
                        const SizedBox(width: 6),
                        Text('SIM',
                            style: TextStyle(
                                color: resposta == true
                                    ? Colors.white
                                    : AppColors.textPrimary,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // NÃO
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _checks[index] = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: resposta == false
                          ? AppColors.danger
                          : AppColors.inputBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: resposta == false
                            ? AppColors.danger
                            : AppColors.border,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.close,
                            size: 18,
                            color: resposta == false
                                ? Colors.white
                                : AppColors.textMuted),
                        const SizedBox(width: 6),
                        Text('NÃO',
                            style: TextStyle(
                                color: resposta == false
                                    ? Colors.white
                                    : AppColors.textPrimary,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Observação — opcional ou obrigatória dependendo da resposta
          const SizedBox(height: 8),
          TextField(
            controller: _obsControllers[index],
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: obsObrigatoria
                  ? 'Justificativa obrigatória'
                  : 'Observação (opcional)',
              hintStyle: TextStyle(
                color: obsObrigatoria
                    ? AppColors.dangerLight
                    : AppColors.textMuted,
                fontSize: 13,
              ),
              filled: true,
              fillColor: AppColors.inputBg,
              border: const OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: obsObrigatoria &&
                        _obsControllers[index].text.trim().isEmpty
                    ? const BorderSide(color: AppColors.danger, width: 1)
                    : BorderSide.none,
                borderRadius: const BorderRadius.all(Radius.circular(8)),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
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
                size: 80, color: AppColors.primary),
            const SizedBox(height: 24),
            const Text(
              'Visita finalizada!',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => context.go('/home'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
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
          child: Image.file(
            File(path),
            fit: BoxFit.cover,
            // Watermark queue troca _raw.jpg por _watermark.jpg e deleta o
            // arquivo cru. Se a UI rebuildar com path antigo (ex: promotor
            // volta do checklist), o file pode não existir mais — placeholder
            // em vez de crash. Reportado em produção (Cleiton, A05, 2026-05).
            errorBuilder: (_, __, ___) => Container(
              color: AppColors.card,
              alignment: Alignment.center,
              child: const Icon(
                Icons.image_not_supported_outlined,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),

        // Botão X (deletar) - canto superior direito
        Positioned(
          top: 4,
          right: 4,
          child: _CircleButton(
            icon: Icons.close,
            onTap: onRemove,
            background: AppColors.danger,
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
