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
