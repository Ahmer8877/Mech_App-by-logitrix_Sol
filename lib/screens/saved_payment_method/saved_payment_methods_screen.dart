import 'package:flutter/material.dart';
import '../../widgets/app_text.dart';
import '../../cores/theme/app_theme.dart';
import '../../widgets/step_progress.dart';

class SavedPaymentMethodsScreen extends StatelessWidget {
  const SavedPaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: const FlowAppBar(title: 'Payment Methods'),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: c.borderStrong.withValues(alpha: .4)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: c.surface2,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.payments_outlined, color: scheme.primary),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          'Cash',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        AppText(
                          'Available for all bookings',
                          style: TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.check_circle, color: scheme.primary, size: 19),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
