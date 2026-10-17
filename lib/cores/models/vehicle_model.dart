class Vehicle {
  final String id;
  final String model;
  final String plate;
  final String? year;

  const Vehicle({
    this.id = '',
    required this.model,
    required this.plate,
    this.year,
  });

  factory Vehicle.fromMap(Map<String, dynamic> map) {
    return Vehicle(
      id: map['id']?.toString() ?? '',
      model: map['make_model']?.toString() ?? '',
      plate: map['license_plate']?.toString() ?? '',
      year: map['year']?.toString(),
    );
  }

  Map<String, dynamic> toInsertMap(String ownerId) => {
    'owner_id': ownerId,
    'make_model': model.trim(),
    'license_plate': plate.trim().toUpperCase(),
    if (year != null && year!.trim().isNotEmpty) 'year': year!.trim(),
  };
}
