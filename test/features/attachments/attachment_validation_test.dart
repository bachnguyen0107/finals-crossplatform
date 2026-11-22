import 'package:finals/features/attachments/domain/attachment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validateAttachmentFile', () {
    test('accepts allowed types within 20 MB limit', () {
      expect(
        validateAttachmentFile(fileName: 'photo.png', sizeBytes: 500 * 1024),
        'image/png',
      );
      expect(
        validateAttachmentFile(fileName: 'clip.mp4', sizeBytes: 10 * 1024 * 1024),
        'video/mp4',
      );
      expect(
        validateAttachmentFile(fileName: 'lecture.pdf', sizeBytes: 2 * 1024 * 1024),
        'application/pdf',
      );
      expect(
        validateAttachmentFile(
          fileName: 'report.docx',
          sizeBytes: 1024 * 1024,
        ),
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      );
      expect(
        validateAttachmentFile(fileName: 'notes.txt', sizeBytes: 128),
        'text/plain',
      );
      expect(
        validateAttachmentFile(fileName: 'archive.zip', sizeBytes: kMaxAttachmentBytes),
        'application/zip',
      );
    });

    test('rejects files over 20 MB or empty/invalid size', () {
      expect(
        () => validateAttachmentFile(
          fileName: 'big.zip',
          sizeBytes: kMaxAttachmentBytes + 1,
        ),
        throwsA(isA<AttachmentValidationException>()),
      );
      expect(
        () => validateAttachmentFile(fileName: 'empty.txt', sizeBytes: 0),
        throwsA(isA<AttachmentValidationException>()),
      );
      expect(
        () => validateAttachmentFile(fileName: 'neg.txt', sizeBytes: -10),
        throwsA(isA<AttachmentValidationException>()),
      );
    });

    test('rejects disallowed extensions or missing extension', () {
      expect(
        () => validateAttachmentFile(fileName: 'malware.exe', sizeBytes: 1024),
        throwsA(isA<AttachmentValidationException>()),
      );
      expect(
        () => validateAttachmentFile(fileName: 'script.sh', sizeBytes: 1024),
        throwsA(isA<AttachmentValidationException>()),
      );
      expect(
        () => validateAttachmentFile(fileName: 'noextension', sizeBytes: 1024),
        throwsA(isA<AttachmentValidationException>()),
      );
    });
  });
}