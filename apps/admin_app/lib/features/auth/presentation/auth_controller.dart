import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skp_admin/core/auth/jwt_utils.dart';
import 'package:skp_admin/core/network/api_client.dart';
import 'package:skp_admin/features/auth/data/auth_repository.dart';

const adminTokenPrefsKey = 'skp_admin_token';

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient();
  ref.onDispose(client.close);
  return client;
});

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider)),
);

class StaffAuthState {
  const StaffAuthState({
    this.token,
    this.role,
    this.error,
    this.loading = false,
    this.restoring = false,
  });

  final String? token;
  final String? role;
  final String? error;
  final bool loading;
  final bool restoring;

  bool get isAuthenticated => token != null && token!.isNotEmpty && !isJwtExpired(token!);

  bool get canWrite => staffCanWrite(role);
}

class StaffAuthNotifier extends Notifier<StaffAuthState> {
  @override
  StaffAuthState build() {
    ref.read(apiClientProvider).onUnauthorized = () {
      unawaited(logout());
    };
    Future.microtask(restoreSession);
    return const StaffAuthState(restoring: true);
  }

  Future<void> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(adminTokenPrefsKey);
      if (token != null && token.isNotEmpty && !isJwtExpired(token)) {
        ref.read(apiClientProvider).setAccessToken(token);
        state = StaffAuthState(token: token, role: roleFromToken(token));
      } else {
        if (token != null) await prefs.remove(adminTokenPrefsKey);
        ref.read(apiClientProvider).setAccessToken(null);
        state = const StaffAuthState();
      }
    } catch (_) {
      ref.read(apiClientProvider).setAccessToken(null);
      state = const StaffAuthState();
    }
  }

  Future<void> login(String email, String password) async {
    state = StaffAuthState(loading: true);
    try {
      ref.read(apiClientProvider).setAccessToken(null);
      final token = await ref.read(authRepositoryProvider).login(
        email: email,
        password: password,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(adminTokenPrefsKey, token);
      ref.read(apiClientProvider).setAccessToken(token);
      state = StaffAuthState(token: token, role: roleFromToken(token));
    } on ApiException catch (error) {
      state = StaffAuthState(error: error.message);
    } catch (_) {
      state = const StaffAuthState(error: 'Login failed');
    }
  }

  Future<void> logout() async {
    ref.read(apiClientProvider).setAccessToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(adminTokenPrefsKey);
    state = const StaffAuthState();
  }
}

final staffAuthProvider = NotifierProvider<StaffAuthNotifier, StaffAuthState>(
  StaffAuthNotifier.new,
);
