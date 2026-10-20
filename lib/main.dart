import 'package:flutter/material.dart';

import 'pages/weather_screen.dart';
import 'repositories/weather_repository.dart';

void main() {
  runApp(const WeatherApp());
}

class WeatherApp extends StatelessWidget {
  final WeatherRepository? repository;

  const WeatherApp({super.key, this.repository});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Погода',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF1B1C1F),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF202124)),
        cardTheme: const CardThemeData(color: Color(0xFF292A2D)),
      ),
      home: WeatherScreen(repository: repository),
    );
  }
}
