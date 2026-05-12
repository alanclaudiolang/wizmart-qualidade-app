// lib/core/utils/app_colors.dart
//
// Paleta unificada baseada na tela de login (referência da marca Wizmart).
// Fundo branco, tons de cinza, verde Wizmart como acento.

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Estrutura ───────────────────────────────────────────────────────
  static const background = Colors.white;
  static const card = Color(0xFFF8F9FA); // bg interno de cards / inputs
  static const inputBg = Color(0xFFF8F9FA);
  static const border = Color(0xFFE2E8F0);
  static const divider = Color(0xFFE2E8F0);

  // ── Texto ───────────────────────────────────────────────────────────
  static const textPrimary = Color(0xFF1A202C); // títulos, labels fortes
  static const textSecondary = Color(0xFF718096); // suporte / metadados
  static const textMuted = Color(0xFF4A5568); // hints / placeholders
  static const onPrimary = Colors.white; // texto/ícone sobre verde
  static const onDanger = Colors.white; // texto/ícone sobre vermelho

  // ── Marca Wizmart ───────────────────────────────────────────────────
  static const primary = Color(0xFF38A169); // verde principal
  static const primaryDark = Color(0xFF2F855A);

  // ── Semântica ───────────────────────────────────────────────────────
  static const success = Color(0xFF38A169);
  static const danger = Color(0xFFE53E3E);
  static const dangerLight = Color(0xFFFC8181);
  static const dangerBg = Color(0xFFFFF5F5);
  static const dangerText = Color(0xFFC53030);
  static const warning = Color(0xFFD69E2E);

  // ── Status de visita ────────────────────────────────────────────────
  static const statusAgendada = Color(0xFF3182CE); // azul
  static const statusEmAndamento = Color(0xFFD69E2E); // âmbar
  static const statusRealizada = Color(0xFF38A169); // verde
  static const statusFalta = Color(0xFFE53E3E); // vermelho
}
