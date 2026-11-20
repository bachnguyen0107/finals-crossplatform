import 'package:flutter/material.dart';

import '../../application/avatar_validator.dart';

class UserAvatar extends StatefulWidget {
  const UserAvatar({
    super.key,
    this.avatarUrl,
    this.displayName,
    this.email,
    this.radius = 36,
  });

  final String? avatarUrl;
  final String? displayName;
  final String? email;
  final double radius;

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  bool _imageFailed = false;

  @override
  void didUpdateWidget(covariant UserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avatarUrl != widget.avatarUrl) {
      _imageFailed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = (widget.avatarUrl ?? '').trim();
    final hasImage = url.isNotEmpty && !_imageFailed;
    final initials = extractUserInitials(
      displayName: widget.displayName,
      email: widget.email,
    );

    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: theme.colorScheme.primaryContainer,
      foregroundColor: theme.colorScheme.onPrimaryContainer,
      backgroundImage: hasImage ? NetworkImage(url) : null,
      onBackgroundImageError: hasImage
          ? (_, _) {
              if (mounted) {
                setState(() {
                  _imageFailed = true;
                });
              }
            }
          : null,
      child: hasImage
          ? null
          : Text(
              initials,
              style: TextStyle(
                fontSize: widget.radius * 0.7,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }
}