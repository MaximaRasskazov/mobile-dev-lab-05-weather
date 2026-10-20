import 'package:flutter/material.dart';

import '../data/weather_api_client.dart';
import '../models/city.dart';
import '../models/forecast_day.dart';
import '../models/weather.dart';
import '../repositories/favorites_repository.dart';
import '../repositories/weather_repository.dart';
import '../weather_display.dart';

class WeatherScreen extends StatefulWidget {
  final WeatherRepository? repository;

  const WeatherScreen({super.key, this.repository});

  @override
  State<WeatherScreen> createState() {
    return WeatherState();
  }
}

class WeatherState extends State<WeatherScreen> {
  late final WeatherRepository repository;
  final favorites = FavoritesRepository();
  final cityController = TextEditingController();
  final scrollController = ScrollController();
  List<City> cities = [];
  City? selectedCity;
  Weather? weather;
  bool isLoading = false;
  bool hasSearched = false;
  String lastQuery = '';
  String? inputError;
  String? error;
  bool favoritesReady = false;
  bool savingFavorite = false;
  String? favoritesError;

  @override
  void initState() {
    super.initState();
    repository = widget.repository ?? WeatherRepository();
    loadFavorites();
  }

  @override
  void dispose() {
    cityController.dispose();
    scrollController.dispose();
    repository.close();
    super.dispose();
  }

  Future<void> loadFavorites() async {
    String? message;
    try {
      await favorites.load();
    } catch (exception) {
      message = 'Не удалось загрузить избранные города.';
    }
    if (!mounted) {
      return;
    }
    setState(() {
      favoritesError = message;
      favoritesReady = message == null;
    });
  }

  Future<void> toggleFavorite(City city) async {
    if (savingFavorite || !favoritesReady) {
      return;
    }
    setState(() {
      savingFavorite = true;
    });
    try {
      await favorites.toggle(city);
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Не удалось сохранить избранное. Попробуйте ещё раз.',
            ),
          ),
        );
      }
    }
    if (mounted) {
      setState(() {
        savingFavorite = false;
      });
    }
  }

  Future<void> searchCities() async {
    if (isLoading) {
      return;
    }
    final query = cityController.text.trim();
    if (query.isEmpty) {
      setState(() {
        inputError = 'Введите название города';
      });
      return;
    }
    setState(() {
      inputError = null;
      error = null;
      weather = null;
      selectedCity = null;
      cities = [];
      lastQuery = query;
      hasSearched = true;
      isLoading = true;
    });
    try {
      final results = await repository.searchCities(query);
      if (!mounted) {
        return;
      }
      setState(() {
        cities = results;
        isLoading = false;
      });
      if (results.length == 1) {
        await loadWeather(results.first);
      }
    } on WeatherException catch (exception) {
      if (mounted) {
        setState(() {
          error = exception.message;
          isLoading = false;
        });
      }
    }
  }

  Future<void> loadWeather(City city) async {
    if (isLoading) {
      return;
    }
    cityController.text = city.name;
    scrollController.jumpTo(0);
    setState(() {
      selectedCity = city;
      cities = [];
      weather = null;
      inputError = null;
      error = null;
      hasSearched = true;
      isLoading = true;
    });
    try {
      final result = await repository.getWeather(city);
      if (!mounted) {
        return;
      }
      setState(() {
        weather = result;
        isLoading = false;
      });
    } on WeatherException catch (exception) {
      if (mounted) {
        setState(() {
          error = exception.message;
          isLoading = false;
        });
      }
    }
  }

  void retry() {
    final city = selectedCity;
    if (city != null) {
      loadWeather(city);
    } else {
      cityController.text = lastQuery;
      searchCities();
    }
  }

  Widget buildCityCard(City city, {bool favorite = false}) {
    return Card(
      key: ValueKey('${favorite ? 'favorite' : 'city'}_${city.id}'),
      child: ListTile(
        leading: Icon(
          favorite ? Icons.star : Icons.location_on,
          color: Colors.amber,
        ),
        title: Text(city.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(city.fullName),
        onTap: isLoading
            ? null
            : () {
                loadWeather(city);
              },
        trailing: favorite
            ? IconButton(
                tooltip: 'Удалить из избранного',
                onPressed: savingFavorite
                    ? null
                    : () {
                        toggleFavorite(city);
                      },
                icon: const Icon(Icons.close),
              )
            : null,
      ),
    );
  }

  Widget buildCurrentWeather(Weather value) {
    final isFavorite = favorites.contains(value.city);
    final hour = value.time.hour.toString().padLeft(2, '0');
    final minute = value.time.minute.toString().padLeft(2, '0');
    return Card(
      key: const ValueKey('current_weather'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    value.city.fullName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: isFavorite
                      ? 'Убрать город из избранного'
                      : 'Добавить город в избранное',
                  onPressed: !favoritesReady || savingFavorite
                      ? null
                      : () {
                          toggleFavorite(value.city);
                        },
                  icon: Icon(
                    isFavorite ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 24,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(
                  weatherIcon(value.code, isDay: value.isDay),
                  size: 64,
                  color: Colors.lightBlueAccent,
                ),
                Text(
                  formatTemperature(value.temperature),
                  style: const TextStyle(fontSize: 48),
                ),
              ],
            ),
            Text(
              weatherDescription(value.code),
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 20,
              runSpacing: 12,
              children: [
                Text('Влажность: ${value.humidity}%'),
                Text('Ветер: ${value.wind.toStringAsFixed(1)} м/с'),
                if (value.pressure != null)
                  Text('Давление: ${value.pressure!.toStringAsFixed(0)} гПа'),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Данные на ${formatDate(value.time)} $hour:$minute\nМестное время города',
            ),
          ],
        ),
      ),
    );
  }

  Widget buildForecastDay(ForecastDay day) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    formatDate(day.date),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Icon(weatherIcon(day.code), color: Colors.lightBlueAccent),
              ],
            ),
            const SizedBox(height: 6),
            Text(weatherDescription(day.code)),
            Text(
              'Мин. ${formatTemperature(day.minimum)} / макс. ${formatTemperature(day.maximum)}',
            ),
          ],
        ),
      ),
    );
  }

  Widget buildWeatherDetails(Weather value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildCurrentWeather(value),
        const SizedBox(height: 20),
        Text(
          'Прогноз на ${value.forecast.length} дн.',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        for (final day in value.forecast) buildForecastDay(day),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = weather;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Погода'),
        actions: [
          IconButton(
            tooltip: 'Обновить погоду',
            onPressed: isLoading || selectedCity == null
                ? null
                : () {
                    loadWeather(selectedCity!);
                  },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: cityController,
                        enabled: !isLoading,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          labelText: 'Город',
                          hintText: 'Например, Ханты-Мансийск',
                          errorText: inputError,
                          errorMaxLines: 2,
                        ),
                        onSubmitted: (value) {
                          searchCities();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: 'Найти погоду',
                      onPressed: isLoading ? null : searchCities,
                      icon: const Icon(Icons.search),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Загружаем данные…'),
                      ],
                    ),
                  ),
                if (error != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(error!),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: retry,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Повторить'),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (!isLoading &&
                    error == null &&
                    current == null &&
                    cities.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      hasSearched
                          ? 'Город не найден. Проверьте название.'
                          : 'Введите название города, чтобы узнать погоду.',
                    ),
                  ),
                if (cities.isNotEmpty)
                  const Text(
                    'Уточните город',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                for (final city in cities) buildCityCard(city),
                if (current != null) buildWeatherDetails(current),
                const SizedBox(height: 24),
                const Text(
                  'Избранные города',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                if (!favoritesReady && favoritesError == null)
                  const Text('Загрузка избранного…'),
                if (favoritesReady && favorites.cities.isEmpty)
                  const Text(
                    'Нажмите звезду в карточке погоды, чтобы добавить город.',
                  ),
                if (favoritesError != null) Text(favoritesError!),
                if (favoritesError != null)
                  TextButton(
                    onPressed: loadFavorites,
                    child: const Text('Повторить загрузку избранного'),
                  ),
                for (final city in favorites.cities)
                  buildCityCard(city, favorite: true),
                const SizedBox(height: 24),
                const Text(
                  'Данные погоды: Open-Meteo.com\nПоиск городов: GeoNames',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
