import 'dart:convert';

import 'package:http/http.dart' as http;

import 'backend_config.dart';

class AlertRecipientService {
  // Keep client validation aligned with backend/server.py.
  static final RegExp _emailRegex = RegExp(
    r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$',
  );

  bool isValidEmail(String email) => _emailRegex.hasMatch(email.trim());

  Future<List<String>> listRecipients() async {
    final uri = Uri.parse('${BackendConfig.baseUrl}/alert_recipients');
    final resp = await http.get(uri).timeout(const Duration(seconds: 4));
    if (resp.statusCode != 200) {
      throw Exception('Failed to load recipients: HTTP ${resp.statusCode}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList(growable: false);
    return items;
  }

  Future<String> addRecipient(String email) async {
    final trimmed = email.trim();
    if (!isValidEmail(trimmed)) throw Exception('Invalid email');

    final uri = Uri.parse('${BackendConfig.baseUrl}/alert_recipients');
    final resp = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': trimmed}),
        )
        .timeout(const Duration(seconds: 4));

    if (resp.statusCode != 201 &&
        resp.statusCode != 200 &&
        resp.statusCode != 409) {
      if (resp.statusCode == 400) {
        throw Exception('Invalid email');
      }
      throw Exception('Failed to add recipient: HTTP ${resp.statusCode}');
    }

    try {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final status = data['status']?.toString();
      if (status == 'exists' || status == 'added') return status!;
    } catch (_) {}
    return resp.statusCode == 201 ? 'added' : 'exists';
  }

  Future<void> removeRecipient(String email) async {
    final trimmed = email.trim();
    if (!isValidEmail(trimmed)) throw Exception('Invalid email');

    final uri = Uri.parse('${BackendConfig.baseUrl}/alert_recipients');
    final resp = await http
        .delete(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': trimmed}),
        )
        .timeout(const Duration(seconds: 4));

    if (resp.statusCode != 200 && resp.statusCode != 404) {
      throw Exception('Failed to remove recipient: HTTP ${resp.statusCode}');
    }
  }

  Future<void> sendTestEmail() async {
    final uri = Uri.parse('${BackendConfig.baseUrl}/test_alert_email');
    final resp = await http.post(uri).timeout(const Duration(seconds: 8));
    if (resp.statusCode != 200) {
      final backendError = _extractBackendError(resp.body);
      if (backendError.isNotEmpty) {
        throw Exception('Test email failed: $backendError');
      }
      throw Exception('Test email failed: HTTP ${resp.statusCode}');
    }
  }

  Future<void> sendLatestEvidence() async {
    final uri = Uri.parse('${BackendConfig.baseUrl}/send_latest_evidence');
    final resp = await http.post(uri).timeout(const Duration(seconds: 8));
    if (resp.statusCode != 200) {
      final backendError = _extractBackendError(resp.body);
      if (backendError.isNotEmpty) {
        throw Exception('Send latest failed: $backendError');
      }
      throw Exception('Send latest failed: HTTP ${resp.statusCode}');
    }
  }
}
  String _extractBackendError(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final err = data['error']?.toString();
      if (err != null && err.trim().isNotEmpty) return err;
    } catch (_) {}
    return body.trim();
  }
