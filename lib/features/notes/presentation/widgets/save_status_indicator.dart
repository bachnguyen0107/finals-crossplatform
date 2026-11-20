import 'package:flutter/material.dart';

import '../../application/auto_saver.dart';

class SaveStatusIndicator extends StatelessWidget {
  const SaveStatusIndicator({super.key, required this.status, this.onRetry});

  final SaveStatus status;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodyMedium;

    final child = switch (status) {
      SaveStatus.idle => const SizedBox.shrink(),
      SaveStatus.saving => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text('Saving...', style: textStyle),
          ],
        ),
      SaveStatus.saved => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_done_outlined, size: 18),
            const SizedBox(width: 8),
            Text('Saved', style: textStyle),
          ],
        ),
      SaveStatus.failed => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 18, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            Text(
              'Not saved',
              style: textStyle?.copyWith(color: theme.colorScheme.error),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
    };

    // liveRegion: screen readers announce the new status.
    return Semantics(liveRegion: true, child: child);
  }
}