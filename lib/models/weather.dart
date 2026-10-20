import 'city.dart';
import 'forecast_day.dart';

class Weather {
  final City city;
  final double temperature;
  final int humidity;
  final double wind;
  final double? pressure;
  final int code;
  final bool isDay;
  final DateTime time;
  final List<ForecastDay> forecast;

  Weather({
    required this.city,
    required this.temperature,
    required this.humidity,
    required this.wind,
    required this.code,
    required this.isDay,
    required this.time,
    required this.forecast,
    this.pressure,
  });
}
