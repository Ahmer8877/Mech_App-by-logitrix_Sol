import 'package:flutter/material.dart';
import '../../widgets/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../cores/providers/auth_provider.dart';
import '../../cores/models/user_role.dart';
import '../../cores/theme/app_theme.dart';
import '../../widgets/app_buttons.dart';
import '../customer/customer_home_screen.dart';
import '../mechanic/mechanic_home_screen.dart';
import '../mechanic/mechanic_verification_screen.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final UserRole role;
  const LoginScreen({super.key, required this.role});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    final success = await ref
        .read(authProvider.notifier)
        .loginWithEmail(email, password, widget.role);

    if (!mounted) return;

    final authState = ref.read(authProvider);

    if (success && authState.user != null) {
      final userProfile = ref.read(currentUserProfileProvider);

      // Strict Role Security Validation:
      if (userProfile.role != widget.role) {
        await ref.read(authProvider.notifier).logout();

        final expectedRoleName = userProfile.role == UserRole.customer
            ? 'Customer'
            : 'Mechanic';
        final attemptedRoleName = widget.role == UserRole.customer
            ? 'Customer'
            : 'Mechanic';

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: AppText(
              'This account is registered as a $expectedRoleName. You cannot log into the $attemptedRoleName portal.',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }

      // Role matches! Navigate to respective portal
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => userProfile.role == UserRole.customer
              ? const CustomerHomeScreen()
              : const MechanicHomeScreen(),
        ),
        (route) => false,
      );
    } else {
      if (authState.errorMessage != null &&
          authState.errorMessage!.contains('missing')) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => widget.role == UserRole.customer
                ? const CustomerHomeScreen()
                : const MechanicHomeScreen(),
          ),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: AppText(
              authState.errorMessage ??
                  'Login failed. Please check your credentials.',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _finishSocialLoginNavigation() async {
    // OAuth callbacks return asynchronously. Wait briefly for AuthNotifier to
    // receive the session/profile before deciding which portal to open.
    for (var i = 0; i < 30; i++) {
      if (!mounted) return;
      final authState = ref.read(authProvider);
      final profile = authState.profile;
      if (authState.user != null && profile != null) {
        if (profile.role != widget.role) {
          await ref.read(authProvider.notifier).logout();
          if (!mounted) return;
          final expected = profile.role == UserRole.mechanic
              ? 'Mechanic'
              : 'Customer';
          final attempted = widget.role == UserRole.mechanic
              ? 'Mechanic'
              : 'Customer';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: AppText(
                'This account is registered as a $expected. You cannot log into the $attempted portal.',
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
              duration: const Duration(seconds: 4),
            ),
          );
          return;
        }
        final isMechanic = profile.role == UserRole.mechanic;
        final isApproved =
            profile.isVerified || profile.verificationStatus == 'approved';

        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => isMechanic && !isApproved
                ? const MechanicVerificationScreen()
                : (isMechanic
                      ? const MechanicHomeScreen()
                      : const CustomerHomeScreen()),
          ),
          (route) => false,
        );
        return;
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (!mounted) return;
    final message =
        ref.read(authProvider).errorMessage ??
        'Sign-in completed, but your profile is still loading. Please try again.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: AppText(message)));
  }

  void _loginWithGoogle() async {
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;

    final success = await ref
        .read(authProvider.notifier)
        .loginWithGoogle(widget.role);

    if (!mounted) return;

    if (success) {
      await _finishSocialLoginNavigation();
    } else {
      final message = ref.read(authProvider).errorMessage;
      if (message != null) {
        messenger.showSnackBar(
          SnackBar(content: AppText(message), backgroundColor: errorColor),
        );
      }
    }
  }

  void _loginWithFacebook() async {
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;

    final success = await ref
        .read(authProvider.notifier)
        .loginWithFacebook(widget.role);

    if (!mounted) return;

    if (success) {
      await _finishSocialLoginNavigation();
    } else {
      final message = ref.read(authProvider).errorMessage;
      if (message != null) {
        messenger.showSnackBar(
          SnackBar(content: AppText(message), backgroundColor: errorColor),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  widget.role == UserRole.customer
                      ? 'Customer Login'
                      : 'Mechanic Login',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineMedium?.copyWith(fontSize: 21),
                ),
                const SizedBox(height: 20),
                _Label('EMAIL /'),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'user@example.com',
                    prefixIcon: Icon(Icons.email_outlined, size: 20),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email or phone number';
                    }
                    if (value.contains('@') &&
                        !RegExp(
                          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                        ).hasMatch(value.trim())) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _Label('PASSWORD'),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ForgotPasswordScreen(),
                      ),
                    ),
                    child: AppText(
                      'Forgot password?',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: authState.isLoading ? 'Logging in...' : 'Login',
                  onPressed: authState.isLoading ? () {} : _login,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: Divider(color: c.borderStrong)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: AppText(
                        'or continue with',
                        style: TextStyle(fontSize: 10.5, color: c.textMuted),
                      ),
                    ),
                    Expanded(child: Divider(color: c.borderStrong)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlineActionButton(
                        label: 'Google',
                        icon: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          alignment: Alignment.center,
                          child: const AppText(
                            'G',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        onPressed: _loginWithGoogle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlineActionButton(
                        label: 'Facebook',
                        icon: const Icon(
                          Icons.facebook,
                          color: Color(0xFF1877F2),
                          size: 20,
                        ),
                        onPressed: _loginWithFacebook,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SignupScreen(role: widget.role),
                      ),
                    ),
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 11.5, color: c.textMuted),
                        children: [
                          const TextSpan(text: "Don't have an account? "),
                          TextSpan(
                            text: 'Sign up',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: AppText(
        text,
        style: TextStyle(
          fontSize: 9.5,
          color: context.colors.textMuted,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
