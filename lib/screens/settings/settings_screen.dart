import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../config/constants.dart';
import '../../config/database_helper.dart';
import '../auth/login_screen.dart'; // Assurez-vous que le chemin est correct pour votre projet

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Contrôleurs pour la modification du mot de passe
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmNewPasswordController = TextEditingController();
  final GlobalKey<FormState> _passwordFormKey = GlobalKey<FormState>();

  // Contrôleurs pour la modification des informations de la mutualité
  final TextEditingController _nomMutualiteController = TextEditingController();
  final TextEditingController _nomResponsableController = TextEditingController();
  final TextEditingController _telephoneController = TextEditingController();
  final TextEditingController _adresseController = TextEditingController();
  final TextEditingController _idNationalController = TextEditingController();
  final TextEditingController _rccmController = TextEditingController();
  final GlobalKey<FormState> _mutualiteFormKey = GlobalKey<FormState>();

  // ID local de la mutualité
  int? _mutualiteLocalId;
  String _selectedCurrency = 'USD';
  final List<String> _availableCurrencies = ['USD', 'XAF', 'XOF', 'EUR', 'GBP', 'CDF'];

  @override
  void initState() {
    super.initState();
    _loadMutualiteInfo();
    _loadCurrencySetting();
  }

  // --- Fonctions existantes (inchangées) ---
  Future<void> _loadMutualiteInfo() async {
    try {
      final mutualite = await _dbHelper.getMutualite();
      if (mutualite != null) {
        setState(() {
          _mutualiteLocalId = mutualite['id'] as int;
          _nomMutualiteController.text = mutualite['nom_mutualite'] ?? '';
          _nomResponsableController.text = mutualite['nom_responsable'] ?? '';
          _telephoneController.text = mutualite['telephone'] ?? '';
          _adresseController.text = mutualite['adresse'] ?? '';
          _idNationalController.text = mutualite['id_national'] ?? '';
          _rccmController.text = mutualite['rccm'] ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement des informations de la mutualité: $e', style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadCurrencySetting() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedCurrency = prefs.getString('currencyUnit') ?? 'USD';
    });
  }

  Future<void> _saveCurrencySetting(String? newCurrency) async {
    if (newCurrency != null && newCurrency != _selectedCurrency) {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('currencyUnit', newCurrency);
      setState(() {
        _selectedCurrency = newCurrency;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unité monétaire mise à jour à $newCurrency !', style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) {
      return;
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? currentUsername = prefs.getString('loggedInUser');

    if (currentUsername == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur: Aucun utilisateur connecté.', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final String currentPassword = _currentPasswordController.text;
    final String newPassword = _newPasswordController.text;

    try {
      final bool passwordMatches = await _dbHelper.checkUserPassword(currentUsername, currentPassword);

      if (passwordMatches) {
        await _dbHelper.updateUserPassword(currentUsername, newPassword);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mot de passe mis à jour avec succès !', style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.green,
            ),
          );
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmNewPasswordController.clear();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mot de passe actuel incorrect.', style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la mise à jour du mot de passe: $e', style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.red,
          ),
        );
      }
      // print('Erreur _changePassword: $e'); // Pour le débogage
    }
  }

  Future<void> _updateMutualiteInfo() async {
    if (!_mutualiteFormKey.currentState!.validate()) {
      return;
    }

    if (_mutualiteLocalId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur: Aucune mutualité trouvée pour la mise à jour.', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final updatedMutualite = {
      'id': _mutualiteLocalId,
      'nom_mutualite': _nomMutualiteController.text,
      'nom_responsable': _nomResponsableController.text,
      'telephone': _telephoneController.text,
      'adresse': _adresseController.text,
      'id_national': _idNationalController.text,
      'rccm': _rccmController.text,
      'synchronized': 0,
    };

    try {
      await _dbHelper.updateMutualite(updatedMutualite);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Informations de la mutualité mises à jour !', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Erreur lors de la mise à jour des informations de la mutualité: $e';
        if (e.toString().contains('UNIQUE constraint failed')) {
          errorMessage = 'Erreur : L\'ID National ou le RCCM existe déjà pour une autre mutualité.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage, style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.red,
          ),
        );
      }
      // print('Erreur _updateMutualiteInfo: $e'); // Pour le débogage
    }
  }

  Future<void> _syncMutualiteToServer(int localId) async {
    final mutualiteToSync = await _dbHelper.getMutualiteById(localId);

    if (mutualiteToSync != null) {
      try {
        // Remplacez 'VOTRE_URL_LARAVEL' par l'URL réelle de votre API Laravel
        final response = await http.post(
          Uri.parse('VOTRE_URL_LARAVEL/api/mutualites'),
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: jsonEncode(mutualiteToSync),
        );

        if (response.statusCode == 201 || response.statusCode == 200) {
          await _dbHelper.updateMutualiteSynchronizedStatus(localId, 1);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Mutualité synchronisée avec le serveur !', style: TextStyle(color: Colors.white)),
                backgroundColor: Colors.lightGreen,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Échec de la synchronisation : ${response.body}', style: const TextStyle(color: Colors.white)),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur de connexion au serveur lors de la synchronisation : $e', style: const TextStyle(color: Colors.white)),
              backgroundColor: Colors.red,
            ),
          );
        }
        // print('Erreur _syncMutualiteToServer: $e'); // Pour le débogage
      }
    }
  }

  
  Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      
      final status = await Permission.storage.request();
      return status.isGranted;
    }
    return true; // iOS/gestion simplifiée
  }
  Future<bool> _requestStoragePermission() async {
    // Note: On Android, for API level 30+, using getExternalStorageDirectory
    // and FilePicker's saveFile might not explicitly require
    // MANAGE_EXTERNAL_STORAGE. However, for broader compatibility
    // (especially older Android versions) or if accessing arbitrary paths,
    // it's good practice to ensure permissions.
    // For iOS, storage permissions are usually handled by default for app's sandbox.
    requestStoragePermission();
    /* if (Platform.isAndroid) {
      // print("xxxxxxxxxxxxxx");
      // final status = await permission.request();
      final status = await Permission.storage.status;
      if (status.isGranted) {
        return true;
      } else {
        final result = await Permission.storage.request();
        if (result.isGranted) {
          return true;
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Permission de stockage non accordée. Veuillez l\'activer dans les paramètres de l\'application.', style: TextStyle(color: Colors.white)),
                backgroundColor: Colors.red,
                action: SnackBarAction(label: 'Ouvrir Paramètres', onPressed: openAppSettings),
              ),
            );
          }
          return false;
        }
        
      }
    } */
    return true; // iOS et autres plateformes gèrent les permissions différemment ou n'en ont pas besoin explicite
  }

  /* Future<bool> _checkMediaPermissions() async {
  if (Platform.isAndroid) {
    // Gestion spécifique Android
    final sdkVersion = await DeviceInfoPlugin().androidInfo.then((info) => info.version.sdkInt);
    
    if (sdkVersion >= 33) {
      // Android 13+
      return await Permission.photos.request().isGranted &&
             await Permission.videos.request().isGranted &&
             await Permission.audio.request().isGranted;
    } else {
      // Android <13
      return await Permission.storage.request().isGranted;
    }
  } else {
    // iOS (utiliser Permission.photos, etc.)
    return await Permission.photos.request().isGranted;
  }
} */

  Future<void> _backupData() async {
    if (!await _requestStoragePermission()) {
      return;
    }

    try {
      final List<Map<String, dynamic>> mutualites = await _dbHelper.getAllMutualites();
      final List<Map<String, dynamic>> users = await _dbHelper.getAllUsers();
      // TODO: Récupérez ici toutes les autres tables que vous voulez sauvegarder
      final List<Map<String, dynamic>> membres = await _dbHelper.getAllMembres();
      final List<Map<String, dynamic>> operations = await _dbHelper.getAllOperations();

      final Map<String, dynamic> backupData = {
        'mutualites': mutualites,
        'users': users,
        // TODO: Ajoutez ici les autres tables
        'membres': membres,
        'operations': operations,
      };

      final String jsonString = jsonEncode(backupData);
      // CONVERSION CLÉ ICI : Convertir la chaîne JSON en Uint8List (bytes)
      final Uint8List jsonBytes = Uint8List.fromList(utf8.encode(jsonString));

      final String timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 0); // Modifié à 0 pour éviter un problème potentiel de sous-chaîne si la chaîne est courte
      final String defaultFileName = 'mutualite_backup_$timestamp.json';

      // Utilisez le paramètre `bytes` de saveFile
      String? outputPath = await FilePicker.platform.saveFile(
        fileName: defaultFileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: jsonBytes, // PASSEZ LES BYTES ICI
      );

      if (outputPath == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sauvegarde annulée.', style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Si FilePicker.platform.saveFile a réussi à sauvegarder les bytes,
      // vous n'avez plus besoin de faire backupFile.writeAsString(jsonString);
      // La ligne suivante peut être supprimée si la sauvegarde par FilePicker.platform.saveFile
      // est suffisante pour votre cas d'utilisation.
      // Cependant, si vous voulez garantir que le fichier est bien écrit,
      // ou si FilePicker.platform.saveFile retourne juste le chemin sans écrire les bytes sur certaines plateformes,
      // vous pourriez garder la logique d'écriture manuelle.
      // Dans la plupart des cas, si `bytes` est fourni à `saveFile`, il écrira le fichier.
      // S'il y a un souci, vous pouvez décommenter les lignes suivantes:
      /*
      final File backupFile = File(outputPath);
      if (!outputPath.endsWith('.json')) {
        outputPath += '.json';
      }
      await backupFile.writeAsBytes(jsonBytes); // Écriture avec les bytes
      */

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sauvegarde réussie dans : $outputPath', style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Échec de la sauvegarde : $e', style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.red,
          ),
        );
      }
      // print('Erreur _backupData: $e'); // Pour le débogage
    }
  }

  // La fonction _restoreData reste inchangée et sera déplacée/dupliquée dans restore_screen.dart
  // Pour le moment, nous la gardons ici car elle est encore utilisée dans le TabBarView.
  // Une fois restore_screen.dart implémenté, cette fonction sera retirée de SettingsScreen.
  Future<void> _restoreData() async {
    if (!await _requestStoragePermission()) {
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Restaurer les données'),
          content: const Text(
              'ATTENTION : La restauration écrasera toutes les données actuelles de l\'application. Êtes-vous sûr de vouloir continuer ?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Confirmer la restauration', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    try {
      // Permettre à l'utilisateur de sélectionner un fichier JSON
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.single.path == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aucun fichier de sauvegarde sélectionné.', style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final File backupFile = File(result.files.single.path!);
      final String jsonString = await backupFile.readAsString();
      final Map<String, dynamic> backupData = jsonDecode(jsonString);

      // Vider les tables existantes avant d'insérer les nouvelles données
      await _dbHelper.deleteAll('mutualites');
      await _dbHelper.deleteAll('users');
      // TODO: Videz ici toutes vos autres tables
      await _dbHelper.deleteAll('membres');
      await _dbHelper.deleteAll('operations');

      // Insérer les données restaurées
      if (backupData.containsKey('mutualites')) {
        for (var item in backupData['mutualites']) {
          await _dbHelper.insertMutualite(item);
        }
      }
      if (backupData.containsKey('users')) {
        for (var item in backupData['users']) {
          await _dbHelper.insertUser(item);
        }
      }
      // TODO: Insérez ici les données de vos autres tables
      if (backupData.containsKey('membres')) {
        for (var item in backupData['membres']) {
          await _dbHelper.insertMembre(item);
        }
      }
      if (backupData.containsKey('operations')) {
        for (var item in backupData['operations']) {
          await _dbHelper.insertOperation(item);
        }
      }

      // Après restauration, assurez-vous que l'état de la mutualité est revalidé
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isMutualiteConfigured', true); // Supposons qu'une mutualité est restaurée
      await prefs.remove('loggedInUser'); // Force l'utilisateur à se reconnecter
      await prefs.setBool('rememberMe', false); // Désactive le "se souvenir de moi" après restauration

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Données restaurées avec succès ! Veuillez vous reconnecter.', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.green,
          ),
        );
        // Rediriger vers l'écran de connexion après restauration réussie
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Échec de la restauration : $e', style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.red,
          ),
        );
      }
      // print('Erreur _restoreData: $e'); // Pour le débogage
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4, // CHANGEMENT ICI: 4 onglets maintenant
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Paramètres'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.lock), text: 'Mot de passe'),
              Tab(icon: Icon(Icons.business), text: 'Mutualité'),
              Tab(icon: Icon(Icons.archive), text: 'Sauvegarde'),
              Tab(icon: Icon(Icons.info_outline), text: 'À propos'), // NOUVEL ONGLET
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Onglet 1: Modification du mot de passe
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _passwordFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Modifier le mot de passe',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _currentPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Mot de passe actuel',
                        prefixIcon: const Icon(Icons.vpn_key),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer votre mot de passe actuel.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _newPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Nouveau mot de passe',
                        prefixIcon: const Icon(Icons.lock),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer un nouveau mot de passe.';
                        }
                        if (value.length < 6) {
                          return 'Le mot de passe doit contenir au moins 6 caractères.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _confirmNewPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Confirmer le nouveau mot de passe',
                        prefixIcon: const Icon(Icons.lock_reset),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez confirmer votre nouveau mot de passe.';
                        }
                        if (value != _newPasswordController.text) {
                          return 'Les mots de passe ne correspondent pas.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton.icon(
                      onPressed: _changePassword,
                      icon: const Icon(Icons.save),
                      label: const Text('Enregistrer le nouveau mot de passe'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Onglet 2: Modification des informations de la mutualité
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _mutualiteFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Modifier les informations de la Mutualité',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
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
                    const SizedBox(height: 15),
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
                    const SizedBox(height: 15),
                    const Text(
                      'Unité Monétaire :',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _selectedCurrency,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.currency_exchange),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                      items: _availableCurrencies.map((String currency) {
                        return DropdownMenuItem<String>(
                          value: currency,
                          child: Text(currency),
                        );
                      }).toList(),
                      onChanged: _saveCurrencySetting,
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton.icon(
                      onPressed: _updateMutualiteInfo,
                      icon: const Icon(Icons.save),
                      label: const Text('Enregistrer les modifications'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Onglet 3: Sauvegarde et Restauration
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Sauvegarde et Restauration Locales',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Sauvegardez les données de l\'application vers un fichier sur votre appareil. Vous pourrez choisir le dossier de destination.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _backupData,
                    icon: const Icon(Icons.cloud_download),
                    label: const Text('Créer une sauvegarde locale'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    'Restaurer les données de l\'application à partir d\'un fichier de sauvegarde local. Cette opération écrasera toutes les données actuelles de l\'application. Assurez-vous de sélectionner le bon fichier.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _restoreData,
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('Restaurer à partir d\'une sauvegarde'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),

            // NOUVEL ONGLET: Fonctionnalités clés de l'application
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Fonctionnalités Clés de l\'Application',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                    textAlign: TextAlign.center,
                  ),
                  const Text(
                    'Version: $appVersion',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const Text(
                    'Developer: $developper',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const Text(
                    'Contact: $adresse',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  
                  
                  const SizedBox(height: 20),
                  _buildFeatureTile(
                    Icons.dashboard,
                    'Tableau de Bord Intuitif',
                    'Visualisez un aperçu rapide de l\'état de votre mutualité avec des statistiques clés et des graphiques faciles à comprendre.',
                  ),
                  _buildFeatureTile(
                    Icons.group,
                    'Gestion des Membres',
                    'Enregistrez et gérez les informations de vos membres, y compris leurs détails personnels, leur historique de cotisation et leurs coordonnées.',
                  ),
                  _buildFeatureTile(
                    Icons.account_balance_wallet,
                    'Suivi des Opérations Financières',
                    // 'Enregistrez toutes les transactions (dépôts, retraits, prêts, remboursements) avec des détails précis et un suivi en temps réel des soldes.',
                    'Enregistrez toutes les transactions (dépenses, recettes) avec des détails précis et un suivi en temps réel des soldes.',
                  ),
                  /* _buildFeatureTile(
                    Icons.request_quote,
                    'Gestion des Prêts',
                    'Créez, suivez et gérez les demandes de prêt, y compris les montants, les échéanciers de remboursement et le statut des prêts.',
                  ), */
                  _buildFeatureTile(
                    Icons.receipt,
                    'Rapports Détaillés',
                    // 'Générez des rapports financiers complets (bilan, compte de résultat, flux de trésorerie) et des rapports d\'activités pour une meilleure prise de décision.',
                    'Générez des rapports d\'activités pour une meilleure prise de décision.',
                  ),
                  /* _buildFeatureTile(
                    Icons.security,
                    'Gestion Sécurisée des Utilisateurs',
                    'Créez et gérez des comptes utilisateurs avec différents niveaux d\'autorisation pour contrôler l\'accès aux fonctionnalités de l\'application.',
                  ), */
                  _buildFeatureTile(
                    Icons.settings_backup_restore,
                    'Sauvegarde et Restauration des Données',
                    'Protégez vos données importantes grâce à des fonctionnalités de sauvegarde locale et de restauration facile en cas de besoin.',
                  ),
                  /* _buildFeatureTile(
                    Icons.cloud_sync,
                    'Synchronisation des Données (Optionnel)',
                    'Synchronisez les informations de votre mutualité avec un serveur distant pour un accès et une sauvegarde centralisés (nécessite une configuration serveur).',
                  ), */
                  _buildFeatureTile(
                    Icons.currency_exchange,
                    'Support Multi-Devises',
                    'Choisissez l\'unité monétaire de votre mutualité pour s\'adapter à vos besoins locaux.',
                  ),
                  // Ajoutez d'autres fonctionnalités si nécessaire
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget helper pour les TextFormField (inchangé)
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
      validator: validator ?? (value) {
        if (value == null || value.isEmpty) {
          return 'Ce champ est requis.';
        }
        return null;
      },
    );
  }

  // NOUVEAU WIDGET HELPER pour les tuiles de fonctionnalités
  Widget _buildFeatureTile(IconData icon, String title, String description) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 36, color: Theme.of(context).primaryColor),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 14,
                      // color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmNewPasswordController.dispose();
    _nomMutualiteController.dispose();
    _nomResponsableController.dispose();
    _telephoneController.dispose();
    _adresseController.dispose();
    _idNationalController.dispose();
    _rccmController.dispose();
    super.dispose();
  }
}