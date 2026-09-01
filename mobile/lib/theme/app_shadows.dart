import 'package:flutter/material.dart';

/// Shadows are almost invisible on purpose. Depth here comes from a hairline
/// border plus a wide, very soft ambient shadow — never a hard drop.
abstract final class AppShadows {
  static List<BoxShadow> resting(Color ink) => [
        BoxShadow(
          color: ink.withValues(alpha: 0.04),
          blurRadius: 16,
          spreadRadius: -6,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> raised(Color ink) => [
        BoxShadow(
          color: ink.withValues(alpha: 0.05),
          blurRadius: 28,
          spreadRadius: -8,
          offset: const Offset(0, 12),
        ),
        BoxShadow(
          color: ink.withValues(alpha: 0.03),
          blurRadius: 6,
          spreadRadius: -2,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> sheet(Color ink) => [
        BoxShadow(
          color: ink.withValues(alpha: 0.12),
          blurRadius: 40,
          spreadRadius: -12,
          offset: const Offset(0, -8),
        ),
      ];
}
