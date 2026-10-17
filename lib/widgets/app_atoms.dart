import 'package:flutter/material.dart';
import 'app_text.dart';

import '../cores/theme/app_theme.dart';

/// Base bordered card — mirrors .card in the HTML kit.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? background;
  final Color? borderColor;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.background,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = context.colors;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background ?? scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor ?? c.borderStrong.withValues(alpha: 0.5),
        ),
      ),
      child: child,
    );
  }
}

/// One tappable service icon tile (General, Engine, Battery...) — mirrors .service-tile.
class ServiceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const ServiceTile({
    super.key,
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.08)
              : scheme.surface,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: selected
                ? scheme.primary
                : c.borderStrong.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: selected ? scheme.primary : c.surface2,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 14,
                color: selected ? scheme.onPrimary : scheme.primary,
              ),
            ),
            const SizedBox(height: 6),
            AppText(
              label,
              style: const TextStyle(fontSize: 10),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}

/// One mechanic's offer in the bidding list — mirrors .offer-row / .offer-row.best.
class OfferRow extends StatelessWidget {
  final String initials;
  final String name;
  final double rating;
  final String distance;
  final int price;
  final bool isBest;
  final VoidCallback? onSelect;

  const OfferRow({
    super.key,
    required this.initials,
    required this.name,
    required this.rating,
    required this.distance,
    required this.price,
    this.isBest = false,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isBest ? c.accent.withValues(alpha: 0.08) : scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isBest ? c.accent : c.borderStrong.withValues(alpha: 0.4),
          width: isBest ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: c.surface2,
            child: AppText(
              initials,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: scheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  '$name  ⭐$rating',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                AppText(
                  distance,
                  style: TextStyle(fontSize: 9.5, color: c.textMuted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AppText(
                'Rs $price',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              if (isBest)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: c.accent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: AppText(
                    'Best offer',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w600,
                      color: c.onAccent,
                    ),
                  ),
                )
              else
                GestureDetector(
                  onTap: onSelect,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: c.surface2,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: AppText(
                      'Select',
                      style: TextStyle(fontSize: 8.5, color: c.textSecondary),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small stat block (used on dashboards) — mirrors .stat-mini.
class StatMini extends StatelessWidget {
  final String value;
  final String label;

  const StatMini({super.key, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: c.borderStrong.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          AppText(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          AppText(label, style: TextStyle(fontSize: 8, color: c.textMuted)),
        ],
      ),
    );
  }
}

/// A labeled read-only "field" block — mirrors .field (used for static text,
/// or wrap in InkWell for tappable pickers like location/vehicle selectors).
class AppFieldBox extends StatelessWidget {
  final String text;
  final double height;
  final CrossAxisAlignment align;

  const AppFieldBox({
    super.key,
    required this.text,
    this.height = 44,
    this.align = CrossAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      height: height,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.borderStrong.withValues(alpha: 0.35)),
      ),
      alignment: align == CrossAxisAlignment.start
          ? Alignment.topLeft
          : Alignment.centerLeft,
      child: AppText(text, style: TextStyle(fontSize: 11, color: c.textMuted)),
    );
  }
}

/// Faint dashed-grid "map" placeholder block with pin(s) — mirrors .map-block.
/// Swap this out for a real GoogleMap widget once API keys are wired up.
class MapPlaceholder extends StatelessWidget {
  final double height;
  final List<Widget> pins;

  const MapPlaceholder({super.key, this.height = 140, this.pins = const []});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: height,
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.surface2, c.surface3],
        ),
      ),
      child: Stack(
        children: [
          CustomPaint(
            size: Size.infinite,
            painter: _GridPainter(color: c.borderStrong),
          ),
          ...pins,
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final Color color;
  _GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 18) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 18) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => false;
}

/// Teardrop map pin — mirrors .pin / .pin.accent.
class MapPin extends StatelessWidget {
  final double top;
  final double left;
  final String emoji;
  final bool accent;

  const MapPin({
    super.key,
    required this.top,
    required this.left,
    required this.emoji,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = context.colors;
    return Positioned(
      top: top,
      left: left,
      child: Transform.rotate(
        angle: -0.785398, // -45deg
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: accent ? c.accent : scheme.primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(13),
              topRight: Radius.circular(13),
              bottomLeft: Radius.circular(13),
            ),
          ),
          alignment: Alignment.center,
          child: Transform.rotate(
            angle: 0.785398,
            child: AppText(emoji, style: const TextStyle(fontSize: 11)),
          ),
        ),
      ),
    );
  }
}
