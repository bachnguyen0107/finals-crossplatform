import 'dart:async';
import 'dart:io';

import 'package:finals/features/note_lock/data/note_lock_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late SupabaseClient dummyClient;

  setUp(() {
    dummyClient = SupabaseClient('https://example.supabase.co', 'anon-key');
  });

  group('NoteLockRepository actions', () {
    test('lock sends expected payload and succeeds', () async {
      String? calledFunction;
      JsonMap? sentBody;

      final repo = NoteLockRepository(
        dummyClient,
        invoker: (functionName, {body}) async {
          calledFunction = functionName;
          sentBody = body;
          return <String, dynamic>{'ok': true};
        },
      );

      await repo.lock(noteId: 'note-1', password: 'secret');

      expect(calledFunction, 'note-lock');
      expect(sentBody, <String, dynamic>{
        'action': 'lock',
        'note_id': 'note-1',
        'password': 'secret',
      });
    });

    test('open returns decrypted content string', () async {
      final repo = NoteLockRepository(
        dummyClient,
        invoker: (functionName, {body}) async {
          expect(body?['action'], 'open');
          return <String, dynamic>{'content': 'Hidden note body'};
        },
      );

      final content = await repo.open(noteId: 'note-1', password: 'secret');
      expect(content, 'Hidden note body');
    });

    test('save, changePassword, and unlock send expected payloads', () async {
      final calls = <JsonMap>[];

      final repo = NoteLockRepository(
        dummyClient,
        invoker: (functionName, {body}) async {
          calls.add(JsonMap.from(body ?? <String, dynamic>{}));
          return <String, dynamic>{'ok': true, 'content': 'Restored body'};
        },
      );

      await repo.save(
        noteId: 'note-1',
        password: 'secret',
        content: 'Updated body',
      );
      await repo.changePassword(
        noteId: 'note-1',
        password: 'secret',
        newPassword: 'new-secret',
      );
      final restored = await repo.unlock(
        noteId: 'note-1',
        password: 'new-secret',
      );

      expect(restored, 'Restored body');
      expect(calls[0]['action'], 'save');
      expect(calls[0]['content'], 'Updated body');
      expect(calls[1]['action'], 'change_password');
      expect(calls[1]['new_password'], 'new-secret');
      expect(calls[2]['action'], 'unlock');
    });
  });

  group('NoteLockRepository error mapping', () {
    test('maps wrong_password FunctionException to Incorrect password', () async {
      final repo = NoteLockRepository(
        dummyClient,
        invoker: (functionName, {body}) async {
          throw const FunctionException(
            status: 400,
            details: <String, dynamic>{'error': 'wrong_password'},
          );
        },
      );

      await expectLater(
        () => repo.open(noteId: 'note-1', password: 'wrong'),
        throwsA(
          isA<NoteLockFailure>()
              .having((e) => e.message, 'message', 'Incorrect password')
              .having((e) => e.code, 'code', 'wrong_password'),
        ),
      );
    });

    test('maps JSON string details with wrong_password correctly', () async {
      final repo = NoteLockRepository(
        dummyClient,
        invoker: (functionName, {body}) async {
          throw const FunctionException(
            status: 400,
            details: '{"error":"wrong_password"}',
          );
        },
      );

      await expectLater(
        () => repo.unlock(noteId: 'note-1', password: 'wrong'),
        throwsA(
          isA<NoteLockFailure>()
              .having((e) => e.message, 'message', 'Incorrect password'),
        ),
      );
    });

    test('maps forbidden error to owner-only message', () async {
      final repo = NoteLockRepository(
        dummyClient,
        invoker: (functionName, {body}) async {
          throw const FunctionException(
            status: 403,
            details: <String, dynamic>{'error': 'forbidden'},
          );
        },
      );

      await expectLater(
        () => repo.lock(noteId: 'note-1', password: 'secret'),
        throwsA(
          isA<NoteLockFailure>().having(
            (e) => e.message,
            'message',
            'Only the note owner can perform this action.',
          ),
        ),
      );
    });

    test('maps SocketException to friendly network error', () async {
      final repo = NoteLockRepository(
        dummyClient,
        invoker: (functionName, {body}) async {
          throw const SocketException('Failed host lookup');
        },
      );

      await expectLater(
        () => repo.open(noteId: 'note-1', password: 'secret'),
        throwsA(
          isA<NoteLockFailure>()
              .having(
                (e) => e.message,
                'message',
                'Unable to connect to the server. Please check your internet connection and try again.',
              )
              .having((e) => e.code, 'code', 'network_error'),
        ),
      );
    });

    test('maps TimeoutException to friendly network error', () async {
      final repo = NoteLockRepository(
        dummyClient,
        invoker: (functionName, {body}) async {
          throw TimeoutException('Request timed out');
        },
      );

      await expectLater(
        () => repo.save(
          noteId: 'note-1',
          password: 'secret',
          content: 'Body',
        ),
        throwsA(
          isA<NoteLockFailure>()
              .having(
                (e) => e.message,
                'message',
                'Connection timed out. Please check your internet connection and try again.',
              )
              .having((e) => e.code, 'code', 'network_error'),
        ),
      );
    });
  });
}