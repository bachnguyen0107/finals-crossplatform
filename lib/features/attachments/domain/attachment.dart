class NoteAttachment {
  const NoteAttachment({
    required this.id,
    required this.noteId,
    required this.ownerId,
    required this.storagePath,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.createdAt,
  });

  final String id;
  final String noteId;
  final String ownerId;
  final String storagePath;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final DateTime createdAt;

  bool get isImage => mimeType.startsWith('image/');

  factory NoteAttachment.fromMap(Map<String, dynamic> map) {
    return NoteAttachment(
      id: map['id'] as String,
      noteId: map['note_id'] as String,
      ownerId: map['owner_id'] as String,
      storagePath: map['storage_path'] as String,
      fileName: map['file_name'] as String,
      mimeType: (map['mime_type'] as String?) ?? 'application/octet-stream',
      sizeBytes: (map['size_bytes'] as num).toInt(),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

class AttachmentValidationException implements Exception {
  const AttachmentValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

const int kMaxAttachmentBytes = 20 * 1024 * 1024; // 20 MB

const Set<String> _allowedExtensions = {
  // Images
  'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic', 'heif',
  // Videos
  'mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v',
  // PDF
  'pdf',
  // Word
  'doc', 'docx',
  // Text
  'txt', 'md', 'csv', 'log',
  // Zip
  'zip',
};

const Map<String, String> _extensionToMime = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'gif': 'image/gif',
  'webp': 'image/webp',
  'bmp': 'image/bmp',
  'heic': 'image/heic',
  'heif': 'image/heif',
  'mp4': 'video/mp4',
  'mov': 'video/quicktime',
  'avi': 'video/x-msvideo',
  'mkv': 'video/x-matroska',
  'webm': 'video/webm',
  'm4v': 'video/x-m4v',
  'pdf': 'application/pdf',
  'doc': 'application/msword',
  'docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'txt': 'text/plain',
  'md': 'text/markdown',
  'csv': 'text/csv',
  'log': 'text/plain',
  'zip': 'application/zip',
};

String resolveAttachmentMimeType(String fileName) {
  final dotIndex = fileName.lastIndexOf('.');
  if (dotIndex == -1 || dotIndex == fileName.length - 1) {
    return 'application/octet-stream';
  }
  final ext = fileName.substring(dotIndex + 1).toLowerCase();
  return _extensionToMime[ext] ?? 'application/octet-stream';
}

/// Validates file size (<= 20 MB) and allowed file extension
/// (images, videos, PDF, Word, text, zip).
/// Returns the resolved MIME type if valid, or throws [AttachmentValidationException].
String validateAttachmentFile({
  required String fileName,
  required int sizeBytes,
}) {
  final trimmed = fileName.trim();
  if (trimmed.isEmpty) {
    throw const AttachmentValidationException('Invalid file name.');
  }

  if (sizeBytes <= 0) {
    throw const AttachmentValidationException('File is empty.');
  }

  if (sizeBytes > kMaxAttachmentBytes) {
    throw const AttachmentValidationException(
      'File exceeds the 20 MB size limit.',
    );
  }

  final dotIndex = trimmed.lastIndexOf('.');
  if (dotIndex == -1 || dotIndex == trimmed.length - 1) {
    throw const AttachmentValidationException(
      'Unsupported file type. Allowed: images, videos, PDF, Word, text, and zip.',
    );
  }

  final ext = trimmed.substring(dotIndex + 1).toLowerCase();
  if (!_allowedExtensions.contains(ext)) {
    throw AttachmentValidationException(
      'Unsupported file type (.$ext). Allowed: images, videos, PDF, Word, text, and zip.',
    );
  }

  return _extensionToMime[ext] ?? 'application/octet-stream';
}