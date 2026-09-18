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
final selectedRoleProvider = StateProvider<UserRole>((ref) => UserRole.customer);

/// Riverpod StateNotifier for managing Authentication state & user profile fetching
class AuthNotifier extends StateNotifier<AppAuthState> {
  static UserRole targetRole = UserRole.customer;

  AuthNotifier()
      : super(AppAuthState(
    user: Supabase.instance.client.auth.currentUser,
  )) {
    _initUser();
  }

  void setTargetRole(UserRole role) {
    targetRole = role;
    state = state.copyWith(role: role, errorMessage: null);
  }

  Future<void> _initUser() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      await fetchUserProfile(user.id);
    }

    supabase.auth.onAuthStateChange.listen((data) async {
      final user = data.session?.user;
      if (user == null) return;

      // During a normal app restart there is no selected portal role yet.
      // The persisted database profile is the source of truth. Do not compare
      // it with targetRole here, otherwise a mechanic can be treated as a
      // customer simply because targetRole defaults to customer.
      final profileResponse = await _loadProfile(user.id);

      if (profileResponse != null) {
        final fetchedProfile = UserProfile.fromMap(profileResponse);

        // Only a genuinely new OAuth profile may inherit the role selected
        // immediately before signup. Existing accounts always keep the role
        // stored in profiles.
        bool isNewSocialSignup = false;
        final createdAtRaw = profileResponse['created_at']?.toString();
        if (createdAtRaw != null) {
          final createdAt = DateTime.tryParse(createdAtRaw);
          if (data.event.name == 'signedIn' &&
              createdAt != null &&
              DateTime.now().difference(createdAt).inSeconds.abs() < 45) {
            isNewSocialSignup = true;
          }
        }

        if (isNewSocialSignup && fetchedProfile.role != targetRole) {
          try {
            await supabase
                .from('profiles')
                .update({'role': targetRole.name})
                .eq('id', user.id);
          } catch (_) {
            // Keep the database value if the role update is rejected.
          }
        }

        final finalRole = isNewSocialSignup ? targetRole : fetchedProfile.role;
        state = state.copyWith(
          user: user,
          profile: finalRole == fetchedProfile.role
              ? fetchedProfile
              : UserProfile(
            id: fetchedProfile.id,
            fullName: fetchedProfile.fullName,
            email: fetchedProfile.email,
            phone: fetchedProfile.phone,
            role: finalRole,
            avatarUrl: fetchedProfile.avatarUrl,
            cnic: fetchedProfile.cnic,
            rating: fetchedProfile.rating,
            totalJobs: fetchedProfile.totalJobs,
            isVerified: fetchedProfile.isVerified,
          ),
          role: finalRole,
          isLoading: false,
          errorMessage: null,
        );
        return;
      }

      // Do not create or upsert a fake profile on a transient read failure.
      // That was the source of incorrect/default mechanic data on cold start.
      state = state.copyWith(
        user: user,
        isLoading: false,
        errorMessage: 'Could not load your profile. Please try again.',
      );
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
        // Never manufacture a profile from local/default role data. A missing
        // profile must be fixed server-side rather than overwriting an
        // existing mechanic account during startup.
        state = state.copyWith(
          user: currentUser,
          isLoading: false,
          errorMessage: 'Your profile could not be loaded.',
        );
        return false;
      }

      final profile = UserProfile.fromMap(response);

      String fullName = profile.fullName;
      if ((fullName == 'User' || fullName.trim().isEmpty) && currentUser != null) {
        fullName = currentUser.userMetadata?['full_name'] ??
            currentUser.userMetadata?['name'] ??
            currentUser.email?.split('@').first ??
            'User';
      }

      String phone = profile.phone;
      if (phone.trim().isEmpty && currentUser != null) {
        phone = currentUser.userMetadata?['phone_number'] ??
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
        rating: profile.rating,
        totalJobs: profile.totalJobs,
        isVerified: profile.isVerified,
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
      final fileName = '$userId-${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await supabase.storage.from('avatars').uploadBinary(
        fileName,
        fileBytes,
        fileOptions: FileOptions(contentType: 'image/$fileExt', upsert: true),
      );

      final imageUrl = supabase.storage.from('avatars').getPublicUrl(fileName);

      if (userId != 'user') {
        await supabase.from('profiles').update({'avatar_url': imageUrl}).eq('id', userId);
      }

      final updatedProfile = UserProfile(
        id: state.profile?.id ?? userId,
        fullName: state.profile?.fullName ?? 'User',
        email: state.profile?.email ?? '',
        phone: state.profile?.phone ?? '',
        role: state.profile?.role ?? targetRole,
        avatarUrl: imageUrl,
        cnic: state.profile?.cnic,
        rating: state.profile?.rating ?? 5.0,
        totalJobs: state.profile?.totalJobs ?? 0,
        isVerified: state.profile?.isVerified ?? false,
      );

      state = state.copyWith(isLoading: false, profile: updatedProfile);
      return imageUrl;
    } catch (e) {
      debugPrint('Avatar upload error: $e');
      state = state.copyWith(isLoading: false);
      return null;
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
        await supabase.from('profiles').update({
          'full_name': fullName.trim(),
          'phone_number': phone.trim(),
          'email': email.trim(),
        }).eq('id', userId);
      }

      final updatedProfile = UserProfile(
        id: state.profile?.id ?? userId ?? 'user',
        fullName: fullName.trim(),
        email: email.trim(),
        phone: phone.trim(),
        role: state.profile?.role ?? targetRole,
        avatarUrl: state.profile?.avatarUrl,
        cnic: state.profile?.cnic,
        rating: state.profile?.rating ?? 5.0,
        totalJobs: state.profile?.totalJobs ?? 0,
        isVerified: state.profile?.isVerified ?? false,
      );

      state = state.copyWith(isLoading: false, profile: updatedProfile);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Failed to update profile');
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
      state = state.copyWith(isLoading: false, errorMessage: 'Failed to send password reset email.');
      return false;
    }
  }

  Future<bool> loginWithEmail(String email, String password, UserRole targetRole) async {
    setTargetRole(targetRole);
    state = state.copyWith(isLoading: true, errorMessage: null, role: targetRole);
    try {
      final response = await supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      final user = response.user;
      if (user != null) {
        final profileResponse = await supabase.from('profiles').select().eq('id', user.id).maybeSingle();

        if (profileResponse != null) {
          final profile = UserProfile.fromMap(profileResponse);

          // STRICT ROLE CHECK ON EMAIL LOGIN:
          if (profile.role != targetRole) {
            await supabase.auth.signOut();
            final expectedRoleName = profile.role == UserRole.customer ? 'Customer' : 'Mechanic';
            final attemptedRoleName = targetRole == UserRole.customer ? 'Customer' : 'Mechanic';

            state = AppAuthState(
              isLoading: false,
              user: null,
              profile: null,
              role: targetRole,
              errorMessage: 'This account is registered as a $expectedRoleName. You cannot log into the $attemptedRoleName portal.',
            );
            return false;
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
      state = state.copyWith(isLoading: false, errorMessage: 'Authentication failed. Please check your credentials.');
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
      state = state.copyWith(isLoading: false, errorMessage: 'Signup failed. Please try again.');
      return false;
    }
  }

  Future<bool> _handlePostSocialAuth(User user, UserRole role) async {
    try {
      Map<String, dynamic>? response;
      try {
        response = await supabase.from('profiles').select().eq('id', user.id).maybeSingle();
      } on PostgrestException catch (pe) {
        if (pe.message.contains('JWT issued at future') || pe.code == 'PGRST303' || pe.code == '401') {
          await Future.delayed(const Duration(seconds: 2));
          try {
            response = await supabase.from('profiles').select().eq('id', user.id).maybeSingle();
          } catch (_) {}
        }
      } catch (_) {}

      if (response != null) {
        final profile = UserProfile.fromMap(response);

        // Check if profile was created just now (within 45 seconds -> brand new social signup)
        bool isNewSocialSignup = false;
        if (response['created_at'] != null) {
          try {
            final createdAt = DateTime.parse(response['created_at']);
            if (DateTime.now().difference(createdAt).inSeconds < 45) {
              isNewSocialSignup = true;
            }
          } catch (_) {}
        }

        if (isNewSocialSignup && profile.role != role) {
          // Brand new social signup! Update role in database
          try {
            await supabase.from('profiles').update({'role': role.name}).eq('id', user.id);
          } catch (_) {}

          final updatedProfile = UserProfile(
            id: profile.id,
            fullName: profile.fullName != 'User' ? profile.fullName : (user.userMetadata?['full_name'] ?? user.userMetadata?['name'] ?? 'User'),
            email: profile.email.isNotEmpty ? profile.email : (user.email ?? ''),
            phone: profile.phone.isNotEmpty ? profile.phone : (user.userMetadata?['phone_number'] ?? ''),
            role: role,
            avatarUrl: profile.avatarUrl,
            cnic: profile.cnic,
            rating: profile.rating,
            totalJobs: profile.totalJobs,
            isVerified: profile.isVerified,
          );

          state = state.copyWith(isLoading: false, user: user, profile: updatedProfile, role: role);
          return true;
        }

        if (profile.role != role) {
          // Mismatched role! Immediately sign out unauthorized session
          await supabase.auth.signOut();
          final expectedRole = profile.role == UserRole.customer ? 'Customer' : 'Mechanic';
          final attemptedRole = role == UserRole.customer ? 'Customer' : 'Mechanic';
          state = AppAuthState(
            isLoading: false,
            user: null,
            profile: null,
            role: role,
            errorMessage: 'This account is registered as a $expectedRole. You cannot log into the $attemptedRole portal.',
          );
          return false;
        }
        state = state.copyWith(isLoading: false, user: user, profile: profile, role: profile.role);
        return true;
      } else {
        // Create new social auth profile with role
        final newProfile = UserProfile(
          id: user.id,
          fullName: user.userMetadata?['full_name'] ?? user.userMetadata?['name'] ?? 'User',
          email: user.email ?? '',
          phone: user.userMetadata?['phone_number'] ?? '',
          role: role,
        );

        await supabase.from('profiles').upsert({
          'id': user.id,
          'full_name': newProfile.fullName,
          'email': newProfile.email,
          'role': role.name,
        });

        state = state.copyWith(isLoading: false, user: user, profile: newProfile, role: role);
        return true;
      }
    } catch (e) {
      debugPrint('Post social auth error: $e');
      state = state.copyWith(isLoading: false, user: user, role: role);
      return true;
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
        );
        state = state.copyWith(isLoading: false);
        return true;
      }

      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
      );
      state = state.copyWith(isLoading: false);
      return true;
    } on AuthException catch (e) {
      String msg = e.message;
      if (msg.contains('missing OAuth secret') || msg.contains('Unsupported provider')) {
        msg = 'Google Sign-In is disabled in Supabase. Please configure Google Client ID & Secret in Supabase Dashboard -> Authentication -> Providers -> Google.';
      }
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      state = state.copyWith(isLoading: false, errorMessage: 'Google sign-in failed.');
      return false;
    }
  }

  Future<bool> loginWithFacebook(UserRole role) async {
    setTargetRole(role);
    try {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.facebook,
        redirectTo: kIsWeb ? null : 'io.supabase.mechapp://login-callback/',
      );
      state = state.copyWith(isLoading: false);
      return true;
    } on AuthException catch (e) {
      String msg = e.message;
      if (msg.contains('missing OAuth secret') || msg.contains('Unsupported provider')) {
        msg = 'Facebook Sign-In is disabled in Supabase. Please add Facebook Client ID & Secret in Supabase Dashboard -> Authentication -> Providers -> Facebook.';
      }
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Facebook sign-in failed.');
      return false;
    }
  }

  Future<void> logout() async {
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

/// Current User Profile Provider (Dynamically returns current user profile or fallback)
final currentUserProfileProvider = Provider<UserProfile>((ref) {
  final authState = ref.watch(authProvider);
  if (authState.profile != null) {
    return authState.profile!;
  }
  final user = authState.user;
  if (user != null) {
    final metaName = user.userMetadata?['full_name'] ?? user.userMetadata?['name'] ?? user.email?.split('@').first ?? 'User';
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
