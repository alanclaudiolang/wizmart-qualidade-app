// lib/core/utils/session_service.dart

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyUserId = 'wizmart_user_id';
  static const _keyEmail = 'wizmart_email';
  static const _keyNome = 'wizmart_nome';
  static const _keySenhaHash = 'wizmart_senha';

  static Future<void> saveSession({
    required int userId,
    required String email,
    required String nome,
    String senhaHash = '',
  }) async {
    await _storage.write(key: _keyUserId, value: userId.toString());
    await _storage.write(key: _keyEmail, value: email);
    await _storage.write(key: _keyNome, value: nome);
    if (senhaHash.isNotEmpty) {
      await _storage.write(key: _keySenhaHash, value: senhaHash);
    }
  }

  static Future<SessionData?> getSession() async {
    final idStr = await _storage.read(key: _keyUserId);
    final email = await _storage.read(key: _keyEmail);
    if (idStr == null || email == null) return null;
    return SessionData(
      userId: int.parse(idStr),
      email: email,
      nome: await _storage.read(key: _keyNome) ?? '',
      senhaHash: await _storage.read(key: _keySenhaHash) ?? '',
    );
  }

  static Future<bool> hasSession() async {
    final id = await _storage.read(key: _keyUserId);
    return id != null;
  }

  static Future<void> clearSession() async {
    await _storage.deleteAll();
  }
}

class SessionData {
  final int userId;
  final String email;
  final String nome;
  final String senhaHash;

  const SessionData({
    required this.userId,
    required this.email,
    required this.nome,
    this.senhaHash = '',
  });
}
