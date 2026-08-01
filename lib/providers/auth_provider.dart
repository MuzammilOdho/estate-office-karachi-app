import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';

import '../config/constants.dart';
import '../services/pocketbase_service.dart';
import '../utils/app_exception.dart';

class AuthProvider extends ChangeNotifier {
  StreamSubscription<AuthStoreEvent>? _subscription;

  bool get isLoggedIn => PocketBaseService.instance.client.authStore.isValid;

  String get staffDisplayName {
    final record = PocketBaseService.instance.client.authStore.record;
    if (record == null) return '';
    final name = record.get<String>('name', '');
    if (name.isNotEmpty) return name;
    return record.get<String>('username', record.get<String>('email', ''));
  }

  /// Whether the logged-in account has the admin role. Gates the
  /// activity/audit log and allottee modification history screens —
  /// everyday actions (adding units/payments, allotting, modifying
  /// allottee info) remain open to any authenticated staff account.
  bool get isAdmin {
    final record = PocketBaseService.instance.client.authStore.record;
    return record?.get<String>('role', '') == UserRole.admin;
  }

  void attach() {
    _subscription?.cancel();
    _subscription =
        PocketBaseService.instance.client.authStore.onChange.listen((_) {
          notifyListeners();
        });
  }

  Future<void> login({required String identity, required String password}) async {
    try {
      await PocketBaseService.instance.client
          .collection(Collections.users)
          .authWithPassword(identity.trim(), password);
    } catch (e) {
      throw asAppException(e);
    }
    notifyListeners();
  }

  void logout() {
    PocketBaseService.instance.logout();
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}