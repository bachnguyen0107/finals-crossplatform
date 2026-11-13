class Note {
  const Note({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.content,
    required this.isPinned,
    required this.pinnedAt,
    required this.isLocked,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as String,
      ownerId: map['owner_id'] as String,
      title: map['title'] as String? ?? '',
      content: map['content'] as String? ?? '',
      isPinned: map['is_pinned'] as bool? ?? false,
      pinnedAt: _parseDate(map['pinned_at']),
      isLocked: map['is_locked'] as bool? ?? false,
      version: (map['version'] as num?)?.toInt() ?? 1,
      createdAt: _parseDate(map['created_at'])!,
      updatedAt: _parseDate(map['updated_at'])!,
    );
  }

  final String id;
  final String ownerId;
  final String title;
  final String content;
  final bool isPinned;
  final DateTime? pinnedAt;
  final bool isLocked;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    return DateTime.parse(value as String).toUtc();
  }
}

// Pinned notes stay at the top,if multiple -> most recently pinned first.
// Other notes: most recently modified first.
List<Note> sortNotes(Iterable<Note> notes) {
  int byId(Note a, Note b) => a.id.compareTo(b.id);

  final pinned = notes.where((n) => n.isPinned).toList()
    ..sort((a, b) {
      final timeA = a.pinnedAt ?? a.updatedAt;
      final timeB = b.pinnedAt ?? b.updatedAt;
      final result = timeB.compareTo(timeA);
      return result != 0 ? result : byId(a, b);
    });

  final others = notes.where((n) => !n.isPinned).toList()
    ..sort((a, b) {
      final result = b.updatedAt.compareTo(a.updatedAt);
      return result != 0 ? result : byId(a, b);
    });

  return [...pinned, ...others];
}