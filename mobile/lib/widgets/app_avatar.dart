import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/utils/formatters.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// An avatar that never looks broken.
///
/// If the photo is missing or the network is down we fall back to initials on a
/// tint derived from the name — deterministic, so the same person always gets
/// the same colour. Empty grey circles are what make demo apps look unfinished.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 48,
    this.isOnline = false,
    this.showPresence = false,
    this.ring,
  });

  final String name;
  final String? imageUrl;
  final double size;
  final bool isOnline;
  final bool showPresence;
  final Color? ring;

  static const List<Color> _palette = <Color>[
    Color(0xFF4B5BA6),
    Color(0xFF2F7A5E),
    Color(0xFFC0603A),
    Color(0xFF8C4A70),
    Color(0xFF2B7683),
    Color(0xFF6A4FA3),
    Color(0xFFB0821F),
    Color(0xFF5E7A2A),
  ];

  Color get _fallbackHue {
    if (name.isEmpty) return _palette.first;
    int hash = 0;
    for (final int unit in name.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return _palette[hash % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Widget placeholder = Container(
      color: _fallbackHue.withValues(alpha: isDark ? 0.28 : 0.14),
      alignment: Alignment.center,
      child: Text(
        Format.initials(name),
        style: context.type.bodyStrong.copyWith(
          fontSize: size * 0.34,
          color: isDark
              ? HSLColor.fromColor(_fallbackHue).withLightness(0.72).toColor()
              : _fallbackHue,
        ),
      ),
    );

    final Widget image = imageUrl == null || imageUrl!.isEmpty
        ? placeholder
        : CachedNetworkImage(
            imageUrl: imageUrl!,
            fit: BoxFit.cover,
            width: size,
            height: size,
            fadeInDuration: AppMotion.base,
            placeholder: (_, __) => placeholder,
            errorWidget: (_, __, ___) => placeholder,
          );

    final Widget avatar = Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ring ?? colors.border, width: ring != null ? 2 : 1),
      ),
      child: ClipOval(child: image),
    );

    if (!showPresence) return avatar;

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        avatar,
        Positioned(
          right: 0,
          bottom: 0,
          child: AnimatedContainer(
            duration: AppMotion.base,
            height: size * 0.26,
            width: size * 0.26,
            constraints: const BoxConstraints(minHeight: 10, minWidth: 10),
            decoration: BoxDecoration(
              color: isOnline ? colors.success : colors.inkFaint,
              shape: BoxShape.circle,
              border: Border.all(color: colors.surface, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

/// Overlapping avatars for "3 people are in".
class AvatarStack extends StatelessWidget {
  const AvatarStack({
    super.key,
    required this.entries,
    this.size = 28,
    this.maxVisible = 3,
  });

  final List<({String name, String? imageUrl})> entries;
  final double size;
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final List<({String name, String? imageUrl})> visible =
        entries.take(maxVisible).toList(growable: false);
    final int overflow = entries.length - visible.length;
    final double overlap = size * 0.32;

    return SizedBox(
      height: size,
      width: visible.isEmpty
          ? 0
          : size + (visible.length - 1) * (size - overlap) + (overflow > 0 ? size - overlap : 0),
      child: Stack(
        children: <Widget>[
          for (int index = 0; index < visible.length; index += 1)
            Positioned(
              left: index * (size - overlap),
              child: AppAvatar(
                name: visible[index].name,
                imageUrl: visible[index].imageUrl,
                size: size,
                ring: colors.surface,
              ),
            ),
          if (overflow > 0)
            Positioned(
              left: visible.length * (size - overlap),
              child: Container(
                height: size,
                width: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.surfaceSunken,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.surface, width: 2),
                ),
                child: Text(
                  '+$overflow',
                  style: context.type.caption.copyWith(
                    color: colors.inkMuted,
                    fontWeight: FontWeight.w600,
                    fontSize: size * 0.32,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
