import 'package:skp_admin/core/network/api_client.dart';

class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  Future<String> login({required String email, required String password}) async {
    final body = await _api.post(
      '/auth/admin/login',
      body: {'email': email.trim(), 'password': password},
    );
    final token = body['accessToken'];
    if (token is! String || token.isEmpty) {
      throw const ApiException('Login did not return a token');
    }
    return token;
  }
}
