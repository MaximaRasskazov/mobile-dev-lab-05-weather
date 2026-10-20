import '../data/weather_api_client.dart';
import '../models/city.dart';
import '../models/forecast_day.dart';
import '../models/weather.dart';

class WeatherRepository {
  final WeatherApiClient apiClient;

  WeatherRepository({WeatherApiClient? apiClient})
    : apiClient = apiClient ?? WeatherApiClient();

  Future<List<City>> searchCities(String name) async {
    if (name.trim().isEmpty) {
      return [];
    }
    final data = await apiClient.searchCities(name.trim());
    try {
      final List<dynamic> results = data['results'] as List<dynamic>? ?? [];
      final List<City> cities = [];
      for (final item in results) {
        cities.add(City.fromJson(item as Map<String, dynamic>));
      }
      return cities;
    } catch (error) {
      throw WeatherException(
        'Не удалось прочитать список городов. Повторите запрос.',
      );
    }
  }

  Future<Weather> getWeather(City city) async {
    final data = await apiClient.getWeather(city.latitude, city.longitude);
    try {
      final current = data['current'] as Map<String, dynamic>;
      final daily = data['daily'] as Map<String, dynamic>;
      final dates = daily['time'] as List<dynamic>;
      final List<ForecastDay> forecast = [];
      if (dates.length < 3) {
        throw const FormatException();
      }
      for (int index = 0; index < dates.length; index++) {
        forecast.add(
          ForecastDay(
            date: DateTime.parse(dates[index] as String),
            minimum: (daily['temperature_2m_min'][index] as num).toDouble(),
            maximum: (daily['temperature_2m_max'][index] as num).toDouble(),
            code: daily['weather_code'][index] as int,
          ),
        );
      }
      return Weather(
        city: city,
        temperature: (current['temperature_2m'] as num).toDouble(),
        humidity: current['relative_humidity_2m'] as int,
        wind: (current['wind_speed_10m'] as num).toDouble(),
        pressure: (current['surface_pressure'] as num?)?.toDouble(),
        code: current['weather_code'] as int,
        isDay: current['is_day'] == 1,
        time: DateTime.parse(current['time'] as String),
        forecast: forecast,
      );
    } catch (error) {
      throw WeatherException(
        'Не удалось прочитать погоду и прогноз. Повторите запрос.',
      );
    }
  }

  void close() {
    apiClient.close();
  }
}
