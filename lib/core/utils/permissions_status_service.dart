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

  /// Pede ao usuário a permissão. Comportamento difere por plataforma:
  ///
  /// **Android** (ROMs Samsung/Xiaomi/etc bugadas, defensivo):
  ///   1. Se já está permanently denied, abre Configurações.
  ///   2. Senão pede dialog nativo. Se ainda não foi concedida ao final
  ///      (dialog nem apareceu por bug da ROM, ou usuário fechou),
  ///      abre Configurações automaticamente.
  ///
  /// **iOS** (Apple rejeita "auto-redirect after Don't Allow" —
  /// guideline 5.1.1(iv)):
  ///   1. Se já está permanently denied (negou uma vez no iOS = não
  ///      pergunta mais), abre Configurações — é a única recuperação.
  ///   2. Senão pede dialog nativo e RESPEITA a escolha do usuário —
  ///      não abre Configurações automaticamente após negação. Se ele
  ///      quiser permitir depois, toca de novo no botão (que vai pegar
  ///      o estado permanently denied e abrir Configurações).
  Future<void> pedir(PermissionItem item) async {
    final perms = _permissoesNativas(item);
    final antesStatus = await _checkCombinado(perms);
    if (antesStatus == PermissionState.permanentlyDenied) {
      await openAppSettings();
      await _check();
      return;
    }
    for (final perm in perms) {
      await perm.request();
    }
    // iOS: respeita a escolha do usuário. Se ele negou, NÃO abre
    // configs — Apple guideline 5.1.1(iv) considera disrespect.
    // Android: mantém fallback pras ROMs bugadas onde o dialog nem
    // apareceu OU o sistema reportou denied sem mostrar nada.
    if (Platform.isAndroid) {
      final depoisStatus = await _checkCombinado(perms);
      if (depoisStatus != PermissionState.granted) {
        await openAppSettings();
      }
    }
    await _check();
  }

  /// Retorna a lista de Permission nativas que satisfazem o item.
  /// Pra mídia em Android: tanto READ_MEDIA_IMAGES (Permission.photos
  /// em Android 13+) quanto READ_EXTERNAL_STORAGE (Permission.storage
  /// em Android 12-). Se QUALQUER UMA estiver granted, considera ok.
  List<Permission> _permissoesNativas(PermissionItem item) {
    switch (item) {
      case PermissionItem.camera:
        return [Permission.camera];
      case PermissionItem.midia:
        if (Platform.isAndroid) {
          return [Permission.photos, Permission.storage];
        }
        return [Permission.photos];
    }
  }

  /// Combina o status de várias permissions: granted se QUALQUER UMA
  /// está granted/limited; permanentlyDenied se TODAS estão; denied
  /// caso contrário.
  Future<PermissionState> _checkCombinado(List<Permission> perms) async {
    PermissionState melhor = PermissionState.denied;
    bool todasPermanente = perms.isNotEmpty;
    for (final perm in perms) {
      final s = await perm.status;
      if (s.isGranted || s.isLimited) {
        return PermissionState.granted;
      }
      if (!s.isPermanentlyDenied) {
        todasPermanente = false;
      }
    }
    if (todasPermanente) melhor = PermissionState.permanentlyDenied;
    return melhor;
  }

  PermissionState _mapStatus(PermissionStatus s) {
    if (s.isGranted || s.isLimited) return PermissionState.granted;
    if (s.isPermanentlyDenied) return PermissionState.permanentlyDenied;
    return PermissionState.denied;
  }

  Future<void> _check() async {
    final cam = await Permission.camera.status;
    final midia = await _checkCombinado(_permissoesNativas(PermissionItem.midia));
    final novo = PermissionsStatus(
      camera: _mapStatus(cam),
      midia: midia,
    );
    if (novo.camera != state.camera || novo.midia != state.midia) {
      state = novo;
    }
  }
}

final permissionsStatusProvider =
    NotifierProvider<PermissionsStatusService, PermissionsStatus>(
        PermissionsStatusService.new);
