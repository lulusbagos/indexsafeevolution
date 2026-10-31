import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'pages/splash_page.dart';
import 'services/background.dart';
import 'services/fcm_service.dart';
import 'services/notification.dart';
import 'services/offline_sync_service.dart';
import 'services/preference.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

Future<void> main() async {
  HttpOverrides.global = MyHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();

  await PreferenceService.init();
  await NotificationService.init();
  await FCMService.init();
  await BackgroundService.instance.init();
  await OfflineSyncService.instance.init();

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
        debugShowCheckedModeBanner: false,
        navigatorKey: rootNavigatorKey,
        title: 'IndexSafe Evolution',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: CupertinoPageTransitionsBuilder(),
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            },
          ),
          scaffoldBackgroundColor: Colors.white,
          appBarTheme: const AppBarTheme(backgroundColor: Colors.white),
          dialogTheme: DialogThemeData(
            backgroundColor: const Color(0xFFFDFEFF).withValues(alpha: .96),
            surfaceTintColor: Colors.transparent,
            elevation: 18,
            shadowColor: const Color(0x330F172A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            titleTextStyle: const TextStyle(color: Color(0xFF0F172A), fontSize: 19, fontWeight: FontWeight.w800),
            contentTextStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.45),
            actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
          ),
          filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          )),
          inputDecorationTheme: InputDecorationTheme(
            // constraints: const BoxConstraints(maxHeight: 40),
            floatingLabelBehavior: FloatingLabelBehavior.always,
            fillColor: Colors.white,
            filled: true,
            isDense: true,
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: Colors.grey.shade300,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(
                color: Colors.blue,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            errorBorder: OutlineInputBorder(
              borderSide: const BorderSide(
                color: Colors.red,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderSide: const BorderSide(
                color: Colors.red,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        home: const SplashPage(),
      ),
    );
  }
}
