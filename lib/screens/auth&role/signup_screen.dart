import 'package:flutter/material.dart';
import '../../widgets/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../cores/providers/auth_provider.dart';
import '../../cores/models/user_role.dart';
import '../../cores/theme/app_theme.dart';
import '../../widgets/app_buttons.dart';
import '../../utils/pakistan_input_formatters.dart';
import '../customer/customer_home_screen.dart';
import '../mechanic/mechanic_home_screen.dart';

class SignupScreen extends ConsumerStatefulWidget {
  final UserRole role;
  const SignupScreen({super.key, required this.role});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _cnicController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _cnicController.dispose();
    super.dispose();
  }

  void _createAccount() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref
        .read(authProvider.notifier)
        .signUpWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          fullName: _nameController.text.trim(),
          phone: normalizePakistanPhone(_phoneController.text.trim()),
          role: widget.role,
          cnic: widget.role == UserRole.mechanic
              ? normalizePakistanCnic(_cnicController.text.trim())
              : null,
        );

    if (!mounted) return;

    final authState = ref.read(authProvider);

    if (success || authState.user != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText('Account created successfully! Welcome to MechX.'),
        ),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => widget.role == UserRole.customer
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
              authState.errorMessage ?? 'Signup failed. Please try again.',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
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
                  'Create Account',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineMedium?.copyWith(fontSize: 21),
                ),
                const SizedBox(height: 4),
                AppText(
                  widget.role == UserRole.customer
                      ? 'Creating a Customer Account'
                      : 'Creating a Mechanic Account',
                  style: TextStyle(fontSize: 11.5, color: c.textMuted),
                ),
                const SizedBox(height: 20),
                _Label('FULL NAME'),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    hintText: 'John Doe',
                    prefixIcon: Icon(Icons.person_outline, size: 20),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your full name';
                    }
                    if (value.trim().length < 2) {
                      return 'Name must be at least 2 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _Label('PHONE NUMBER'),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [PakistanPhoneFormatter()],
                  decoration: const InputDecoration(
                    hintText: '03001234567',
                    prefixIcon: Icon(Icons.phone_outlined, size: 20),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your phone number';
                    }
                    if (normalizePakistanPhone(value.trim()).isEmpty) {
                      return 'Please enter a valid 11-digit Pakistani mobile number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _Label('EMAIL'),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'john@example.com',
                    prefixIcon: Icon(Icons.email_outlined, size: 20),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email address';
                    }
                    if (!RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(value.trim())) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
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
                      return 'Please enter a password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _Label('CONFIRM PASSWORD'),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                      ),
                      onPressed: () => setState(
                        () =>
                            _obscureConfirmPassword = !_obscureConfirmPassword,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                if (widget.role == UserRole.mechanic) ...[
                  const SizedBox(height: 14),
                  _Label('CNIC NUMBER'),
                  TextFormField(
                    controller: _cnicController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [PakistanCnicFormatter()],
                    decoration: const InputDecoration(
                      hintText: '35202-1234567-1',
                      prefixIcon: Icon(Icons.badge_outlined, size: 20),
                    ),
                    validator: (value) {
                      if (widget.role == UserRole.mechanic) {
                        if (value == null || value.trim().isEmpty) {
                          return 'CNIC number is required for mechanic registration';
                        }
                        if (normalizePakistanCnic(value.trim()).isEmpty) {
                          return 'Please enter a valid 13-digit CNIC number';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  AppText(
                    'Mechanic account requires admin verification before approval.',
                    style: TextStyle(fontSize: 10, color: c.textMuted),
                  ),
                ],
                const SizedBox(height: 22),
                PrimaryButton(
                  label: authState.isLoading
                      ? 'Creating Account...'
                      : 'Create Account',
                  onPressed: authState.isLoading ? () {} : _createAccount,
                ),
                const SizedBox(height: 16),
                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 11.5, color: c.textMuted),
                        children: [
                          const TextSpan(text: 'Already have an account? '),
                          TextSpan(
                            text: 'Login',
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
