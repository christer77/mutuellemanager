import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../config/database_helper.dart';
import '../dashboardScreen.dart';


class StartScreen extends StatefulWidget {
  @override
  _StartScreenState createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0; // Pour gérer l'étape actuelle du Stepper

  // Créez une liste de GlobalKey pour chaque étape qui contient un formulaire
  final List<GlobalKey<FormState>> _stepFormKeys = [
    GlobalKey<FormState>(), // Pour la première étape (Infos Générales)
    GlobalKey<FormState>(), // Pour la deuxième étape (Adresse & Identifiants)
    // Pas besoin de clé pour la troisième étape car elle ne contient pas de champs à valider
  ];

  final TextEditingController _nomMutualiteController = TextEditingController();
  final TextEditingController _nomResponsableController = TextEditingController();
  final TextEditingController _telephoneController = TextEditingController();
  final TextEditingController _adresseController = TextEditingController();
  final TextEditingController _idNationalController = TextEditingController();
  final TextEditingController _rccmController = TextEditingController();

  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _checkIfConfigured(); // Vérifier si l'app est déjà configurée
  }

  Future<void> _checkIfConfigured() async {
    // Dans une vraie app, vous stockeriez un flag 'isConfigured' dans SharedPreferences
    // Pour cet exemple, on peut vérifier si des mutualités existent
    final mutualites = await _dbHelper.getAllMutualites(); // Ajoutons cette méthode au DatabaseHelper
    if (mutualites.isNotEmpty) {
      // Si une mutualité existe, on redirige directement vers l'accueil
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => DashboardScreen()),
      );
    }
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
      final insertedId = await _dbHelper.insertMutualite(mutualite);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mutualité enregistrée localement (ID: $insertedId)!', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.green,
        ),
      );

      _syncMutualiteToServer();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => DashboardScreen()),
      );
    } catch (e) {
      String errorMessage = 'Erreur lors de l\'enregistrement local : $e';
      if (e.toString().contains('UNIQUE constraint failed')) {
        errorMessage = 'Erreur : L\'ID National ou le RCCM existe déjà. Veuillez vérifier vos informations.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage, style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _syncMutualiteToServer() async {
    final List<Map<String, dynamic>> unsyncedMutualites = await _dbHelper.getUnsyncedMutualites();

    if (unsyncedMutualites.isNotEmpty) {
      for (var mutualite in unsyncedMutualites) {
        try {
          final response = await http.post(
            Uri.parse('VOTRE_URL_LARAVEL/api/mutualites'),
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
            },
            body: jsonEncode(mutualite),
          );

          if (response.statusCode == 201 || response.statusCode == 200) {
            await _dbHelper.updateMutualiteSynchronizedStatus(mutualite['id'] as int, 1);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Mutualité synchronisée avec le serveur !', style: TextStyle(color: Colors.white)),
                backgroundColor: Colors.lightGreen,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Échec de la synchronisation : ${response.body}', style: TextStyle(color: Colors.white)),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur de connexion au serveur : $e', style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  List<Step> get _steps => [
        Step(
          title: Text('Infos Générales', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('Nom et contact de la mutualité'),
          content: Form( // Ajoutez un widget Form pour cette étape
            key: _stepFormKeys[0], // Associez la clé de la première étape
            child: Column(
              children: [
                _buildTextFormField(
                  controller: _nomMutualiteController,
                  labelText: 'Nom de la Mutualité',
                  icon: Icons.business,
                ),
                SizedBox(height: 15),
                _buildTextFormField(
                  controller: _nomResponsableController,
                  labelText: 'Nom du Responsable',
                  icon: Icons.person,
                ),
                SizedBox(height: 15),
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
          title: Text('Adresse & Identifiants', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('Adresse, ID National et RCCM'),
          content: Form( // Ajoutez un widget Form pour cette étape
            key: _stepFormKeys[1], // Associez la clé de la deuxième étape
            child: Column(
              children: [
                _buildTextFormField(
                  controller: _adresseController,
                  labelText: 'Adresse de la Mutualité',
                  icon: Icons.location_on,
                ),
                SizedBox(height: 15),
                _buildTextFormField(
                  controller: _idNationalController,
                  labelText: 'ID National',
                  icon: Icons.credit_card,
                ),
                SizedBox(height: 15),
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
          title: Text('Confirmation', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('Vérifiez et confirmez !'),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildConfirmationRow('Nom Mutualité:', _nomMutualiteController.text),
              _buildConfirmationRow('Responsable:', _nomResponsableController.text),
              _buildConfirmationRow('Téléphone:', _telephoneController.text),
              _buildConfirmationRow('Adresse:', _adresseController.text),
              _buildConfirmationRow('ID National:', _idNationalController.text),
              _buildConfirmationRow('RCCM:', _rccmController.text),
              SizedBox(height: 20),
              Text(
                'Toutes les informations sont-elles correctes ?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.blueGrey[800]),
              ),
            ],
          ),
          isActive: _currentStep >= 2,
          state: _currentStep == 2 ? StepState.indexed : StepState.disabled,
        ),
      ];

  // Helper pour les champs de texte afin de réduire la répétition
  Widget _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(icon, color: Colors.blueAccent),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Ce champ est requis.';
        }
        return null;
      },
    );
  }

  // Helper pour les lignes de confirmation
  Widget _buildConfirmationRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 16),
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
        title: Text('Configurez votre Mutualité !'),
      ),
      // Supprimez le widget Form ici, car chaque étape aura son propre Form
      body: Stepper(
        type: StepperType.vertical,
        currentStep: _currentStep,
        onStepContinue: () {
          // Si l'étape actuelle a une clé de formulaire, validez-la
          if (_currentStep < _stepFormKeys.length && _stepFormKeys[_currentStep].currentState!.validate()) {
            if (_currentStep < _steps.length - 1) {
              setState(() {
                _currentStep++;
              });
            } else {
              // Dernière étape : Sauvegarder
              _saveMutualiteLocally();
            }
          } else if (_currentStep >= _stepFormKeys.length) {
            // Si c'est une étape sans formulaire (comme la confirmation), on passe directement
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
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: details.onStepCancel,
                      child: Text('Précédent'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).primaryColor,
                        side: BorderSide(color: Theme.of(context).primaryColor),
                        padding: EdgeInsets.symmetric(vertical: 12),
                        textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
        steps: _steps,
      ),
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
    super.dispose();
  }
}
