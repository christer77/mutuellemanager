// lib/screens/member_contributions_statement_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Pour formater les dates
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/constants.dart';
import '../../config/database_helper.dart';
import '../../models/membre.dart';
import '../../models/operation.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw; // Utilisez pw pour éviter les conflits avec flutter widgets
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart'; // Pour ouvrir le fichier après l'avoir créé
import 'dart:io'; // Nécessaire pour File

class MemberContributionsStatementScreen extends StatefulWidget {
  final Membre membre;

  const MemberContributionsStatementScreen({Key? key, required this.membre}) : super(key: key);

  @override
  State<MemberContributionsStatementScreen> createState() => _MemberContributionsStatementScreenState();
}

class _MemberContributionsStatementScreenState extends State<MemberContributionsStatementScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Operation> _contributions = [];
  double _soldeReport = 0.0; // Le nouveau solde de report
  bool _isLoading = true;

  // Filtres de date
  DateTime _startDateFilter = DateTime(DateTime.now().year, 1, 1); // Début de l'année courante par défaut
  DateTime _endDateFilter = DateTime.now(); // Date du jour par défaut
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd'); // Pour les requêtes DB et l'affichage
  String _currencyUnit = 'USD'; // Valeur par défaut ou fallback

  @override
  void initState() {
    super.initState();
    _loadCurrencyUnit();
    _loadMemberContributions();
  }

  Future<void> _loadCurrencyUnit() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _currencyUnit = prefs.getString('currencyUnit') ?? 'USD';
    });
  }

  Future<void> _loadMemberContributions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.membre.id == null) {
        throw Exception('L\'ID du membre est null.');
      }

      // Appeler la nouvelle méthode qui retourne le solde de report et les opérations filtrées
      final Map<String, dynamic> data = await _dbHelper.getMemberContributionStatementWithReport(
        widget.membre.id!,
        startDate: _dateFormat.format(_startDateFilter),
        endDate: _dateFormat.format(_endDateFilter),
      );

      _soldeReport = data['soldeReport'] as double;
      _contributions = (data['operations'] as List<Map<String, dynamic>>)
          .map((map) => Operation.fromMap(map))
          .toList();
    } catch (e) {
      // print('Erreur lors du chargement du relevé de cotisations : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Méthode pour sélectionner une nouvelle plage de dates
  Future<void> _selectDateRangeFilter(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000), // Date de début la plus ancienne possible
      lastDate: DateTime(2101), // Date de fin la plus lointaine possible
      initialDateRange: DateTimeRange(start: _startDateFilter, end: _endDateFilter),
    );
    if (picked != null && (picked.start != _startDateFilter || picked.end != _endDateFilter)) {
      setState(() {
        _startDateFilter = picked.start;
        _endDateFilter = picked.end;
      });
      _loadMemberContributions(); // Recharger les données avec la nouvelle plage de dates
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calcul du solde courant après les opérations de la période
    double currentBalance = _soldeReport;
    for (var op in _contributions) {
      currentBalance += op.montant;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Relevé de ${widget.membre.prenom} ${widget.membre.nom}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectDateRangeFilter(context),
            tooltip: 'Filtrer par période',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMemberContributions,
            tooltip: 'Rafraîchir le relevé',
          ),
          IconButton(
          icon: const Icon(Icons.picture_as_pdf), // Ou Icons.share
          onPressed: _generateAndSharePdf,
          tooltip: 'Générer et partager le relevé PDF',
        ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column( // Utilisez une Column pour le solde de report et la liste
              children: [
                // --- Bloc du Solde de Report et Période ---
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Membre : ${widget.membre.prenom} ${widget.membre.nom}',
                            style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.grey[700]),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Période du relevé : ${_dateFormat.format(_startDateFilter)} au ${_dateFormat.format(_endDateFilter)}',
                            style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.grey[700]),
                          ),
                          const SizedBox(height: 10),
                          
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Solde Reporté (avant cette période) :',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${_soldeReport.toStringAsFixed(2)} $_currencyUnit',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _soldeReport >= 0 ? Colors.blue : Colors.red,
                                ),
                              ),
                            ],
                          ),
                           const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Solde Cumulé (fin de période) :',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${currentBalance.toStringAsFixed(2)} $_currencyUnit',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: currentBalance >= 0 ? Colors.green : Colors.deepOrange,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1, thickness: 1), // Séparateur
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    'Opérations de la période :',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                // --- Liste des Opérations de la Période ---
                Expanded( // Utilisez Expanded pour que le ListView prenne l'espace restant
                  child: _contributions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.money_off, size: 60, color: Colors.grey),
                              SizedBox(height: 10),
                              Text(
                                'Aucune cotisation enregistrée pour ce membre dans la période sélectionnée.',
                                style: TextStyle(fontSize: 16, color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8.0),
                          itemCount: _contributions.length,
                          itemBuilder: (context, index) {
                            final contribution = _contributions[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
                              elevation: 3,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.green.shade100,
                                  child: const Icon(Icons.check_circle_outline, color: Colors.green),
                                ),
                                title: Text(
                                  contribution.description,
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  'Date: ${contribution.date}',
                                ),
                                trailing: Text(
                                  '${contribution.montant.toStringAsFixed(2)} $_currencyUnit',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
  Future<void> _generateAndSharePdf() async {
    setState(() {
      _isLoading = true; // Afficher un indicateur de chargement pendant la génération du PDF
    });

    try {
      final pdf = pw.Document();

      // Récupérer le solde cumulé calculé
      double currentBalance = _soldeReport;
      for (var op in _contributions) {
        currentBalance += op.montant;
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Center(
                child: pw.Text(
                  'Relevé de Cotisations',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Membre : ${widget.membre.prenom} ${widget.membre.nom}',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text('Téléphone : ${widget.membre.telephone ?? 'N/A'}'),
              pw.Text('Date Adhésion : ${widget.membre.dateAdhesion}'),
              pw.SizedBox(height: 10),
              pw.Text('Période du relevé : ${_dateFormat.format(_startDateFilter)} au ${_dateFormat.format(_endDateFilter)}'),
              pw.SizedBox(height: 10),

              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Solde Reporté :', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('${_soldeReport.toStringAsFixed(2)} $_currencyUnit'),
                ],
              ),
              pw.SizedBox(height: 5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Solde Cumulé (fin de période) :', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                    '${currentBalance.toStringAsFixed(2)} $_currencyUnit',
                    style: pw.TextStyle(color: currentBalance >= 0 ? PdfColors.green : PdfColors.red),
                  ),
                ],
              ),
              pw.Divider(),
              pw.SizedBox(height: 10),

              pw.Text(
                'Détail des opérations :',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),

              if (_contributions.isEmpty)
                pw.Text('Aucune cotisation pour cette période.')
              else
                pw.Table.fromTextArray(
                  headers: ['Date', 'Description', 'Montant ($_currencyUnit)'],
                  data: _contributions.map((op) => [
                    op.date,
                    op.description,
                    op.montant.toStringAsFixed(2),
                  ]).toList(),
                  border: pw.TableBorder.all(color: PdfColors.grey),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  cellAlignment: pw.Alignment.centerLeft,
                  cellPadding: pw.EdgeInsets.all(5),
                ),
              pw.SizedBox(height: 20),
              pw.Align(
                alignment: pw.Alignment.bottomRight,
                child: pw.Text('Généré le ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())} Par l\'application $appName'),
              ),
              
            ];
          },
        ),
      );

      // Enregistrer le PDF
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/releve_${widget.membre.nom}_${widget.membre.prenom}_${_dateFormat.format(_startDateFilter)}-${_dateFormat.format(_endDateFilter)}-${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
      final file = File(path);
      await file.writeAsBytes(await pdf.save());

      // Ouvrir le PDF
      await OpenFilex.open(path);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Relevé PDF généré et ouvert !')),
      );

    } catch (e) {
      print('Erreur lors de la génération ou de l\'ouverture du PDF : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec de la génération du PDF: ${e.toString()}', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}