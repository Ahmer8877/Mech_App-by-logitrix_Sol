import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_role.dart';

/// User Profile Model corresponding to Supabase `profiles` table
class UserProfile {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final UserRole role;
  final String? avatarUrl;
  final String? cnic;
  final double rating;
  final int totalJobs;
  final bool isVerified;

  const UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    this.avatarUrl,
    this.cnic,
    this.rating = 5.0,
    this.totalJobs = 0,
    this.isVerified = false,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] ?? '',
      fullName: map['full_name'] ?? 'User',
      email: map['email'] ?? '',
      phone: map['phone_number'] ?? '',
      role: map['role'] == 'mechanic' ? UserRole.mechanic : UserRole.customer,
      avatarUrl: map['avatar_url'],
      cnic: map['cnic_number'],
      // `rating` belongs to mechanics. Customer profiles must not inherit
      // the mechanics' default 5.0 rating from the database.
      rating: map['role'] == 'mechanic'
          ? (map['rating'] as num?)?.toDouble() ?? 5.0
          : 0.0,
      totalJobs: map['total_jobs'] ?? 0,
      isVerified: map['is_verified'] ?? false,
    );
  }

  String get initials {
    final names = fullName.trim().split(' ');
    if (names.length >= 2) {
      return '${names[0][0]}${names[1][0]}'.toUpperCase();
    } else if (names.isNotEmpty && names[0].isNotEmpty) {
      return names[0][0].toUpperCase();
    }
    return 'U';
  }
}

/// App Auth State Model
class AppAuthState {
  final bool isLoading;
  final User? user;
  final UserProfile? profile;
  final UserRole role;
  final String? errorMessage;

  const AppAuthState({
    this.isLoading = false,
    this.user,
    this.profile,
    this.role = UserRole.customer,
    this.errorMessage,
  });

  AppAuthState copyWith({
    bool? isLoading,
    User? user,
    UserProfile? profile,
    UserRole? role,
    String? errorMessage,
  }) {
    return AppAuthState(
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      profile: profile ?? this.profile,
      role: role ?? this.role,
      errorMessage: errorMessage,
    );
  }
}
