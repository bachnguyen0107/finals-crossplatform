import 'dart:async';

enum SaveStatus { idle, saving, saved, failed }

class AutoSaver {
  AutoSaver({
    required this.save,
    this.delay = const Duration(milliseconds: 800),
    this.onStatusChanged,
  });

  final Future<void> Function() save;
  final Duration delay;
  final void Function(SaveStatus status)? onStatusChanged;

  Timer? _timer;
  Future<void>? _running;
  bool _dirty = false;
  SaveStatus _status = SaveStatus.idle;

  SaveStatus get status => _status;
  bool get hasUnsavedChanges => _dirty || _running != null;

  void markChanged() {
    _dirty = true;
    _timer?.cancel();
    _timer = Timer(delay, () => unawaited(flush()));
  }

  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    while (_running != null) {
      await _running;
    }
    if (!_dirty) return;

    _dirty = false;
    final run = _saveOnce();
    _running = run;
    try {
      await run;
    } finally {
      _running = null;
    }
    if (_dirty && _status != SaveStatus.failed) {
      await flush();
    }
  }

  Future<void> _saveOnce() async {
    _setStatus(SaveStatus.saving);
    try {
      await save();
      if (!_dirty) _setStatus(SaveStatus.saved);
    } catch (_) {
      _dirty = true; 
      _setStatus(SaveStatus.failed);
    }
  }

  void _setStatus(SaveStatus status) {
    if (_status == status) return;
    _status = status;
    onStatusChanged?.call(status);
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}