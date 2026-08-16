/// PocketBase collection names.
class Collections {
  Collections._();

  static const units = 'units';
  static const allottees = 'allottees';
  static const allotments = 'allotments';
  static const payments = 'payments';
  static const allotteeModifications = 'allottee_modifications';
  static const auditLog = 'audit_log';
  static const users = 'users';
}

class UserRole {
  UserRole._();

  static const admin = 'admin';
}

class AppDefaults {
  AppDefaults._();

  /// Pre-filled but editable in Settings.
  static const defaultServerUrl = 'http://192.168.1.50:8090';

  /// Retirement threshold used to auto-derive an allottee's service status
  /// from their date of birth. Strictly greater than, per spec.
  static const retirementAge = 60;
}

class PrefsKeys {
  PrefsKeys._();

  static const serverUrl = 'server_url';
  static const pbAuthStore = 'pb_auth_store';
}