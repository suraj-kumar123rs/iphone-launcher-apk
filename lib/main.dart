import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'native.dart';
import 'state.dart';
import 'ui/home.dart';
import 'weather.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarContrastEnforced: false,
  ));
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  Native.init();
  await Launcher.i.init();
  await Weather.i.init();
  runApp(const LumenApp());
}

class LumenApp extends StatelessWidget {
  const LumenApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true, colorSchemeSeed: CupertinoColors.systemBlue);
    final text = GoogleFonts.interTextTheme(base.textTheme).apply(bodyColor: Colors.white, displayColor: Colors.white);
    return MaterialApp(
      title: 'Lumen',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        textTheme: text,
        scaffoldBackgroundColor: Colors.black,
        cupertinoOverrideTheme: CupertinoThemeData(
          brightness: Brightness.dark,
          primaryColor: CupertinoColors.systemBlue,
          textTheme: CupertinoTextThemeData(
            textStyle: GoogleFonts.inter(fontSize: 17, color: Colors.white, letterSpacing: -0.4),
          ),
        ),
      ),
      home: const LauncherHome(),
    );
  }
}
