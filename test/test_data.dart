import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:l5_weather/models/city.dart';

final testCity = City(
  id: 1503772,
  name: 'Ханты-Мансийск',
  region: 'Ханты-Мансийский АО',
  country: 'Россия',
  latitude: 61.00187,
  longitude: 69.02728,
);

// Тестовые данные, а не настоящая сводка погоды.
Map<String, dynamic> weatherData({int days = 5, bool pressure = true}) {
  return {
    'current': {
      'temperature_2m': -2.5,
      'relative_humidity_2m': 80,
      'wind_speed_10m': 3,
      'surface_pressure': pressure ? 1002.0 : null,
      'weather_code': 73,
      'is_day': 0,
      'time': '2026-10-20T12:00',
    },
    'daily': {
      'time': List.generate(
        days,
        (index) =>
            DateTime(2026, 10, 20 + index).toIso8601String().substring(0, 10),
      ),
      'temperature_2m_min': List.generate(days, (index) => -5 - index),
      'temperature_2m_max': List.generate(days, (index) => 2 + index),
      'weather_code': List.generate(days, (index) => 3),
    },
  };
}

http.Response jsonResponse(Object data) {
  return http.Response(
    jsonEncode(data),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

Future<http.Response> successfulResponse(http.Request request) async {
  if (request.url.host == 'geocoding-api.open-meteo.com') {
    return jsonResponse({
      'results': [testCity.toJson()],
    });
  }
  return jsonResponse(weatherData());
}
