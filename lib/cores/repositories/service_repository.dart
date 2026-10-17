import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/service_model.dart';

/// Repository managing roadside repair services catalog.
/// Fetches active services from Supabase 'services' table (e.g. Engine Repair, Towing).
/// Used by customer screens during service selection and request creation.
class ServiceRepository {
  final SupabaseClient client;
  ServiceRepository(this.client);

  /// Queries all active services from Supabase 'services' table where is_active is true.
  /// Deduplicates service entries by lowercase title to prevent duplicate tiles.
  /// Returns a sorted list of strongly-typed ServiceItem models for UI rendering.
  Future<List<ServiceItem>> getServices() async {
    final rows = await client
        .from('services')
        .select()
        .eq('is_active', true)
        .order('title');
    final seenTitles = <String>{};
    final services = <ServiceItem>[];

    for (final row in rows as List) {
      final service = ServiceItem.fromMap(Map<String, dynamic>.from(row));
      final key = service.title.trim().toLowerCase();
      if (key.isEmpty || !seenTitles.add(key)) continue;
      services.add(service);
    }

    return services;
  }
}
