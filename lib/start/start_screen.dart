import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math'; // Pour Random
// import 'dart:convert'; // Pour base64UrlEncode - déjà importé ci-dessus

import '../config/database_helper.dart';
// import '../dashboardScreen.dart'; // Non utilisé dans ce fichier
import '../screens/auth/login_screen.dart';
import '../screens/settings/restore_screen.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});
  @override
  _StartScreenState createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  int _currentStep = 0;

  final List<GlobalKey<FormState>> _stepFormKeys = [
    GlobalKey<FormState>(), // Étape 0: Infos Générales
    GlobalKey<FormState>(), // Étape 1: Adresse & Identifiants
    GlobalKey<FormState>(), // NOUVEAU: Étape 2: Infos Administrateur
  ];

  final TextEditingController _nomMutualiteController = TextEditingController();
  final TextEditingController _nomResponsableController = TextEditingController();
  final TextEditingController _telephoneController = TextEditingController();
  final TextEditingController _adresseController = TextEditingController();
  final TextEditingController _idNationalController = TextEditingController();
  final TextEditingController _rccmController = TextEditingController();
  final TextEditingController _adminUsernameController = TextEditingController();
  final TextEditingController _adminPasswordController = TextEditingController();
  final TextEditingController _adminConfirmPasswordController = TextEditingController();

  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
  }

  Future<void> _saveMutualiteLocally() async {
    final mutualite = {
      'nom_mutualite': _nomMutualiteController.text,
      'nom_responsable': _nomResponsableController.text,
      'telephone': _telephoneController.text,
      'adresse': _adresseController.text,
      'id_national': _idNationalController.text,
      'rccm': _rccmController.text,
      'synchronized': 0,
    };

    try {
      final insertedMutualiteId = await _dbHelper.insertMutualite(mutualite);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mutualité enregistrée localement (ID: $insertedMutualiteId)!', style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.green,
        ),
      );

      final user = {
        'username': _adminUsernameController.text,
        'password': _adminPasswordController.text, // N'oubliez pas de hacher ceci en production!
        'role': 'admin',
      };
      await _dbHelper.insertUser(user);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Compte administrateur créé avec succès !', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.green,
        ),
      );

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isMutualiteConfigured', true);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } catch (e) {
      String errorMessage = 'Erreur lors de l\'enregistrement local : $e';
      if (e.toString().contains('UNIQUE constraint failed')) {
        errorMessage = 'Erreur : L\'ID National ou le RCCM ou le nom d\'utilisateur existe déjà. Veuillez vérifier vos informations.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage, style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _syncMutualiteToServer(int localId) async {
    final mutualiteToSync = await _dbHelper.getMutualiteById(localId);

    if (mutualiteToSync != null) {
      try {
        final response = await http.post(
          Uri.parse('VOTRE_URL_LARAVEL/api/mutualites'),
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: jsonEncode(mutualiteToSync),
        );

        if (response.statusCode == 201 || response.statusCode == 200) {
          await _dbHelper.updateMutualiteSynchronizedStatus(localId, 1);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Mutualité synchronisée avec le serveur !', style: const TextStyle(color: Colors.white)),
              backgroundColor: Colors.lightGreen,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Échec de la synchronisation : ${response.body}', style: const TextStyle(color: Colors.white)),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de connexion au serveur : $e', style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Step> get _steps => [
        Step(
          title: const Text('Infos Générales', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('Nom et contact de la mutualité'),
          content: Form(
            key: _stepFormKeys[0],
            child: Column(
              children: [
                _buildTextFormField(
                  controller: _nomMutualiteController,
                  labelText: 'Nom de la Mutualité',
                  icon: Icons.business,
                ),
                const SizedBox(height: 15),
                _buildTextFormField(
                  controller: _nomResponsableController,
                  labelText: 'Nom du Responsable',
                  icon: Icons.person,
                ),
                const SizedBox(height: 15),
                _buildTextFormField(
                  controller: _telephoneController,
                  labelText: 'Téléphone de contact',
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
          ),
          isActive: _currentStep >= 0,
          state: _currentStep > 0 ? StepState.complete : StepState.indexed,
        ),
        Step(
          title: const Text('Adresse & Identifiants', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('Adresse, ID National et RCCM'),
          content: Form(
            key: _stepFormKeys[1],
            child: Column(
              children: [
                _buildTextFormField(
                  controller: _adresseController,
                  labelText: 'Adresse de la Mutualité',
                  icon: Icons.location_on,
                ),
                const SizedBox(height: 15),
                _buildTextFormField(
                  controller: _idNationalController,
                  labelText: 'ID National',
                  icon: Icons.credit_card,
                ),
                const SizedBox(height: 15),
                _buildTextFormField(
                  controller: _rccmController,
                  labelText: 'RCCM',
                  icon: Icons.assignment,
                ),
              ],
            ),
          ),
          isActive: _currentStep >= 1,
          state: _currentStep > 1 ? StepState.complete : StepState.indexed,
        ),
        Step(
          title: const Text('Compte Administrateur', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('Créez votre nom d\'utilisateur et mot de passe admin'),
          content: Form(
            key: _stepFormKeys[2],
            child: Column(
              children: [
                _buildTextFormField(
                  controller: _adminUsernameController,
                  labelText: 'Nom d\'utilisateur Admin',
                  icon: Icons.person_add,
                ),
                const SizedBox(height: 15),
                _buildTextFormField(
                  controller: _adminPasswordController,
                  labelText: 'Mot de passe Admin',
                  icon: Icons.lock,
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Le mot de passe est requis.';
                    }
                    if (value.length < 6) {
                      return 'Le mot de passe doit contenir au moins 6 caractères.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),
                _buildTextFormField(
                  controller: _adminConfirmPasswordController,
                  labelText: 'Confirmer le mot de passe',
                  icon: Icons.lock_reset,
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'La confirmation du mot de passe est requise.';
                    }
                    if (value != _adminPasswordController.text) {
                      return 'Les mots de passe ne correspondent pas.';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          isActive: _currentStep >= 2,
          state: _currentStep > 2 ? StepState.complete : StepState.indexed,
        ),
        Step(
          title: const Text('Confirmation', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('Vérifiez et confirmez toutes les informations !'),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildConfirmationRow('Nom Mutualité:', _nomMutualiteController.text),
              _buildConfirmationRow('Responsable:', _nomResponsableController.text),
              _buildConfirmationRow('Téléphone:', _telephoneController.text),
              _buildConfirmationRow('Adresse:', _adresseController.text),
              _buildConfirmationRow('ID National:', _idNationalController.text),
              _buildConfirmationRow('RCCM:', _rccmController.text),
              const SizedBox(height: 15),
              const Divider(),
              const SizedBox(height: 15),
              _buildConfirmationRow('Nom utilisateur Admin:', _adminUsernameController.text),
              _buildConfirmationRow('Mot de passe Admin:', '********'), // Ne jamais afficher le vrai mot de passe
              const SizedBox(height: 20),
              Text(
                'Toutes les informations sont-elles correctes ?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.blueGrey[800]),
              ),
            ],
          ),
          isActive: _currentStep >= 3,
          state: _currentStep == 3 ? StepState.indexed : StepState.disabled,
        ),
      ];

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(icon, color: Colors.blueAccent),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
        contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 10.0),
      ),
      validator: validator ??
          (value) {
            if (value == null || value.isEmpty) {
              return 'Ce champ est requis.';
            }
            return null;
          },
    );
  }

  Widget _buildConfirmationRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuration de la Mutualité'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column( // Changé de SingleChildScrollView à Column
        children: [
          Expanded( // Ajouté Expanded ici
            child: Stepper(
              type: StepperType.vertical,
              currentStep: _currentStep,
              onStepContinue: () {
                if (_currentStep < _stepFormKeys.length) {
                  if (_stepFormKeys[_currentStep].currentState!.validate()) {
                    if (_currentStep < _steps.length - 1) {
                      setState(() {
                        _currentStep++;
                      });
                    } else {
                      _saveMutualiteLocally();
                    }
                  }
                } else {
                  if (_currentStep < _steps.length - 1) {
                    setState(() {
                      _currentStep++;
                    });
                  } else {
                    _saveMutualiteLocally();
                  }
                }
              },
              onStepCancel: () {
                if (_currentStep > 0) {
                  setState(() {
                    _currentStep--;
                  });
                }
              },
              controlsBuilder: (BuildContext context, ControlsDetails details) {
                return Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: ElevatedButton(
                          onPressed: details.onStepContinue,
                          child: Text(_currentStep == _steps.length - 1 ? 'Terminer et Créer !' : 'Continuer'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (_currentStep > 0)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: details.onStepCancel,
                            child: const Text('Précédent'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Theme.of(context).primaryColor,
                              side: BorderSide(color: Theme.of(context).primaryColor),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
              steps: _steps,
            ),
          ),
          // Déplacé le TextButton en dehors du Stepper mais toujours dans la Column
          Padding(
            padding: const EdgeInsets.only(bottom: 20.0), // Ajouter un peu de padding en bas
            child: TextButton(
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
            ),
          ),
        ],
      )
    );
  }

  @override
  void dispose() {
    _nomMutualiteController.dispose();
    _nomResponsableController.dispose();
    _telephoneController.dispose();
    _adresseController.dispose();
    _idNationalController.dispose();
    _rccmController.dispose();
    _adminUsernameController.dispose();
    _adminPasswordController.dispose();
    _adminConfirmPasswordController.dispose();
    super.dispose();
  }
}