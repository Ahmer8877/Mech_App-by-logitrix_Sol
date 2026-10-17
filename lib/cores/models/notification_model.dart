import 'package:flutter/material.dart';

class NotificationModel {
  final String id;
  final IconData icon;
  final String title;
  final String subtitle;
  final DateTime? createdAt;
  final bool unread;

  String get time {
    final value = createdAt;
    if (value == null) return '';
    final now = DateTime.now();
    final difference = now.difference(value);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${value.day}/${value.month}/${value.year}';
  }

  const NotificationModel({
    this.id = '',
    required this.icon,
    required this.title,
    required this.subtitle,
    this.createdAt,
    this.unread = false,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id']?.toString() ?? '',
      icon: _iconFromName(map['icon_name']?.toString()),
      title: map['title']?.toString() ?? 'Notification',
      subtitle: map['subtitle']?.toString() ?? '',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
      unread: !(map['is_read'] as bool? ?? false),
    );
  }

  static IconData _iconFromName(String? name) {
    switch (name) {
      case 'check_circle_outline':
        return Icons.check_circle_outline;
      case 'payments_outlined':
        return Icons.payments_outlined;
      case 'campaign_outlined':
        return Icons.campaign_outlined;
      case 'directions_car_outlined':
        return Icons.directions_car_outlined;
      case 'chat_bubble_outline':
        return Icons.chat_bubble_outline;
      default:
        return Icons.notifications_outlined;
    }
  }
}
