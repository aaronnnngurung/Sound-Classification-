import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/false_negative_report.dart';

class ApiService {
  final String baseUrl;
  String? _authToken;

  ApiService({required this.baseUrl});

  void setAuthToken(String token) {
    _authToken = token;
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_authToken != null) 'Authorization': 'Bearer $_authToken',
  };

  Future<void> submitFalseNegativeReport(FalseNegativeReport report) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/reports/false-negative'),
      headers: _headers,
      body: jsonEncode(report.toJson()),
    );

    if (response.statusCode != 201) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? 'Failed to submit report');
    }
  }
}
