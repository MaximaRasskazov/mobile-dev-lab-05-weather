import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/city.dart';

class FavoritesRepository {
  final preferences = SharedPreferencesAsync();
  final storageKey = 'weather_favorites';
  final List<City> cities = [];

  Future<void> load() async {
    final saved = await preferences.getString(storageKey);
    final List<City> loaded = [];
    if (saved != null) {
      final List<dynamic> data = jsonDecode(saved);
      for (final item in data) {
        loaded.add(City.fromJson(item as Map<String, dynamic>));
      }
    }
    cities.clear();
    cities.addAll(loaded);
  }

  bool contains(City city) {
    for (final saved in cities) {
      if (saved.id == city.id) {
        return true;
      }
    }
    return false;
  }

  Future<void> toggle(City city) async {
    final List<City> updated = List<City>.from(cities);
    if (contains(city)) {
      updated.removeWhere((saved) => saved.id == city.id);
    } else {
      updated.add(city);
    }
    final List<Map<String, dynamic>> data = [];
    for (final item in updated) {
      data.add(item.toJson());
    }
    // Обновляем видимый список только после успешного сохранения.
    await preferences.setString(storageKey, jsonEncode(data));
    cities.clear();
    cities.addAll(updated);
  }
}
