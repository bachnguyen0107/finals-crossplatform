class Env {
  const Env._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  static void validate() {
    final missing = <String>[];
    if (supabaseUrl.trim().isEmpty) {
      missing.add('SUPABASE_URL');
    }
    if (supabaseAnonKey.trim().isEmpty) {
      missing.add('SUPABASE_ANON_KEY');
    }

    if (missing.isNotEmpty) {
      throw StateError(
        'Missing required environment variable(s): ${missing.join(', ')}.\n'
        'Run the app with:\n'
        'flutter run --dart-define=SUPABASE_URL=<your_url> --dart-define=SUPABASE_ANON_KEY=<your_anon_key>',
      );
    }
  }
}
