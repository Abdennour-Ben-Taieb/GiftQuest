import 'package:flutter/material.dart';

import '../theme.dart';

StickerTheme _stickerOf(BuildContext context) =>
    Theme.of(context).extension<StickerTheme>() ?? StickerTheme.defaults;

/// A panel with a thick flat border and a hard-edged (unblurred) offset
/// shadow — the "chunky sticker-shadow" card used for hero panels, code
/// cards, chat bubbles, etc. across the app.
class StickerCard extends StatelessWidget {
  const StickerCard({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderColor,
    this.radius,
  });

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? borderColor;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final sticker = _stickerOf(context);
    final scheme = Theme.of(context).colorScheme;
    final r = radius ?? sticker.radius;

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(
          color: borderColor ?? sticker.borderColor,
          width: sticker.borderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: sticker.shadowColor,
            offset: sticker.shadowOffset,
            blurRadius: 0,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Circular photo picker with the same hard-edged sticker-shadow ring as
/// [StickerButton]/[StickerCard]. Pass an [image] (e.g. `FileImage` for a
/// freshly-picked photo or `NetworkImage` for an already-uploaded one) to
/// show it filled in; leave it null to show [placeholder] text instead.
class StickerAvatar extends StatelessWidget {
  const StickerAvatar({
    super.key,
    required this.onTap,
    this.image,
    this.placeholder = 'Add\nphoto',
    this.size = 104,
  });

  final VoidCallback onTap;
  final ImageProvider? image;
  final String placeholder;
  final double size;

  @override
  Widget build(BuildContext context) {
    final sticker = _stickerOf(context);
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scheme.surfaceContainerHigh,
          border: Border.all(
            color: sticker.borderColor,
            width: sticker.borderWidth,
          ),
          boxShadow: [
            BoxShadow(
              color: sticker.shadowColor,
              offset: sticker.shadowOffset,
              blurRadius: 0,
            ),
          ],
          image: image != null
              ? DecorationImage(image: image!, fit: BoxFit.cover)
              : null,
        ),
        alignment: Alignment.center,
        child: image == null
            ? Text(
                placeholder,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              )
            : null,
      ),
    );
  }
}

/// Rectangular dashed-border photo picker — used by Add/Edit Wish's photo
/// field, where the mockup calls for a rectangle rather than the circular
/// [StickerAvatar] used for profile photos.
class DashedPhotoBox extends StatelessWidget {
  const DashedPhotoBox({
    super.key,
    required this.onTap,
    this.image,
    this.height = 160,
    this.label = 'add a photo',
  });

  final VoidCallback onTap;
  final ImageProvider? image;
  final double height;
  final String label;

  @override
  Widget build(BuildContext context) {
    final sticker = _stickerOf(context);
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _DashedRRectPainter(
            color: sticker.borderColor,
            strokeWidth: sticker.borderWidth,
            radius: sticker.radius,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(sticker.radius),
              image: image != null
                  ? DecorationImage(image: image!, fit: BoxFit.cover)
                  : null,
            ),
            alignment: Alignment.center,
            child: image == null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        color: scheme.onSurfaceVariant,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(label, style: TextStyle(color: scheme.onSurfaceVariant)),
                    ],
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

/// Big tinted rounded-square icon sticker used by the Reveal screen's
/// win/lose outcome graphic. [dashed] swaps the solid border for a dashed
/// one (used for the "lose" state per the mockup).
class StickerOutcomeIcon extends StatelessWidget {
  const StickerOutcomeIcon({
    super.key,
    required this.icon,
    required this.tint,
    this.size = 140,
    this.dashed = false,
  });

  final IconData icon;
  final Color tint;
  final double size;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final sticker = _stickerOf(context);

    final content = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(sticker.radius),
        border: dashed
            ? null
            : Border.all(color: tint, width: sticker.borderWidth),
      ),
      child: Icon(icon, color: tint, size: size * 0.42),
    );

    if (!dashed) return content;
    return CustomPaint(
      painter: _DashedRRectPainter(
        color: tint,
        strokeWidth: sticker.borderWidth,
        radius: sticker.radius,
      ),
      child: content,
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({
    required this.color,
    required this.strokeWidth,
    required this.radius,
  });

  final Color color;
  final double strokeWidth;
  final double radius;
  static const dashWidth = 6.0;
  static const gapWidth = 5.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dashWidth).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gapWidth;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) {
    return color != oldDelegate.color ||
        strokeWidth != oldDelegate.strokeWidth ||
        radius != oldDelegate.radius;
  }
}

enum StickerButtonVariant { primary, secondary, outline }

/// Chunky pill/rounded button with the same sticker-shadow treatment as
/// [StickerCard]. Used for every CTA across the app so buttons stay visually
/// consistent.
class StickerButton extends StatelessWidget {
  const StickerButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = StickerButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final StickerButtonVariant variant;
  final Widget? icon;
  final bool isLoading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sticker = _stickerOf(context);
    final enabled = onPressed != null && !isLoading;

    final Color fill;
    final Color textColor;
    switch (variant) {
      case StickerButtonVariant.primary:
        fill = scheme.primary;
        textColor = scheme.onPrimary;
      case StickerButtonVariant.secondary:
        fill = scheme.secondary;
        textColor = scheme.onSecondary;
      case StickerButtonVariant.outline:
        fill = scheme.surfaceContainerHigh;
        textColor = scheme.onSurface;
    }

    final content = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: textColor),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[icon!, const SizedBox(width: 10)],
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );

    return AnimatedOpacity(
      opacity: enabled ? 1 : 0.5,
      duration: const Duration(milliseconds: 150),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(sticker.radius),
          child: Container(
            width: expand ? double.infinity : null,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(sticker.radius),
              border: Border.all(
                color: sticker.borderColor,
                width: sticker.borderWidth,
              ),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: sticker.shadowColor,
                        offset: sticker.shadowOffset,
                        blurRadius: 0,
                      ),
                    ]
                  : null,
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}
