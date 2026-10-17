import 'package:flutter/material.dart';
import '../../widgets/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../cores/models/user_profile_model.dart';
import '../../cores/providers/auth_provider.dart';
import '../../cores/theme/app_theme.dart';
import '../../widgets/app_buttons.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _sendResetLink() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final success = await ref
        .read(authProvider.notifier)
        .sendPasswordResetEmail(email);

    if (!mounted) return;

    final authState = ref.read(authProvider);

    if (success) {
      setState(() => _emailSent = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText(
            authState.errorMessage ??
                'Failed to send reset link. Please check your email.',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final scheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: _emailSent
              ? _buildSuccessView(context, c, scheme)
              : _buildFormView(context, authState),
        ),
      ),
    );
  }

  Widget _buildFormView(BuildContext context, AppAuthState authState) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            'Forgot Password?',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontSize: 21),
          ),
          const SizedBox(height: 8),
          AppText(
            'Enter your registered email address and we will send you a link to reset your password.',
            style: TextStyle(fontSize: 12, color: context.colors.textMuted),
          ),
          const SizedBox(height: 28),
          _Label('REGISTERED EMAIL'),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'user@example.com',
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
          const SizedBox(height: 24),
          PrimaryButton(
            label: authState.isLoading ? 'Sending Link...' : 'Send Reset Link',
            onPressed: authState.isLoading ? () {} : _sendResetLink,
          ),
          const Spacer(),
          Center(
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const AppText('Back to Login'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView(
    BuildContext context,
    AppColorsExt c,
    ColorScheme scheme,
  ) {
    return Column(
      children: [
        const Spacer(),
        CircleAvatar(
          radius: 36,
          backgroundColor: c.success.withValues(alpha: 0.15),
          child: Icon(
            Icons.mark_email_read_outlined,
            color: c.success,
            size: 36,
          ),
        ),
        const SizedBox(height: 20),
        AppText(
          'Check Your Email',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontSize: 20),
        ),
        const SizedBox(height: 8),
        AppText(
          'We have sent a password reset link to:\n${_emailController.text.trim()}',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: c.textMuted),
        ),
        const SizedBox(height: 28),
        AccentButton(
          label: 'Back to Login',
          onPressed: () => Navigator.of(context).pop(),
        ),
        const Spacer(),
      ],
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
