import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../config/supabase_config.dart';
import '../models/user_profile_model.dart';
import '../models/user_role.dart';

/// Provider for tracking currently selected role during role selection / signup
final selectedRoleProvider = StateProvider<UserRole>(
  (ref) => UserRole.customer,
);

/// Real-time stream provider watching active user profile changes (is_verified, status, rating, avatar)
final activeProfileStreamProvider =
    StreamProvider.family<UserProfile?, String>((ref, userId) {
  if (userId.isEmpty) return Stream.value(null);

  return supabase
      .from('profiles')
      .stream(primaryKey: ['id'])
      .eq('id', userId)
      .handleError((e) {
        debugPrint('Active profile stream error: $e');
      })
      .map((rows) {
        if (rows.isEmpty) return null;
        return UserProfile.fromMap(Map<String, dynamic>.from(rows.first));
      });
});

/// Riverpod StateNotifier for managing Authentication state & user profile fetching
class AuthNotifier extends StateNotifier<AppAuthState> {
  static UserRole targetRole = UserRole.customer;
  StreamSubscription<List<Map<String, dynamic>>>? _profileSubscription;

  AuthNotifier()
    : super(AppAuthState(user: Supabase.instance.client.auth.currentUser)) {
    _initUser();
  }

  void setTargetRole(UserRole role) {
    targetRole = role;
    state = state.copyWith(role: role, errorMessage: null);
  }

  void _listenToProfileChanges(String userId) {
    _profileSubscription?.cancel();
    _profileSubscription = supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .handleError((e) {
          debugPrint('Profiles realtime stream error: $e');
        })
        .listen((rows) {
          if (rows.isNotEmpty) {
            final updatedProfile = UserProfile.fromMap(
              Map<String, dynamic>.from(rows.first),
            );
            state = state.copyWith(
              profile: updatedProfile,
              role: updatedProfile.role,
            );
          }
        }, onError: (e) {
          debugPrint('Profiles stream listen error: $e');
        });
  }

  Future<void> _initUser() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      await fetchUserProfile(user.id);
      _listenToProfileChanges(user.id);
    }

    supabase.auth.onAuthStateChange.listen((data) async {
      final user = data.session?.user;
      if (user == null) {
        _profileSubscription?.cancel();
        return;
      }

      _listenToProfileChanges(user.id);

      final existing = await _loadProfile(user.id);
      final createdAt = DateTime.tryParse(user.createdAt);
      final isNewAuthUser = createdAt != null &&
          DateTime.now().difference(createdAt).abs() <
              const Duration(minutes: 5);
      final requestedRole = targetRole;

      // Supabase's profile trigger creates OAuth profiles before the client
      // receives the auth callback. Only a genuinely new OAuth account may
      // inherit the role selected on the login screen. Existing accounts keep
      // their database role and are never silently converted between portals.
      if (existing == null) {
        await supabase.from('profiles').upsert({
          'id': user.id,
          'full_name':
              user.userMetadata?['full_name'] ??
              user.userMetadata?['name'] ??
              user.email?.split('@').first ??
              'User',
          'email': user.email ?? '',
          'phone_number': user.userMetadata?['phone_number'] ?? user.phone ?? '',
          'role': requestedRole.name,
          'avatar_url':
              user.userMetadata?['avatar_url'] ?? user.userMetadata?['picture'],
          'is_verified': requestedRole == UserRole.customer,
          'verification_status':
              requestedRole == UserRole.customer ? 'approved' : 'pending',
        });
      } else if (isNewAuthUser && existing['role'] != 'admin') {
        // The OAuth trigger creates the profile first. Role/verification fields
        // are server-controlled, so a new mechanic is prepared through the
        // SECURITY DEFINER RPC instead of a client-side role update.
        if (requestedRole == UserRole.mechanic) {
          await supabase.rpc('prepare_new_social_mechanic');
        }
      }

      await fetchUserProfile(user.id);
    });
  }

  Future<Map<String, dynamic>?> _loadProfile(String userId) async {
    try {
      return await supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
    } on PostgrestException catch (pe) {
      if (pe.message.contains('JWT issued at future') ||
          pe.code == 'PGRST303' ||
          pe.code == '401') {
        await Future.delayed(const Duration(seconds: 2));
        try {
          return await supabase
              .from('profiles')
              .select()
              .eq('id', userId)
              .maybeSingle();
        } catch (_) {}
      }
    } catch (_) {}
    return null;
  }

  Future<bool> fetchUserProfile(String userId) async {
    try {
      final response = await _loadProfile(userId);
      final currentUser = supabase.auth.currentUser ?? state.user;

      if (response == null) {
        state = state.copyWith(
          user: currentUser,
          isLoading: false,
          errorMessage: 'Your profile could not be loaded.',
        );
        return false;
      }

      final profile = UserProfile.fromMap(response);

      String fullName = profile.fullName;
      if ((fullName == 'User' || fullName.trim().isEmpty) &&
          currentUser != null) {
        fullName =
            currentUser.userMetadata?['full_name'] ??
            currentUser.userMetadata?['name'] ??
            currentUser.email?.split('@').first ??
            'User';
      }

      String phone = profile.phone;
      if (phone.trim().isEmpty && currentUser != null) {
        phone =
            currentUser.userMetadata?['phone_number'] ??
            currentUser.phone ??
            '';
      }

      final enrichedProfile = UserProfile(
        id: profile.id,
        fullName: fullName,
        email: profile.email.isNotEmpty
            ? profile.email
            : (currentUser?.email ?? ''),
        phone: phone,
        role: profile.role,
        avatarUrl: profile.avatarUrl,
        cnic: profile.cnic,
        cnicFrontUrl: profile.cnicFrontUrl,
        cnicBackUrl: profile.cnicBackUrl,
        workshopToolsUrls: profile.workshopToolsUrls,
        rating: profile.rating,
        totalJobs: profile.totalJobs,
        isVerified: profile.isVerified,
        verificationStatus: profile.verificationStatus,
        verificationNotes: profile.verificationNotes,
      );

      state = state.copyWith(
        user: currentUser,
        profile: enrichedProfile,
        role: enrichedProfile.role,
        isLoading: false,
        errorMessage: null,
      );
      return true;
    } catch (e) {
      debugPrint('Fetch user profile error: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Could not load your profile. Please try again.',
      );
      return false;
    }
  }

  Future<String?> uploadAvatar(XFile imageFile) async {
    state = state.copyWith(isLoading: true);
    try {
      final userId = state.user?.id ?? 'user';
      final fileBytes = await imageFile.readAsBytes();
      final fileExt = imageFile.name.split('.').last;
      final fileName =
          '$userId-${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await supabase.storage
          .from('avatars')
          .uploadBinary(
            fileName,
            fileBytes,
            fileOptions: FileOptions(
              contentType: 'image/$fileExt',
              upsert: true,
            ),
          );

      final imageUrl = supabase.storage.from('avatars').getPublicUrl(fileName);

      if (userId != 'user') {
        await supabase
            .from('profiles')
            .update({'avatar_url': imageUrl})
            .eq('id', userId);
      }

      final updatedProfile = UserProfile(
        id: state.profile?.id ?? userId,
        fullName: state.profile?.fullName ?? 'User',
        email: state.profile?.email ?? '',
        phone: state.profile?.phone ?? '',
        role: state.profile?.role ?? targetRole,
        avatarUrl: imageUrl,
        cnic: state.profile?.cnic,
        cnicFrontUrl: state.profile?.cnicFrontUrl,
        cnicBackUrl: state.profile?.cnicBackUrl,
        workshopToolsUrls: state.profile?.workshopToolsUrls ?? const [],
        rating: state.profile?.rating ?? 0.0,
        totalJobs: state.profile?.totalJobs ?? 0,
        isVerified: state.profile?.isVerified ?? false,
        verificationStatus: state.profile?.verificationStatus ?? 'pending',
        verificationNotes: state.profile?.verificationNotes,
      );

      state = state.copyWith(isLoading: false, profile: updatedProfile);
      return imageUrl;
    } catch (e) {
      debugPrint('Avatar upload error: $e');
      state = state.copyWith(isLoading: false);
      return null;
    }
  }

  Future<bool> submitMechanicVerification({
    required String phoneNumber,
    required String cnicNumber,
    required XFile cnicFront,
    required XFile cnicBack,
    required List<XFile> toolsPhotos,
    XFile? profilePhoto,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final userId = state.user?.id;
      if (userId == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'User session not found. Please log in again.',
        );
        return false;
      }

      final storageBucket = supabase.storage.from('avatars');

      // 1. Upload Profile Photo if provided
      String? avatarUrl = state.profile?.avatarUrl;
      if (profilePhoto != null) {
        final bytes = await profilePhoto.readAsBytes();
        final ext = profilePhoto.name.split('.').last;
        final name =
            '$userId-avatar-${DateTime.now().millisecondsSinceEpoch}.$ext';
        await storageBucket.uploadBinary(
          name,
          bytes,
          fileOptions: FileOptions(
            contentType: 'image/$ext',
            upsert: true,
          ),
        );
        avatarUrl = storageBucket.getPublicUrl(name);
      }

      // 2. Upload CNIC Front Photo
      final frontBytes = await cnicFront.readAsBytes();
      final frontExt = cnicFront.name.split('.').last;
      final frontName =
          'docs/$userId-cnic-front-${DateTime.now().millisecondsSinceEpoch}.$frontExt';
      await storageBucket.uploadBinary(
        frontName,
        frontBytes,
        fileOptions: FileOptions(
          contentType: 'image/$frontExt',
          upsert: true,
        ),
      );
      final cnicFrontUrl = storageBucket.getPublicUrl(frontName);

      // 3. Upload CNIC Back Photo
      final backBytes = await cnicBack.readAsBytes();
      final backExt = cnicBack.name.split('.').last;
      final backName =
          'docs/$userId-cnic-back-${DateTime.now().millisecondsSinceEpoch}.$backExt';
      await storageBucket.uploadBinary(
        backName,
        backBytes,
        fileOptions: FileOptions(
          contentType: 'image/$frontExt',
          upsert: true,
        ),
      );
      final cnicBackUrl = storageBucket.getPublicUrl(backName);

      // 4. Upload Workshop / Tools Photos
      final List<String> toolsUrls = [];
      for (int i = 0; i < toolsPhotos.length; i++) {
        final tFile = toolsPhotos[i];
        final tBytes = await tFile.readAsBytes();
        final tExt = tFile.name.split('.').last;
        final tName =
            'docs/$userId-tool-$i-${DateTime.now().millisecondsSinceEpoch}.$tExt';
        await storageBucket.uploadBinary(
          tName,
          tBytes,
          fileOptions: FileOptions(
            contentType: 'image/$tExt',
            upsert: true,
          ),
        );
        toolsUrls.add(storageBucket.getPublicUrl(tName));
      }

      // 5. Save verification data. The account must already be a mechanic;
      // role is controlled by the server-side social/email signup flow.
      final currentProfile = await _loadProfile(userId);
      if (currentProfile == null || currentProfile['role'] != 'mechanic') {
        throw Exception('Mechanic role is not prepared for this account. Please log in again from the Mechanic portal.');
      }

      await supabase.from('profiles').update({
        'phone_number': phoneNumber.trim(),
        'cnic_number': cnicNumber.trim(),
        'cnic': cnicNumber.trim(),
        'cnic_front_url': cnicFrontUrl,
        'cnic_back_url': cnicBackUrl,
        'workshop_tools_urls': toolsUrls,
        'avatar_url': avatarUrl,
        'is_verified': false,
        'verification_status': 'pending',
        'verification_notes': null,
      }).eq('id', userId);

      await fetchUserProfile(userId);
      state = state.copyWith(isLoading: false, errorMessage: null);
      return true;
    } catch (e) {
      debugPrint('Submit mechanic verification error: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage:
            'Upload error ($e). Please check internet connection and try again.',
      );
      return false;
    }
  }

  Future<bool> updateProfile({
    required String fullName,
    required String phone,
    required String email,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final userId = state.user?.id;
      if (userId != null) {
        await supabase
            .from('profiles')
            .update({
              'full_name': fullName.trim(),
              'phone_number': phone.trim(),
              'email': email.trim(),
            })
            .eq('id', userId);
      }

      final updatedProfile = UserProfile(
        id: state.profile?.id ?? userId ?? 'user',
        fullName: fullName.trim(),
        email: email.trim(),
        phone: phone.trim(),
        role: state.profile?.role ?? targetRole,
        avatarUrl: state.profile?.avatarUrl,
        cnic: state.profile?.cnic,
        cnicFrontUrl: state.profile?.cnicFrontUrl,
        cnicBackUrl: state.profile?.cnicBackUrl,
        workshopToolsUrls: state.profile?.workshopToolsUrls ?? const [],
        rating: state.profile?.rating ?? 0.0,
        totalJobs: state.profile?.totalJobs ?? 0,
        isVerified: state.profile?.isVerified ?? false,
        verificationStatus: state.profile?.verificationStatus ?? 'pending',
        verificationNotes: state.profile?.verificationNotes,
      );

      state = state.copyWith(isLoading: false, profile: updatedProfile);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to update profile',
      );
      return false;
    }
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await supabase.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: kIsWeb ? null : 'io.supabase.mechapp://reset-password/',
      );
      state = state.copyWith(isLoading: false);
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to send password reset email.',
      );
      return false;
    }
  }

  Future<bool> loginWithEmail(
    String email,
    String password,
    UserRole targetRole,
  ) async {
    setTargetRole(targetRole);
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      role: targetRole,
    );
    try {
      final response = await supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      final user = response.user;
      if (user != null) {
        _listenToProfileChanges(user.id);
        final profileResponse = await supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();

        if (profileResponse != null) {
          final profile = UserProfile.fromMap(profileResponse);

          // If role doesn't match portal, update profile role to match targetRole instead of signing out
          if (profile.role != targetRole) {
            final bool isAlreadyVerified = targetRole == UserRole.mechanic &&
                profile.isVerified &&
                profile.cnicFrontUrl != null &&
                profile.cnicFrontUrl!.isNotEmpty;

            await supabase.from('profiles').update({
              'role': targetRole.name,
              'is_verified': isAlreadyVerified,
              'verification_status':
                  isAlreadyVerified ? 'approved' : 'pending',
            }).eq('id', user.id);

            final updatedProfile = UserProfile(
              id: profile.id,
              fullName: profile.fullName,
              email: profile.email,
              phone: profile.phone,
              role: targetRole,
              avatarUrl: profile.avatarUrl,
              cnic: profile.cnic,
              cnicFrontUrl: profile.cnicFrontUrl,
              cnicBackUrl: profile.cnicBackUrl,
              workshopToolsUrls: profile.workshopToolsUrls,
              rating: profile.rating,
              totalJobs: profile.totalJobs,
              isVerified: isAlreadyVerified,
              verificationStatus:
                  isAlreadyVerified ? 'approved' : 'pending',
              verificationNotes: profile.verificationNotes,
            );

            state = state.copyWith(
              isLoading: false,
              user: user,
              profile: updatedProfile,
              role: targetRole,
            );
            return true;
          }

          state = state.copyWith(
            isLoading: false,
            user: user,
            profile: profile,
            role: profile.role,
          );
          return true;
        }
      }
      state = state.copyWith(isLoading: false);
      return false;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Authentication failed. Please check your credentials.',
      );
      return false;
    }
  }

  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required UserRole role,
    String? cnic,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await supabase.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'full_name': fullName.trim(),
          'phone_number': phone.trim(),
          'role': role.name,
          'cnic_number': cnic?.trim(),
        },
      );

      final user = response.user;
      if (user != null) {
        _listenToProfileChanges(user.id);
        final newProfile = UserProfile(
          id: user.id,
          fullName: fullName.trim(),
          email: email.trim(),
          phone: phone.trim(),
          role: role,
          cnic: cnic?.trim(),
        );

        try {
          await supabase.from('profiles').upsert({
            'id': user.id,
            'full_name': fullName.trim(),
            'email': email.trim(),
            'phone_number': phone.trim(),
            'role': role.name,
            'cnic_number': cnic?.trim(),
          });
        } catch (_) {}

        state = state.copyWith(
          isLoading: false,
          user: user,
          profile: newProfile,
          role: role,
        );
        return true;
      }
      state = state.copyWith(isLoading: false);
      return false;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Signup failed. Please try again.',
      );
      return false;
    }
  }

  Future<bool> _handlePostSocialAuth(User user, UserRole role) async {
    try {
      _listenToProfileChanges(user.id);

      final socialAvatar =
          user.userMetadata?['avatar_url'] ?? user.userMetadata?['picture'];
      final fullName =
          user.userMetadata?['full_name'] ??
          user.userMetadata?['name'] ??
          user.email?.split('@').first ??
          'User';
      final phone = user.userMetadata?['phone_number'] ?? user.phone ?? '';

      final response = await _loadProfile(user.id);
      final createdAt = DateTime.tryParse(user.createdAt);
      final isNewAuthUser = createdAt != null &&
          DateTime.now().difference(createdAt).abs() <
              const Duration(minutes: 5);

      if (response != null) {
        var profile = UserProfile.fromMap(response);

        // The profiles trigger protects role/is_verified from direct client
        // updates. For a genuinely new social account, use the controlled
        // SECURITY DEFINER RPC to assign the selected mechanic role. Existing
        // accounts keep their database role and verification state.
        if (isNewAuthUser && role == UserRole.mechanic) {
          await supabase.rpc('prepare_new_social_mechanic');
          final refreshed = await _loadProfile(user.id);
          if (refreshed != null) {
            profile = UserProfile.fromMap(refreshed);
          }
        }

        final effectiveRole = profile.role;
        final effectiveVerified = profile.isVerified;
        final effectiveStatus = profile.verificationStatus;

        await supabase.from('profiles').update({
          'full_name': profile.fullName == 'User' ? fullName : profile.fullName,
          'phone_number': profile.phone.isNotEmpty ? profile.phone : phone,
          'avatar_url': socialAvatar ?? profile.avatarUrl,
        }).eq('id', user.id);

        final updatedProfile = UserProfile(
          id: profile.id,
          fullName: profile.fullName != 'User' ? profile.fullName : fullName,
          email: profile.email.isNotEmpty ? profile.email : (user.email ?? ''),
          phone: profile.phone.isNotEmpty ? profile.phone : phone,
          role: effectiveRole,
          avatarUrl: profile.avatarUrl ?? socialAvatar,
          cnic: profile.cnic,
          cnicFrontUrl: profile.cnicFrontUrl,
          cnicBackUrl: profile.cnicBackUrl,
          workshopToolsUrls: profile.workshopToolsUrls,
          rating: profile.rating,
          totalJobs: profile.totalJobs,
          isVerified: effectiveVerified,
          verificationStatus: effectiveStatus,
          verificationNotes: profile.verificationNotes,
        );

        state = state.copyWith(
          isLoading: false,
          user: user,
          profile: updatedProfile,
          role: effectiveRole,
          errorMessage: null,
        );
        return true;
      }

      final newProfile = UserProfile(
        id: user.id,
        fullName: fullName,
        email: user.email ?? '',
        phone: phone,
        role: role,
        avatarUrl: socialAvatar,
        isVerified: role == UserRole.customer,
        verificationStatus: role == UserRole.customer ? 'approved' : 'pending',
      );

      await supabase.from('profiles').upsert({
        'id': user.id,
        'full_name': newProfile.fullName,
        'email': newProfile.email,
        'phone_number': newProfile.phone,
        'role': role.name,
        'avatar_url': socialAvatar,
        'is_verified': newProfile.isVerified,
        'verification_status': newProfile.verificationStatus,
      });

      state = state.copyWith(
        isLoading: false,
        user: user,
        profile: newProfile,
        role: role,
        errorMessage: null,
      );
      return true;
    } catch (e) {
      debugPrint('Post social auth error: $e');
      state = state.copyWith(
        isLoading: false,
        user: user,
        role: role,
        errorMessage: 'Could not finish social sign-in. Please try again.',
      );
      return false;
    }
  }

  Future<bool> loginWithGoogle(UserRole role) async {
    setTargetRole(role);
    try {
      if (!kIsWeb) {
        final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'];
        final GoogleSignIn googleSignIn = GoogleSignIn(
          scopes: ['email', 'profile'],
          serverClientId: webClientId,
        );

        try {
          await googleSignIn.signOut();
          await googleSignIn.disconnect();
        } catch (_) {}

        final googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          state = state.copyWith(isLoading: false);
          return false;
        }

        final googleAuth = await googleUser.authentication;
        final idToken = googleAuth.idToken;
        final accessToken = googleAuth.accessToken;

        if (idToken != null) {
          final response = await supabase.auth.signInWithIdToken(
            provider: OAuthProvider.google,
            idToken: idToken,
            accessToken: accessToken,
          );
          if (response.user != null) {
            return await _handlePostSocialAuth(response.user!, role);
          }
        }

        await supabase.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: kIsWeb ? null : 'io.supabase.mechapp://login-callback/',
          queryParams: {'role': role.name},
        );
        state = state.copyWith(isLoading: false);
        return true;
      }

      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        queryParams: {'role': role.name},
      );
      state = state.copyWith(isLoading: false);
      return true;
    } on AuthException catch (e) {
      String msg = e.message;
      if (msg.contains('missing OAuth secret') ||
          msg.contains('Unsupported provider')) {
        msg =
            'Google Sign-In is disabled in Supabase. Please configure Google Client ID & Secret in Supabase Dashboard.';
      }
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Google sign-in failed.',
      );
      return false;
    }
  }

  Future<bool> loginWithFacebook(UserRole role) async {
    setTargetRole(role);
    try {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.facebook,
        redirectTo: kIsWeb ? null : 'io.supabase.mechapp://login-callback/',
        queryParams: {'role': role.name},
      );
      state = state.copyWith(isLoading: false);
      return true;
    } on AuthException catch (e) {
      String msg = e.message;
      if (msg.contains('missing OAuth secret') ||
          msg.contains('Unsupported provider')) {
        msg =
            'Facebook Sign-In is disabled in Supabase. Please add Facebook Client ID & Secret in Supabase Dashboard.';
      }
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Facebook sign-in failed.',
      );
      return false;
    }
  }

  Future<void> logout() async {
    _profileSubscription?.cancel();
    state = state.copyWith(isLoading: true);
    try {
      await supabase.auth.signOut();
    } catch (_) {}
    state = const AppAuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AppAuthState>((ref) {
  return AuthNotifier();
});

/// Current User Profile Provider
final currentUserProfileProvider = Provider<UserProfile>((ref) {
  final authState = ref.watch(authProvider);
  if (authState.profile != null) {
    return authState.profile!;
  }
  final user = authState.user;
  if (user != null) {
    final metaName =
        user.userMetadata?['full_name'] ??
        user.userMetadata?['name'] ??
        user.email?.split('@').first ??
        'User';
    final metaPhone = user.userMetadata?['phone_number'] ?? user.phone ?? '';
    return UserProfile(
      id: user.id,
      fullName: metaName.isNotEmpty ? metaName : 'User',
      email: user.email ?? '',
      phone: metaPhone,
      role: authState.role,
    );
  }
  return UserProfile(
    id: 'guest',
    fullName: 'User',
    email: '',
    phone: '',
    role: authState.role,
  );
});
