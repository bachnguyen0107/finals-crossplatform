import 'package:finals/features/ai/data/ai_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late SupabaseClient dummyClient;

  setUp(() {
    dummyClient = SupabaseClient('https://example.supabase.co', 'anon-key');
  });

  group('AiRepository.summarize', () {
    test('returns summary string when ai-summary succeeds', () async {
      String? calledFunction;
      JsonMap? sentBody;

      final repo = AiRepository(
        dummyClient,
        invoker: (functionName, {body}) async {
          calledFunction = functionName;
          sentBody = body;
          return <String, dynamic>{
            'summary': '- Bullet one\n- Bullet two',
          };
        },
      );

      final result = await repo.summarize('note-123');

      expect(calledFunction, 'ai-summary');
      expect(sentBody, <String, dynamic>{'note_id': 'note-123'});
      expect(result, '- Bullet one\n- Bullet two');
    });

    test('maps locked error to AiFailure', () async {
      final repo = AiRepository(
        dummyClient,
        invoker: (functionName, {body}) async {
          throw const FunctionException(
            status: 400,
            details: <String, dynamic>{'error': 'locked'},
          );
        },
      );

      await expectLater(
        () => repo.summarize('note-123'),
        throwsA(
          isA<AiFailure>().having(
            (e) => e.message,
            'message',
            'Unlock the note to summarize it.',
          ),
        ),
      );
    });

    test('maps too_short error to AiFailure', () async {
      final repo = AiRepository(
        dummyClient,
        invoker: (functionName, {body}) async {
          throw const FunctionException(
            status: 400,
            details: <String, dynamic>{'error': 'too_short'},
          );
        },
      );

      await expectLater(
        () => repo.summarize('note-123'),
        throwsA(
          isA<AiFailure>().having(
            (e) => e.message,
            'message',
            'This note is too short to summarize.',
          ),
        ),
      );
    });

    test('maps not_found error to AiFailure', () async {
      final repo = AiRepository(
        dummyClient,
        invoker: (functionName, {body}) async {
          throw const FunctionException(
            status: 404,
            details: <String, dynamic>{'error': 'not_found'},
          );
        },
      );

      await expectLater(
        () => repo.summarize('note-123'),
        throwsA(
          isA<AiFailure>().having(
            (e) => e.message,
            'message',
            'This note could not be found.',
          ),
        ),
      );
    });

    test('maps ai_failed error to AiFailure', () async {
      final repo = AiRepository(
        dummyClient,
        invoker: (functionName, {body}) async {
          throw const FunctionException(
            status: 502,
            details: '{"error":"ai_failed"}',
          );
        },
      );

      await expectLater(
        () => repo.summarize('note-123'),
        throwsA(
          isA<AiFailure>().having(
            (e) => e.message,
            'message',
            'The AI could not summarize this note. Please try again.',
          ),
        ),
      );
    });

    test('maps network/generic Exception to connection AiFailure', () async {
      final repo = AiRepository(
        dummyClient,
        invoker: (functionName, {body}) async {
          throw Exception('Network unreachable');
        },
      );

      await expectLater(
        () => repo.summarize('note-123'),
        throwsA(
          isA<AiFailure>().having(
            (e) => e.message,
            'message',
            'Unable to reach the server. Check your connection and try again.',
          ),
        ),
      );
    });
  });
}