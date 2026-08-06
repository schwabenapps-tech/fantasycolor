import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/start_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const FantasyColorApp());
}

class FantasyColorApp extends StatelessWidget {
  const FantasyColorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fantasy Color',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5B6FBF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const StartScreen(),
    );
  }
}
