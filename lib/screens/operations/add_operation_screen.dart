// lib/screens/add_operation_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/database_helper.dart';
import '../../models/operation.dart';

class AddOperationScreen extends StatefulWidget {
  final Operation? operationToEdit;
  final String initialType; // 'revenu' ou 'depense'

  const AddOperationScreen({
    Key? key,
    this.operationToEdit,
    this.initialType = 'depense', // Valeur par défaut
  }) : super(key: key);

  @override
  _AddOperationScreenState createState() => _AddOperationScreenState();
}

class _AddOperationScreenState extends State<AddOperationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dbHelper = DatabaseHelper();

  late TextEditingController _descriptionController;
  late TextEditingController _montantController;
  late TextEditingController _dateController;
  late TextEditingController _categorieController; // Pour dépenses
  late TextEditingController _sourceController;    // Pour revenus
  late TextEditingController _payeeParController;  // Pour dépenses
  late TextEditingController _recuParController;   // Pour revenus

  DateTime? _selectedDate;
  late String _currentType;
  String _currencyUnit = 'USD'; // Valeur par défaut ou fallback

  @override
  void initState() {
    super.initState();
    _loadCurrencyUnit();
    _descriptionController = TextEditingController();
    _montantController = TextEditingController();
    _dateController = TextEditingController();
    _categorieController = TextEditingController();
    _sourceController = TextEditingController();
    _payeeParController = TextEditingController();
    _recuParController = TextEditingController();

    if (widget.operationToEdit != null) {
      _currentType = widget.operationToEdit!.typeOperation;
      _descriptionController.text = widget.operationToEdit!.description;
      _montantController.text = widget.operationToEdit!.montant.toString();
      _dateController.text = widget.operationToEdit!.date;
      _selectedDate = DateTime.parse(widget.operationToEdit!.date);
      if (_currentType == 'depense') {
        _categorieController.text = widget.operationToEdit!.categorie ?? '';
        _payeeParController.text = widget.operationToEdit!.payeePar ?? '';
      } else { // 'revenu'
        _sourceController.text = widget.operationToEdit!.source ?? '';
        _recuParController.text = widget.operationToEdit!.recuPar ?? '';
      }
    } else {
      _currentType = widget.initialType;
      _selectedDate = DateTime.now();
      _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate!);
    }
  }

  Future<void> _loadCurrencyUnit() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _currencyUnit = prefs.getString('currencyUnit') ?? 'USD';
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _montantController.dispose();
    _dateController.dispose();
    _categorieController.dispose();
    _sourceController.dispose();
    _payeeParController.dispose();
    _recuParController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      });
    }
  }

  Future<void> _saveOperation() async {
    if (_formKey.currentState!.validate()) {
      final operation = Operation(
        id: widget.operationToEdit?.id,
        description: _descriptionController.text,
        montant: double.parse(_montantController.text),
        date: _dateController.text,
        typeOperation: _currentType,
        categorie: _currentType == 'depense' && _categorieController.text.isNotEmpty ? _categorieController.text : null,
        source: _currentType == 'revenu' && _sourceController.text.isNotEmpty ? _sourceController.text : null,
        payeePar: _currentType == 'depense' && _payeeParController.text.isNotEmpty ? _payeeParController.text : null,
        recuPar: _currentType == 'revenu' && _recuParController.text.isNotEmpty ? _recuParController.text : null,
        synchronized: 0,
      );

      try {
        if (widget.operationToEdit == null) {
          final insertedId = await _dbHelper.insertOperation(operation.toMap());
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${_currentType == 'depense' ? 'Dépense' : 'Revenu'} ajouté localement (ID: $insertedId)!')),
          );
        } else {
          final updatedRows = await _dbHelper.updateOperation(operation.toMap());
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${_currentType == 'depense' ? 'Dépense' : 'Revenu'} mis à jour localement ($updatedRows rangée(s))!')),
          );
        }
        Navigator.pop(context, true);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'enregistrement : $e', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red,),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.operationToEdit == null
            ? (_currentType == 'depense' ? 'Ajouter une Dépense' : 'Ajouter un Revenu')
            : 'Modifier ${_currentType == 'depense' ? 'une Dépense' : 'un Revenu'}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Sélecteur de type d'opération (si ce n'est pas une modification)
              if (widget.operationToEdit == null) ...[
                Text('Type d\'opération :', style: TextStyle(fontSize: 16)),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Dépense'),
                        value: 'depense',
                        groupValue: _currentType,
                        onChanged: (String? value) {
                          setState(() {
                            _currentType = value!;
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Revenu'),
                        value: 'revenu',
                        groupValue: _currentType,
                        onChanged: (String? value) {
                          setState(() {
                            _currentType = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 15),
              ],
              _buildTextFormField(
                controller: _descriptionController,
                labelText: 'Description de l\'opération',
                icon: Icons.description,
                validator: (value) => value == null || value.isEmpty ? 'La description est requise.' : null,
              ),
              SizedBox(height: 15),
              _buildTextFormField(
                controller: _montantController,
                labelText: 'Montant ($_currencyUnit)',
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
              SizedBox(height: 15),
              TextFormField(
                controller: _dateController,
                decoration: InputDecoration(
                  labelText: 'Date de l\'opération',
                  prefixIcon: Icon(Icons.calendar_today, color: Theme.of(context).primaryColor),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.calendar_month),
                    onPressed: () => _selectDate(context),
                  ),
                ),
                readOnly: true,
                onTap: () => _selectDate(context),
                validator: (value) => value == null || value.isEmpty ? 'La date est requise.' : null,
              ),
              SizedBox(height: 15),
              if (_currentType == 'depense') ...[
                _buildTextFormField(
                  controller: _categorieController,
                  labelText: 'Catégorie de dépense (ex: Loyer, Fournitures)',
                  icon: Icons.category,
                ),
                SizedBox(height: 15),
                _buildTextFormField(
                  controller: _payeeParController,
                  labelText: 'Payée par',
                  icon: Icons.person,
                ),
              ] else if (_currentType == 'revenu') ...[
                _buildTextFormField(
                  controller: _sourceController,
                  labelText: 'Source du revenu (ex: Dons, Cotisations)',
                  icon: Icons.account_balance,
                ),
                SizedBox(height: 15),
                _buildTextFormField(
                  controller: _recuParController,
                  labelText: 'Reçu par',
                  icon: Icons.person_outline,
                ),
              ],
              SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _saveOperation,
                icon: Icon(Icons.save),
                label: Text(widget.operationToEdit == null ? 'Enregistrer Opération' : 'Mettre à Jour Opération'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size.fromHeight(50),
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