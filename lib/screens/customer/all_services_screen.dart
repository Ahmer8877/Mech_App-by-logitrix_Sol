import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../cores/models/service_model.dart';
import '../../cores/providers/services_provider.dart';
import '../../widgets/app_atoms.dart';
import '../../widgets/step_progress.dart';

class AllServicesScreen extends ConsumerWidget {
  const AllServicesScreen({super.key});

  static const List<ServiceItem> _additionalStaticServices = [
    ServiceItem(
      id: 'static_fuel',
      title: 'Fuel Delivery',
      description: 'Emergency petrol/diesel delivery',
      icon: Icons.local_gas_station_outlined,
    ),
    ServiceItem(
      id: 'static_locksmith',
      title: 'Car Locksmith',
      description: 'Key unlock & door lockout service',
      icon: Icons.key_outlined,
    ),
    ServiceItem(
      id: 'static_oil',
      title: 'Oil Change',
      description: 'Engine oil & filter replacement',
      icon: Icons.opacity_outlined,
    ),
    ServiceItem(
      id: 'static_brake',
      title: 'Brake Repair',
      description: 'Brake pad & disc check',
      icon: Icons.car_repair_outlined,
    ),
    ServiceItem(
      id: 'static_alignment',
      title: 'Wheel Alignment',
      description: 'Tyre balancing & alignment',
      icon: Icons.tire_repair_outlined,
    ),
    ServiceItem(
      id: 'static_electrical',
      title: 'Electrical Check',
      description: 'Wiring & fuse box diagnostics',
      icon: Icons.electrical_services_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(servicesProvider);

    return Scaffold(
      appBar: const FlowAppBar(title: 'All Services'),
      body: servicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Failed to load services.'),
              TextButton(
                onPressed: () => ref.invalidate(servicesProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (fetchedServices) {
          final Map<String, ServiceItem> allMap = {};
          for (final s in fetchedServices) {
            allMap[s.title.toLowerCase()] = s;
          }
          for (final s in _additionalStaticServices) {
            allMap.putIfAbsent(s.title.toLowerCase(), () => s);
          }
          final displayList = allMap.values.toList();

          return Padding(
            padding: const EdgeInsets.all(18),
            child: GridView.builder(
              itemCount: displayList.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.05,
              ),
              itemBuilder: (context, i) {
                final service = displayList[i];
                return ServiceTile(
                  icon: service.icon,
                  label: service.title,
                  onTap: null, // Purely static display tile
                );
              },
            ),
          );
        },
      ),
    );
  }
}
