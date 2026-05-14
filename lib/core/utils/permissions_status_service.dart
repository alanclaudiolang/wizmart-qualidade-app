// lib/core/utils/permissions_status_service.dart
//
// Monitora permissões críticas (câmera + galeria/storage) e expõe via
// Riverpod. Igual ao GpsStatusService, mas pra permissões.
//
// Diferente do GPS, não há stream nativa pra mudança de permissão —
// precisa re-checar manualmente. O WizMartApp chama `refresh()` quando
// o app volta do foreground (lifecycle resumed), porque é nessa janela
// que o usuário pode ter ido às configurações alterar.

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

enum PermissionItem { camera, midia }

/// Estado de UMA permissão.
enum PermissionState {
  unknown,
  granted,
  denied,
  /// Negada com flag "não perguntar mais" → precisa abrir configurações.
  permanentlyDenied,
}

class PermissionsStatus {
  final PermissionState camera;
  final PermissionState midia;
  const PermissionsStatus({
    this.camera = PermissionState.unknown,
    this.midia = PermissionState.unknown,
  });

  /// Lista de permissões que precisam ser resolvidas (não-granted e
  /// não-unknown). Se vazia, está tudo OK.
  List<PermissionItem> get pendencias {
    final out = <PermissionItem>[];
    if (camera != PermissionState.granted &&
        camera != PermissionState.unknown) {
      out.add(PermissionItem.camera);
    }
    if (midia != PermissionState.granted &&
        midia != PermissionState.unknown) {
      out.add(PermissionItem.midia);
    }
    return out;
  }

  bool get tudoOk =>
      camera == PermissionState.granted && midia == PermissionState.granted;
}

class PermissionsStatusService extends Notifier<PermissionsStatus> {
  @override
  PermissionsStatus build() {
    _check();
    return const PermissionsStatus();
  }

  Future<void> refresh() => _check();

  /// Pede ao usuário a permissão. Se permanentlyDenied, abre configs.
  Future<void> pedir(PermissionItem item) async {
    final perm = _permissaoNativa(item);
    final atual = await perm.status;
    if (atual.isPermanentlyDenied) {
      await openAppSettings();
    } else {
      await perm.request();
    }
    await _check();
  }

  Permission _permissaoNativa(PermissionItem item) {
    switch (item) {
      case PermissionItem.camera:
        return Permission.camera;
      case PermissionItem.midia:
        // Android 13+ usa READ_MEDIA_IMAGES → Permission.photos.
        // Versões antigas usam WRITE_EXTERNAL_STORAGE → Permission.storage.
        // permission_handler resolve no plugin, mas precisamos escolher
        // a permission "certa" pra checar.
        if (Platform.isAndroid) {
          // Heurística: tenta photos primeiro (existe em Android 13+)
          // e cai pra storage. Em sdk < 33 photos retorna granted
          // automaticamente, então o teste funciona pros dois.
          return Permission.photos;
        }
        return Permission.photos;
    }
  }

  PermissionState _mapStatus(PermissionStatus s) {
    if (s.isGranted || s.isLimited) return PermissionState.granted;
    if (s.isPermanentlyDenied) return PermissionState.permanentlyDenied;
    return PermissionState.denied;
  }

  Future<void> _check() async {
    final cam = await Permission.camera.status;
    final mid = await Permission.photos.status;
    final novo = PermissionsStatus(
      camera: _mapStatus(cam),
      midia: _mapStatus(mid),
    );
    if (novo.camera != state.camera || novo.midia != state.midia) {
      state = novo;
    }
  }
}

final permissionsStatusProvider =
    NotifierProvider<PermissionsStatusService, PermissionsStatus>(
        PermissionsStatusService.new);
