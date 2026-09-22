import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../cores/providers/vehicles_provider.dart';
import '../../cores/theme/app_theme.dart';
import '../../widgets/step_progress.dart';
import 'add_vehicle_screen.dart';

/// Vehicle management screen reached from Profile -> My Vehicles,
/// powered by Riverpod [vehiclesProvider].
class MyVehiclesScreen extends ConsumerStatefulWidget {
  const MyVehiclesScreen({super.key});

  @override
  ConsumerState<MyVehiclesScreen> createState() => _MyVehiclesScreenState();
}

class _MyVehiclesScreenState extends ConsumerState<MyVehiclesScreen> {
  void _addVehicle() async {
    final result = await Navigator.of(context).push<NewVehicleResult>(
      MaterialPageRoute(builder: (_) => const AddVehicleScreen()),
    );
    if (result != null) {
      await ref
          .read(vehiclesProvider.notifier)
          .addVehicle(result.make, result.plate, year: result.year);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final scheme = Theme.of(context).colorScheme;
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final vehicles = vehiclesAsync.valueOrNull ?? const [];
    final selectedId = ref.watch(selectedVehicleIdProvider);

    return Scaffold(
      appBar: const FlowAppBar(title: 'My Vehicles'),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: vehiclesAsync.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : vehiclesAsync.hasError
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Failed to load vehicles.'),
                          TextButton(
                            onPressed: () => ref.invalidate(vehiclesProvider),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : vehicles.isEmpty
                  ? Center(
                      child: Text(
                        'No vehicles added yet',
                        style: TextStyle(color: c.textMuted, fontSize: 12),
                      ),
                    )
                  : ListView.separated(
                      itemCount: vehicles.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final v = vehicles[i];
                        final isSelected = v.id == selectedId;
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isSelected
                                  ? scheme.primary
                                  : c.borderStrong.withValues(alpha: 0.4),
                              width: isSelected ? 1.5 : 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
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
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${v.model} · ${v.plate}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (isSelected)
                                      Text(
                                        'Default vehicle',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          color: scheme.primary,
                                        ),
                                      )
                                    else
                                      GestureDetector(
                                        onTap: () =>
                                            ref
                                                    .read(
                                                      selectedVehicleIdProvider
                                                          .notifier,
                                                    )
                                                    .state =
                                                v.id,
                                        child: Text(
                                          'Set as default',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            color: c.textMuted,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () async {
                                  await ref
                                      .read(vehiclesProvider.notifier)
                                      .removeVehicle(v.id);
                                  if (ref.read(selectedVehicleIdProvider) ==
                                      v.id) {
                                    ref
                                            .read(
                                              selectedVehicleIdProvider
                                                  .notifier,
                                            )
                                            .state =
                                        null;
                                  }
                                },
                                icon: Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: c.danger,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _addVehicle,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(color: c.borderStrong),
              ),
              child: const Text('+ Add New Vehicle'),
            ),
          ],
        ),
      ),
    );
  }
}
