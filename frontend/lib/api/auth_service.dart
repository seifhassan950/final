import 'api_client.dart';

class AuthService {
  AuthService(this._api);

  final ApiClient _api;

  Future<void> signup({
    required String email,
    required String password,
    required String username,
    bool persist = true,
  }) async {
    final data = await _api.postJson('/auth/signup', auth: false, body: {
      'email': email,
      'password': password,
      'username': username,
    });

    await _api.tokenStore.saveTokens(
      accessToken: (data['access_token'] ?? '').toString(),
      refreshToken: (data['refresh_token'] ?? '').toString(),
      persist: persist,
    );
  }

  Future<void> login({
    required String email,
    required String password,
    bool persist = true,
  }) async {
    final data = await _api.postJson('/auth/login', auth: false, body: {
      'email': email,
      'password': password,
    });

    await _api.tokenStore.saveTokens(
      accessToken: (data['access_token'] ?? '').toString(),
      refreshToken: (data['refresh_token'] ?? '').toString(),
      persist: persist,
    );
  }

  Future<void> logout() async {
    // Backend supports /auth/logout but it needs refresh_token. We'll call it if present.
    final rt = await _api.tokenStore.getRefreshToken();
    if (rt != null && rt.isNotEmpty) {
      try {
        await _api.postJson('/auth/logout', auth: false, body: {'refresh_token': rt});
      } catch (_) {
        // ignore network/logout errors; we'll still clear locally
      }
    }
    await _api.tokenStore.clear();
  }

  Future<Map<String, dynamic>> me() async {
    return _api.getJson('/me', auth: true);
  }

  Future<void> changePassword(String newPassword) async {
    await _api.postJson('/auth/password/change', auth: true, body: {
      'new_password': newPassword,
    });
  }
}
