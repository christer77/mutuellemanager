// lib/screens/update_required_screen.dart
import 'package:flutter/material.dart';
// import 'package:url_launcher/url_launcher.dart'; // Pour ouvrir le lien de l'App Store

class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key});

  // Remplacez par vos URL réelles de l'App Store
  // final String _androidAppUrl = 'https://play.google.com/store/apps/details?id=YOUR_ANDROID_APP_ID';
  // final String _iosAppUrl = 'https://apps.apple.com/us/app/YOUR_IOS_APP_ID';

  // Future<void> _launchURL(String url) async {
  //   final Uri uri = Uri.parse(url);
  //   if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
  //     throw 'Could not launch $url';
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mise à jour requise'),
        automaticallyImplyLeading: false, // Empêcher de revenir en arrière
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.system_update_alt, size: 80, color: Colors.redAccent),
              const SizedBox(height: 20),
              const Text(
                'Une nouvelle version de l\'application est disponible et obligatoire.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'Veuillez mettre à jour l\'application pour continuer à utiliser toutes les fonctionnalités.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 40),
              // ElevatedButton.icon(
              //   onPressed: () => _launchURL(_androidAppUrl), // Ou détecter la plateforme et lancer l'URL appropriée
              //   icon: const Icon(Icons.download),
              //   label: const Text('Mettre à jour via Google Play', style: TextStyle(fontSize: 16)),
              //   style: ElevatedButton.styleFrom(
              //     padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              //   ),
              // ),
              // const SizedBox(height: 15),
              // Vous voudrez peut-être ajouter un bouton iOS si vous prévoyez également pour iOS
              // ElevatedButton.icon(
              //   onPressed: () => _launchURL(_iosAppUrl),
              //   icon: const Icon(Icons.apple),
              //   label: const Text('Mettre à jour via App Store', style: TextStyle(fontSize: 16)),
              //   style: ElevatedButton.styleFrom(
              //     padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              //   ),
              // ),
            ],
          ),
        ),
      ),
    );
  }
}