// lib/core/utils/session_service.dart

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

class SessionService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Salva sessão após login por número
  static Future<void> saveSession({
    required int userId,
    required String phone,
    required String nome,
  }) async {
    await _storage.write(
        key: AppConstants.sessionUserIdKey, value: userId.toString());
    await _storage.write(
        key: AppConstants.sessionUserPhoneKey, value: phone);
    await _storage.write(
        key: AppConstants.sessionUserNameKey, value: nome);
  }

  // Lê sessão salva
  static Future<SessionData?> getSession() async {
    final idStr =
        await _storage.read(key: AppConstants.sessionUserIdKey);
    final phone =
        await _storage.read(key: AppConstants.sessionUserPhoneKey);
    final nome =
        await _storage.read(key: AppConstants.sessionUserNameKey);

    if (idStr == null || phone == null) return null;

    return SessionData(
      userId: int.parse(idStr),
      phone: phone,
      nome: nome ?? '',
    );
  }

  // Verifica se tem sessão salva
  static Future<bool> hasSession() async {
    final id = await _storage.read(key: AppConstants.sessionUserIdKey);
    return id != null;
  }

  // Apaga sessão (logout ou usuário inativo)
  static Future<void> clearSession() async {
    await _storage.deleteAll();
  }
}

class SessionData {
  final int userId;
  final String phone;
  final String nome;

  const SessionData({
    required this.userId,
    required this.phone,
    required this.nome,
  });
}
