import 'package:flutter/material.dart';
import 'package:mutuellemanager/screens/auth/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';
import '../screens/membres/add_member_screen.dart';
import '../screens/membres/members_balance_screen.dart';
import '../screens/membres/members_list_screen.dart';
import '../screens/operations/add_contribution_screen.dart';
import '../screens/operations/add_operation_screen.dart';
import '../screens/operations/operations_list_screen.dart';
import '../screens/rapports/reports_screen.dart';

typedef VoidCallbackWithRefresh = Future<void> Function();


class Navbar extends StatelessWidget {
  final VoidCallbackWithRefresh onRefreshDashboard;

  final BuildContext context;

  const Navbar({super.key, required this.context, required this.onRefreshDashboard});

  // Fonction de déconnexion
  Future<void> _logout(BuildContext context) async {
    // Afficher une boîte de dialogue de confirmation (optionnel mais recommandé)
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Déconnexion'),
          content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false), // Annuler
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true), // Confirmer
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Déconnexion', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      // Supprimer l'information de l'utilisateur connecté
      await prefs.remove('loggedInUser'); //
      await prefs.setBool('rememberMe', false); // Optionnel: décocher 'rememberMe' aussi lors de la déconnexion
      await prefs.remove('lastUsername'); // Optionnel: supprimer le dernier nom d'utilisateur

      // Vous pouvez également supprimer d'autres données de session si nécessaire
      // await prefs.clear(); // Pour supprimer TOUTES les préférences

      // Naviguer vers l'écran de connexion et supprimer toutes les routes précédentes
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false, // Cela supprime toutes les routes du stack
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Déconnecté avec succès !', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              image: DecorationImage(
                image: AssetImage('assets/images/logo.png'), // Ajoutez une image de fond si vous en avez une
                fit: BoxFit.cover,
                opacity: 0.6,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.group_work, color: Theme.of(context).primaryColor, size: 30),
                ),
                SizedBox(height: 8),
                Text(
                  '$appName', // Remplacez par le nom réel de la mutualité
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Bienvenue !',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          /* ListTile(
            leading: Icon(Icons.dashboard),
            title: Text('Tableau de Bord'),
            onTap: () {
              Navigator.pop(context); // Ferme le tiroir
              // Vous êtes déjà sur le tableau de bord
            },
          ), */
          Divider(),
          ListTile(
            leading: Icon(Icons.person_add),
            title: Text('Ajouter un Nouveau Membre'),
            onTap: () async {
              Navigator.pop(context);
              final bool? result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddMemberScreen()),
              );
              if (result == true) {
                onRefreshDashboard();
              }
            },
          ),
          ListTile(
            leading: Icon(Icons.balance),
            title: Text('Solde des Membres'),
            onTap: () async {
              Navigator.pop(context);
              final bool? result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MembersBalanceScreen()),
              );
              if (result == true) {
                onRefreshDashboard();
              }
            },
          ),
          
          ListTile(
            leading: Icon(Icons.payment),
            title: Text('Ajouter une Cotisation'),
            onTap: () async {
              Navigator.pop(context);
              final bool? result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddContributionScreen())); // Nouvelle route
              if (result == true) {
                onRefreshDashboard();
              }
            },
          ),
          ListTile(
            leading: Icon(Icons.money_off_csred),
            title: Text('Ajouter une Dépense'),
            onTap: () async {
              Navigator.pop(context);
              final bool? result = await Navigator.push(context, MaterialPageRoute(builder: (context) => AddOperationScreen(initialType: 'depense')));
              if (result == true) {
                onRefreshDashboard();
              }
            },
          ),
          ListTile(
            leading: Icon(Icons.attach_money_rounded),
            title: Text('Ajouter un Revenu'),
            onTap: () async {
              Navigator.pop(context);
              // Passe 'revenu' comme type initial
              final bool? result = await Navigator.push(context, MaterialPageRoute(builder: (context) => AddOperationScreen(initialType: 'revenu')));
              if (result == true) {
                onRefreshDashboard();
              }
            },
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.group),
            title: Text('Gérer les Membres'),
            onTap: () async {
              Navigator.pop(context);
              final bool? result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MembersListScreen()),
            );
            if (result == true) {
              onRefreshDashboard(); // Pour mettre à jour le nombre de membres
            }
            },
          ),
          ListTile(
            leading: Icon(Icons.price_change),
            title: Text('Historique des Dépenses'),
            onTap: () async {
              Navigator.pop(context);
              final bool? result = await Navigator.push(context, MaterialPageRoute(builder: (context) => OperationsListScreen(typeOperation: 'depense',)));
              if (result == true) {
                onRefreshDashboard();
              }
            },
          ),
           ListTile(
            leading: Icon(Icons.trending_up),
            title: Text('Historique des Revenus'),
            onTap: () async {
              Navigator.pop(context);
              final bool? result = await Navigator.push(context, MaterialPageRoute(builder: (context) => OperationsListScreen(typeOperation: 'revenu',)));
              if (result == true) {
                onRefreshDashboard();
              }
            },
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.bar_chart),
            title: Text('Rapports et Statistiques'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => ReportsScreen()));
            },
          ),
          /* ListTile(
            leading: Icon(Icons.settings),
            title: Text('Paramètres'),
            onTap: () {
              // Navigator.pop(context);
              // Navigator.push(context, MaterialPageRoute(builder: (context) => SettingsScreen()));
            },
          ), */
          const Divider(),
          // NOUVEAU: Bouton de déconnexion
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Déconnexion', style: TextStyle(color: Colors.redAccent)),
            onTap: () => _logout(context), // Appelle la fonction de déconnexion
          ),
        ],
      ),
    );
  }
}
