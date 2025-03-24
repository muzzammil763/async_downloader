import 'package:flutter/material.dart';

import 'app.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  bool isDarkMode = true;

  void toggleTheme() {
    setState(() {
      isDarkMode = !isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Async Downloader',
      debugShowCheckedModeBanner: false,
      theme:
          isDarkMode
              ? ThemeData.dark().copyWith(
                primaryColor: const Color(0xFF00272B),
                scaffoldBackgroundColor: const Color(0xFF00272B),
                colorScheme: ColorScheme.dark(
                  primary: const Color(0xFFE0FF4F),
                  secondary: const Color(0xFFE0FF4F),
                  surface: const Color(0xFF003640),
                ),
                appBarTheme: const AppBarTheme(
                  backgroundColor: Color(0xFF00272B),
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                filledButtonTheme: FilledButtonThemeData(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE0FF4F),
                    foregroundColor: const Color(0xFF00272B),
                  ),
                ),
              )
              : ThemeData.light().copyWith(
                primaryColor: Colors.white,
                colorScheme: ColorScheme.light(
                  primary: const Color(0xFF00272B),
                  secondary: const Color(0xFF00272B),
                  surface: Colors.grey[100]!,
                ),
                appBarTheme: const AppBarTheme(
                  backgroundColor: Colors.white,
                  foregroundColor: Color(0xFF00272B),
                  elevation: 0,
                ),
                filledButtonTheme: FilledButtonThemeData(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00272B),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
      home: DownloaderApp(toggleTheme: toggleTheme, isDarkMode: isDarkMode),
    );
  }
}
