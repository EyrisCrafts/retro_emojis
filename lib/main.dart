import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:retro_typer/search_bar/widget_search.dart';
import 'package:window_manager/window_manager.dart';

const double searchBarSize = 76;
const int gridCrossAxisCount = 5;
const double itemHeight = 116;
// Acceiblity apis needed.
// Write where cursor is
// Find cursor position

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();
  // Platform.isWindows;
  WindowOptions windowOptions =
      const WindowOptions(size: Size(600, 76), center: true, backgroundColor: Colors.transparent, skipTaskbar: true, titleBarStyle: TitleBarStyle.hidden, windowButtonVisibility: false);

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setSize(const Size(600, 76));
    await windowManager.setAsFrameless();
    await windowManager.show();
    await windowManager.focus();
    final size = await windowManager.getSize();
    log("Size after running: $size");
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Retro Typer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const WidgetSearch(),
    );
  }
}
