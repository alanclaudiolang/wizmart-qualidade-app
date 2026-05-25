// lib/core/utils/gps_status_service.dart
//
// Monitora o status do GPS em tempo real (serviço ativo + permissão
// concedida) e expõe via Riverpod. Um overlay global escuta esse
// provider e bloqueia toda a UI quando algo não está OK — o promotor
// não consegue logar, abrir uma visita ou interagir com nada sem GPS.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

enum GpsState {
  /// Status ainda não verificado.
  unknown,
  /// GPS ligado e permissão concedida.
  ok,
  /// GPS está desligado no sistema.
  serviceDisabled,
  /// Permissão negada (mas pode pedir de novo).
  permissionDenied,
  /// Permissão negada permanentemente — precisa abrir configs do app.
  permissionDeniedForever,
}

class GpsStatusService extends Notifier<GpsState> {
  StreamSubscription<ServiceStatus>? _sub;

  @override
  GpsState build() {
    _check();
    // Dispara automaticamente quando o usuário liga/desliga o GPS.
    _sub = Geolocator.getServiceStatusStream().listen((_) => _check());
    ref.onDispose(() => _sub?.cancel());
    return GpsState.unknown;
  }

  Future<void> refresh() => _check();

  /// Pede a permissão de localização de forma BLINDADA:
  /// 1. Se já está permanentemente negada, vai direto pras configs.
  /// 2. Tenta pedir via dialog nativo.
  /// 3. Se ainda não foi concedida após o pedido, abre as configs
  ///    do app — única saída que funciona em todo Android/ROM.
  Future<void> pedir() async {
    final antes = await Geolocator.checkPermission();
    if (antes == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      await _check();
      return;
    }
    final depois = await Geolocator.requestPermission();
    final ok = depois == LocationPermission.whileInUse ||
        depois == LocationPermission.always;
    if (!ok) {
      await Geolocator.openAppSettings();
    }
    await _check();
  }

  /// Abre a tela do sistema pra ligar o GPS (quando service está off).
  Future<void> abrirConfigsGps() async {
    await Geolocator.openLocationSettings();
    await _check();
  }

  Future<void> _check() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      _setState(GpsState.serviceDisabled);
      return;
    }
    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      _setState(GpsState.permissionDenied);
      return;
    }
    if (perm == LocationPermission.deniedForever) {
      _setState(GpsState.permissionDeniedForever);
      return;
    }
    _setState(GpsState.ok);
  }

  void _setState(GpsState s) {
    if (state != s) state = s;
  }
}

final gpsStatusProvider =
    NotifierProvider<GpsStatusService, GpsState>(GpsStatusService.new);
