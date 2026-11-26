import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/sharing_providers.dart';
import '../data/sharing_repository.dart';
import '../domain/share_models.dart';

/// Pure validation helper so email format, self-share, and duplicate recipient
/// rules can be unit-tested without mounting Supabase or widgets.
String? validateShareEmailInput({
  required String rawEmail,
  String? currentUserEmail,
  Iterable<String?> existingRecipientEmails = const <String?>[],
}) {
  final email = rawEmail.trim().toLowerCase();
  if (email.isEmpty) {
    return 'Please enter an email address.';
  }

  final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  if (!emailRegex.hasMatch(email)) {
    return 'Please enter a valid email address.';
  }

  final normalizedSelf = currentUserEmail?.trim().toLowerCase();
  if (normalizedSelf != null && normalizedSelf.isNotEmpty && email == normalizedSelf) {
    return 'You cannot share a note with yourself.';
  }

  final normalizedExisting = existingRecipientEmails
      .whereType<String>()
      .map((e) => e.trim().toLowerCase())
      .where((e) => e.isNotEmpty)
      .toSet();

  if (normalizedExisting.contains(email)) {
    return 'This note is already shared with this user.';
  }

  return null;
}

class ShareNoteDialog extends ConsumerStatefulWidget {
  const ShareNoteDialog({
    super.key,
    required this.noteId,
    this.noteTitle,
  });

  final String noteId;
  final String? noteTitle;

  @override
  ConsumerState<ShareNoteDialog> createState() => _ShareNoteDialogState();
}

class _ShareNoteDialogState extends ConsumerState<ShareNoteDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  SharePermission _selectedPermission = SharePermission.read;
  bool _isSubmitting = false;
  String? _busyShareId;
  String? _bannerError;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String _friendlyErrorMessage(Object error) {
    if (error is SharingFailure) return error.message;
    return 'Something went wrong. Please try again.';
  }

  Future<void> _handleShareSubmit(List<ShareItem> currentShares) async {
    setState(() {
      _bannerError = null;
    });

    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      await ref
          .read(noteSharesProvider(widget.noteId).notifier)
          .addShareByEmail(
            email: _emailController.text,
            permission: _selectedPermission,
          );

      if (!mounted) return;
      _emailController.clear();
      setState(() {
        _selectedPermission = SharePermission.read;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note shared successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _bannerError = _friendlyErrorMessage(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _handlePermissionChange(
    ShareItem item,
    SharePermission? newPermission,
  ) async {
    if (newPermission == null || newPermission == item.permission) return;

    setState(() {
      _bannerError = null;
      _busyShareId = item.id;
    });

    try {
      await ref
          .read(noteSharesProvider(widget.noteId).notifier)
          .changePermission(
            shareId: item.id,
            permission: newPermission,
          );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _bannerError = _friendlyErrorMessage(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _busyShareId = null;
        });
      }
    }
  }

  Future<void> _handleRevoke(ShareItem item) async {
    final displayName = (item.recipientEmail != null && item.recipientEmail!.isNotEmpty)
        ? item.recipientEmail!
        : item.recipientId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Revoke access?'),
          content: Text(
            'Remove sharing access for $displayName?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Revoke'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _bannerError = null;
      _busyShareId = item.id;
    });

    try {
      await ref.read(noteSharesProvider(widget.noteId).notifier).revoke(item.id);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _bannerError = _friendlyErrorMessage(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _busyShareId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sharesAsync = ref.watch(noteSharesProvider(widget.noteId));
    final currentShares = sharesAsync.value ?? const <ShareItem>[];
    final currentUserEmail =
        ref.watch(sharingRepositoryProvider).currentUserEmail;

    return AlertDialog(
      title: Text(
        widget.noteTitle != null && widget.noteTitle!.trim().isNotEmpty
            ? 'Share "${widget.noteTitle!.trim()}"'
            : 'Share note',
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _emailController,
                      enabled: !_isSubmitting,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Recipient email',
                        hintText: 'teammate@example.com',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => validateShareEmailInput(
                        rawEmail: value ?? '',
                        currentUserEmail: currentUserEmail,
                        existingRecipientEmails: currentShares
                            .map((s) => s.recipientEmail),
                      ),
                      onFieldSubmitted: (_) => _handleShareSubmit(currentShares),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<SharePermission>(
                            initialValue: _selectedPermission,
                            onChanged: _isSubmitting
                                ? null
                                : (val) {
                                    if (val != null) {
                                      setState(() {
                                        _selectedPermission = val;
                                      });
                                    }
                                  },
                            decoration: const InputDecoration(
                              labelText: 'Permission',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: SharePermission.values
                                .map(
                                  (perm) => DropdownMenuItem<SharePermission>(
                                    value: perm,
                                    child: Text(perm.label),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: _isSubmitting
                              ? null
                              : () => _handleShareSubmit(currentShares),
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.person_add_alt_1),
                          label: Text(_isSubmitting ? 'Sharing...' : 'Share'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_bannerError != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _bannerError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'People with access',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              sharesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _friendlyErrorMessage(err),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
                data: (shares) {
                  if (shares.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Not shared with anyone yet.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: shares.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final share = shares[index];
                      final isRowBusy = _busyShareId == share.id;
                      final titleText = (share.recipientEmail != null &&
                              share.recipientEmail!.isNotEmpty)
                          ? share.recipientEmail!
                          : 'User (${share.recipientId.substring(0, 8)}...)';

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          titleText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text('Permission: ${share.permission.label}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DropdownButton<SharePermission>(
                              value: share.permission,
                              onChanged: isRowBusy
                                  ? null
                                  : (val) => _handlePermissionChange(share, val),
                              items: SharePermission.values
                                  .map(
                                    (perm) => DropdownMenuItem<SharePermission>(
                                      value: perm,
                                      child: Text(perm.label),
                                    ),
                                  )
                                  .toList(),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: 'Revoke access',
                              onPressed:
                                  isRowBusy ? null : () => _handleRevoke(share),
                              icon: isRowBusy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.person_remove_outlined),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}