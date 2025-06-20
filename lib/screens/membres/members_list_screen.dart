// lib/screens/members_list_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../config/database_helper.dart';
import '../../models/membre.dart';
import 'add_member_screen.dart';


class MembersListScreen extends StatefulWidget {
  const MembersListScreen({Key? key}) : super(key: key);

  @override
  _MembersListScreenState createState() => _MembersListScreenState();
}

class _MembersListScreenState extends State<MembersListScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Membre> _members = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() {
      _isLoading = true;
    });

    final List<Map<String, dynamic>> memberMaps = await _dbHelper.getAllMembres();
    setState(() {
      _members = memberMaps.map((map) => Membre.fromMap(map)).toList();
      _isLoading = false;
    });
  }

  Future<void> _deleteMember(int id) async {
    // Demander confirmation avant de supprimer
    final bool? confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: const Text('Êtes-vous sûr de vouloir supprimer ce membre ? Cette action est irréversible localement.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      final int rowsAffected = await _dbHelper.deleteMembre(id);
      if (rowsAffected > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Membre supprimé localement !')),
        );
        _loadMembers(); // Recharger la liste
        // Marquez pour synchronisation de suppression si vous avez un mécanisme pour cela
        // (ex: une table des "opérations en attente de synchro")
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: Le membre n\'a pas pu être supprimé.')),
        );
      }
    }
  }

  Future<void> _syncMembersToServer() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Synchronisation des membres en cours...')),
    );

    final List<Map<String, dynamic>> unsyncedMembers = await _dbHelper.getUnsyncedMembres();

    if (unsyncedMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Aucun nouveau membre ou modification à synchroniser.')),
      );
      return;
    }

    for (var memberMap in unsyncedMembers) {
      final int localId = memberMap['id'] as int;
      // Supprime l'ID local car le serveur générera le sien
      final Map<String, dynamic> dataToSend = Map.from(memberMap)..remove('id');
      dataToSend.remove('synchronized'); // Ne pas envoyer le statut de synchronisation

      // Déterminer si c'est une création ou une mise à jour sur le serveur
      // Ceci est un exemple simple. Dans une vraie app, vous auriez un champ 'server_id'
      // ou un champ 'status' pour les créations/mises à jour/suppressions.
      // Pour l'instant, on considère que tout non-synchronisé est une création.
      // Une solution robuste impliquerait de stocker un flag 'is_new' ou 'is_updated'
      // et d'avoir un endpoint pour 'PUT /api/members/{id}' et 'POST /api/members'.

      try {
        final response = await http.post(
          Uri.parse('VOTRE_URL_LARAVEL/api/membres'), // Remplacez par votre endpoint Laravel
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: jsonEncode(dataToSend),
        );

        if (response.statusCode == 201 || response.statusCode == 200) {
          // Si succès, mettre à jour le statut de synchronisation en local
          await _dbHelper.updateMembreSynchronizedStatus(localId, 1);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Membre synchronisé avec succès !')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Échec synchro membre ID $localId: ${response.body}')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur réseau synchro membre ID $localId: $e')),
        );
      }
    }
    _loadMembers(); // Recharger la liste pour refléter les statuts de synchronisation
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Liste des Membres'),
        actions: [
          IconButton(
            icon: Icon(Icons.sync),
            onPressed: _syncMembersToServer,
            tooltip: 'Synchroniser avec le serveur',
          ),
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () async {
              // Naviguer vers l'écran d'ajout de membre
              final bool? result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddMemberScreen()),
              );
              if (result == true) {
                _loadMembers(); // Recharger la liste si un membre a été ajouté/modifié
              }
            },
            tooltip: 'Ajouter un nouveau membre',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _members.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_off, size: 80, color: Colors.blueGrey[300]),
                      SizedBox(height: 20),
                      const Text(
                        'Aucun membre enregistré pour l\'instant.',
                        style: TextStyle(fontSize: 18, color: Colors.blueGrey),
                      ),
                      SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final bool? result = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AddMemberScreen()),
                          );
                          if (result == true) {
                            _loadMembers();
                          }
                        },
                        icon: Icon(Icons.person_add),
                        label: Text('Ajouter le premier membre'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _members.length,
                  itemBuilder: (context, index) {
                    final membre = _members[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: membre.synchronized == 1 ? Colors.green[100] : Colors.orange[100],
                          child: Icon(
                            membre.synchronized == 1 ? Icons.check_circle_outline : Icons.sync_problem,
                            color: membre.synchronized == 1 ? Colors.green : Colors.orange,
                          ),
                        ),
                        title: Text(
                          '${membre.nom} ${membre.postNom} ${membre.prenom}',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (membre.numeroAffiliation != null && membre.numeroAffiliation!.isNotEmpty)
                              Text('Affil.: ${membre.numeroAffiliation}'),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.blue),
                              onPressed: () async {
                                final bool? result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AddMemberScreen(memberToEdit: membre),
                                  ),
                                );
                                if (result == true) {
                                  _loadMembers();
                                }
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteMember(membre.id!),
                            ),
                          ],
                        ),
                        onTap: () {
                          // Optionnel: Afficher les détails complets du membre
                          _showMemberDetails(membre);
                        },
                      ),
                    );
                  },
                ),
    );
  }

  void _showMemberDetails(Membre membre) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('${membre.nom} ${membre.postNom} ${membre.prenom}'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Numéro d\'affiliation: ${membre.numeroAffiliation ?? 'N/A'}'),
                Text('Téléphone: ${membre.telephone ?? 'N/A'}'),
                Text('Adresse: ${membre.adresse ?? 'N/A'}'),
                Text('Profession: ${membre.profession ?? 'N/A'}'),
                Text('Activité actuelle: ${membre.activiteActuelle ?? 'N/A'}'),
                Text('Synchronisé: ${membre.synchronized == 1 ? 'Oui' : 'Non'}'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Fermer'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}