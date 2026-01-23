import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../api/r2v_api.dart';

class OAuthCallbackScreen extends StatefulWidget {
  const OAuthCallbackScreen({super.key});

  @override
  State<OAuthCallbackScreen> createState() => _OAuthCallbackScreenState();
}

class _OAuthCallbackScreenState extends State<OAuthCallbackScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _handleCallback();
  }

  Future<void> _handleCallback() async {
    if (!kIsWeb) {
      setState(() => _error = 'OAuth callback is only available on web.');
      return;
    }

    final uri = Uri.base;
    final fragment = uri.fragment;
    final fragmentUri = _parseFragment(fragment);

    final params = {
      ...uri.queryParameters,
      ...fragmentUri.queryParameters,
    };

    final accessToken = params['access_token'];
    final refreshToken = params['refresh_token'];
    final error = params['error'];
    final errorDescription = params['error_description'];

    if (error != null && error.isNotEmpty) {
      setState(() => _error = errorDescription ?? error);
      return;
    }

    if (accessToken == null || refreshToken == null) {
      setState(() => _error = 'Missing authentication tokens.');
      return;
    }

    await r2vApiClient.tokenStore.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      persist: true,
    );

    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
  }

  Uri _parseFragment(String fragment) {
    if (fragment.isEmpty) {
      return Uri();
    }

    final normalized = fragment.startsWith('/') ? fragment : '/$fragment';
    return Uri.parse('https://callback.local$normalized');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: _error == null
            ? const CircularProgressIndicator(color: Colors.white)
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/signin',
                        (_) => false,
                      ),
                      child: const Text('Back to Sign In'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
