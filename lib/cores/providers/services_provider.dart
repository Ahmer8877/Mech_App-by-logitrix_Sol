import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/supabase_config.dart';
import '../models/service_model.dart';
import '../repositories/service_repository.dart';

final serviceRepositoryProvider = Provider<ServiceRepository>(
  (ref) => ServiceRepository(supabase),
);

final servicesProvider = FutureProvider<List<ServiceItem>>((ref) async {
  return ref.read(serviceRepositoryProvider).getServices();
});

final popularServicesProvider = Provider<List<ServiceItem>>((ref) {
  final services =
      ref.watch(servicesProvider).valueOrNull ?? const <ServiceItem>[];
  return services.take(6).toList(growable: false);
});

final allServicesProvider = Provider<List<ServiceItem>>((ref) {
  return ref.watch(servicesProvider).valueOrNull ?? const <ServiceItem>[];
});

final selectedServiceIdProvider = StateProvider<String?>((ref) => null);
