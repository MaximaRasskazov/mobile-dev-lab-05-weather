import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l5_weather/weather_display.dart';

void main() {
  test('Weather codes have Russian descriptions and an unknown fallback', () {
    expect(weatherDescription(73), 'Снег');
    expect(weatherDescription(95), 'Гроза');
    expect(weatherDescription(1000), contains('Неизвестные'));
    expect(weatherIcon(0), Icons.wb_sunny);
    expect(weatherIcon(0, isDay: false), Icons.nightlight_round);
    expect(weatherIcon(85), Icons.ac_unit);
    expect(weatherIcon(1000), Icons.help_outline);
  });

  test('Temperature formatting preserves sign without negative zero', () {
    expect(formatTemperature(2.2), '+2 °C');
    expect(formatTemperature(-2.2), '-2 °C');
    expect(formatTemperature(-0.1), '0 °C');
  });

  test('Forecast dates display a weekday and leading zeros', () {
    expect(formatDate(DateTime(2026, 10, 20)), 'Вт, 20.10');
    expect(formatDate(DateTime(2026, 2, 1)), 'Вс, 01.02');
  });
}
