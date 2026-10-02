import 'package:flutter/material.dart';
import '../../widgets/app_text.dart';
import '../../cores/theme/app_theme.dart';
import '../../widgets/step_progress.dart';

class _SavedMethod {
  final IconData icon;
  final String label;
  final String detail;
  const _SavedMethod(this.icon, this.label, this.detail);
}

/// Profile -> Payment Methods: manage saved cards/wallets for future bookings.
class SavedPaymentMethodsScreen extends StatelessWidget {
  const SavedPaymentMethodsScreen({super.key});

  static const _methods = [
    _SavedMethod(Icons.payments_outlined, 'Cash', 'Default for all bookings'),
    _SavedMethod(Icons.phone_android_outlined, 'JazzCash', '+92 300 1234567'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: const FlowAppBar(title: 'Payment Methods'),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ..._methods.map(
              (m) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: c.borderStrong.withValues(alpha: 0.4),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: c.surface2,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(m.icon, size: 16, color: scheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            m.label,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          AppText(
                            m.detail,
                            style: TextStyle(fontSize: 10, color: c.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 18, color: c.textMuted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: AppText(
                    'Card/wallet linking will be available after payment gateway integration',
                  ),
                ),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const AppText('Add Card or Wallet'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(color: c.borderStrong),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
