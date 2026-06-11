import 'package:flutter/material.dart';

class AppColors {
  // PRIMARY
  static const Color primary = Color(0xFF1565C0);

  // BACKGROUNDS
  static const Color background = Color(0xFFF8FAFC);
  static const Color scaffold = Color(0xFFFFFFFF);
  static const Color card = Colors.white;

  // TEXT
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);

  // STATUS
  static const Color success = Color(0xFF16A34A);
  static const Color error = Color(0xFFDC2626);
  static const Color warning = Color(0xFFF59E0B);

  // BORDER
  static const Color border = Color(0xFFE5E7EB);

  // ICONS
  static const Color icon = Color(0xFF374151);

  // INPUT
  static const Color inputFill = Color(0xFFF3F4F6);

  // SHADOW
  static const Color shadow = Color(0x14000000);

  // PROPERTY TAGS
  static const Color featured = Color(0xFF0F172A);

  // GRADIENTS
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
