import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class WeatherException implements Exception {
  final String message;

  WeatherException(this.message);
}

/*
{
  "results": [
    {
      "id": 1503772,
      "name": "Ханты-Мансийск",
      "country": "Россия",
      "latitude": 61.00187,
      "longitude": 69.02728
    }
  ]
}
*/

class WeatherApiClient {
  final http.Client client;

  WeatherApiClient({http.Client? client}) : client = client ?? http.Client();

  Future<Map<String, dynamic>> getJson(Uri address) async {
    try {
      final response = await client
          .get(address)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 404) {
        throw WeatherException('Сервис не нашёл запрошенный адрес (HTTP 404).');
      }
      if (response.statusCode >= 500) {
        throw WeatherException(
          'Ошибка погодного сервиса (HTTP ${response.statusCode}). Попробуйте позже.',
        );
      }
      if (response.statusCode == 429) {
        throw WeatherException(
          'Слишком много запросов. Подождите немного и повторите.',
        );
      }
      if (response.statusCode != 200) {
        throw WeatherException(
          'Не удалось получить данные (HTTP ${response.statusCode}).',
        );
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! Map<String, dynamic> || data['error'] == true) {
        throw const FormatException();
      }
      return data;
    } on TimeoutException {
      throw WeatherException('Сервис долго не отвечает. Повторите запрос.');
    } on http.ClientException {
      throw WeatherException(
        'Не удалось подключиться к сервису. Проверьте интернет.',
      );
    } on FormatException {
      throw WeatherException(
        'Сервис вернул некорректные данные. Повторите запрос.',
      );
    }
  }

  Future<Map<String, dynamic>> searchCities(String name) {
    final address = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
      'name': name,
      'count': '5',
      'language': 'ru',
      'format': 'json',
    });
    return getJson(address);
  }

  Future<Map<String, dynamic>> getWeather(double latitude, double longitude) {
    final address = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'current': 'temperature_2m,relative_humidity_2m,wind_speed_10m,surface_pressure,weather_code,is_day',
      'daily': 'weather_code,temperature_2m_min,temperature_2m_max',
      'forecast_days': '5',
      'temperature_unit': 'celsius',
      'wind_speed_unit': 'ms',
      'timezone': 'auto',
    });
    return getJson(address);
  }

  void close() {
    client.close();
  }
}
