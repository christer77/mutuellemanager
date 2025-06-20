// lib/screens/add_member_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart'; // Pour générer un UUID
import 'package:permission_handler/permission_handler.dart'; // Pour les permissions
import 'package:flutter/services.dart';

import '../../config/database_helper.dart';
import '../../models/membre.dart'; // Pour les plateformes

class AddMemberScreen extends StatefulWidget {
  final Membre? memberToEdit; // Optionnel, pour la modification d'un membre

  const AddMemberScreen({Key? key, this.memberToEdit}) : super(key: key);

  @override
  _AddMemberScreenState createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<AddMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dbHelper = DatabaseHelper();
  final _uuid = Uuid();

  late TextEditingController _numeroAffiliationController;
  late TextEditingController _nomController;
  late TextEditingController _postNomController;
  late TextEditingController _prenomController;
  late TextEditingController _telephoneController;
  late TextEditingController _adresseController;
  late TextEditingController _professionController;
  late TextEditingController _activiteActuelleController;
  late TextEditingController _dateAdhesionController ;
  DateTime? _selectedAdhesionDate;

  bool _isGeneratingAffiliation = true; // Par défaut, générer l'affiliation

  @override
  void initState() {
    super.initState();
    _numeroAffiliationController = TextEditingController();
    _nomController = TextEditingController();
    _postNomController = TextEditingController();
    _prenomController = TextEditingController();
    _telephoneController = TextEditingController();
    _adresseController = TextEditingController();
    _professionController = TextEditingController();
    _activiteActuelleController = TextEditingController();
    _dateAdhesionController = TextEditingController();
    _selectedAdhesionDate = DateTime.now(); // Date par défaut
    _dateAdhesionController.text = DateFormat('yyyy-MM-dd').format(_selectedAdhesionDate!);

    if (widget.memberToEdit != null) {
      // Si c'est une modification, pré-remplir les champs
      _numeroAffiliationController.text = widget.memberToEdit!.numeroAffiliation ?? '';
      _nomController.text = widget.memberToEdit!.nom;
      _postNomController.text = widget.memberToEdit!.postNom;
      _prenomController.text = widget.memberToEdit!.prenom;
      _telephoneController.text = widget.memberToEdit!.telephone ?? '';
      _adresseController.text = widget.memberToEdit!.adresse ?? '';
      _professionController.text = widget.memberToEdit!.profession ?? '';
      _activiteActuelleController.text = widget.memberToEdit!.activiteActuelle ?? '';
      _isGeneratingAffiliation = widget.memberToEdit!.numeroAffiliation != null && widget.memberToEdit!.numeroAffiliation!.startsWith('MUT-'); // Exemple de détection
    } else {
      // Pour une nouvelle création, générer l'affiliation par défaut
      _generateAffiliationNumber();
    }
  }

  @override
  void dispose() {
    _numeroAffiliationController.dispose();
    _nomController.dispose();
    _postNomController.dispose();
    _prenomController.dispose();
    _telephoneController.dispose();
    _adresseController.dispose();
    _professionController.dispose();
    _activiteActuelleController.dispose();
    super.dispose();
  }

  Future<void> _selectAdhesionDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedAdhesionDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedAdhesionDate) {
      setState(() {
        _selectedAdhesionDate = picked;
        _dateAdhesionController.text = DateFormat('yyyy-MM-dd').format(_selectedAdhesionDate!);
      });
    }
  }

  void _generateAffiliationNumber() {
    if (_isGeneratingAffiliation) {
      _numeroAffiliationController.text = 'MUT-${_uuid.v4().substring(0, 8).toUpperCase()}'; // Ex: MUT-A1B2C3D4
    } else {
      _numeroAffiliationController.clear();
    }
  }

  Future<void> requestContactsPermission() async {
    final status = await Permission.contacts.status;
    if (status.isGranted) {
      _pickContact();
    } else {
      final result = await Permission.contacts.request();
      if (result.isGranted) {
        _pickContact();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Permission requise pour accéder aux contacts')),
        );
      }
    }
  }
 Future<void> _pickContact() async {
    
    // if (await FlutterContacts.requestPermission()) {
      try {
        // 2. Ouvrir le sélecteur de contacts
        // Ici, nous voulons un contact complet, y compris les adresses et téléphones
        final Contact? contact = await FlutterContacts.openExternalPick(); // Ouvre le sélecteur natif
        // Vous pouvez aussi utiliser FlutterContacts.getContacts() si vous voulez afficher votre propre liste
        // et filtrer les contacts. openExternalPick() est plus simple pour l'import.

        if (contact != null) {
          setState(() {
            // Remplir les champs du formulaire avec les données du contact
            _nomController.text = contact.name.first ?? ''; // Nom de famille
            _postNomController.text = contact.name.last ?? ''; // Post-Nom (middle name)
            _prenomController.text = contact.name.middle ?? ''; // Prénom
            

            // Récupérer le premier numéro de téléphone (s'il existe)
            if (contact.phones.isNotEmpty) {
              _telephoneController.text = contact.phones.first.number ?? '';
            } else {
              _telephoneController.text = '';
            }

            // Récupérer la première adresse postale (s'il existe)
            if (contact.addresses.isNotEmpty) {
              final address = contact.addresses.first;
              _adresseController.text = [
                address.street,
                address.city,
                address.address,
                address.country,
              ].where((element) => element != null && element.isNotEmpty).join(', ');
            } else {
              _adresseController.text = '';
            }
            // Profession et Activité actuelle ne sont pas directement dans les contacts
            // Laissez-les vides ou gérez-les manuellement.
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Contact importé avec succès !')),
          );
          // print('Contact importé: ${contact.displayName}'); // Pour le débogage
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Aucun contact selectionné')),
          );
        }
      } on PlatformException catch (e) {
        // Gérer les erreurs spécifiques à la plateforme
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'importation du contact : ${e.message}')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Une erreur inattendue est survenue lors de l\'importation du contact.')),
        );
      }
    // } else {
    //   // print('Permission contacts refusée ou refusée en permanence.');
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(
    //       content: Text('Permission de contacts refusée. Veuillez l\'activer dans les paramètres pour importer des contacts.'),
    //       action: SnackBarAction(label: 'Ouvrir Paramètres', onPressed: openAppSettings),
    //     ),
    //   );
    // }
  }

  Future<void> _saveMember() async {
    if (_formKey.currentState!.validate()) {
      final membre = Membre(
        id: widget.memberToEdit?.id, // Pour la mise à jour
        numeroAffiliation: _numeroAffiliationController.text.isEmpty ? null : _numeroAffiliationController.text,
        nom: _nomController.text,
        postNom: _postNomController.text,
        prenom: _prenomController.text,
        telephone: _telephoneController.text.isEmpty ? null : _telephoneController.text,
        adresse: _adresseController.text.isEmpty ? null : _adresseController.text,
        dateAdhesion: _dateAdhesionController.text,
        statut: 'Actif',
        profession: _professionController.text.isEmpty ? null : _professionController.text,
        activiteActuelle: _activiteActuelleController.text.isEmpty ? null : _activiteActuelleController.text,
        synchronized: 0, // Nouveau membre ou membre modifié, doit être synchronisé
      );

      try {
        if (widget.memberToEdit == null) {
          // Création
          final insertedId = await _dbHelper.insertMembre(membre.toMap());
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Membre ajouté localement (ID: $insertedId)!')),
          );
        } else {
          // Modification
          final updatedRows = await _dbHelper.updateMembre(membre.toMap());
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Membre mis à jour localement ($updatedRows rangée(s))!')),
          );
        }

        // Tenter la synchronisation après l'enregistrement local (à implémenter)
        // _syncMembersToServer();

        Navigator.pop(context, true); // Retourne au tableau de bord ou à la liste des membres
      } catch (e) {
        String errorMessage = 'Erreur lors de l\'enregistrement local du membre : $e';
        if (e.toString().contains('UNIQUE constraint failed')) {
          errorMessage = 'Erreur : Le numéro d\'affiliation existe déjà. Veuillez en utiliser un autre.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage, style: TextStyle(color: Colors.white)), backgroundColor: Colors.red,),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.memberToEdit == null ? 'Ajouter un Membre' : 'Modifier Membre'),
        actions: [
          IconButton(
            icon: Icon(Icons.contacts),
            onPressed: requestContactsPermission,
            tooltip: 'Importer depuis les contacts',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Option de génération automatique du numéro d'affiliation
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _numeroAffiliationController,
                      decoration: InputDecoration(
                        labelText: 'Numéro d\'affiliation',
                        prefixIcon: Icon(Icons.badge),
                      ),
                      enabled: !_isGeneratingAffiliation, // Désactivé si auto-génération
                      validator: (value) {
                        if (!_isGeneratingAffiliation && (value == null || value.isEmpty)) {
                          return 'Veuillez entrer un numéro d\'affiliation.';
                        }
                        return null;
                      },
                    ),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () {
                      // print("xxxxxxxxxxxxxxxxxxxx");
                      setState(() {
                        _isGeneratingAffiliation = !_isGeneratingAffiliation;
                        _generateAffiliationNumber();
                      });
                    },
                    icon: Icon(_isGeneratingAffiliation ? Icons.edit : Icons.auto_awesome),
                    label: Text(_isGeneratingAffiliation ? 'Saisir Manuellement' : 'Générer Auto'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                      textStyle: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 15),
              _buildTextFormField(
                controller: _nomController,
                labelText: 'Nom',
                icon: Icons.person,
                validator: (value) => value == null || value.isEmpty ? 'Le nom est requis.' : null,
              ),
              SizedBox(height: 15),
              _buildTextFormField(
                controller: _postNomController,
                labelText: 'Post-Nom',
                icon: Icons.person_outline,
                validator: (value) => value == null || value.isEmpty ? 'Le post-nom est requis.' : null,
              ),
              SizedBox(height: 15),
              _buildTextFormField(
                controller: _prenomController,
                labelText: 'Prénom',
                icon: Icons.person_outline,
                // validator: (value) => value == null || value.isEmpty ? 'Le prénom est requis.' : null,
              ),
              SizedBox(height: 15),
              _buildTextFormField(
                controller: _telephoneController,
                labelText: 'Téléphone',
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 15),
              _buildTextFormField(
                controller: _adresseController,
                labelText: 'Adresse',
                icon: Icons.location_on,
              ),
              SizedBox(height: 15),
              _buildTextFormField(
                controller: _professionController,
                labelText: 'Profession',
                icon: Icons.work,
              ),
              SizedBox(height: 15),
              _buildTextFormField(
                controller: _activiteActuelleController,
                labelText: 'Activité Actuelle',
                icon: Icons.local_activity,
              ),
              
              SizedBox(height: 15),
              TextFormField(
                controller: _dateAdhesionController,
                decoration: InputDecoration(
                  labelText: 'Date d\'Adhésion',
                  prefixIcon: Icon(Icons.calendar_today),
                  // border: OutlineInputBorder(),
                ),
                readOnly: true,
                onTap: () => _selectAdhesionDate(context),
                validator: (value) => value == null || value.isEmpty ? 'La date d\'adhésion est requise.' : null,
              ),
              SizedBox(height: 30),
              
              ElevatedButton.icon(
                onPressed: _saveMember,
                icon: Icon(Icons.save),
                label: Text(widget.memberToEdit == null ? 'Enregistrer Membre' : 'Mettre à Jour Membre'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size.fromHeight(50), // Bouton pleine largeur
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(icon, color: Theme.of(context).primaryColor),
      ),
      validator: validator,
    );
  }
}