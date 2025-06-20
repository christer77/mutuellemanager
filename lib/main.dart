// lib/main.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dashboardScreen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/error/update_required_screen.dart';
import 'start/start_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Définir la date de sortie de la version cible
  // Dans une vraie application, cela proviendrait d'un serveur distant (ex: Firebase Remote Config, votre API)
  final DateTime _requiredUpdateDate = DateTime(2025, 9, 30); // Exemple : L'application nécessite une mise à jour après le 17 juin 2025

  @override
  Widget build(BuildContext context) {
    // Vérifier si une mise à jour est requise
    if (DateTime.now().isAfter(_requiredUpdateDate)) {
      return MaterialApp(
        title: 'Gestion Mutualité',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 255, 79, 25)),
          useMaterial3: true,
        ),
        home: const UpdateRequiredScreen(), // Afficher l'écran de mise à jour si obsolète
        debugShowCheckedModeBanner: false,
      );
    } else {
      // Si l'application est à jour, procéder à la vérification de la configuration initiale ou de la connexion
      return MaterialApp(
        title: 'Gestion Mutualité',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 255, 79, 25)),
          useMaterial3: true,
        ),
        home: const _AuthWrapper(), // Gère la configuration initiale ou la connexion
        debugShowCheckedModeBanner: false,
      );
    }
  }
}

// NOUVEAU : Un widget wrapper pour décider quel écran afficher initialement
class _AuthWrapper extends StatefulWidget {
  const _AuthWrapper();

  @override
  State<_AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<_AuthWrapper> {
  bool _isLoading = true;
  Widget? _initialScreen;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    if (prefs.getString('currencyUnit') == null) {
      await prefs.setString('currencyUnit', 'USD');
    }
    final bool isMutualiteConfigured = prefs.getBool('isMutualiteConfigured') ?? false;
    final bool isLoggedIn = prefs.getString('loggedInUser') != null; // Vérifier si un utilisateur est connecté
  
    if (!isMutualiteConfigured) {
      _initialScreen = const StartScreen(); // Force la configuration initiale
    } else if (!isLoggedIn) {
      _initialScreen = const LoginScreen(); // Force la connexion
    } else {
      _initialScreen = DashboardScreen(); // L'utilisateur est configuré et connecté
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return _initialScreen!;
  }
}