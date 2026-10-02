import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../cores/models/user_profile_model.dart';
import '../../cores/models/user_role.dart';
import '../../cores/providers/auth_provider.dart';
import '../../cores/theme/app_theme.dart';
import '../../widgets/app_buttons.dart';
import '../../utils/pakistan_input_formatters.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  final UserRole role;
  const EditProfileScreen({super.key, required this.role});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _specializationController;
  late final TextEditingController _experienceController;
  XFile? _selectedImage;
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(currentUserProfileProvider);
    _nameController = TextEditingController(text: profile.fullName);
    _phoneController = TextEditingController(
      text: displayPakistanPhone(profile.phone),
    );
    _emailController = TextEditingController(text: profile.email);
    _specializationController = TextEditingController(
      text: profile.specialization ?? '',
    );
    _experienceController = TextEditingController(
      text: profile.experienceYears?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _specializationController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final picker = ImagePicker();
      // HD Compression (maxWidth: 1200, maxHeight: 1200, imageQuality: 85)
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (picked != null) {
        setState(() {
          _selectedImage = picked;
          _isUploadingAvatar = true;
        });

        // Upload compressed image to Supabase Storage bucket 'avatars'
        final uploadedUrl = await ref
            .read(authProvider.notifier)
            .uploadAvatar(picked);

        if (!mounted) return;

        setState(() => _isUploadingAvatar = false);

        if (uploadedUrl != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: AppText(
                'Compressed profile picture saved successfully!',
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: AppText('Profile picture saved locally.')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingAvatar = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: AppText('Could not pick image')));
    }
  }

  void _openFullImageDialog(UserProfile profile) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: _selectedImage != null
                      ? Image.file(
                          File(_selectedImage!.path),
                          fit: BoxFit.contain,
                        )
                      : (profile.avatarUrl != null &&
                                profile.avatarUrl!.isNotEmpty
                            ? Image.network(
                                profile.avatarUrl!,
                                fit: BoxFit.contain,
                                loadingBuilder: (_, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return const CircularProgressIndicator(
                                    color: Colors.white,
                                  );
                                },
                                errorBuilder: (_, _, _) =>
                                    _buildAvatarFallback(profile),
                              )
                            : _buildAvatarFallback(profile)),
                ),
              ),
              Positioned(
                top: 40,
                left: 16,
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ),
              ),
              Positioned(
                bottom: 40,
                left: 20,
                right: 20,
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          _pickAvatar();
                        },
                        icon: const Icon(Icons.photo_camera, size: 18),
                        label: const AppText('Edit / Change Picture'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvatarFallback(UserProfile profile) {
    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: AppText(
        profile.initials,
        style: TextStyle(
          fontSize: 64,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  void _saveProfile() async {
    final profile = ref.read(currentUserProfileProvider);
    final isMechanic =
        widget.role == UserRole.mechanic || profile.role == UserRole.mechanic;
    final name = _nameController.text.trim();
    final phone = normalizePakistanPhone(_phoneController.text.trim());
    final email = _emailController.text.trim();

    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText(
            'Please enter a valid 11-digit Pakistani mobile number',
          ),
        ),
      );
      return;
    }

    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: AppText('Name cannot be empty')));
      return;
    }

    final success = await ref
        .read(authProvider.notifier)
        .updateProfile(
          fullName: name,
          phone: phone,
          email: email,
          specialization: isMechanic ? _specializationController.text : null,
          experienceYears: isMechanic
              ? int.tryParse(_experienceController.text.trim())
              : null,
        );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('Profile updated successfully!')),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const AppText('Failed to update profile. Please try again.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final scheme = Theme.of(context).colorScheme;
    final profile = ref.watch(currentUserProfileProvider);
    final isMechanic =
        widget.role == UserRole.mechanic || profile.role == UserRole.mechanic;
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const AppText('Edit Profile', style: TextStyle(fontSize: 15)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Center(
            child: GestureDetector(
              onTap: () => _openFullImageDialog(profile),
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: c.surface2,
                    backgroundImage: _selectedImage != null
                        ? FileImage(File(_selectedImage!.path))
                        : (profile.avatarUrl != null &&
                                  profile.avatarUrl!.isNotEmpty
                              ? CachedNetworkImageProvider(profile.avatarUrl!)
                                    as ImageProvider
                              : null),
                    child: (_isUploadingAvatar)
                        ? const CircularProgressIndicator(strokeWidth: 2)
                        : (_selectedImage == null &&
                                  (profile.avatarUrl == null ||
                                      profile.avatarUrl!.isEmpty)
                              ? AppText(
                                  profile.initials,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                    color: scheme.primary,
                                  ),
                                )
                              : null),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.camera_alt_outlined,
                        size: 14,
                        color: scheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _Label('FULL NAME'),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.person_outline, size: 20),
            ),
          ),
          const SizedBox(height: 14),
          _Label('PHONE NUMBER'),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [PakistanPhoneFormatter()],
            decoration: const InputDecoration(
              hintText: 'e.g. +92 300 0000000',
              prefixIcon: Icon(Icons.phone_outlined, size: 20),
            ),
          ),
          const SizedBox(height: 14),
          _Label('EMAIL'),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'you@example.com',
              prefixIcon: Icon(Icons.email_outlined, size: 20),
            ),
          ),
          if (isMechanic) ...[
            const SizedBox(height: 14),
            _Label('SPECIALIZATION'),
            TextField(
              controller: _specializationController,
              decoration: const InputDecoration(
                hintText: 'Engine, Battery, AC...',
                prefixIcon: Icon(Icons.build_outlined, size: 20),
              ),
            ),
            const SizedBox(height: 14),
            _Label('YEARS OF EXPERIENCE'),
            TextField(
              controller: _experienceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: '5',
                prefixIcon: Icon(Icons.work_outline, size: 20),
              ),
            ),
          ],
          const SizedBox(height: 24),
          AccentButton(
            label: authState.isLoading ? 'Saving...' : 'Save Changes',
            onPressed: authState.isLoading ? () {} : _saveProfile,
          ),
        ],
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
