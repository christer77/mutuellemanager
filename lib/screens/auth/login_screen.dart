import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/constants.dart';
import '../../config/database_helper.dart';
import '../../dashboardScreen.dart';
import '../settings/restore_screen.dart';
import 'forgot_password_screen.dart'; // Pour la validation utilisateur

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isLoading = false;
  bool _rememberMe = false; // NOUVEAU: État pour la case à cocher "Se souvenir de moi"

  @override
  void initState() {
    super.initState();
    // La logique d'auto-login initiale est gérée dans _AuthWrapper de main.dart.
    // Ici, nous pouvons éventuellement charger l'état précédent du "Se souvenir de moi"
    // si l'application est relancée et que l'utilisateur n'est pas déjà connecté.
    _loadRememberMeSetting();
  }

  Future<void> _loadRememberMeSetting() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    // Si l'utilisateur était précédemment en mode "se souvenir de moi"
    // et qu'il n'est pas déjà connecté (ce qui est décidé par _AuthWrapper)
    // nous pourrions pré-cocher la case ici pour l'UX.
    // Cependant, comme _AuthWrapper gère la redirection, cette partie est moins critique.
    // Pour l'instant, la case reste décochée par défaut à l'arrivée sur l'écran de connexion.
    setState(() {
      _rememberMe = prefs.getBool('rememberMe') ?? false;
      if (_rememberMe) {
        // Optionnel: Pré-remplir les champs si "rememberMe" est vrai
        // et si vous stockez le dernier nom d'utilisateur.
        _usernameController.text = prefs.getString('lastUsername') ?? '';
      }
    });
  }


  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final String username = _usernameController.text;
    final String password = _passwordController.text;

    try {
      // Valider l'utilisateur via DatabaseHelper
      // IMPORTANT: Hacher le mot de passe avant de le comparer en production!
      final Map<String, dynamic>? user = await _dbHelper.validateUser(username, password);

      if (user != null) {
        final SharedPreferences prefs = await SharedPreferences.getInstance();

        if (_rememberMe) {
          // Si "Rester connecté" est coché, enregistrez l'utilisateur comme connecté
          await prefs.setString('loggedInUser', username);
          await prefs.setBool('rememberMe', true); // Enregistre aussi le paramètre de la case à cocher
          await prefs.setString('lastUsername', username); // Optionnel: Enregistrer le dernier nom d'utilisateur
        } else {
          // Si "Rester connecté" n'est PAS coché, assurez-vous de supprimer toute session précédente.
          await prefs.remove('loggedInUser');
          await prefs.setBool('rememberMe', false);
          await prefs.remove('lastUsername');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connexion réussie pour $username !', style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => DashboardScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nom d\'utilisateur ou mot de passe incorrect.', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de connexion : $e', style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connexion'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.lock_person,
                  size: 80,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 30),
                Text(
                  'Connectez-vous à votre $appName',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColorDark,
                  ),
                ),
                const SizedBox(height: 30),
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Nom d\'utilisateur',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer votre nom d\'utilisateur.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    prefixIcon: const Icon(Icons.lock),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer votre mot de passe.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10), // Espace avant la case à cocher

                // NOUVEAU: Case à cocher "Se souvenir de moi"
                Row(
                  mainAxisAlignment: MainAxisAlignment.end, // Aligner à droite
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      onChanged: (bool? newValue) {
                        setState(() {
                          _rememberMe = newValue ?? false;
                        });
                      },
                    ),
                    const Text('Se souvenir de moi'),
                  ],
                ),

                const SizedBox(height: 30),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 5,
                        ),
                        child: const Text(
                          'Se connecter',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                  );
                  },
                  child: Text(
                    'Mot de passe oublié ?',
                    style: TextStyle(color: Theme.of(context).primaryColorDark, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const RestoreScreen()),
                    );
                  },
                  child: const Text(
                    'Restaurer les données de l\'application',
                    style: TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 16,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}