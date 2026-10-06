import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.uncertain = false});
  final String message;
  final bool uncertain;
  @override
  String toString() => message;
}

abstract interface class DiaryRepository {
  Future<DayData> getDay(DateTime day);
  Future<Trip> createTrip(Map<String, dynamic> payload);
}

class DiaryApi implements DiaryRepository {
  DiaryApi({http.Client? client, String? baseUrl, Duration? readTimeout})
    : _client = client ?? http.Client(),
      _readTimeout =
          readTimeout ??
          const Duration(
            seconds: int.fromEnvironment(
              'API_READ_TIMEOUT_SECONDS',
              defaultValue: 15,
            ),
          ),
      _baseUrl =
          (baseUrl ??
                  const String.fromEnvironment(
                    'API_BASE_URL',
                    defaultValue: 'http://localhost:8000',
                  ))
              .replaceFirst(RegExp(r'/$'), '');
  final http.Client _client;
  final String _baseUrl;
  final Duration _readTimeout;

  Future<http.Response> _request(
    Future<http.Response> Function() send, {
    bool mutation = false,
  }) async {
    try {
      final response = await send().timeout(
        mutation ? const Duration(seconds: 15) : _readTimeout,
      );
      if (response.statusCode >= 500) {
        throw ApiException(
          mutation
              ? 'Сервер не подтвердил сохранение. Повторите отправку этой поездки.'
              : 'Сервер временно недоступен. Попробуйте ещё раз.',
          uncertain: mutation,
        );
      }
      return response;
    } on TimeoutException {
      throw ApiException(
        mutation
            ? 'Ответ не получен. Поездка могла сохраниться — повторите ту же отправку.'
            : 'Сервер не ответил вовремя. Попробуйте ещё раз.',
        uncertain: mutation,
      );
    } on http.ClientException {
      throw ApiException(
        mutation
            ? 'Связь прервалась. Повторите отправку, данные поездки сохранены в форме.'
            : 'Не удалось подключиться. Проверьте соединение и повторите попытку.',
        uncertain: mutation,
      );
    }
  }

  @override
  Future<DayData> getDay(DateTime day) async {
    final response = await _request(
      () => _client.get(Uri.parse('$_baseUrl/api/days/${dateKey(day)}')),
    );
    if (response.statusCode != 200) {
      throw const ApiException('Не удалось загрузить выбранный день.');
    }
    try {
      final data = DayData.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
      if (dateKey(data.date) != dateKey(day)) {
        throw const FormatException('Date mismatch');
      }
      return data;
    } on Object {
      throw const ApiException(
        'Сервер вернул некорректные данные. Повторите загрузку.',
      );
    }
  }

  @override
  Future<Trip> createTrip(Map<String, dynamic> payload) async {
    final response = await _request(
      () => _client.post(
        Uri.parse('$_baseUrl/api/trips'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ),
      mutation: true,
    );
    if (response.statusCode == 409) {
      throw const ApiException(
        'Этот идентификатор уже занят другой поездкой. Проверьте список.',
      );
    }
    if (response.statusCode == 422) {
      throw const ApiException(
        'Проверьте сумму, комиссию и время поездки. Сервер отклонил данные.',
      );
    }
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ApiException(
        'Не удалось подтвердить сохранение. Повторите отправку.',
        uncertain: response.statusCode >= 500,
      );
    }
    try {
      return Trip.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } on Object {
      throw const ApiException(
        'Ответ о сохранении не удалось прочитать. Повторите ту же отправку.',
        uncertain: true,
      );
    }
  }
}
