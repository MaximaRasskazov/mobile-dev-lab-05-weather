import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:l5_weather/data/weather_api_client.dart';
import 'package:l5_weather/models/city.dart';
import 'package:l5_weather/repositories/weather_repository.dart';

import 'test_data.dart';

void main() {
  test(
    'Search trims and encodes a Russian name and parses city coordinates',
    () async {
      final client = MockClient((request) async {
        expect(request.url.host, 'geocoding-api.open-meteo.com');
        expect(request.url.queryParameters['name'], 'Ханты-Мансийск');
        expect(request.url.queryParameters['language'], 'ru');
        return jsonResponse({
          'results': [testCity.toJson()],
        });
      });
      final repository = WeatherRepository(
        apiClient: WeatherApiClient(client: client),
      );
      addTearDown(repository.close);
      final cities = await repository.searchCities('  Ханты-Мансийск  ');
      expect(cities.single.toJson(), testCity.toJson());
      expect(cities.single.fullName, contains('Россия'));
    },
  );

  test(
    'Blank search makes no network request and absent results mean empty list',
    () async {
      int requests = 0;
      final repository = WeatherRepository(
        apiClient: WeatherApiClient(
          client: MockClient((request) async {
            requests++;
            return jsonResponse({'generationtime_ms': 1});
          }),
        ),
      );
      addTearDown(repository.close);
      expect(await repository.searchCities('   '), isEmpty);
      expect(requests, 0);
      expect(await repository.searchCities('Несуществующийгород123'), isEmpty);
      expect(requests, 1);
    },
  );

  test(
    'Forecast requests units and local time and parses all required fields',
    () async {
      final repository = WeatherRepository(
        apiClient: WeatherApiClient(
          client: MockClient((request) async {
            expect(request.url.host, 'api.open-meteo.com');
            expect(
              request.url.queryParameters['latitude'],
              testCity.latitude.toString(),
            );
            expect(request.url.queryParameters['forecast_days'], '5');
            expect(request.url.queryParameters['wind_speed_unit'], 'ms');
            expect(request.url.queryParameters['temperature_unit'], 'celsius');
            expect(request.url.queryParameters['timezone'], 'auto');
            return jsonResponse(weatherData());
          }),
        ),
      );
      addTearDown(repository.close);
      final weather = await repository.getWeather(testCity);
      expect(weather.temperature, -2.5);
      expect(weather.humidity, 80);
      expect(weather.wind, 3.0);
      expect(weather.pressure, 1002.0);
      expect(weather.isDay, isFalse);
      expect(weather.time, DateTime(2026, 10, 20, 12));
      expect(weather.forecast, hasLength(5));
      expect(weather.forecast.first.minimum, -5.0);
      expect(weather.forecast.last.date, DateTime(2026, 10, 24));
    },
  );

  test('Pressure is optional and three forecast days are sufficient', () async {
    final repository = WeatherRepository(
      apiClient: WeatherApiClient(
        client: MockClient((request) async {
          return jsonResponse(weatherData(days: 3, pressure: false));
        }),
      ),
    );
    addTearDown(repository.close);
    final weather = await repository.getWeather(testCity);
    expect(weather.pressure, isNull);
    expect(weather.forecast, hasLength(3));
  });

  for (final status in [404, 500, 429, 403]) {
    test('HTTP $status produces a readable error', () async {
      final client = WeatherApiClient(
        client: MockClient((request) async => http.Response('error', status)),
      );
      addTearDown(client.close);
      await expectLater(
        client.getWeather(61, 69),
        throwsA(
          isA<WeatherException>().having(
            (error) => error.message,
            'message',
            isNotEmpty,
          ),
        ),
      );
    });
  }

  test('Offline and timeout errors are translated for the screen', () async {
    final offline = WeatherApiClient(
      client: MockClient((request) async {
        throw http.ClientException('offline');
      }),
    );
    final timeout = WeatherApiClient(
      client: MockClient((request) async {
        throw TimeoutException('slow');
      }),
    );
    addTearDown(offline.close);
    addTearDown(timeout.close);
    await expectLater(
      offline.searchCities('Город'),
      throwsA(
        isA<WeatherException>().having(
          (error) => error.message,
          'message',
          contains('интернет'),
        ),
      ),
    );
    await expectLater(
      timeout.searchCities('Город'),
      throwsA(
        isA<WeatherException>().having(
          (error) => error.message,
          'message',
          contains('долго'),
        ),
      ),
    );
  });

  test('Invalid JSON and API error objects become errors', () async {
    for (final body in ['not json', '[]', '{"error":true}']) {
      final client = WeatherApiClient(
        client: MockClient((request) async => http.Response(body, 200)),
      );
      await expectLater(
        client.searchCities('Город'),
        throwsA(isA<WeatherException>()),
      );
      client.close();
    }
  });

  test('Incomplete or broken forecast is rejected', () async {
    for (final data in [
      weatherData(days: 2),
      {'current': {}, 'daily': {}},
      {'results': 'wrong type'},
    ]) {
      final repository = WeatherRepository(
        apiClient: WeatherApiClient(
          client: MockClient((request) async => jsonResponse(data)),
        ),
      );
      await expectLater(
        repository.getWeather(testCity),
        throwsA(isA<WeatherException>()),
      );
      repository.close();
    }
  });

  test('A city can have integer coordinates and no country or region', () {
    final city = City.fromJson({
      'id': 1,
      'name': 'Город',
      'latitude': 61,
      'longitude': 69,
    });
    expect(city.latitude, 61.0);
    expect(city.fullName, 'Город');
  });
}
