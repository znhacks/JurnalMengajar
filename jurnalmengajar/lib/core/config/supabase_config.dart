/// Konfigurasi Environment Supabase
/// Memungkinkan perpindahan cepat (toggle) antara server Supabase Cloud (Legacy)
/// dan Supabase Self-Hosted (UBIG).
enum SupabaseEnvironment {
  /// Supabase Cloud Resmi / Lama (https://egcxjuudphnbjwqhhbra.supabase.co)
  cloudLegacy,

  /// Supabase Self-Hosted UBIG (https://supabase-jurnal.ubigdev.com)
  selfHostedUbig,
}

class SupabaseConfig {
  /// TOGGLE ENVIRONMENT:
  /// Ubah nilai ini untuk beralih backend database secara instan:
  /// - `SupabaseEnvironment.cloudLegacy` : Menggunakan Supabase Cloud lama
  /// - `SupabaseEnvironment.selfHostedUbig`: Menggunakan Supabase Self-Hosted UBIG
  static const SupabaseEnvironment activeEnv = SupabaseEnvironment.selfHostedUbig;

  // --------------------------------------------------------------------------
  // 1. Supabase Cloud (Legacy / Asli)
  // --------------------------------------------------------------------------
  static const String cloudUrl = 'https://egcxjuudphnbjwqhhbra.supabase.co';
  static const String cloudPublishableKey =
      'sb_publishable_8VGYplCO-QO1kTLhhEfJKw_On4QCQ4u';

  // --------------------------------------------------------------------------
  // 2. Supabase Self-Hosted UBIG
  // --------------------------------------------------------------------------
  static const String selfHostedUrl = 'https://supabase-jurnal.ubigdev.com';
  static const String selfHostedPublishableKey =
      'sb_publishable_zkT8Drvu9-q7ZKMOSm1flF_JKtqwXwG';

  // --------------------------------------------------------------------------
  // Getters
  // --------------------------------------------------------------------------
  /// URL Supabase aktif sesuai [activeEnv]
  static String get url => activeEnv == SupabaseEnvironment.selfHostedUbig
      ? selfHostedUrl
      : cloudUrl;

  /// Publishable/Anon Key Supabase aktif sesuai [activeEnv]
  static String get publishableKey =>
      activeEnv == SupabaseEnvironment.selfHostedUbig
          ? selfHostedPublishableKey
          : cloudPublishableKey;

  /// Apakah saat ini menggunakan server Self-Hosted UBIG
  static bool get isSelfHosted =>
      activeEnv == SupabaseEnvironment.selfHostedUbig;

  /// Label nama server aktif untuk logging / info
  static String get activeEnvironmentName =>
      activeEnv == SupabaseEnvironment.selfHostedUbig
          ? 'UBIG Self-Hosted (https://supabase-jurnal.ubigdev.com)'
          : 'Supabase Cloud Legacy (https://egcxjuudphnbjwqhhbra.supabase.co)';
}

