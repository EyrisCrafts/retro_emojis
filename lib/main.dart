import 'package:flutter/material.dart';
import 'package:retro_typer/widget_search.dart';
import 'package:window_manager/window_manager.dart';

const double searchBarSize = 48;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();

  WindowOptions windowOptions =
      const WindowOptions(size: Size(600, 76), center: true, backgroundColor: Colors.transparent, skipTaskbar: true, titleBarStyle: TitleBarStyle.hidden, windowButtonVisibility: false);

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setAsFrameless();
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const WidgetSearch(),
    );
  }
}
