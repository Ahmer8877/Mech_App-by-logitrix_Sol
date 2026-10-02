import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../cores/providers/auth_provider.dart';
import '../../cores/theme/app_theme.dart';
import '../../utils/pakistan_input_formatters.dart';
import '../../widgets/app_buttons.dart';
import '../auth&role/role_select_screen.dart';
import 'mechanic_home_screen.dart';

class MechanicVerificationScreen extends ConsumerStatefulWidget {
  final VoidCallback? onContinueToDashboard;

  const MechanicVerificationScreen({super.key, this.onContinueToDashboard});

  @override
  ConsumerState<MechanicVerificationScreen> createState() =>
      _MechanicVerificationScreenState();
}

class _MechanicVerificationScreenState
    extends ConsumerState<MechanicVerificationScreen> {
  final _picker = ImagePicker();
  final _cnicController = TextEditingController();
  final _phoneController = TextEditingController();

  XFile? _profilePhoto;
  XFile? _cnicFront;
  XFile? _cnicBack;
  List<XFile> _toolsPhotos = [];
  String? _errorMessage;
  bool _resubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(authProvider).profile;
      if (profile != null && profile.phone.isNotEmpty) {
        var initialPhone = displayPakistanPhone(profile.phone.trim());
        if (initialPhone.startsWith('+92')) {
          initialPhone = initialPhone.substring(3);
        } else if (initialPhone.startsWith('0')) {
          initialPhone = initialPhone.substring(1);
        }
        _phoneController.text = initialPhone;
      }
    });
  }

  @override
  void dispose() {
    _cnicController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _logout(BuildContext context) async {
    await ref.read(authProvider.notifier).logout();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _pickProfilePhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 70,
    );
    if (file != null) {
      setState(() => _profilePhoto = file);
    }
  }

  Future<void> _pickCnicFront() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 70,
    );
    if (file != null) {
      setState(() => _cnicFront = file);
    }
  }

  Future<void> _pickCnicBack() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 70,
    );
    if (file != null) {
      setState(() => _cnicBack = file);
    }
  }

  Future<void> _pickToolsPhotos() async {
    final files = await _picker.pickMultiImage(
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 70,
    );
    if (files.isNotEmpty) {
      setState(() {
        _toolsPhotos = [..._toolsPhotos, ...files].take(6).toList();
      });
    }
  }

  Future<void> _submit() async {
    final formattedPhone = normalizePakistanPhone(_phoneController.text.trim());
    if (formattedPhone.isEmpty) {
      setState(
        () => _errorMessage =
            'Please enter a valid 11-digit Pakistani mobile number (e.g. 03001234567).',
      );
      return;
    }
    final cnic = normalizePakistanCnic(_cnicController.text.trim());
    if (cnic.isEmpty) {
      setState(() => _errorMessage = 'Please enter a valid CNIC number.');
      return;
    }
    if (_cnicFront == null) {
      setState(() => _errorMessage = 'Please upload CNIC Front Photo.');
      return;
    }
    if (_cnicBack == null) {
      setState(() => _errorMessage = 'Please upload CNIC Back Photo.');
      return;
    }
    if (_toolsPhotos.isEmpty) {
      setState(
        () =>
            _errorMessage = 'Please upload at least one workshop/tools photo.',
      );
      return;
    }

    setState(() => _errorMessage = null);

    final success = await ref
        .read(authProvider.notifier)
        .submitMechanicVerification(
          phoneNumber: formattedPhone,
          cnicNumber: cnic,
          cnicFront: _cnicFront!,
          cnicBack: _cnicBack!,
          toolsPhotos: _toolsPhotos,
          profilePhoto: _profilePhoto,
        );

    if (success && mounted) {
      setState(() => _resubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText('Verification documents submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final scheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authProvider);
    final user = authState.user;

    // Real-time active profile stream
    final liveProfile = user != null
        ? (ref.watch(activeProfileStreamProvider(user.id)).valueOrNull ??
              authState.profile)
        : authState.profile;

    final profile = liveProfile;

    // STATE 1: APPROVED / VERIFIED MECHANIC
    if (profile != null &&
        (profile.isVerified || profile.verificationStatus == 'approved')) {
      return Scaffold(
        appBar: AppBar(title: const AppText('Verification Completed')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 48,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 20),
                const AppText(
                  'Verification Approved! 🎉',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                AppText(
                  'Congratulations! Your mechanic account has been verified by the administrator. You can now start accepting service requests and sending offers.',
                  style: TextStyle(fontSize: 12.5, color: c.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                PrimaryButton(
                  label: 'Continue to Dashboard',
                  onPressed: () async {
                    await ref
                        .read(authProvider.notifier)
                        .fetchUserProfile(profile.id);
                    if (widget.onContinueToDashboard != null) {
                      widget.onContinueToDashboard!();
                    } else {
                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (_) => const MechanicHomeScreen(),
                          ),
                          (route) => false,
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    // STATE 2: REJECTED BY ADMIN WITH REASON
    if (profile != null &&
        profile.verificationStatus == 'rejected' &&
        !_resubmitting) {
      final reason = profile.verificationNotes?.trim().isNotEmpty == true
          ? profile.verificationNotes!
          : 'Documents were unclear or invalid.';

      return Scaffold(
        appBar: AppBar(title: const AppText('Verification Declined')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.cancel_rounded,
                      size: 44,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const AppText(
                    'Verification Declined ❌',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  AppText(
                    'Your verification request was rejected by the admin.',
                    style: TextStyle(fontSize: 12.5, color: c.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppText(
                          'REASON FOR DECLINE:',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        AppText(
                          reason,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  AccentButton(
                    label: 'Re-submit Verification Documents',
                    onPressed: () {
                      setState(() {
                        _resubmitting = true;
                        if (profile.cnic != null) {
                          _cnicController.text = profile.cnic!;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => _logout(context),
                    child: const AppText(
                      'Logout',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // STATE 3: PENDING REVIEW
    if (profile != null &&
        profile.isVerificationSubmitted &&
        profile.verificationStatus == 'pending' &&
        !_resubmitting) {
      return Scaffold(
        appBar: AppBar(title: const AppText('Verification Under Review')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.hourglass_top_rounded,
                    size: 42,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 20),
                const AppText(
                  'Verification Under Review ⏳',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                AppText(
                  'Your CNIC and workshop documents have been received! The admin team is currently reviewing your profile.',
                  style: TextStyle(fontSize: 12.5, color: c.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                AppText(
                  'CNIC: ${profile.cnic ?? 'Provided'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    AppText(
                      'Waiting for Admin approval in real-time...',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => _logout(context),
                  child: const AppText(
                    'Logout',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // STATE 4: VERIFICATION FORM INPUT
    return Scaffold(
      appBar: AppBar(title: const AppText('Mechanic Verification')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                'Complete Your Verification',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 4),
              AppText(
                'Upload your CNIC, workshop photos, and profile photo to start accepting mechanic requests.',
                style: TextStyle(fontSize: 11.5, color: c.textSecondary),
              ),
              const SizedBox(height: 20),

              // 1. Profile Photo
              Center(
                child: GestureDetector(
                  onTap: _pickProfilePhoto,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 42,
                        backgroundColor: c.surface2,
                        backgroundImage: _profilePhoto != null
                            ? FileImage(File(_profilePhoto!.path))
                            : (profile?.avatarUrl != null &&
                                      profile!.avatarUrl!.isNotEmpty
                                  ? CachedNetworkImageProvider(
                                          profile.avatarUrl!,
                                        )
                                        as ImageProvider
                                  : null),
                        child:
                            (_profilePhoto == null &&
                                (profile?.avatarUrl == null ||
                                    profile!.avatarUrl!.isEmpty))
                            ? Icon(
                                Icons.person_outline,
                                size: 36,
                                color: scheme.primary,
                              )
                            : null,
                      ),
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: scheme.primary,
                        child: const Icon(
                          Icons.camera_alt,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: AppText(
                    'Tap to upload Profile Photo',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 2. Phone Number
              const AppText(
                'PHONE NUMBER',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: c.surface2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: c.borderStrong.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const AppText(
                      '🇵🇰 +92',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [PakistanPhoneFormatter()],
                      maxLength: 11,
                      decoration: const InputDecoration(
                        hintText: '3001234567',
                        counterText: '',
                        prefixIcon: Icon(
                          Icons.phone_android_outlined,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 3. CNIC Number
              const AppText(
                'CNIC NUMBER',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _cnicController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'e.g. 35202-1234567-1',
                  prefixIcon: Icon(Icons.badge_outlined, size: 18),
                ),
              ),
              const SizedBox(height: 20),

              // 4. CNIC Front & Back Photos
              const AppText(
                'CNIC PHOTOS (FRONT & BACK)',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _ImagePickerBox(
                      label: 'CNIC Front',
                      file: _cnicFront,
                      onTap: _pickCnicFront,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ImagePickerBox(
                      label: 'CNIC Back',
                      file: _cnicBack,
                      onTap: _pickCnicBack,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 5. Workshop & Tools Photos
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const AppText(
                    'WORKSHOP & TOOLS PHOTOS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  AppText(
                    '${_toolsPhotos.length} selected',
                    style: TextStyle(fontSize: 10, color: scheme.primary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickToolsPhotos,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: c.surface2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: c.borderStrong.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        color: scheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const AppText(
                        'Upload Workshop / Tools Photos',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_toolsPhotos.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _toolsPhotos.length,
                    itemBuilder: (context, index) {
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          image: DecorationImage(
                            image: FileImage(File(_toolsPhotos[index].path)),
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],

              if (_errorMessage != null || authState.errorMessage != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.3),
                    ),
                  ),
                  child: AppText(
                    _errorMessage ?? authState.errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 11.5),
                  ),
                ),
              ],

              const SizedBox(height: 28),
              AccentButton(
                label: authState.isLoading
                    ? 'Uploading Documents...'
                    : 'Submit Verification',
                onPressed: authState.isLoading ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImagePickerBox extends StatelessWidget {
  final String label;
  final XFile? file;
  final VoidCallback onTap;

  const _ImagePickerBox({
    required this.label,
    required this.file,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: file != null
                ? scheme.primary
                : c.borderStrong.withValues(alpha: 0.4),
            width: file != null ? 1.6 : 1.0,
          ),
          image: file != null
              ? DecorationImage(
                  image: FileImage(File(file!.path)),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: file == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    color: scheme.primary,
                    size: 22,
                  ),
                  const SizedBox(height: 4),
                  AppText(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            : Align(
                alignment: Alignment.topRight,
                child: Container(
                  margin: const EdgeInsets.all(4),
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 14),
                ),
              ),
      ),
    );
  }
}
