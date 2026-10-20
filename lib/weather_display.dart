import 'package:flutter/material.dart';

const weatherDescriptions = {
  0: 'Ясно',
  1: 'Преимущественно ясно',
  2: 'Переменная облачность',
  3: 'Пасмурно',
  45: 'Туман',
  48: 'Туман с изморозью',
  51: 'Слабая морось',
  53: 'Морось',
  55: 'Сильная морось',
  56: 'Слабая ледяная морось',
  57: 'Ледяная морось',
  61: 'Слабый дождь',
  63: 'Дождь',
  65: 'Сильный дождь',
  66: 'Ледяной дождь',
  67: 'Сильный ледяной дождь',
  71: 'Слабый снег',
  73: 'Снег',
  75: 'Сильный снег',
  77: 'Снежные зёрна',
  80: 'Слабый ливень',
  81: 'Ливень',
  82: 'Сильный ливень',
  85: 'Снежный ливень',
  86: 'Сильный снежный ливень',
  95: 'Гроза',
  96: 'Гроза с градом',
  97: 'Сильная гроза',
  99: 'Гроза с сильным градом',
};

String weatherDescription(int code) {
  return weatherDescriptions[code] ?? 'Неизвестные погодные условия';
}

IconData weatherIcon(int code, {bool isDay = true}) {
  if (code == 0 || code == 1) {
    if (!isDay) {
      return Icons.nightlight_round;
    }
    return Icons.wb_sunny;
  }
  if (code == 2 || code == 3) {
    return Icons.cloud;
  }
  if (code == 45 || code == 48) {
    return Icons.foggy;
  }
  if ((code >= 71 && code <= 77) || code == 85 || code == 86) {
    return Icons.ac_unit;
  }
  if (code >= 95 && code <= 99) {
    return Icons.thunderstorm;
  }
  if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
    return Icons.water_drop;
  }
  return Icons.help_outline;
}

String formatTemperature(double value) {
  final rounded = value.round();
  if (rounded > 0) {
    return '+$rounded °C';
  }
  return '$rounded °C';
}

String formatDate(DateTime date) {
  const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '${days[date.weekday - 1]}, $day.$month';
}
