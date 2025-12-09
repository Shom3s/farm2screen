import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import 'firebase_options.dart';
import 'theme.dart';
import 'theme_controller.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await supa.Supabase.initialize(
    url: 'https://qkucnyzuswpgetbggpiy.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFrdWNueXp1c3dwZ2V0YmdncGl5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ5MjEwMjksImV4cCI6MjA4MDQ5NzAyOX0.UBjZjlcAB5HUCVFlO9-XLH29Fd1r3L6cXKFVxdAzdeo',
  );

  final themeController = ThemeController();

  runApp(
    ThemeControllerProvider(
      controller: themeController,
      child: Farm2ScreenApp(controller: themeController),
    ),
  );
}

class Farm2ScreenApp extends StatelessWidget {
  final ThemeController controller;

  const Farm2ScreenApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return MaterialApp(
          title: 'Farm2Screen',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: controller.mode,
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasData) {
                return const HomeShell();
              }
              return const LoginScreen();
            },
          ),
        );
      },
    );
  }
}
