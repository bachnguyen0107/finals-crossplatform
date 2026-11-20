const maxAvatarSizeBytes = 2 * 1024 * 1024; // 2 MB

class AvatarValidationResult {
  const AvatarValidationResult._({
    this.errorMessage,
    this.extension,
    this.contentType,
  });

  const AvatarValidationResult.valid({
    required String extension,
    required String contentType,
  }) : this._(extension: extension, contentType: contentType);

  const AvatarValidationResult.invalid(String message)
      : this._(errorMessage: message);

  final String? errorMessage;
  final String? extension;
  final String? contentType;

  bool get isValid => errorMessage == null;
}

AvatarValidationResult validateAvatarFile({
  required String fileName,
  required int byteLength,
  String? mimeType,
}) {
  if (byteLength <= 0) {
    return const AvatarValidationResult.invalid(
      'Selected image file is empty.',
    );
  }
  if (byteLength > maxAvatarSizeBytes) {
    return const AvatarValidationResult.invalid(
      'Image must be 2 MB or smaller.',
    );
  }

  final lowerName = fileName.trim().toLowerCase();
  final lowerMime = (mimeType ?? '').trim().toLowerCase();

  String? ext;
  if (lowerName.endsWith('.jpg') ||
      lowerName.endsWith('.jpeg') ||
      lowerMime == 'image/jpeg' ||
      lowerMime == 'image/jpg') {
    ext = 'jpg';
  } else if (lowerName.endsWith('.png') || lowerMime == 'image/png') {
    ext = 'png';
  } else if (lowerName.endsWith('.webp') || lowerMime == 'image/webp') {
    ext = 'webp';
  }

  if (ext == null) {
    return const AvatarValidationResult.invalid(
      'Only JPG, PNG, and WEBP images are supported.',
    );
  }

  final contentType = switch (ext) {
    'jpg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    _ => 'image/jpeg',
  };

  return AvatarValidationResult.valid(
    extension: ext,
    contentType: contentType,
  );
}

String extractUserInitials({String? displayName, String? email}) {
  final cleanName = (displayName ?? '').trim();
  if (cleanName.isNotEmpty) {
    final parts = cleanName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return parts.first[0].toUpperCase();
  }

  final cleanEmail = (email ?? '').trim();
  if (cleanEmail.isNotEmpty) {
    return cleanEmail[0].toUpperCase();
  }

  return '?';
}