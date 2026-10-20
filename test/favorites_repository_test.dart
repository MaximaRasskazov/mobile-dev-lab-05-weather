import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:l5_weather/models/city.dart';
import 'package:l5_weather/repositories/favorites_repository.dart';

import 'test_data.dart';

final class FailingPreferences extends InMemorySharedPreferencesAsync {
  FailingPreferences() : super.empty();
  bool failWrites = true;

  @override
  Future<bool> setString(
    String key,
    String value,
    SharedPreferencesOptions options,
  ) async {
    if (failWrites) {
      throw Exception('Unavailable');
    }
    return super.setString(key, value, options);
  }
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('Favorites survive recreation and are removed by ID', () async {
    final repository = FavoritesRepository();
    await repository.load();
    expect(repository.cities, isEmpty);
    await repository.toggle(testCity);
    final restored = FavoritesRepository();
    await restored.load();
    expect(restored.cities.single.toJson(), testCity.toJson());
    final copy = City.fromJson(testCity.toJson());
    await restored.toggle(copy);
    await repository.load();
    expect(repository.cities, isEmpty);
  });

  test('Cities with the same name but different IDs remain distinct', () async {
    final repository = FavoritesRepository();
    await repository.toggle(testCity);
    final other = City(id: 2, name: testCity.name, latitude: 1, longitude: 2);
    await repository.toggle(other);
    expect(repository.cities, hasLength(2));
    await repository.toggle(testCity);
    expect(repository.cities.single.id, 2);
  });

  test('Failed write does not change the visible favorites list', () async {
    final preferences = FailingPreferences();
    SharedPreferencesAsyncPlatform.instance = preferences;
    final repository = FavoritesRepository();
    await expectLater(repository.toggle(testCity), throwsException);
    expect(repository.cities, isEmpty);
    preferences.failWrites = false;
    await repository.toggle(testCity);
    preferences.failWrites = true;
    await expectLater(repository.toggle(testCity), throwsException);
    expect(repository.contains(testCity), isTrue);
  });

  test(
    'Corrupt data does not partially replace an existing favorites list',
    () async {
      final repository = FavoritesRepository();
      await repository.toggle(testCity);
      await repository.preferences.setString(
        repository.storageKey,
        '[{"id":1}]',
      );
      await expectLater(repository.load(), throwsA(anything));
      expect(repository.cities.single.id, testCity.id);
      expect(
        await repository.preferences.getString(repository.storageKey),
        '[{"id":1}]',
      );
    },
  );
}
