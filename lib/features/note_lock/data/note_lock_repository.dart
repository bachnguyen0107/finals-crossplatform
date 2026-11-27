import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

typedef JsonMap = Map<String, dynamic>;

/// Hàm gọi Edge Function được tách riêng để có thể giả lập (stub/mock) trong unit test.
typedef NoteLockFunctionInvoker = Future<dynamic> Function(
  String functionName, {
  JsonMap? body,
});

/// Ngoại lệ chuẩn hóa với thông báo dễ đọc cho giao diện người dùng.
class NoteLockFailure implements Exception {
  const NoteLockFailure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class NoteLockRepository {
  NoteLockRepository(
    SupabaseClient client, {
    NoteLockFunctionInvoker? invoker,
  }) : _invoker = invoker ??
            ((functionName, {body}) async {
              final response = await client.functions.invoke(
                functionName,
                body: body,
              );
              return response.data;
            });

  static const String _functionName = 'note-lock';

  final NoteLockFunctionInvoker _invoker;

  /// Khóa ghi chú với mật khẩu (>= 4 ký tự).
  Future<void> lock({
    required String noteId,
    required String password,
  }) async {
    await _callFunction(<String, dynamic>{
      'action': 'lock',
      'note_id': noteId,
      'password': password,
    });
  }

  /// Xác thực mật khẩu và lấy nội dung gốc của ghi chú đang bị khóa.
  Future<String> open({
    required String noteId,
    required String password,
  }) async {
    final data = await _callFunction(<String, dynamic>{
      'action': 'open',
      'note_id': noteId,
      'password': password,
    });

    final content = data['content'];
    if (content is! String) {
      throw const NoteLockFailure(
        'Invalid response from server when opening locked note.',
        code: 'invalid_response',
      );
    }
    return content;
  }

  /// Lưu nội dung đã chỉnh sửa vào `note_locks.locked_content` khi đang mở khóa tạm thời.
  Future<void> save({
    required String noteId,
    required String password,
    required String content,
  }) async {
    await _callFunction(<String, dynamic>{
      'action': 'save',
      'note_id': noteId,
      'password': password,
      'content': content,
    });
  }

  /// Đổi mật khẩu khóa ghi chú sau khi xác thực mật khẩu hiện tại.
  Future<void> changePassword({
    required String noteId,
    required String password,
    required String newPassword,
  }) async {
    await _callFunction(<String, dynamic>{
      'action': 'change_password',
      'note_id': noteId,
      'password': password,
      'new_password': newPassword,
    });
  }

  /// Gỡ khóa ghi chú vĩnh viễn và khôi phục nội dung về `notes.content`.
  Future<String> unlock({
    required String noteId,
    required String password,
  }) async {
    final data = await _callFunction(<String, dynamic>{
      'action': 'unlock',
      'note_id': noteId,
      'password': password,
    });

    final content = data['content'];
    return content is String ? content : '';
  }

  Future<JsonMap> _callFunction(JsonMap body) async {
    try {
      final rawData = await _invoker(_functionName, body: body);
      final map = _normalizeResponseMap(rawData);

      final errorCode = map['error']?.toString();
      if (errorCode != null && errorCode.isNotEmpty) {
        throw _mapErrorCodeToFailure(errorCode);
      }

      return map;
    } on NoteLockFailure {
      rethrow;
    } on FunctionException catch (error) {
      final detailsMap = _normalizeResponseMap(error.details);
      final errorCode = detailsMap['error']?.toString();
      if (errorCode != null && errorCode.isNotEmpty) {
        throw _mapErrorCodeToFailure(errorCode);
      }
      if (error.status == 401) {
        throw _mapErrorCodeToFailure('unauthorized');
      }
      if (error.status == 403) {
        throw _mapErrorCodeToFailure('forbidden');
      }
      throw const NoteLockFailure(
        'Unable to process note lock request. Please try again.',
      );
    } on SocketException {
      throw const NoteLockFailure(
        'Unable to connect to the server. Please check your internet connection and try again.',
        code: 'network_error',
      );
    } on TimeoutException {
      throw const NoteLockFailure(
        'Connection timed out. Please check your internet connection and try again.',
        code: 'network_error',
      );
    } catch (error) {
      if (_looksLikeNetworkError(error.toString())) {
        throw const NoteLockFailure(
          'Unable to connect to the server. Please check your internet connection and try again.',
          code: 'network_error',
        );
      }
      throw const NoteLockFailure(
        'Unable to process note lock request. Please try again.',
      );
    }
  }

  JsonMap _normalizeResponseMap(dynamic raw) {
    if (raw is JsonMap) {
      return raw;
    }
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is JsonMap) {
          return decoded;
        }
        if (decoded is Map) {
          return decoded.map((key, value) => MapEntry(key.toString(), value));
        }
      } catch (_) {
        return <String, dynamic>{};
      }
    }
    return <String, dynamic>{};
  }

  NoteLockFailure _mapErrorCodeToFailure(String code) {
    switch (code) {
      case 'wrong_password':
        return const NoteLockFailure(
          'Incorrect password',
          code: 'wrong_password',
        );
      case 'weak_password':
        return const NoteLockFailure(
          'Password must be at least 4 characters.',
          code: 'weak_password',
        );
      case 'already_locked':
        return const NoteLockFailure(
          'This note is already locked.',
          code: 'already_locked',
        );
      case 'not_locked':
        return const NoteLockFailure(
          'This note is not locked.',
          code: 'not_locked',
        );
      case 'forbidden':
        return const NoteLockFailure(
          'Only the note owner can perform this action.',
          code: 'forbidden',
        );
      case 'unauthorized':
        return const NoteLockFailure(
          'Your session has expired. Please sign in again.',
          code: 'unauthorized',
        );
      case 'not_found':
        return const NoteLockFailure(
          'Note not found.',
          code: 'not_found',
        );
      default:
        return NoteLockFailure(
          'Unable to process note lock request ($code).',
          code: code,
        );
    }
  }

  bool _looksLikeNetworkError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('socketexception') ||
        lower.contains('clientexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('failed to fetch') ||
        lower.contains('network is unreachable') ||
        lower.contains('connection refused') ||
        lower.contains('connection closed');
  }
}