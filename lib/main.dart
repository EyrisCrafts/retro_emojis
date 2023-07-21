import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:retro_typer/search_bar/widget_search.dart';
import 'package:retro_typer/service_locator.dart';
import 'package:retro_typer/services/service_local_storage.dart';
import 'package:retro_typer/services/service_user_preferences.dart';
import 'package:window_manager/window_manager.dart';

const double searchBarSize = 76;

// Acceiblity apis needed.
// Write where cursor is
// Find cursor position

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();
  WindowOptions windowOptions =
      const WindowOptions(size: Size(600, 76), center: true, backgroundColor: Colors.transparent, skipTaskbar: true, titleBarStyle: TitleBarStyle.hidden, windowButtonVisibility: false);

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setSize(const Size(600, 76));
    await windowManager.setAsFrameless();
    await windowManager.show();
    await windowManager.focus();
    if ((await GetIt.I<ServiceLocalStorage>().getEmojis()).isNotEmpty) {
      windowManager.setSize(const Size(600, searchBarSize + 464));
    }
  });

  setupServiceLocator();

  await GetIt.I<ServiceUserPreferences>().init();

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
