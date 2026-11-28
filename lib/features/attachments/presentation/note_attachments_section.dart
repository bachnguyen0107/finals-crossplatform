import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../application/attachments_providers.dart';
import '../domain/attachment.dart';

class NoteAttachmentsSection extends ConsumerStatefulWidget {
  const NoteAttachmentsSection({
    super.key,
    required this.noteId,
    this.readOnly = false,
  });

  final String noteId;
  final bool readOnly;

  @override
  ConsumerState<NoteAttachmentsSection> createState() =>
      _NoteAttachmentsSectionState();
}

class _NoteAttachmentsSectionState
    extends ConsumerState<NoteAttachmentsSection> {
  bool _isUploading = false;
  String? _activeActionId;

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickAndUpload() async {
    if (widget.readOnly || _isUploading) return;

    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const [
          'jpg',
          'jpeg',
          'png',
          'gif',
          'webp',
          'bmp',
          'heic',
          'heif',
          'mp4',
          'mov',
          'avi',
          'mkv',
          'webm',
          'm4v',
          'pdf',
          'doc',
          'docx',
          'txt',
          'md',
          'csv',
          'log',
          'zip',
        ],
        withData: true,
        allowMultiple: false,
      );
    } catch (e) {
      _showSnackBar('Failed to pick file: $e');
      return;
    }

    if (result == null || result.files.isEmpty) {
      _showSnackBar('File selection cancelled.');
      return;
    }

    final picked = result.files.first;
    final bytes = picked.bytes;
    if (bytes == null) {
      _showSnackBar('Could not read file bytes.');
      return;
    }

    try {
      validateAttachmentFile(
        fileName: picked.name,
        sizeBytes: bytes.length,
      );
    } on AttachmentValidationException catch (e) {
      _showSnackBar(e.message);
      return;
    }

    setState(() => _isUploading = true);
    try {
      await ref
          .read(noteAttachmentsProvider(widget.noteId).notifier)
          .upload(fileName: picked.name, bytes: bytes);
      _showSnackBar('Attached "${picked.name}".');
    } on AttachmentValidationException catch (e) {
      _showSnackBar(e.message);
    } catch (e) {
      _showSnackBar('Upload failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _openAttachment(NoteAttachment attachment) async {
    if (_activeActionId != null) return;
    setState(() => _activeActionId = attachment.id);
    try {
      final signedUrl = await ref
          .read(attachmentsRepositoryProvider)
          .createSignedUrl(attachment.storagePath, expiresInSeconds: 60);
      final uri = Uri.parse(signedUrl);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        _showSnackBar('Could not open "${attachment.fileName}".');
      }
    } catch (e) {
      _showSnackBar('Failed to open file: $e');
    } finally {
      if (mounted) {
        setState(() => _activeActionId = null);
      }
    }
  }

  Future<void> _confirmAndDelete(NoteAttachment attachment) async {
    if (widget.readOnly || _activeActionId != null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete attachment?'),
        content: Text(
          'Remove "${attachment.fileName}" from this note? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _activeActionId = attachment.id);
    try {
      await ref
          .read(noteAttachmentsProvider(widget.noteId).notifier)
          .remove(attachment);
      _showSnackBar('Removed "${attachment.fileName}".');
    } catch (e) {
      _showSnackBar('Failed to delete attachment: $e');
    } finally {
      if (mounted) {
        setState(() => _activeActionId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final attachmentsAsync = ref.watch(noteAttachmentsProvider(widget.noteId));
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Attachments',
              style: theme.textTheme.titleSmall,
            ),
            if (!widget.readOnly)
              FilledButton.tonalIcon(
                onPressed: _isUploading ? null : _pickAndUpload,
                icon: _isUploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.attach_file, size: 18),
                label: Text(_isUploading ? 'Uploading...' : 'Attach file'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        attachmentsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Could not load attachments: $err',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
          data: (items) {
            if (items.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No attachments yet.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final item = items[index];
                final isBusy = _activeActionId == item.id;

                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  leading: _AttachmentLeading(attachment: item),
                  title: Text(
                    item.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(_formatSize(item.sizeBytes)),
                  onTap: isBusy ? null : () => _openAttachment(item),
                  trailing: isBusy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Open',
                              icon: const Icon(Icons.open_in_new),
                              onPressed: () => _openAttachment(item),
                            ),
                            if (!widget.readOnly)
                              IconButton(
                                tooltip: 'Delete',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _confirmAndDelete(item),
                              ),
                          ],
                        ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _AttachmentLeading extends ConsumerWidget {
  const _AttachmentLeading({required this.attachment});

  final NoteAttachment attachment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!attachment.isImage) {
      return CircleAvatar(
        child: Icon(_fallbackIcon(attachment.mimeType)),
      );
    }

    final signedUrlAsync =
        ref.watch(attachmentSignedUrlProvider(attachment.storagePath));

    return SizedBox(
      width: 44,
      height: 44,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: signedUrlAsync.when(
          loading: () => const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (_, _) => CircleAvatar(
            child: Icon(_fallbackIcon(attachment.mimeType)),
          ),
          data: (url) => Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => CircleAvatar(
              child: Icon(_fallbackIcon(attachment.mimeType)),
            ),
          ),
        ),
      ),
    );
  }

  IconData _fallbackIcon(String mimeType) {
    if (mimeType.startsWith('image/')) return Icons.image_outlined;
    if (mimeType.startsWith('video/')) return Icons.movie_outlined;
    if (mimeType == 'application/pdf') return Icons.picture_as_pdf_outlined;
    if (mimeType.contains('word') || mimeType.contains('document')) {
      return Icons.description_outlined;
    }
    if (mimeType.startsWith('text/')) return Icons.article_outlined;
    if (mimeType.contains('zip')) return Icons.folder_zip_outlined;
    return Icons.attach_file;
  }
}