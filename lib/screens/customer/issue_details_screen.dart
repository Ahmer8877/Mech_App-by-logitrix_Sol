import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../cores/config/supabase_config.dart';
import '../../cores/providers/auth_provider.dart';
import '../../cores/providers/booking_draft_provider.dart';
import '../../cores/repositories/booking_media_repository.dart';
import '../../cores/theme/app_theme.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/step_progress.dart';
import 'set_location_screen.dart';

class IssueDetailsScreen extends ConsumerStatefulWidget {
  const IssueDetailsScreen({super.key});

  @override
  ConsumerState<IssueDetailsScreen> createState() => _IssueDetailsScreenState();
}

class _IssueDetailsScreenState extends ConsumerState<IssueDetailsScreen> {
  final _descriptionController = TextEditingController();
  final _photos = <XFile>[];
  final _picker = ImagePicker();
  bool _saving = false;

  Future<void> _pickPhoto() async {
    if (_photos.length >= 3) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 80,
      );
      if (file != null && mounted) {
        setState(() => _photos.add(file));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add photo: $e')));
      }
    }
  }

  Future<void> _next() async {
    final userId = ref.read(authProvider).user?.id;
    if (userId == null) return;

    setState(() => _saving = true);
    try {
      final urls = await BookingMediaRepository(
        supabase,
      ).upload(userId: userId, files: _photos);

      ref
          .read(bookingDraftProvider.notifier)
          .setDetails(
            description: _descriptionController.text.trim(),
            photoUrls: urls,
          );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SetLocationScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to upload photos: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      appBar: const FlowAppBar(title: 'Describe the Issue'),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const StepProgress(total: 5, current: 3),
            Text(
              'DESCRIBE THE ISSUE',
              style: TextStyle(
                fontSize: 9.5,
                color: colors.textMuted,
                letterSpacing: .4,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Describe the problem...',
                filled: true,
                fillColor: colors.surface2,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'ADD PHOTOS (OPTIONAL, MAX 3)',
              style: TextStyle(fontSize: 9.5, color: colors.textMuted),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ..._photos.map(
                  (photo) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(photo.path),
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: InkWell(
                          onTap: () => setState(() => _photos.remove(photo)),
                          child: const CircleAvatar(
                            radius: 10,
                            child: Icon(Icons.close, size: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_photos.length < 3)
                  InkWell(
                    onTap: _pickPhoto,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: colors.surface2,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.add),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            AccentButton(
              label: _saving ? 'Uploading...' : 'Next',
              onPressed: _saving ? null : _next,
            ),
          ],
        ),
      ),
    );
  }
}
