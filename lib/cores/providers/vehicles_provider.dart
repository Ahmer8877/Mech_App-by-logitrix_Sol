import 'dart:async';

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
    // Watching the user ID clears/reloads the list when a user logs out or signs in.
    final userId = ref.watch(authProvider.select((state) => state.user?.id));
    ref.listen<String?>(authProvider.select((state) => state.user?.id), (
      previous,
      next,
    ) {
      if (previous != next) {
        // A default vehicle belongs to one account; never carry it into another.
        ref.read(selectedVehicleIdProvider.notifier).state = null;
      }
    });
    if (userId == null) return const [];
    return _loadVehicles(userId);
  }

  Future<List<Vehicle>> _loadVehicles(String userId) async {
    // Supabase auth can take a short moment to restore its session after sign-in.
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        if (supabase.auth.currentSession == null) {
          await Future<void>.delayed(
            Duration(milliseconds: 350 * (attempt + 1)),
          );
        }
        final session = supabase.auth.currentSession;
        if (session == null || session.user.id != userId) {
          if (attempt < 2) continue;
          throw StateError(
            'Your session has not finished loading. Please try again.',
          );
        }
        return await _repository.getMyVehicles(userId);
      } catch (_) {
        if (attempt == 2) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
      }
    }
    return const [];
  }

  /// Explicit refresh keeps errors visible so the screen can offer a real retry.
  Future<void> refresh() async {
    final userId = ref.read(authProvider).user?.id;
    if (userId == null) {
      state = const AsyncData<List<Vehicle>>([]);
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadVehicles(userId));
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
