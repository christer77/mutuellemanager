import 'package:flutter/material.dart';

import '../config/database_helper.dart';
import '../models/membre.dart';

class MemberSelectionBottomSheet extends StatefulWidget {
  const MemberSelectionBottomSheet({Key? key}) : super(key: key);

  @override
  _MemberSelectionBottomSheetState createState() => _MemberSelectionBottomSheetState();
}

class _MemberSelectionBottomSheetState extends State<MemberSelectionBottomSheet> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Membre> _members = [];
  bool _isLoading = true; // Pour gérer l'état de chargement
  String _searchQuery = ''; // Pour la recherche

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final membersData = await _dbHelper.getAllMembres();
      setState(() {
        _members = membersData.map((map) => Membre.fromMap(map)).toList();
        _isLoading = false;
      });
    } catch (e) {
      // print('Erreur lors du chargement des membres: $e'); // Pour le débogage
      setState(() {
        _isLoading = false;
      });
      // Optionnel: Afficher un message d'erreur à l'utilisateur
    }
  }

  List<Membre> get _filteredMembers {
    if (_searchQuery.isEmpty) {
      return _members;
    }
    return _members.where((member) {
      final fullName = '${member.prenom ?? ''} ${member.nom ?? ''}'.toLowerCase();
      return fullName.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8, // 80% de la hauteur de l'écran
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Text(
            'Sélectionner un Membre',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(
              labelText: 'Rechercher un membre',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 16),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredMembers.isEmpty
                  ? const Center(
                      child: Text('Aucun membre trouvé.', style: TextStyle(fontSize: 16)),
                    )
                  : Expanded(
                      child: ListView.builder(
                        itemCount: _filteredMembers.length,
                        itemBuilder: (context, index) {
                          final membre = _filteredMembers[index];
                          // *** C'est ici que la correction est la plus probable ***
                          // Assurez-vous que les chaînes 'prenom' et 'nom' ne sont pas nulles ou vides
                          // avant d'essayer d'accéder à leur premier caractère.
                          final String displayInitial = (membre.prenom?.isNotEmpty == true ? membre.prenom![0] : '') +
                                                        (membre.nom?.isNotEmpty == true ? membre.nom![0] : '');
                          // Vous pouvez aussi utiliser une approche plus simple si vous affichez juste le nom complet
                          final String displayName = '${membre.prenom ?? ''} ${membre.nom ?? ''}'.trim();

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8.0),
                            elevation: 2,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                                // Utilisez l'initiale ou un fallback si les noms sont vides
                                child: Text(
                                  displayInitial.isEmpty ? '?' : displayInitial.toUpperCase(),
                                  style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(displayName.isEmpty ? 'Membre inconnu' : displayName),
                              subtitle: Text('Téléphone: ${membre.telephone ?? 'N/A'}'),
                              onTap: () {
                                Navigator.pop(context, membre);
                              },
                            ),
                          );
                        },
                      ),
                    ),
        ],
      ),
    );
  }
}