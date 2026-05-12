// lib/core/network/connectivity_service.dart

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';

class ConnectivityService extends Notifier<bool> {
  Timer? _pingTimer;
  final _dio = Dio(BaseOptions(
    connectTimeout:
        Duration(seconds: AppConstants.pingTimeoutSeconds),
    receiveTimeout:
        Duration(seconds: AppConstants.pingTimeoutSeconds),
  ));

  @override
  bool build() {
    _startPing();
    ref.onDispose(() {
      _pingTimer?.cancel();
    });
    return false; // começa como offline, primeiro ping confirma
  }

  void _startPing() {
    _pingTimer?.cancel();
    _ping(); // ping imediato
    _pingTimer = Timer.periodic(
      Duration(seconds: AppConstants.pingIntervalSeconds),
      (_) => _ping(),
    );
  }

  Future<void> _ping() async {
    try {
      await _dio.head(
        '${AppConstants.supabaseUrl}/rest/v1/',
        options: Options(
          headers: {
            'apikey': AppConstants.supabaseAnonKey,
          },
          validateStatus: (_) => true,
        ),
      );
      if (state != true) state = true;
    } catch (_) {
      if (state != false) state = false;
    }
  }

  bool get isOnline => state;
}

final connectivityProvider =
    NotifierProvider<ConnectivityService, bool>(ConnectivityService.new);

/// Ping standalone — útil no isolate do WorkManager onde não há providers
/// Riverpod ativos. Retorna `true` SOMENTE se o servidor Supabase respondeu
/// dentro do timeout. "Tem rede no Android" não basta: hotéis, redes
/// corporativas e DNS quebrado dizem "conectado" sem alcançar o servidor.
Future<bool> pingSupabase() async {
  try {
    final dio = Dio(BaseOptions(
      connectTimeout: Duration(seconds: AppConstants.pingTimeoutSeconds),
      receiveTimeout: Duration(seconds: AppConstants.pingTimeoutSeconds),
    ));
    await dio.head(
      '${AppConstants.supabaseUrl}/rest/v1/',
      options: Options(
        headers: {'apikey': AppConstants.supabaseAnonKey},
        validateStatus: (_) => true,
      ),
    );
    return true;
  } catch (_) {
    return false;
  }
}
