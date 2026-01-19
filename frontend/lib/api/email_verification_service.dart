import 'api_client.dart';

class EmailVerificationRequestResult {
  final String? devCode;

  const EmailVerificationRequestResult({this.devCode});

  factory EmailVerificationRequestResult.fromJson(Map<String, dynamic> json) {
    return EmailVerificationRequestResult(
      devCode: json['dev_code']?.toString(),
    );
  }
}

class EmailVerificationService {
  EmailVerificationService(this._api);

  final ApiClient _api;

  Future<EmailVerificationRequestResult> requestCode(String email) async {
    final data = await _api.postJson('/auth/verify/request',
        auth: false, body: {'email': email});
    return EmailVerificationRequestResult.fromJson(data);
  }

  Future<void> verifyCode(String email, String code) async {
    await _api.postJson('/auth/verify/confirm',
        auth: false, body: {'email': email, 'code': code});
  }
}
