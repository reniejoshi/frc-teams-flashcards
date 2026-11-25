import 'dart:convert';

import 'package:http/http.dart' as http;

class Team {
  const Team({required this.number, required this.nickname});

  final int number;
  final String nickname;

  factory Team.fromJson(Map<String, dynamic> json) {
    final number = json['team_number'];
    if (number is! int) {
      throw const FormatException('Team response has no team number');
    }

    final nickname =
        json['nickname'] as String? ??
        json['name'] as String? ??
        'Team $number';
    return Team(number: number, nickname: nickname);
  }
}

class TeamApiException implements Exception {
  const TeamApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class TeamApi {
  static const _configuredBaseUrl = String.fromEnvironment('TEAM_API_BASE_URL');

  TeamApi({required Uri teamServiceBaseUrl, http.Client? client})
    : _baseUrl = teamServiceBaseUrl,
      _client = client ?? http.Client();

  TeamApi.fromEnvironment({http.Client? client})
    : _baseUrl = Uri.tryParse(_configuredBaseUrl),
      _client = client ?? http.Client();

  final Uri? _baseUrl;
  final http.Client _client;

  Future<Team> fetchRandomTeam() async {
    final baseUrl = _baseUrl;
    if (baseUrl == null ||
        !baseUrl.hasAuthority ||
        (baseUrl.scheme != 'https' && baseUrl.scheme != 'http')) {
      throw const TeamApiException(
        'Set TEAM_API_BASE_URL to the deployed team service URL.',
      );
    }

    final response = await _client
        .get(baseUrl.resolve('/random-team'))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw TeamApiException(
        'Team service returned HTTP ${response.statusCode}. Try again.',
      );
    }

    try {
      final payload = jsonDecode(response.body);
      if (payload is! Map) {
        throw const FormatException('Team response is not an object');
      }
      return Team.fromJson(Map<String, dynamic>.from(payload));
    } on FormatException {
      throw const TeamApiException('Team service returned invalid data.');
    }
  }

  void close() => _client.close();
}
