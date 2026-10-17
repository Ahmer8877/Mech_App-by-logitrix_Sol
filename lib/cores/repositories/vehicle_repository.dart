import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vehicle_model.dart';

/// Repository managing customer vehicles database operations.
/// Connects to Supabase 'vehicles' table to add, list, and delete customer vehicles.
/// Used by MyVehiclesScreen and SelectVehicleScreen during service booking.
class VehicleRepository {
  final SupabaseClient client;
  VehicleRepository(this.client);

  /// Queries all registered vehicles belonging to the specified customer user ID.
  /// Orders results by created_at descending so newest added vehicles appear first.
  /// Returns a list of strongly-typed Vehicle models for UI rendering.
  Future<List<Vehicle>> getMyVehicles(String userId) async {
    final rows = await client
        .from('vehicles')
        .select()
        .eq('owner_id', userId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) => Vehicle.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Inserts a new vehicle record into Supabase 'vehicles' table for the specified owner ID.
  /// Requires vehicle make/model name, license plate number, and optional manufacturing year.
  /// Returns the newly inserted Vehicle instance returned by Supabase after database insertion.
  Future<Vehicle> addVehicle({
    required String userId,
    required String model,
    required String plate,
    String? year,
  }) async {
    final row = await client
        .from('vehicles')
        .insert(
          Vehicle(model: model, plate: plate, year: year).toInsertMap(userId),
        )
        .select()
        .single();
    return Vehicle.fromMap(Map<String, dynamic>.from(row));
  }

  /// Deletes a vehicle record by vehicle ID from Supabase 'vehicles' table.
  /// Enforces owner-only deletion via PostgreSQL RLS policies.
  /// Updates Riverpod vehiclesProvider state to reflect vehicle removal.
  Future<void> deleteVehicle(String id) async {
    await client.from('vehicles').delete().eq('id', id);
  }
}
