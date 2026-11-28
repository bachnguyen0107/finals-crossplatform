import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

typedef JsonMap = Map<String, dynamic>;

/// Hàm gọi Edge Function được tách riêng để có thể giả lập trong unit test.
typedef AiFunctionInvoker = Future<dynamic> Function(
  String functionName, {
  JsonMap? body,
});

/// Ngoại lệ chuẩn hóa với thông báo thân thiện cho người dùng khi tóm tắt AI lỗi.
class AiFailure implements Exception {
  const AiFailure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class AiRepository {
  AiRepository(
    SupabaseClient client, {
    AiFunctionInvoker? invoker,
  }) : _invoker = invoker ??
            ((functionName, {body}) async {
              final response = await client.functions.invoke(
                functionName,
                body: body,
              );
              return response.data;
            });

  static const String _functionName = 'ai-summary';

  final AiFunctionInvoker _invoker;

  /// Gọi Edge Function `ai-summary` để tóm tắt nội dung ghi chú.
  Future<String> summarize(String noteId) async {
    try {
      final rawData = await _invoker(
        _functionName,
        body: <String, dynamic>{'note_id': noteId},
      );
      final map = _normalizeResponseMap(rawData);

      final errorCode = map['error']?.toString();
      if (errorCode != null && errorCode.isNotEmpty) {
        throw _mapErrorCodeToFailure(errorCode);
      }

      final summary = map['summary'];
      if (summary is! String || summary.trim().isEmpty) {
        throw _mapErrorCodeToFailure('ai_failed');
      }

      return summary;
    } on AiFailure {
      rethrow;
    } on FunctionException catch (error) {
      final detailsMap = _normalizeResponseMap(error.details);
      final errorCode = detailsMap['error']?.toString();
      if (errorCode != null && errorCode.isNotEmpty) {
        throw _mapErrorCodeToFailure(errorCode);
      }
      if (error.status == 404) {
        throw _mapErrorCodeToFailure('not_found');
      }
      if (error.status == 502) {
        throw _mapErrorCodeToFailure('ai_failed');
      }
      throw const AiFailure(
        'Unable to reach the server. Check your connection and try again.',
        code: 'network_error',
      );
    } on SocketException {
      throw const AiFailure(
        'Unable to reach the server. Check your connection and try again.',
        code: 'network_error',
      );
    } on TimeoutException {
      throw const AiFailure(
        'Unable to reach the server. Check your connection and try again.',
        code: 'network_error',
      );
    } catch (_) {
      throw const AiFailure(
        'Unable to reach the server. Check your connection and try again.',
        code: 'network_error',
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

  AiFailure _mapErrorCodeToFailure(String code) {
    switch (code) {
      case 'locked':
        return const AiFailure(
          'Unlock the note to summarize it.',
          code: 'locked',
        );
      case 'too_short':
        return const AiFailure(
          'This note is too short to summarize.',
          code: 'too_short',
        );
      case 'not_found':
        return const AiFailure(
          'This note could not be found.',
          code: 'not_found',
        );
      case 'ai_failed':
        return const AiFailure(
          'The AI could not summarize this note. Please try again.',
          code: 'ai_failed',
        );
      default:
        return const AiFailure(
          'Unable to reach the server. Check your connection and try again.',
          code: 'network_error',
        );
    }
  }
}