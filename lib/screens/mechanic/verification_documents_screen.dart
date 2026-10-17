import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/app_text.dart';
import '../../cores/models/user_profile_model.dart';
import '../../cores/providers/auth_provider.dart';
import '../../cores/theme/app_theme.dart';
import '../../widgets/step_progress.dart';

enum DocStatus { notUploaded, pending, approved, rejected }

class _DocItem {
  final String label;
  final DocStatus status;
  const _DocItem(this.label, this.status);
}

class VerificationDocumentsScreen extends ConsumerWidget {
  const VerificationDocumentsScreen({super.key});

  DocStatus _statusFor(UserProfile profile, {required bool uploaded}) {
    if (!uploaded) return DocStatus.notUploaded;
    switch (profile.verificationStatus) {
      case 'approved':
        return DocStatus.approved;
      case 'rejected':
        return DocStatus.rejected;
      default:
        return DocStatus.pending;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final scheme = Theme.of(context).colorScheme;
    final userId = ref.watch(authProvider.select((s) => s.user?.id));

    if (userId == null) {
      return const Scaffold(
        body: Center(
          child: AppText('Please sign in to view verification documents.'),
        ),
      );
    }

    final profileAsync = ref.watch(activeProfileStreamProvider(userId));
    return Scaffold(
      appBar: const FlowAppBar(title: 'Verification Documents'),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: AppText(
              'Unable to load verification documents. Please try again.',
            ),
          ),
        ),
        data: (profile) {
          if (profile == null) {
            return const Center(
              child: AppText('Profile information is unavailable.'),
            );
          }

          final docs = <_DocItem>[
            _DocItem(
              'CNIC (Front & Back)',
              _statusFor(
                profile,
                uploaded:
                    profile.cnicFrontUrl?.isNotEmpty == true &&
                    profile.cnicBackUrl?.isNotEmpty == true,
              ),
            ),
            _DocItem(
              'Profile Photo',
              _statusFor(
                profile,
                uploaded: profile.avatarUrl?.isNotEmpty == true,
              ),
            ),
            _DocItem(
              'Tools / Workshop Photos',
              _statusFor(
                profile,
                uploaded: profile.workshopToolsUrls.isNotEmpty,
              ),
            ),
          ];

          final allApproved = docs.every((d) => d.status == DocStatus.approved);

          Color statusColor(DocStatus status) {
            switch (status) {
              case DocStatus.approved:
                return c.success;
              case DocStatus.pending:
                return c.accent;
              case DocStatus.rejected:
                return c.danger;
              case DocStatus.notUploaded:
                return c.textMuted;
            }
          }

          String statusLabel(DocStatus status) {
            switch (status) {
              case DocStatus.approved:
                return 'Approved';
              case DocStatus.pending:
                return 'Under Review';
              case DocStatus.rejected:
                return 'Rejected';
              case DocStatus.notUploaded:
                return 'Not Uploaded';
            }
          }

          return Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: (allApproved ? c.success : c.accent).withValues(
                      alpha: 0.1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        allApproved
                            ? Icons.verified_outlined
                            : Icons.hourglass_empty,
                        size: 18,
                        color: allApproved ? c.success : c.accent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppText(
                          allApproved
                              ? 'Your account is fully verified.'
                              : 'Verification documents are synced with your account.',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final color = statusColor(doc.status);
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: c.borderStrong.withValues(alpha: 0.4),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: c.surface2,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Icon(
                                Icons.description_outlined,
                                size: 16,
                                color: scheme.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AppText(
                                doc.label,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: AppText(
                                statusLabel(doc.status),
                                style: TextStyle(fontSize: 8.5, color: color),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
