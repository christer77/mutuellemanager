import 'package:flutter/material.dart';
import 'package:mutuellemanager/widget/navbar.dart';

import 'screens/membres/add_member_screen.dart';
import 'screens/membres/members_list_screen.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Ces valeurs seraient dynamiques et proviendraient de votre base de données locale/synchronisée
  int _totalMembers = 125;
  double _totalContributions = 542000.00;
  double _totalExpenses = 125000.00;
  double _currentBalance = 417000.00; // Contributions - Expenses

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    // Ici, vous feriez appel à votre DatabaseHelper pour récupérer les données agrégées
    // Par exemple:
    // final members = await DatabaseHelper().getAllMembers();
    // setState(() {
    //   _totalMembers = members.length;
    //   _totalContributions = await DatabaseHelper().getTotalContributions();
    //   _totalExpenses = await DatabaseHelper().getTotalExpenses();
    //   _currentBalance = _totalContributions - _totalExpenses;
    // });
    // Pour l'instant, on utilise des valeurs statiques pour l'interface
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
              // Navigator.push(context, MaterialPageRoute(builder: (context) => SettingsScreen()));
            },
            tooltip: 'Paramètres',
          ),
        ],
      ),
      drawer: Navbar(context: context), // Le menu latéral
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildWelcomeCard(),
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
        onPressed: () {
          // Navigator.push(context, MaterialPageRoute(builder: (context) => AddContributionScreen()));
        },
        label: Text('Ajouter Cotisation'),
        icon: Icon(Icons.add_card),
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
                  child: Icon(Icons.handshake, color: Colors.white, size: 30),
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
          icon: Icons.group,
          title: 'Membres',
          value: _totalMembers.toString(),
          color: Colors.blue.shade700,
          backgroundColor: Colors.blue.shade100,
        ),
        _buildSummaryCard(
          icon: Icons.attach_money,
          title: 'Cotisations',
          value: '${_totalContributions.toStringAsFixed(2)} F.CFA', // Formatage monétaire
          color: Colors.green.shade700,
          backgroundColor: Colors.green.shade100,
        ),
        _buildSummaryCard(
          icon: Icons.money_off,
          title: 'Dépenses',
          value: '${_totalExpenses.toStringAsFixed(2)} F.CFA',
          color: Colors.red.shade700,
          backgroundColor: Colors.red.shade100,
        ),
        _buildSummaryCard(
          icon: Icons.account_balance_wallet,
          title: 'Solde Actuel',
          value: '${_currentBalance.toStringAsFixed(2)} F.CFA',
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
          onTap: () {
            // Navigator.push(context, MaterialPageRoute(builder: (context) => AddContributionScreen()));
          },
        ),
        _buildActionButton(
          icon: Icons.money_off_csred,
          label: 'Ajouter Dépense',
          onTap: () {
            // Navigator.push(context, MaterialPageRoute(builder: (context) => AddExpenseScreen()));
          },
        ),
        _buildActionButton(
          icon: Icons.attach_money_rounded,
          label: 'Ajouter Revenu',
          onTap: () {
            // Navigator.push(context, MaterialPageRoute(builder: (context) => AddIncomeScreen()));
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
            // Navigator.push(context, MaterialPageRoute(builder: (context) => ReportsScreen()));
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
    // Ceci serait une liste dynamique d'activités récentes (ex: dernières cotisations, dépenses)
    return Card(
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Activités Récentes',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[800]),
          ),
          Divider(height: 20, thickness: 1),
          // Si cette liste peut être très longue, utilisez Expanded avec ListView.builder
          // MAIS, si elle est dans un SingleChildScrollView parent, Expanded ne fonctionne pas ici.
          // Il faudrait alors donner une hauteur finie à cette section, ce qui est souvent fait pour les "aperçus".
          Container( // Donnez une hauteur fixe à cette section pour éviter le débordement
            height: 200, // Ajustez cette hauteur selon vos besoins
            child: ListView( // Utilisez un ListView ici si les éléments sont dynamiques et nombreux
              physics: ClampingScrollPhysics(), // Permet au ListView de défiler dans son Container
              shrinkWrap: true, // Si le ListView est dans un Column qui est lui-même dans un SingleChildScrollView
              children: [
                _buildActivityItem(
                  icon: Icons.person_add,
                  description: 'Nouveau membre enregistré : Jean Kalengayi',
                  date: '15 Juin 2025',
                  color: Colors.blueAccent,
                ),
                _buildActivityItem(
                  icon: Icons.payment,
                  description: 'Cotisation reçue de Marie Louise (50,000 F.CFA)',
                  date: '14 Juin 2025',
                  color: Colors.green,
                ),
                _buildActivityItem(
                  icon: Icons.money_off,
                  description: 'Dépense : Achat de fournitures (10,000 F.CFA)',
                  date: '14 Juin 2025',
                  color: Colors.red,
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () { /* ... */ },
              child: Text('Voir tout l\'historique'),
            ),
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required String description,
    required String date,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: TextStyle(fontSize: 15, color: Colors.blueGrey[700]),
                ),
                Text(
                  date,
                  style: TextStyle(fontSize: 13, color: Colors.blueGrey[500]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  
}