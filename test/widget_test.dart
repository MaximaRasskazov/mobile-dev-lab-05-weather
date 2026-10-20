import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:l5_weather/data/weather_api_client.dart';
import 'package:l5_weather/main.dart';
import 'package:l5_weather/models/city.dart';
import 'package:l5_weather/pages/weather_screen.dart';
import 'package:l5_weather/repositories/weather_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'favorites_repository_test.dart' show FailingPreferences;
import 'test_data.dart';

Future<void> openApp(
  WidgetTester tester,
  Future<http.Response> Function(http.Request) response,
) async {
  await tester.pumpWidget(
    WeatherApp(
      repository: WeatherRepository(
        apiClient: WeatherApiClient(client: MockClient(response)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> search(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.tap(find.byTooltip('Найти погоду'));
  await tester.pumpAndSettle();
}

Future<void> reveal(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('Blank query is validated without a request', (tester) async {
    int requests = 0;
    await openApp(tester, (request) async {
      requests++;
      return successfulResponse(request);
    });
    expect(
      find.text('Введите название города, чтобы узнать погоду.'),
      findsOneWidget,
    );
    await search(tester, '   ');
    expect(find.text('Введите название города'), findsOneWidget);
    expect(requests, 0);
  });

  testWidgets(
    'Search displays weather metrics and five days and allows refresh',
    (tester) async {
      int forecasts = 0;
      await openApp(tester, (request) async {
        if (request.url.host == 'api.open-meteo.com') {
          forecasts++;
        }
        return successfulResponse(request);
      });
      await search(tester, 'Ханты-Мансийск');
      expect(find.byKey(const ValueKey('current_weather')), findsOneWidget);
      expect(find.text('Снег'), findsOneWidget);
      expect(find.text('Влажность: 80%'), findsOneWidget);
      expect(find.text('Ветер: 3.0 м/с'), findsOneWidget);
      expect(find.text('Давление: 1002 гПа'), findsOneWidget);
      final state = tester.state<WeatherState>(find.byType(WeatherScreen));
      expect(state.weather!.forecast, hasLength(5));
      await reveal(tester, find.text('Прогноз на 5 дн.'));
      expect(find.text('Прогноз на 5 дн.'), findsOneWidget);
      await reveal(tester, find.text('Сб, 24.10'));
      expect(find.text('Сб, 24.10'), findsOneWidget);
      await tester.tap(find.byTooltip('Обновить погоду'));
      await tester.pumpAndSettle();
      expect(forecasts, 2);
      expect(state.scrollController.offset, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Unknown city gives an empty result rather than a server error', (
    tester,
  ) async {
    await openApp(tester, (request) async => jsonResponse({}));
    await search(tester, 'Несуществующийгород123');
    expect(find.text('Город не найден. Проверьте название.'), findsOneWidget);
    expect(find.text('Повторить'), findsNothing);
  });

  testWidgets('Ambiguous city search lets user select the correct location', (
    tester,
  ) async {
    final other = City(
      id: 2,
      name: testCity.name,
      country: 'Другая страна',
      latitude: 1,
      longitude: 2,
    );
    double? chosenLatitude;
    await openApp(tester, (request) async {
      if (request.url.host == 'geocoding-api.open-meteo.com') {
        return jsonResponse({
          'results': [testCity.toJson(), other.toJson()],
        });
      }
      chosenLatitude = double.parse(request.url.queryParameters['latitude']!);
      return jsonResponse(weatherData());
    });
    await search(tester, 'Город');
    expect(find.text('Уточните город'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('city_2')));
    await tester.pumpAndSettle();
    expect(chosenLatitude, 1.0);
    expect(find.text(other.fullName), findsOneWidget);
  });

  testWidgets('Server error can retry the same search', (tester) async {
    bool fail = true;
    await openApp(tester, (request) async {
      if (fail) {
        return http.Response('error', 500);
      }
      if (request.url.host == 'geocoding-api.open-meteo.com') {
        expect(request.url.queryParameters['name'], testCity.name);
      }
      return successfulResponse(request);
    });
    await search(tester, testCity.name);
    expect(find.textContaining('HTTP 500'), findsOneWidget);
    fail = false;
    await tester.enterText(find.byType(TextField), 'Другой ввод');
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('current_weather')), findsOneWidget);
  });

  testWidgets(
    'Weather retry retains the selected city and does not repeat geocoding',
    (tester) async {
      bool fail = true;
      int searches = 0;
      await openApp(tester, (request) async {
        if (request.url.host == 'geocoding-api.open-meteo.com') {
          searches++;
        } else if (fail) {
          return http.Response('error', 404);
        }
        return successfulResponse(request);
      });
      await search(tester, testCity.name);
      expect(find.textContaining('HTTP 404'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();
      expect(searches, 1);
      expect(find.byKey(const ValueKey('current_weather')), findsOneWidget);
    },
  );

  testWidgets(
    'Offline error is readable and malformed weather is recoverable',
    (tester) async {
      int mode = 0;
      await openApp(tester, (request) async {
        if (mode == 0) {
          throw http.ClientException('offline');
        }
        if (mode == 1 && request.url.host == 'api.open-meteo.com') {
          return jsonResponse({});
        }
        return successfulResponse(request);
      });
      await search(tester, testCity.name);
      expect(find.textContaining('Проверьте интернет'), findsOneWidget);
      mode = 1;
      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Не удалось прочитать погоду'),
        findsOneWidget,
      );
      mode = 2;
      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('current_weather')), findsOneWidget);
    },
  );

  testWidgets('Loading indicator disables competing requests', (tester) async {
    final pending = Completer<http.Response>();
    await openApp(tester, (request) => pending.future);
    await tester.enterText(find.byType(TextField), 'Город');
    await tester.tap(find.byTooltip('Найти погоду'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is IconButton && widget.tooltip == 'Найти погоду',
            ),
          )
          .onPressed,
      isNull,
    );
    pending.complete(jsonResponse({}));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Город не найден. Проверьте название.'), findsOneWidget);
  });

  testWidgets(
    'Favorites survive restart and load weather directly by coordinates',
    (tester) async {
      int searches = 0;
      Future<http.Response> respond(http.Request request) async {
        if (request.url.host == 'geocoding-api.open-meteo.com') {
          searches++;
        }
        return successfulResponse(request);
      }

      await openApp(tester, respond);
      await search(tester, testCity.name);
      await tester.tap(find.byTooltip('Добавить город в избранное'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await openApp(tester, respond);
      final favorite = find.byKey(ValueKey('favorite_${testCity.id}'));
      expect(favorite, findsOneWidget);
      await tester.tap(favorite);
      await tester.pumpAndSettle();
      expect(searches, 1);
      expect(find.byTooltip('Убрать город из избранного'), findsOneWidget);
      await tester.tap(find.byTooltip('Убрать город из избранного'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await openApp(tester, respond);
      expect(favorite, findsNothing);
    },
  );

  testWidgets(
    'Favorite read failure does not block weather or overwrite data',
    (tester) async {
      final preferences = SharedPreferencesAsync();
      await preferences.setString('weather_favorites', 'broken');
      await openApp(tester, successfulResponse);
      expect(
        find.text('Не удалось загрузить избранные города.'),
        findsOneWidget,
      );
      await search(tester, testCity.name);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton &&
                    widget.tooltip == 'Добавить город в избранное',
              ),
            )
            .onPressed,
        isNull,
      );
      expect(await preferences.getString('weather_favorites'), 'broken');
      await preferences.setString('weather_favorites', '[]');
      await reveal(tester, find.text('Повторить загрузку избранного'));
      await tester.tap(find.text('Повторить загрузку избранного'));
      await tester.pumpAndSettle();
      final state = tester.state<WeatherState>(find.byType(WeatherScreen));
      expect(state.favoritesReady, isTrue);
    },
  );

  testWidgets('Favorite write failure leaves the star unchanged', (
    tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance = FailingPreferences();
    await openApp(tester, successfulResponse);
    await search(tester, testCity.name);
    await tester.tap(find.byTooltip('Добавить город в избранное'));
    await tester.pumpAndSettle();
    expect(
      find.text('Не удалось сохранить избранное. Попробуйте ещё раз.'),
      findsOneWidget,
    );
    expect(find.byTooltip('Добавить город в избранное'), findsOneWidget);
  });

  testWidgets(
    'Small dark screen handles long names large text keyboard and missing pressure',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final longCity = City(
        id: 1,
        name: 'Очень длинное название города с несколькими словами',
        country: 'Длинное название страны',
        latitude: 1,
        longitude: 2,
      );
      await openApp(tester, (request) async {
        if (request.url.host == 'geocoding-api.open-meteo.com') {
          return jsonResponse({
            'results': [longCity.toJson()],
          });
        }
        return jsonResponse(weatherData(pressure: false));
      });
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await search(tester, longCity.name);
      expect(
        Theme.of(tester.element(find.byType(Scaffold))).brightness,
        Brightness.dark,
      );
      expect(find.textContaining('Давление:'), findsNothing);
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Сб, 24.10'));
      expect(find.text('Сб, 24.10'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
