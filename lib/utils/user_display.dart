import 'package:pocketbase/pocketbase.dart';

/// Resolves a display name from an *expanded* users relation record.
/// Used anywhere audit info ("added by", "changed by") is shown, so the
/// same "name, falling back to username" logic lives in one place.
class UserDisplay {
  UserDisplay._();

  static String nameFromRecord(RecordModel? userRecord) {
    if (userRecord == null) return 'Unknown';
    final name = userRecord.get<String>('name', '');
    if (name.isNotEmpty) return name;
    final username = userRecord.get<String>('username', '');
    if (username.isNotEmpty) return username;
    return userRecord.get<String>('email', 'Unknown');
  }
}