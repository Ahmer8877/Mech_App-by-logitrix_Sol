import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../cores/models/service_model.dart';
import '../../cores/providers/booking_draft_provider.dart';
import '../../cores/theme/app_theme.dart';
import '../../widgets/app_text.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/step_progress.dart';
import 'select_vehicle_screen.dart';

class ServiceDetailsScreen extends ConsumerWidget {
  final ServiceItem service;
  const ServiceDetailsScreen({super.key, required this.service});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: const FlowAppBar(title: 'Service Details'),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const StepProgress(total: 5, current: 1),
            const SizedBox(height: 24),
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(service.icon, size: 38, color: scheme.primary),
            ),
            const SizedBox(height: 20),
            AppText(
              service.title,
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            AppText(
              service.description.isEmpty
                  ? 'Professional help for your vehicle. Choose this service to continue booking.'
                  : service.description,
              style: TextStyle(fontSize: 14, height: 1.5, color: c.textMuted),
            ),
            const SizedBox(height: 20),
            if (service.basePrice > 0)
              Card(
                child: ListTile(
                  leading: Icon(Icons.payments_outlined, color: scheme.primary),
                  title: const AppText('Indicative base price'),
                  subtitle: AppText(
                    'PKR ${service.basePrice.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            const Spacer(),
            AccentButton(
              label: 'Select Vehicle',
              onPressed: () {
                ref
                    .read(bookingDraftProvider.notifier)
                    .setSelection(
                      serviceId: service.id.isEmpty
                          ? service.title
                          : service.id,
                    );
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SelectVehicleScreen(
                      preselectedServiceId: service.id.isEmpty
                          ? service.title
                          : service.id,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
