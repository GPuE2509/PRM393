import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'data/database_helper.dart';
import 'models/user.dart';
import 'screens/main_shell_screen.dart';
import 'screens/login_screen.dart';
import 'services/app_theme_service.dart';
import 'services/session_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await DatabaseHelper.instance.database;
  await AppThemeService.loadThemeMode();
  runApp(const Prm393App());
}

class Prm393App extends StatefulWidget {
  const Prm393App({super.key});

  @override
  State<Prm393App> createState() => _Prm393AppState();
}

class _Prm393AppState extends State<Prm393App> {
  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    const seed = Color(0xFF34C759);
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: brightness,
      ),
    );

    final textTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: isDark ? const Color(0xFF0B0D12) : Colors.white,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark
            ? const Color(0xFF0F1117)
            : const Color(0xFF34C759),
        foregroundColor: isDark ? Colors.white : Colors.black,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? const Color(0xFF171A21) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1B1E27) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF303543) : const Color(0xFFDCEAD7),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF34C759), width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF34C759),
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF34C759),
        foregroundColor: Colors.white,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeService.themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'prm393',
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: themeMode,
          home: const SessionGate(),
        );
      },
    );
  }
}

class SessionGate extends StatelessWidget {
  const SessionGate({super.key});

  Future<UserModel?> _loadSessionUser() async {
    final userId = await SessionService.getUserSession();
    if (userId == null) return null;
    return DatabaseHelper.instance.getUserById(userId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserModel?>(
      future: _loadSessionUser(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user?.id != null) {
          return MainShellScreen(userId: user!.id!, username: user.username);
        }

        return const LoginScreen();
      },
    );
  }
}
