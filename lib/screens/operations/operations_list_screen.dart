import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/constants.dart';
import '../../config/database_helper.dart';
import '../../models/operation.dart';
import 'add_operation_screen.dart';

// PDF generation imports
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw; // Use pw to avoid conflicts with Flutter widgets
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io'; // Needed for File class

class OperationsListScreen extends StatefulWidget {
  const OperationsListScreen({Key? key, required this.typeOperation}) : super(key: key);
  final String typeOperation; // Changed to final as it's passed in constructor

  @override
  State<OperationsListScreen> createState() => _OperationsListScreenState();
}

class _OperationsListScreenState extends State<OperationsListScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Operation> _operations = [];
  bool _isLoading = true;

  // --- Variables d'état pour les filtres ---
  String? _selectedType; // 'revenu', 'depense', ou null
  String? _selectedSource; // Ex: 'Cotisation Membre', 'Don', ou null
  DateTime? _startDateFilter;
  DateTime? _endDateFilter;

  List<String> _availableSources = []; // Liste des sources disponibles pour le filtre

  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  // --- Nouvelles variables pour les totaux affichés dans le Card ---
  double _totalAmountForPeriod = 0.0;
  String _totalDescription = ''; // Will change based on type of operations shown
  String _currencyUnit = 'USD'; // Valeur par défaut ou fallback

  @override
  void initState() {
    super.initState();
    _loadCurrencyUnit();
    if (widget.typeOperation.isNotEmpty) {
      _selectedType = widget.typeOperation;
    }
    // Set default date filter to current year for initial load
    _startDateFilter ??= DateTime(DateTime.now().year, 1, 1);
    _endDateFilter ??= DateTime.now();
    _loadFiltersAndOperations();
  }

  Future<void> _loadCurrencyUnit() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _currencyUnit = prefs.getString('currencyUnit') ?? 'USD';
    });
  }

  Future<void> _loadFiltersAndOperations() async {
    setState(() {
      _isLoading = true;
      _totalAmountForPeriod = 0.0; // Reset total
    });
    try {
      // Charger les sources disponibles avant de charger les opérations
      _availableSources = await _dbHelper.getAllOperationSources();
      _availableSources.sort(); // Tri alphabétique des sources

      final List<Map<String, dynamic>> operationMaps = await _dbHelper.getFilteredOperations(
        typeOperation: _selectedType,
        source: _selectedSource,
        startDate: _startDateFilter != null ? _dateFormat.format(_startDateFilter!) : null,
        endDate: _endDateFilter != null ? _dateFormat.format(_endDateFilter!) : null,
      );
      _operations = operationMaps.map((map) => Operation.fromMap(map)).toList();

      // Calculate total amount for the displayed operations
      for (var op in _operations) {
        _totalAmountForPeriod += op.montant;
      }

      // Set total description based on selected type
      if (_selectedType == 'revenu') {
        _totalDescription = 'Total des Revenus';
      } else if (_selectedType == 'depense') {
        _totalDescription = 'Total des Dépenses';
      } else {
        _totalDescription = 'Total Général';
        // If showing both, calculate net balance for "Total Général"
        // This requires fetching total revenues and expenses separately for the period
        final totalRevenus = await _dbHelper.getTotalRevenusByPeriod(
          _startDateFilter != null ? _dateFormat.format(_startDateFilter!) : null,
          _endDateFilter != null ? _dateFormat.format(_endDateFilter!) : null,
        );
        final totalDepenses = await _dbHelper.getTotalDepensesByPeriod(
          _startDateFilter != null ? _dateFormat.format(_startDateFilter!) : null,
          _endDateFilter != null ? _dateFormat.format(_endDateFilter!) : null,
        );
        _totalAmountForPeriod = totalRevenus - totalDepenses;
      }

    } catch (e) {
      // print('Erreur lors du chargement des opérations ou des filtres : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteOperation(int id) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: const Text('Êtes-vous sûr de vouloir supprimer cette opération ?'),
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
      final int rowsAffected = await _dbHelper.deleteOperation(id);
      if (rowsAffected > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opération supprimée avec succès !')),
        );
        _loadFiltersAndOperations();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur: L\'opération n\'a pas pu être supprimée.')),
        );
      }
    }
  }

  // --- Méthodes de sélection de filtre ---
  void _selectTypeFilter(String? type) {
    setState(() {
      _selectedType = type;
      // If type is explicitly set, the widget's initial typeOperation should override
      // this could be problematic if you want to clear type filter.
      // Re-evaluate if widget.typeOperation should always force the type or just be an initial value.
      // For now, allow filter to change it.
    });
    _loadFiltersAndOperations();
  }

  void _selectSourceFilter(String? source) {
    setState(() {
      _selectedSource = source;
    });
    _loadFiltersAndOperations();
  }

  Future<void> _selectDateRangeFilter(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      initialDateRange: (_startDateFilter != null && _endDateFilter != null)
          ? DateTimeRange(start: _startDateFilter!, end: _endDateFilter!)
          : DateTimeRange(start: _startDateFilter ?? DateTime(2000), end: _endDateFilter ?? DateTime(2101)), // Fallback
    );
    if (picked != null) {
      setState(() {
        _startDateFilter = picked.start;
        _endDateFilter = picked.end;
      });
      _loadFiltersAndOperations();
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedType = null; // Clear the type filter
      _selectedSource = null;
      _startDateFilter = DateTime(DateTime.now().year, 1, 1); // Reset to current year
      _endDateFilter = DateTime.now(); // Reset to current date
    });
    _loadFiltersAndOperations();
  }

  void _showOperationDetails(Operation operation) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final isExpense = operation.typeOperation == 'depense';
        return AlertDialog(
          title: Text('${isExpense ? 'Dépense' : 'Revenu'}: ${operation.description}'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Montant: ${NumberFormat.currency(locale: 'fr_CD', symbol: '$_currencyUnit').format(operation.montant)}'),
                Text('Date: ${operation.date}'),
                if (isExpense) ...[
                  Text('Catégorie: ${operation.categorie ?? 'N/A'}'),
                  Text('Payée par: ${operation.payeePar ?? 'N/A'}'),
                ] else ...[
                  Text('Source: ${operation.source ?? 'N/A'}'),
                  Text('Reçu par: ${operation.recuPar ?? 'N/A'}'),
                ],
                Text('Synchronisé: ${operation.synchronized == 1 ? 'Oui' : 'Non'}'),
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      IconButton(
                        iconSize: 24,
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () async {
                          Navigator.of(context).pop(); // Close details dialog
                          final bool? result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddOperationScreen(operationToEdit: operation),
                            ),
                          );
                          if (result == true) {
                            _loadFiltersAndOperations();
                          }
                        },
                      ),
                      IconButton(
                        iconSize: 24,
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          Navigator.of(context).pop(); // Close details dialog
                          _deleteOperation(operation.id!);
                        },
                      ),
                    ],
                  ),
                )
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

  // --- PDF Generation Function ---
  Future<void> _generateAndShareOperationsPdf() async {
    setState(() {
      _isLoading = true; // Show loading indicator during PDF generation
    });

    try {
      final pdf = pw.Document();

      // Calculate cumulative balance for PDF table
      double currentBalance = 0.0;
      final List<List<String>> tableData = [];
      for (var op in _operations) {
        double revenu = 0.0;
        double depense = 0.0;
        if (op.typeOperation == 'revenu') {
          revenu = op.montant;
          currentBalance += op.montant;
        } else {
          depense = op.montant;
          currentBalance -= op.montant;
        }
        tableData.add([
          op.date,
          // op.typeOperation == 'revenu' ? 'Revenu' : 'Dépense',
          op.description,
          op.typeOperation == 'revenu' ? op.source ?? 'N/A' : op.categorie ?? 'N/A',
          revenu.toStringAsFixed(2),
          depense.toStringAsFixed(2),
          currentBalance.toStringAsFixed(2), // Cumulative balance
        ]);
      }


      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Center(
                child: pw.Text(
                  'Rapport des Opérations',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Date de génération : ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}'),
              pw.Text('Période filtrée : ${_dateFormat.format(_startDateFilter!)} au ${_dateFormat.format(_endDateFilter!)}'),
              if (_selectedType != null)
                pw.Text('Type d\'opération : ${_selectedType == 'revenu' ? 'Revenu' : 'Dépense'}'),
              if (_selectedSource != null)
                pw.Text('Source : $_selectedSource'),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('$_totalDescription :', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                    '${_totalAmountForPeriod.toStringAsFixed(2)} $_currencyUnit',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: (_selectedType == 'depense') ? PdfColors.red : ((_totalDescription == 'Total Général' && _totalAmountForPeriod < 0) ? PdfColors.red : PdfColors.green),
                    ),
                  ),
                ],
              ),
              pw.Divider(),
              pw.SizedBox(height: 20),
              if (_operations.isEmpty)
                pw.Center(child: pw.Text('Aucune opération trouvée avec les filtres appliqués.'))
              else
                pw.Table.fromTextArray(
                  headers: ['Date'/* , 'Type' */, 'Description', 'Source/Catégorie', 'Montant Revenu', 'Montant Dépense', 'Balance'], // NOUVEAUX EN-TÊTES
                  data: tableData, // Utiliser les données pré-calculées
                  border: pw.TableBorder.all(color: PdfColors.grey),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  cellAlignment: pw.Alignment.centerLeft,
                  cellPadding: pw.EdgeInsets.all(5),
                  columnWidths: {
                    0: pw.FlexColumnWidth(1.3), // Date
                    // 1: pw.FlexColumnWidth(0.8), // Type
                    1: pw.FlexColumnWidth(2.3), // Description
                    2: pw.FlexColumnWidth(1.7), // Source/Category
                    3: pw.FlexColumnWidth(1.0), // Montant Revenu
                    4: pw.FlexColumnWidth(1.0), // Montant Dépense
                    5: pw.FlexColumnWidth(1.0), // Balance
                  },
                ),
              pw.Align(
                alignment: pw.Alignment.bottomRight,
                child: pw.Text('Généré par l\'application $appName'),
              ),
            ];
          },
        ),
      );

      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/operations_report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
      final file = File(path);
      await file.writeAsBytes(await pdf.save());

      await OpenFilex.open(path); // Open the PDF after saving

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rapport d\'opérations exporté en PDF et ouvert !')),
      );

    } catch (e) {
      // print('Error generating or opening PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec de la génération du PDF: ${e.toString()}', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Liste des Opérations'),
        actions: [
          // Bouton de filtre par Type (Revenu/Dépense)
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            onSelected: _selectTypeFilter,
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String?>>[
              const PopupMenuItem<String?>(
                value: null,
                child: Text('Tous les types'),
              ),
              const PopupMenuItem<String>(
                value: 'revenu',
                child: Text('Revenus'),
              ),
              const PopupMenuItem<String>(
                value: 'depense',
                child: Text('Dépenses'),
              ),
            ],
            tooltip: 'Filtrer par type',
          ),
          // Bouton de filtre par Source
          PopupMenuButton<String?>(
            icon: const Icon(Icons.category),
            onSelected: _selectSourceFilter,
            itemBuilder: (BuildContext context) {
              List<PopupMenuEntry<String?>> items = [
                const PopupMenuItem<String?>(
                  value: null,
                  child: Text('Toutes les sources'),
                ),
              ];
              items.addAll(_availableSources.map((source) =>
                  PopupMenuItem<String>(
                    value: source,
                    child: Text(source),
                  )
              ));
              return items;
            },
            tooltip: 'Filtrer par source',
          ),
          // Bouton de filtre par Date
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectDateRangeFilter(context),
            tooltip: 'Filtrer par date',
          ),
          // Bouton pour effacer tous les filtres
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearFilters,
            tooltip: 'Effacer les filtres',
          ),
          // --- Bouton pour exporter en PDF ---
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _generateAndShareOperationsPdf,
            tooltip: 'Exporter en PDF',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column( // Use Column to place the header card above the list
              children: [
                // --- HEADER CARD: PERIOD AND TOTAL AMOUNT ---
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Période : ${_dateFormat.format(_startDateFilter!)} au ${_dateFormat.format(_endDateFilter!)}',
                            style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.grey[700]),
                          ),
                          if (_selectedSource != null)
                            Text(
                              'Source filtrée : $_selectedSource',
                              style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.grey[700]),
                            ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '$_totalDescription :',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${_totalAmountForPeriod.toStringAsFixed(2)} $_currencyUnit',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: (_selectedType == 'depense')
                                      ? Colors.red
                                      : ((_totalDescription == 'Total Général' && _totalAmountForPeriod < 0) ? Colors.red : Colors.green),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // --- END HEADER CARD ---

                Expanded( // The operations list takes available space
                  child: _operations.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.not_interested, size: 60, color: Colors.grey),
                              const SizedBox(height: 10),
                              const Text(
                                'Aucune opération trouvée avec ces filtres.',
                                style: TextStyle(fontSize: 16, color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: _clearFilters,
                                child: const Text('Effacer les filtres'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8.0),
                          itemCount: _operations.length,
                          itemBuilder: (context, index) {
                            final operation = _operations[index];
                            final isExpense = operation.typeOperation == 'depense';
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
                              elevation: 3,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isExpense ? Colors.red[100] : Colors.green[100],
                                  child: Icon(
                                    isExpense ? Icons.trending_down : Icons.trending_up,
                                    color: isExpense ? Colors.red : Colors.green,
                                  ),
                                ),
                                title: Text(
                                  operation.description,
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isExpense ? Colors.red[700] : Colors.green[700]),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${operation.typeOperation == 'revenu' ? 'Source' : 'Catégorie'} : ${operation.typeOperation == 'revenu' ? operation.source ?? 'N/A' : operation.categorie ?? 'N/A'}',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                    Text(
                                      '${operation.recuPar != null && operation.recuPar!.isNotEmpty ? 'Par: ${operation.recuPar}\n' : ''}'
                                      'Date: ${operation.date}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ],
                                ),
                                trailing: Text(
                                  '${operation.montant.toStringAsFixed(2)} $_currencyUnit',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isExpense ? Colors.red : Colors.green,
                                  ),
                                ),
                                isThreeLine: true,
                                onTap: () {
                                  _showOperationDetails(operation);
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