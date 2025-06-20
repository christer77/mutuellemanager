import 'package:flutter/material.dart';
import 'package:mutuellemanager/widget/navbar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/database_helper.dart' show DatabaseHelper;
import 'screens/membres/add_member_screen.dart';
import 'screens/membres/members_list_screen.dart';
import 'screens/operations/add_contribution_screen.dart';
import 'screens/operations/add_operation_screen.dart' show AddOperationScreen;
import 'screens/rapports/reports_screen.dart';
import 'screens/settings/settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Ces valeurs seraient dynamiques et proviendraient de votre base de données locale/synchronisée
  int _totalMembers = 0;
  double _totalContributions = 00.00;
  double _totalOtherRevenus  = 00.00;
  double _totalExpenses = 00.00;
  double _currentBalance = 00.00; // Contributions - Expenses
  String _currencyUnit = 'USD'; // Valeur par défaut ou fallback

  final DatabaseHelper _dbHelper = DatabaseHelper(); // Instanciez le DB Helper

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadCurrencyUnit() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _currencyUnit = prefs.getString('currencyUnit') ?? 'USD';
    });
  }

  Future<void> _loadDashboardData() async {
    

    // Ici, vous feriez appel à votre DatabaseHelper pour récupérer les données agrégées
    // Par exemple:
    // final members = await DatabaseHelper().getAllMembers();

    final memberMaps = await _dbHelper.getAllMembres();
    final totalMembers = memberMaps.length;


    final totalExpenses = await _dbHelper.getTotalExpenses();
    final cotisations = await _dbHelper.getTotalCotisations();
    final otherRevenus = await _dbHelper.getTotalOtherRevenus();

    final currentBalance = (otherRevenus + cotisations) - totalExpenses;
    // print("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx $cotisations xxxxxxxxxxxxxxxxxxxxxx $totalExpenses");

    setState(() {
      _totalContributions = cotisations;
      _totalMembers = totalMembers;
      _totalExpenses = totalExpenses;
      _totalOtherRevenus  = otherRevenus;
      _currentBalance = currentBalance;
    });
    _loadCurrencyUnit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tableau de Bord'),
        leading: Builder( // Permet d'ouvrir le Drawer depuis l'AppBar
          builder: (context) => IconButton(
            icon: Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadDashboardData, // Actualiser les données
            tooltip: 'Actualiser les données',
          ),
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            tooltip: 'Paramètres',
          ),
        ],
      ),
      drawer: Navbar(context: context, onRefreshDashboard: _loadDashboardData), // Le menu latéral
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildWelcomeCard(),
            SizedBox(height: 20),
            /* _buildSummaryCard(
              icon: Icons.group,
              title: 'Membres',
              value: _totalMembers.toString(),
              color: Colors.blue.shade700,
              backgroundColor: Colors.blue.shade100,
            ), */
            SizedBox(height: 20),
            _buildSummaryCards(),
            SizedBox(height: 20),
            Text(
              'Actions Rapides',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.blueGrey[800]),
            ),
            SizedBox(height: 10),
            _buildQuickActionsGrid(),
            SizedBox(height: 20),
            Text(
              'Aperçu Récent',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.blueGrey[800]),
            ),
            SizedBox(height: 10),
            _buildRecentActivitySection(),
          ],
        ),
      ),
      // Bouton flottant pour l'action principale, par exemple Ajouter une cotisation
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final bool? result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddContributionScreen())); // Change ici !
          if (result == true) {
            _loadDashboardData();
          }
        },
        label: const Text('Ajouter Cotisation'), // Changer le label
        icon: const Icon(Icons.group_add), // Changer l'icône
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildWelcomeCard() {
    return Card(
      color: Colors.blue.shade50, // Une couleur de fond légère pour la carte
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  // child: Icon(Icons.handshake, color: Colors.white, size: 30),
                  child: Image.asset('assets/images/logo.png'),
                ),
                SizedBox(width: 15),
                Expanded(
                  child: Text(
                    'Bonjour, Responsable Mutualité !',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey[900]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 15),
            Text(
              'Votre tableau de bord en un coup d\'œil. Gérez votre mutualité efficacement.',
              style: TextStyle(fontSize: 15, color: Colors.blueGrey[700]),
            ),
            SizedBox(height: 15),
            Text(
              'Vous êtes actuellement à ${_totalMembers.toString()} membre(s).',
              style: TextStyle(fontSize: 15, color: const Color.fromARGB(239, 228, 112, 3)),
            ),
            
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return GridView.count(
      shrinkWrap: true, // Important pour que le GridView ne prenne pas toute la hauteur disponible
      physics: NeverScrollableScrollPhysics(), // Empêche le défilement du GridView lui-même
      crossAxisCount: 2,
      crossAxisSpacing: 16.0,
      mainAxisSpacing: 16.0,
      childAspectRatio: 1.2, // Ajuste la proportion des cartes
      children: <Widget>[
        _buildSummaryCard(
          icon: Icons.attach_money,
          title: 'Cotisations',
          value: '${_totalContributions.toStringAsFixed(2)} $_currencyUnit', // Formatage monétaire
          color: Colors.green.shade700,
          backgroundColor: Colors.green.shade100,
        ),
        _buildSummaryCard(
          icon: Icons.attach_money,
          title: 'Autres Rev.',
          value: '${_totalOtherRevenus.toStringAsFixed(2)} $_currencyUnit', // Formatage monétaire
          color: Colors.green.shade700,
          backgroundColor: Colors.green.shade100,
        ),
        
        _buildSummaryCard(
          icon: Icons.money_off,
          title: 'Dépenses',
          value: '${_totalExpenses.toStringAsFixed(2)} $_currencyUnit',
          color: Colors.red.shade700,
          backgroundColor: Colors.red.shade100,
        ),
        _buildSummaryCard(
          icon: Icons.account_balance_wallet,
          title: 'Solde Actuel',
          value: '${_currentBalance.toStringAsFixed(2)} $_currencyUnit',
          color: _currentBalance >= 0 ? Colors.teal.shade700 : Colors.deepOrange.shade700,
          backgroundColor: _currentBalance >= 0 ? Colors.teal.shade100 : Colors.deepOrange.shade100,
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required Color backgroundColor,
  }) {
    return Card(
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          // SUPPRIMEZ CES DEUX LIGNES QUI CAUSENT LE PROBLEME D'OVERFLOW DANS CETTE CONTEXTE:
          // mainAxisAlignment: MainAxisAlignment.spaceBetween,
          // mainAxisSize: MainAxisSize.max,
          children: [
            Icon(icon, size: 36, color: color),
            // Ajoutez un SizedBox pour un espacement explicite si nécessaire, au lieu de spaceBetween
            SizedBox(height: 8), // Ou plus/moins selon le design souhaité

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 16, color: Colors.blueGrey[800], fontWeight: FontWeight.w600),
                ),
                Text(
                  value,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisCount: 3, // 3 colonnes pour les actions rapides
      crossAxisSpacing: 10.0,
      mainAxisSpacing: 10.0,
      children: <Widget>[
        _buildActionButton(
          icon: Icons.person_add,
          label: 'Nouveau Membre',
          onTap: () async {
            final bool? result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddMemberScreen()),
            );
            if (result == true) {
              // Optionnel: rafraîchir les données du tableau de bord si nécessaire
              _loadDashboardData();
            }
          },
        ),
        _buildActionButton(
          icon: Icons.payment,
          label: 'Ajouter Cotisation',
          onTap: () async {
            // Navigator.pop(context);
            final bool? result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddContributionScreen())); // Change ici !
            if (result == true) {
              _loadDashboardData();
            }
          },
        ),
        _buildActionButton(
          icon: Icons.money_off_csred,
          label: 'Ajouter Dépense',
          onTap: () async {
            // Navigator.pop(context);
            final bool? result = await Navigator.push(context, MaterialPageRoute(builder: (context) => AddOperationScreen(initialType: 'depense')));
            if (result == true) {
              _loadDashboardData();
            }
          },
        ),
        _buildActionButton(
          icon: Icons.attach_money_rounded,
          label: 'Ajouter Revenu',
          onTap: () async {
            // Navigator.pop(context);
            final bool? result = await Navigator.push(context, MaterialPageRoute(builder: (context) => AddOperationScreen(initialType: 'revenu')));
            if (result == true) {
              _loadDashboardData();
            }
          },
        ),
        _buildActionButton(
          icon: Icons.group,
          label: 'Liste Membres',
          onTap: () async {
            final bool? result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MembersListScreen()),
            );
            if (result == true) {
              _loadDashboardData(); // Pour mettre à jour le nombre de membres
            }
          },
        ),
        _buildActionButton(
          icon: Icons.receipt_long,
          label: 'Rapports',
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => ReportsScreen()));
          },
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell( // Permet de rendre la carte cliquable
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Theme.of(context).primaryColor),
            SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.blueGrey[800]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivitySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Activités Récentes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[800]),
            ),
            Divider(height: 20, thickness: 1),
            Container(
              height: 200, // Ajustez cette hauteur selon vos besoins
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _getRecentActivities(), // Utilisez une méthode pour récupérer toutes les activités
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Erreur : ${snapshot.error}'));
                  } else if (snapshot.data == null || snapshot.data!.isEmpty) {
                    return Center(child: Text('Aucune activité récente.'));
                  } else {
                    return ListView.builder(
                      physics: ClampingScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final activity = snapshot.data![index];
                        return _buildActivityItem(activity); // Utilisez une seule méthode pour construire chaque élément
                      },
                    );
                  }
                },
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  /* ... Naviguer vers un écran d'historique complet ... */
                },
                child: Text('Voir tout l\'historique'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    IconData icon;
    String description;
    Color color;

    if (activity.containsKey('nom')) { // C'est un membre
      icon = Icons.person_add;
      description = 'Nouveau membre enregistré : ${activity['prenom']} ${activity['nom']}';
      color = Colors.blueAccent;
    } else { // C'est une opération
      if (activity['typeOperation'] == 'revenu') {
        icon = Icons.payment;
        description = 'Revenu : ${activity['description']} (${activity['montant']} $_currencyUnit)';
        color = Colors.green;
      } else {
        icon = Icons.money_off;
        description = 'Dépense : ${activity['description']} (${activity['montant']} $_currencyUnit)';
        color = Colors.red;
      }
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.2),
        child: Icon(icon, color: color),
      ),
      title: Text(description, style: TextStyle(fontSize: 11)),
      subtitle: Text(activity['date'] ?? '', style: TextStyle(fontSize: 10)),
    );
  }

  Future<List<Map<String, dynamic>>> _getRecentActivities() async {
    final operations = await _dbHelper.getRecentOperations();
    // Si vous voulez aussi inclure les nouveaux membres, vous pouvez combiner les deux listes ici
    final members = await _dbHelper.getRecentMembers();
    return [...operations, ...members]; // Combinez les deux listes
    // return operations; // Pour l'instant, on ne montre que les opérations
  }  
}