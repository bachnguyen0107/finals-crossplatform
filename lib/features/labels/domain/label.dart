import 'package:flutter/foundation.dart';

@immutable
class Label {
  const Label({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.createdAt,
  });

  final String id;
  final String ownerId;
  final String name;
  final DateTime createdAt;

  factory Label.fromMap(Map<String, dynamic> map) {
    return Label(
      id: map['id'] as String,
      ownerId: map['owner_id'] as String,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'owner_id': ownerId,
      'name': name,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Validates a label name.
/// Returns an error message string if invalid, or null if valid.
String? validateLabelName(String? name) {
  if (name == null) {
    return 'Label name cannot be empty.';
  }
  final trimmed = name.trim();
  if (trimmed.isEmpty) {
    return 'Label name cannot be empty.';
  }
  if (trimmed.length > 40) {
    return 'Label name cannot exceed 40 characters.';
  }
  return null;
}