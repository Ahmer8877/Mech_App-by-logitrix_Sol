import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/supabase_config.dart';
import '../models/vehicle_model.dart';
import '../repositories/vehicle_repository.dart';
import 'auth_provider.dart';

final vehicleRepositoryProvider = Provider<VehicleRepository>(
  (ref) => VehicleRepository(supabase),
);

class VehiclesNotifier extends AsyncNotifier<List<Vehicle>> {
  late final VehicleRepository _repository;

  @override
  Future<List<Vehicle>> build() async {
    _repository = ref.read(vehicleRepositoryProvider);
    final userId = ref.watch(authProvider.select((state) => state.user?.id));
    if (userId == null) return const [];

    // Ensure Supabase auth session is fully established on login
    if (supabase.auth.currentSession == null) {
      await Future.delayed(const Duration(milliseconds: 500));
    }

    try {
      final list = await _repository.getMyVehicles(userId);
      if (list.isNotEmpty) return list;
    } catch (_) {}

    // Retry once if initial fetch returned empty or failed due to session sync lag on re-login
    await Future.delayed(const Duration(milliseconds: 800));
    try {
      return await _repository.getMyVehicles(userId);
    } catch (_) {
      return const [];
    }
  }

  Future<bool> addVehicle(String model, String plate, {String? year}) async {
    final userId = ref.read(authProvider).user?.id;
    if (userId == null) return false;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repository.addVehicle(
        userId: userId,
        model: model,
        plate: plate,
        year: year,
      );
      return _repository.getMyVehicles(userId);
    });
    return !state.hasError;
  }

  Future<bool> removeVehicle(String id) async {
    if (id.isEmpty) return false;
    final userId = ref.read(authProvider).user?.id;
    if (userId == null) return false;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repository.deleteVehicle(id);
      return _repository.getMyVehicles(userId);
    });
    return !state.hasError;
  }
}

final vehiclesProvider = AsyncNotifierProvider<VehiclesNotifier, List<Vehicle>>(
  VehiclesNotifier.new,
);
final selectedVehicleIdProvider = StateProvider<String?>((ref) => null);
