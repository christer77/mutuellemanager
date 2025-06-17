import 'package:flutter/material.dart';

class Navbar extends StatelessWidget {
  final BuildContext context;

  const Navbar({super.key, required this.context});

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
                  'Ma Mutualité', // Remplacez par le nom réel de la mutualité
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
          ListTile(
            leading: Icon(Icons.dashboard),
            title: Text('Tableau de Bord'),
            onTap: () {
              Navigator.pop(context); // Ferme le tiroir
              // Vous êtes déjà sur le tableau de bord
            },
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.person_add),
            title: Text('Ajouter un Nouveau Membre'),
            onTap: () {
              // Navigator.pop(context);
              // Navigator.push(context, MaterialPageRoute(builder: (context) => AddMemberScreen()));
            },
          ),
          ListTile(
            leading: Icon(Icons.payment),
            title: Text('Ajouter une Cotisation'),
            onTap: () {
              // Navigator.pop(context);
              // Navigator.push(context, MaterialPageRoute(builder: (context) => AddContributionScreen()));
            },
          ),
          ListTile(
            leading: Icon(Icons.money_off_csred),
            title: Text('Ajouter une Dépense'),
            onTap: () {
              // Navigator.pop(context);
              // Navigator.push(context, MaterialPageRoute(builder: (context) => AddExpenseScreen()));
            },
          ),
          ListTile(
            leading: Icon(Icons.attach_money_rounded),
            title: Text('Ajouter un Revenu'),
            onTap: () {
              // Navigator.pop(context);
              // Navigator.push(context, MaterialPageRoute(builder: (context) => AddIncomeScreen()));
            },
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.group),
            title: Text('Gérer les Membres'),
            onTap: () {
              // Navigator.pop(context);
              // Navigator.push(context, MaterialPageRoute(builder: (context) => MembersListScreen()));
            },
          ),
          ListTile(
            leading: Icon(Icons.credit_card),
            title: Text('Historique des Cotisations'),
            onTap: () {
              // Navigator.pop(context);
              // Navigator.push(context, MaterialPageRoute(builder: (context) => ContributionsListScreen()));
            },
          ),
          ListTile(
            leading: Icon(Icons.price_change),
            title: Text('Historique des Dépenses'),
            onTap: () {
              // Navigator.pop(context);
              // Navigator.push(context, MaterialPageRoute(builder: (context) => ExpensesListScreen()));
            },
          ),
           ListTile(
            leading: Icon(Icons.trending_up),
            title: Text('Historique des Revenus'),
            onTap: () {
              // Navigator.pop(context);
              // Navigator.push(context, MaterialPageRoute(builder: (context) => IncomesListScreen()));
            },
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.bar_chart),
            title: Text('Rapports et Statistiques'),
            onTap: () {
              // Navigator.pop(context);
              // Navigator.push(context, MaterialPageRoute(builder: (context) => ReportsScreen()));
            },
          ),
          ListTile(
            leading: Icon(Icons.settings),
            title: Text('Paramètres'),
            onTap: () {
              // Navigator.pop(context);
              // Navigator.push(context, MaterialPageRoute(builder: (context) => SettingsScreen()));
            },
          ),
        ],
      ),
    );
  }
}
