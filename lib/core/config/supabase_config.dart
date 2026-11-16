import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://yotczaajzxlzksaawwfq.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_TpttKp4Z4xdL13Y3b57G-g_lPMdraco',
  );

  static bool _isInitialized = false;

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      !supabaseUrl.contains('your-project');

  static bool get isLiveConnected => _isInitialized && isConfigured;

  static Future<void> initializeIfConfigured() async {
    if (!isConfigured || _isInitialized) return;
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: supabaseAnonKey,
      );
      _isInitialized = true;
    } catch (_) {
      _isInitialized = false;
    }
  }

  static SupabaseClient? get clientOrNull =>
      _isInitialized ? Supabase.instance.client : null;
}
