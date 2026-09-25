import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../cores/providers/vehicles_provider.dart';
import '../../cores/providers/booking_draft_provider.dart';
import '../../cores/theme/app_theme.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/step_progress.dart';
import 'select_service_screen.dart';
import 'add_vehicle_screen.dart';

class SelectVehicleScreen extends ConsumerWidget {
  const SelectVehicleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final scheme = Theme.of(context).colorScheme;
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final selectedId = ref.watch(selectedVehicleIdProvider);

    return Scaffold(
      appBar: const FlowAppBar(title: 'My Vehicles'),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const StepProgress(total: 5, current: 1),
            Expanded(
              child: vehiclesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => _ErrorState(
                  message: 'Failed to load vehicles.',
                  onRetry: () => ref.invalidate(vehiclesProvider),
                ),
                data: (vehicles) {
                  if (vehicles.isEmpty) {
                    return Center(
                      child: Text(
                        'Pehle ek vehicle add karein.',
                        style: TextStyle(color: c.textMuted, fontSize: 12),
                      ),
                    );
                  }
                  final effectiveId =
                      selectedId != null &&
                          vehicles.any((v) => v.id == selectedId)
                      ? selectedId
                      : vehicles.first.id;
                  if (selectedId == null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (context.mounted) {
                        ref.read(selectedVehicleIdProvider.notifier).state =
                            effectiveId;
                      }
                    });
                  }
                  return ListView.separated(
                    itemCount: vehicles.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final vehicle = vehicles[i];
                      final selected = vehicle.id == effectiveId;
                      return InkWell(
                        onTap: () =>
                            ref.read(selectedVehicleIdProvider.notifier).state =
                                vehicle.id,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? scheme.primary
                                  : c.borderStrong.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: c.surface2,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.directions_car_outlined,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      vehicle.model,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      vehicle.plate,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: c.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (selected)
                                Icon(
                                  Icons.check_circle,
                                  color: scheme.primary,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            OutlinedButton(
              onPressed: () async {
                final result = await Navigator.of(context)
                    .push<NewVehicleResult>(
                      MaterialPageRoute(
                        builder: (_) => const AddVehicleScreen(),
                      ),
                    );
                if (result != null) {
                  final ok = await ref
                      .read(vehiclesProvider.notifier)
                      .addVehicle(result.make, result.plate, year: result.year);
                  if (ok) {
                    final vehicles =
                        ref.read(vehiclesProvider).valueOrNull ?? const [];
                    if (vehicles.isNotEmpty) {
                      // Newly added vehicle is sorted first because of created_at DESC
                      ref.read(selectedVehicleIdProvider.notifier).state =
                          vehicles.first.id;
                    }
                  }
                }
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(color: c.borderStrong),
              ),
              child: const Text('+ Add New Vehicle'),
            ),
            const SizedBox(height: 10),
            AccentButton(
              label: 'Next',
              onPressed: selectedId == null
                  ? null
                  : () {
                      ref
                          .read(bookingDraftProvider.notifier)
                          .setSelection(vehicleId: selectedId);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SelectServiceScreen(),
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

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        const SizedBox(height: 8),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}
