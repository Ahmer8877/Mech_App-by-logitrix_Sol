import 'package:flutter/material.dart';
import 'app_text.dart';

import '../cores/theme/app_theme.dart';

/// Thin segmented progress bar — mirrors .stepper/.step-dot in the HTML kit.
/// [current] is 1-indexed (1 = first step done).
class StepProgress extends StatelessWidget {
  final int total;
  final int current;

  const StepProgress({super.key, required this.total, required this.current});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: List.generate(total, (i) {
          final done = i < current;
          return Expanded(
            child: Container(
              height: 3,
              margin: EdgeInsets.only(right: i == total - 1 ? 0 : 4),
              decoration: BoxDecoration(
                color: done ? scheme.primary : c.surface3,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Standard booking-flow app bar: back button + centered-ish title.
class FlowAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  const FlowAppBar({super.key, required this.title});

  @override
  Widget build(BuildContext context) =>
      AppBar(title: AppText(title, style: const TextStyle(fontSize: 15)));

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
