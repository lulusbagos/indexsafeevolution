import 'package:flutter/material.dart';

import 'pages/splash_page.dart';
import 'services/background.dart';
import 'services/notification.dart';
import 'services/offline_sync_service.dart';
import 'services/preference.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await PreferenceService.init();
  await NotificationService.init();
  await BackgroundService.instance.init();
  OfflineSyncService.instance.initAutoSyncListener();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).requestFocus(FocusNode());
      },
      child: MaterialApp(
        navigatorKey: rootNavigatorKey,
        title: 'IndexSafe Evolution',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.white,
          appBarTheme: const AppBarTheme(backgroundColor: Colors.white),
          inputDecorationTheme: InputDecorationTheme(
            // constraints: const BoxConstraints(maxHeight: 40),
            contentPadding: const EdgeInsets.all(10),
            isDense: true,
            filled: true,
            fillColor: Colors.white54,
            border: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.indigo.shade200),
              borderRadius: BorderRadius.circular(20),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.indigo.shade200),
              borderRadius: BorderRadius.circular(20),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.indigo.shade200),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        home: const SplashPage(),
      ),
    );
  }
}
