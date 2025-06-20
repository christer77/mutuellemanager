import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/database_helper.dart';
import '../../models/membre.dart';
import '../../models/operation.dart';
import '../../widget/member_selection_bottom_sheet.dart'; // Assurez-vous que ce fichier existe

class AddContributionScreen extends StatefulWidget {
  const AddContributionScreen({Key? key}) : super(key: key);

  @override
  _AddContributionScreenState createState() => _AddContributionScreenState();
}

class _AddContributionScreenState extends State<AddContributionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dbHelper = DatabaseHelper();

  // Initialisation directe des contrôleurs pour plus de clarté
  final TextEditingController _montantController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController(text: 'Cotisation mensuelle');
  final TextEditingController _memberController = TextEditingController();

  DateTime _selectedDate = DateTime.now(); // Initialisation non-nullable
  Membre? _selectedMember;
  double _totalContributions = 0.0;
  String _currencyUnit = 'USD'; // Valeur par défaut

  @override
  void initState() {
    super.initState();
    _loadCurrencyUnit();
    // La date est initialisée ici pour s'assurer que _dateController.text est défini
    _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate);
  }

  Future<void> _loadCurrencyUnit() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _currencyUnit = prefs.getString('currencyUnit') ?? 'USD';
    });
  }

  @override
  void dispose() {
    _montantController.dispose();
    _dateController.dispose();
    _descriptionController.dispose();
    _memberController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate, // Utiliser la valeur non-nullable
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate);
      });
    }
  }

  Future<void> _selectMember() async {
    final Membre? selectedMembre = await showModalBottomSheet<Membre>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return const MemberSelectionBottomSheet();
      },
    );

    if (selectedMembre != null) {
      setState(() {
        _selectedMember = selectedMembre;
        // Gérer les cas où prenom ou nom pourraient être nuls ou vides
        _memberController.text = [selectedMembre.prenom, selectedMembre.nom]
            .where((element) => element != null && element.isNotEmpty)
            .join(' ');
      });
      _loadMemberContributions();
    }
  }

  Future<void> _loadMemberContributions() async {
    if (_selectedMember?.id != null) { // Utilisation du null-safe operator
      final double total = await _dbHelper.getTotalContributionsForMember(_selectedMember!.id!);
      setState(() {
        _totalContributions = total;
      });
    } else {
      setState(() {
        _totalContributions = 0.0;
      });
    }
  }

  Future<void> _saveContribution() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedMember == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Veuillez sélectionner un membre pour la cotisation.', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final operation = Operation(
        description: _descriptionController.text.isEmpty ? 'Cotisation' : _descriptionController.text,
        montant: double.parse(_montantController.text),
        date: _dateController.text,
        typeOperation: 'revenu',
        source: 'Cotisation Membre',
        recuPar: [
          _selectedMember!.prenom,
          _selectedMember!.nom
        ].where((element) => element != null && element.isNotEmpty).join(' '),
        membreId: _selectedMember!.id,
        synchronized: 0,
      );

      try {
        final insertedId = await _dbHelper.insertOperation(operation.toMap());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cotisation enregistrée localement (ID: $insertedId)!')),
        );
        Navigator.pop(context, true);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'enregistrement de la cotisation : $e', style: TextStyle(color: Colors.white)),
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
        title: const Text('Enregistrer une Cotisation'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextFormField(
                controller: _memberController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Membre concerné',
                  hintText: 'Sélectionner un membre',
                  prefixIcon: Icon(Icons.person_outline, color: Theme.of(context).primaryColor),
                  suffixIcon: _selectedMember != null
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _selectedMember = null;
                              _memberController.clear();
                              _totalContributions = 0.0; // Réinitialiser le total des contributions
                            });
                          },
                        )
                      : const Icon(Icons.arrow_drop_down),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onTap: _selectMember,
                validator: (value) => value == null || value.isEmpty ? 'Veuillez sélectionner un membre.' : null,
              ),
              if (_selectedMember != null) // Afficher le total des contributions uniquement si un membre est sélectionné
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'Total des cotisations du membre: ${_totalContributions.toStringAsFixed(2)} $_currencyUnit',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).hintColor),
                  ),
                ),
              const SizedBox(height: 15),
              _buildTextFormField(
                controller: _montantController,
                labelText: 'Montant de la cotisation ($_currencyUnit)',
                icon: Icons.monetization_on,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Le montant est requis.';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Veuillez entrer un nombre valide.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _dateController,
                decoration: InputDecoration(
                  labelText: 'Date de la cotisation',
                  prefixIcon: Icon(Icons.calendar_today, color: Theme.of(context).primaryColor),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_month),
                    onPressed: () => _selectDate(context),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                readOnly: true,
                onTap: () => _selectDate(context),
                validator: (value) => value == null || value.isEmpty ? 'La date est requise.' : null,
              ),
              const SizedBox(height: 15),
              _buildTextFormField(
                controller: _descriptionController,
                labelText: 'Description (ex: Cotisation mensuelle de Juin)',
                icon: Icons.description,
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _saveContribution,
                icon: const Icon(Icons.save),
                label: const Text('Enregistrer Cotisation'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      validator: validator,
    );
  }
}