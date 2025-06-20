// lib/screens/restore_screen.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/database_helper.dart';
import '../auth/login_screen.dart';

class RestoreScreen extends StatefulWidget {
  const RestoreScreen({super.key});

  @override
  State<RestoreScreen> createState() => _RestoreScreenState();
}

class _RestoreScreenState extends State<RestoreScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<bool> _requestStoragePermission() async {
    requestStoragePermission();
    /* if (Platform.isAndroid) {
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
              ),
            );
          }
          return false;
        }
        
      }
    } */
    return true; // iOS et autres plateformes gèrent les permissions différemment ou n'en ont pas besoin explicite
  }

  Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      
      final status = await Permission.storage.request();
      return status.isGranted;
    }
    return true; // iOS/gestion simplifiée
  }

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
      // await _dbHelper.deleteAll('membres');
      // await _dbHelper.deleteAll('operations');

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
      // if (backupData.containsKey('membres')) {
      //   for (var item in backupData['membres']) {
      //     await _dbHelper.insertMembre(item);
      //   }
      // }
      // if (backupData.containsKey('operations')) {
      //   for (var item in backupData['operations']) {
      //     await _dbHelper.insertOperation(item);
      //   }
      // }

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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurer les données'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.restore,
                size: 80,
                color: Colors.orange,
              ),
              const SizedBox(height: 20),
              const Text(
                'Cliquez ci-dessous pour restaurer les données de l\'application à partir d\'un fichier de sauvegarde. Cette opération écrasera toutes les données actuelles.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _restoreData,
                icon: const Icon(Icons.cloud_upload),
                label: const Text('Restaurer à partir d\'une sauvegarde'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}