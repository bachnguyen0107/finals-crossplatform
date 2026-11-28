enum SharePermission {
  read('read'),
  edit('edit');

  const SharePermission(this.value);

  final String value;

  static SharePermission fromString(String raw) {
    return raw == 'edit' ? SharePermission.edit : SharePermission.read;
  }

  String get label => this == SharePermission.edit ? 'Can edit' : 'Can read';
}

class ShareItem {
  const ShareItem({
    required this.id,
    required this.noteId,
    required this.ownerId,
    required this.recipientId,
    required this.permission,
    required this.createdAt,
    this.recipientEmail,
  });

  final String id;
  final String noteId;
  final String ownerId;
  final String recipientId;
  final SharePermission permission;
  final DateTime createdAt;
  final String? recipientEmail;

  ShareItem copyWith({
    SharePermission? permission,
    String? recipientEmail,
  }) {
    return ShareItem(
      id: id,
      noteId: noteId,
      ownerId: ownerId,
      recipientId: recipientId,
      permission: permission ?? this.permission,
      createdAt: createdAt,
      recipientEmail: recipientEmail ?? this.recipientEmail,
    );
  }

  factory ShareItem.fromMap(Map<String, dynamic> map) {
    return ShareItem(
      id: map['id'] as String,
      noteId: map['note_id'] as String,
      ownerId: map['owner_id'] as String,
      recipientId: map['recipient_id'] as String,
      permission: SharePermission.fromString(
        (map['permission'] as String? ?? 'read').toLowerCase(),
      ),
      createdAt: DateTime.parse(map['created_at'] as String),
      recipientEmail: map['recipient_email'] as String?,
    );
  }
}

class SharedNoteItem {
  const SharedNoteItem({
    required this.shareId,
    required this.noteId,
    required this.ownerId,
    required this.sharerEmail,
    required this.sharerDisplayName,
    required this.permission,
    required this.sharedAt,
    required this.title,
    required this.content,
    required this.isPinned,
    required this.isLocked,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    this.pinnedAt,
  });

  final String shareId;
  final String noteId;
  final String ownerId;
  final String sharerEmail;
  final String sharerDisplayName;
  final SharePermission permission;
  final DateTime sharedAt;
  final String title;
  final String content;
  final bool isPinned;
  final DateTime? pinnedAt;
  final bool isLocked;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get canEdit => permission == SharePermission.edit && !isLocked;

  factory SharedNoteItem.fromMap(Map<String, dynamic> map) {
    final locked = map['is_locked'] as bool? ?? false;
    return SharedNoteItem(
      shareId: map['share_id'] as String,
      noteId: map['note_id'] as String,
      ownerId: map['owner_id'] as String,
      sharerEmail: map['sharer_email'] as String? ?? '',
      sharerDisplayName: map['sharer_display_name'] as String? ?? '',
      permission: SharePermission.fromString(
        (map['permission'] as String? ?? 'read').toLowerCase(),
      ),
      sharedAt: DateTime.parse(map['shared_at'] as String),
      title: map['title'] as String? ?? '',
      content: locked ? '' : (map['content'] as String? ?? ''),
      isPinned: map['is_pinned'] as bool? ?? false,
      pinnedAt: map['pinned_at'] != null
          ? DateTime.parse(map['pinned_at'] as String)
          : null,
      isLocked: locked,
      version: (map['version'] as num?)?.toInt() ?? 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
enum NoteAccess {
  owner,
  edit,
  read,
}