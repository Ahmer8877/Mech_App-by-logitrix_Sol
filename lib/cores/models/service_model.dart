import 'package:flutter/material.dart';

class ServiceItem {
  final String id;
  final IconData icon;
  final String title;
  final String description;
  final double basePrice;
  final bool isActive;

  const ServiceItem({
    this.id = '',
    required this.icon,
    required this.title,
    required this.description,
    this.basePrice = 0,
    this.isActive = true,
  });

  factory ServiceItem.fromMap(Map<String, dynamic> map) {
    return ServiceItem(
      id: map['id']?.toString() ?? '',
      icon: iconFromName(map['icon_name']?.toString()),
      title: map['title']?.toString() ?? 'Service',
      description: map['description']?.toString() ?? '',
      basePrice: (map['base_price'] as num?)?.toDouble() ?? 0,
      isActive: map['is_active'] as bool? ?? true,
    );
  }

  static IconData iconFromName(String? name) {
    switch (name) {
      case 'settings_outlined':
        return Icons.settings_outlined;
      case 'battery_charging_full_outlined':
        return Icons.battery_charging_full_outlined;
      case 'ac_unit_outlined':
        return Icons.ac_unit_outlined;
      case 'tire_repair_outlined':
        return Icons.tire_repair_outlined;
      case 'local_shipping_outlined':
        return Icons.local_shipping_outlined;
      case 'opacity_outlined':
        return Icons.opacity_outlined;
      case 'electrical_services_outlined':
        return Icons.electrical_services_outlined;
      case 'car_repair_outlined':
        return Icons.car_repair_outlined;
      case 'local_gas_station_outlined':
        return Icons.local_gas_station_outlined;
      case 'key_outlined':
        return Icons.key_outlined;
      default:
        return Icons.build_circle_outlined;
    }
  }
}
