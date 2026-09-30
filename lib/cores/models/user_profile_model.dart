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
  final String? cnicFrontUrl;
  final String? cnicBackUrl;
  final List<String> workshopToolsUrls;
  final double rating;
  final int totalJobs;
  final bool isVerified;
  final String verificationStatus; // 'pending' | 'approved' | 'rejected'
  final String? verificationNotes;

  const UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    this.avatarUrl,
    this.cnic,
    this.cnicFrontUrl,
    this.cnicBackUrl,
    this.workshopToolsUrls = const [],
    this.rating = 0.0,
    this.totalJobs = 0,
    this.isVerified = false,
    this.verificationStatus = 'pending',
    this.verificationNotes,
  });

  bool get isVerificationSubmitted =>
      (cnicFrontUrl != null && cnicFrontUrl!.isNotEmpty) &&
      (cnicBackUrl != null && cnicBackUrl!.isNotEmpty);

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    final rawTools = map['workshop_tools_urls'];
    List<String> tools = [];
    if (rawTools is List) {
      tools = rawTools.map((e) => e.toString()).toList();
    }

    final rawStatus = map['verification_status']?.toString().trim();
    final status = (rawStatus == 'approved' || rawStatus == 'rejected' || rawStatus == 'pending')
        ? rawStatus!
        : (map['is_verified'] == true ? 'approved' : 'pending');
    final isVerifiedBool = map['is_verified'] == true || status == 'approved';

    return UserProfile(
      id: map['id'] ?? '',
      fullName: map['full_name'] ?? 'User',
      email: map['email'] ?? '',
      phone: map['phone_number'] ?? '',
      role: map['role'] == 'mechanic' ? UserRole.mechanic : UserRole.customer,
      avatarUrl: map['avatar_url'],
      cnic: map['cnic_number'],
      cnicFrontUrl: map['cnic_front_url'],
      cnicBackUrl: map['cnic_back_url'],
      workshopToolsUrls: tools,
      rating: map['role'] == 'mechanic'
          ? (map['rating'] as num?)?.toDouble() ?? 0.0
          : 0.0,
      totalJobs: map['total_jobs'] ?? 0,
      isVerified: isVerifiedBool,
      verificationStatus: status,
      verificationNotes: map['verification_notes']?.toString(),
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

  static const Object _unset = Object();

  AppAuthState copyWith({
    bool? isLoading,
    User? user,
    UserProfile? profile,
    UserRole? role,
    Object? errorMessage = _unset,
  }) {
    return AppAuthState(
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      profile: profile ?? this.profile,
      role: role ?? this.role,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}
