import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mutuellemanager/config/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/database_helper.dart';

// PDF generation imports
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw; // Use pw to avoid conflicts with Flutter widgets
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io'; // Needed for File class

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  // Variables pour les données de rapport
  double _totalRevenusPeriod = 0.0;
  double _totalDepensesPeriod = 0.0;
  List<Map<String, dynamic>> _monthlyCotisations = [];
  List<Map<String, dynamic>> _revenueDistribution = [];
  int _totalMembers = 0;
  List<Map<String, dynamic>> _membersByStatus = [];

  // Période de rapport sélectionnée
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30)); // Default: last 30 days
  DateTime _endDate = DateTime.now();

  bool _isLoading = true;
  String _currencyUnit = 'USD'; // Valeur par défaut ou fallback

  @override
  void initState() {
    super.initState();
    _loadReportData();
    _loadCurrencyUnit();
  }

  Future<void> _loadCurrencyUnit() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _currencyUnit = prefs.getString('currencyUnit') ?? 'USD';
    });
  }

  Future<void> _loadReportData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Données de flux de trésorerie par période
      _totalRevenusPeriod = await _dbHelper.getTotalRevenusByPeriod(
        _dateFormat.format(_startDate),
        _dateFormat.format(_endDate),
      );
      _totalDepensesPeriod = await _dbHelper.getTotalDepensesByPeriod(
        _dateFormat.format(_startDate),
        _dateFormat.format(_endDate),
      );

      // Données de cotisations mensuelles (pour l'année en cours)
      // Note: This report uses the current year regardless of selected period
      _monthlyCotisations = await _dbHelper.getMonthlyCotisations(DateTime.now().year);

      // Données de répartition des revenus
      _revenueDistribution = await _dbHelper.getRevenueDistributionBySource(
        _dateFormat.format(_startDate),
        _dateFormat.format(_endDate),
      );

      // Données des membres
      _totalMembers = await _dbHelper.getTotalMembersCount();
      _membersByStatus = await _dbHelper.getMembersCountByStatus();

    } catch (e) {
      // print('Erreur lors du chargement des rapports : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du chargement des rapports: ${e.toString()}', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (picked != null && (picked.start != _startDate || picked.end != _endDate)) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadReportData(); // Recharger les données avec la nouvelle période
    }
  }

  // --- NOUVELLE FONCTION POUR GÉNERER ET PARTAGER LE PDF ---
  Future<void> _generateAndShareReportPdf() async {
    setState(() {
      _isLoading = true; // Afficher un indicateur de chargement
    });

    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Center(
                child: pw.Text(
                  'Rapport Général de la Mutualité',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Date de génération : ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}'),
              pw.Text('Période du rapport : ${_dateFormat.format(_startDate)} au ${_dateFormat.format(_endDate)}'),
              pw.SizedBox(height: 20),

              // Section Flux de Trésorerie
              _buildPdfSectionTitle('Flux de Trésorerie sur la Période'),
              _buildPdfStatRow('Revenus Totaux', _totalRevenusPeriod, PdfColors.green),
              _buildPdfStatRow('Dépenses Totales', _totalDepensesPeriod, PdfColors.red),
              pw.Divider(),
              _buildPdfStatRow(
                'Solde Net',
                _totalRevenusPeriod - _totalDepensesPeriod,
                (_totalRevenusPeriod - _totalDepensesPeriod) >= 0 ? PdfColors.blue : PdfColors.deepOrange,
                isBold: true,
              ),
              pw.SizedBox(height: 20),

              // Section Cotisations Mensuelles
              _buildPdfSectionTitle('Cotisations Mensuelles (${DateTime.now().year})'),
              if (_monthlyCotisations.isEmpty)
                pw.Text('Aucune cotisation enregistrée pour cette année.')
              else
                pw.Table.fromTextArray(
                  headers: ['Mois', 'Total ($_currencyUnit)'],
                  data: _monthlyCotisations.map((data) => [
                    'Mois ${data['month']}',
                    (data['total'] as double).toStringAsFixed(2),
                  ]).toList(),
                  border: pw.TableBorder.all(color: PdfColors.grey),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  cellAlignment: pw.Alignment.centerLeft,
                  cellPadding: pw.EdgeInsets.all(5),
                ),
              pw.SizedBox(height: 20),

              // Section Répartition des Revenus
              _buildPdfSectionTitle('Répartition des Revenus par Source'),
              if (_revenueDistribution.isEmpty)
                pw.Text('Aucun revenu enregistré pour cette période.')
              else
                pw.Table.fromTextArray(
                  headers: ['Source', 'Total ($_currencyUnit)'],
                  data: _revenueDistribution.map((data) => [
                    data['source'],
                    (data['total'] as double).toStringAsFixed(2),
                  ]).toList(),
                  border: pw.TableBorder.all(color: PdfColors.grey),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  cellAlignment: pw.Alignment.centerLeft,
                  cellPadding: pw.EdgeInsets.all(5),
                ),
              pw.SizedBox(height: 20),

              // Section Statistiques des Membres
              _buildPdfSectionTitle('Statistiques des Membres'),
              _buildPdfStatRow('Total Membres', _totalMembers.toDouble(), PdfColors.deepPurple, isValueDouble: false),
              pw.SizedBox(height: 8),
              pw.Text('Par Statut:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              if (_membersByStatus.isEmpty)
                pw.Text('Aucun membre par statut.')
              else
                pw.Table.fromTextArray(
                  headers: ['Statut', 'Nombre'],
                  data: _membersByStatus.map((data) => [
                    data['statut'],
                    (data['count'] as int).toString(),
                  ]).toList(),
                  border: pw.TableBorder.all(color: PdfColors.grey),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  cellAlignment: pw.Alignment.centerLeft,
                  cellPadding: pw.EdgeInsets.all(5),
                ),
              pw.SizedBox(height: 20),

              pw.Align(
                alignment: pw.Alignment.bottomRight,
                child: pw.Text('Généré par l\'application $appName'),
              ),
            ];
          },
        ),
      );

      // Enregistrer le PDF
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/rapport_mutualite_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
      final file = File(path);
      await file.writeAsBytes(await pdf.save());

      // Ouvrir le PDF
      await OpenFilex.open(path);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rapport PDF généré et ouvert !')),
      );

    } catch (e) {
      // print('Erreur lors de la génération ou de l\'ouverture du PDF du rapport : $e');
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
        title: const Text('Rapports & Statistiques'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectDateRange(context),
            tooltip: 'Sélectionner la période',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReportData,
            tooltip: 'Rafraîchir les données',
          ),
          // --- Bouton pour exporter en PDF ---
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _generateAndShareReportPdf,
            tooltip: 'Exporter en PDF',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Période sélectionnée : ${_dateFormat.format(_startDate)} au ${_dateFormat.format(_endDate)}',
                    style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 20),

                  // --- Section Résumé des Flux de Trésorerie ---
                  _buildReportCard(
                    title: 'Flux de Trésorerie sur la Période',
                    children: [
                      _buildStatRow('Revenus Totaux', _totalRevenusPeriod, Colors.green),
                      _buildStatRow('Dépenses Totales', _totalDepensesPeriod, Colors.red),
                      const Divider(),
                      _buildStatRow(
                        'Solde Net',
                        _totalRevenusPeriod - _totalDepensesPeriod,
                        (_totalRevenusPeriod - _totalDepensesPeriod) >= 0 ? Colors.blue : Colors.deepOrange,
                        isBold: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // --- Section Cotisations Mensuelles (Exemple pour l'année en cours) ---
                  _buildReportCard(
                    title: 'Cotisations Mensuelles (${DateTime.now().year})',
                    children: [
                      if (_monthlyCotisations.isEmpty)
                        const Text('Aucune cotisation enregistrée pour cette année.')
                      else
                        ..._monthlyCotisations.map((data) =>
                            _buildStatRow(
                              'Mois ${data['month']}',
                              data['total'],
                              Colors.blueGrey,
                            )
                        ).toList(),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // --- Section Répartition des Revenus par Source ---
                  _buildReportCard(
                    title: 'Répartition des Revenus par Source',
                    children: [
                      if (_revenueDistribution.isEmpty)
                        const Text('Aucun revenu enregistré pour cette période.')
                      else
                        ..._revenueDistribution.map((data) =>
                            _buildStatRow(
                              '${data['source']}',
                              data['total'],
                              Colors.purple,
                            )
                        ).toList(),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // --- Section Statistiques des Membres ---
                  _buildReportCard(
                    title: 'Statistiques des Membres',
                    children: [
                      _buildStatRow('Total Membres', _totalMembers.toDouble(), Colors.deepPurple, isValueDouble: false),
                      const SizedBox(height: 8),
                      const Text('Par Statut:', style: TextStyle(fontWeight: FontWeight.bold)),
                      if (_membersByStatus.isEmpty)
                        const Text('Aucun membre par statut.')
                      else
                        ..._membersByStatus.map((data) =>
                            _buildStatRow(
                              '  ${data['statut']}', // Indent for sub-item
                              data['count'].toDouble(),
                              Colors.indigo,
                              isValueDouble: false,
                            )
                        ).toList(),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  // Widget utilitaire pour une carte de rapport
  Widget _buildReportCard({required String title, required List<Widget> children}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[800]),
            ),
            const Divider(height: 20, thickness: 1),
            ...children,
          ],
        ),
      ),
    );
  }

  // Widget utilitaire pour une ligne de statistique
  Widget _buildStatRow(String label, double value, Color color, {bool isBold = false, bool isValueDouble = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: Colors.grey[800],
            ),
          ),
          Text(
            isValueDouble ? '${value.toStringAsFixed(2)} $_currencyUnit' : value.toInt().toString(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // --- Fonctions utilitaires pour le PDF ---
  pw.Widget _buildPdfSectionTitle(String title) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800),
        ),
        pw.Divider(height: 20, thickness: 1, color: PdfColors.grey),
      ],
    );
  }

  pw.Widget _buildPdfStatRow(String label, double value, PdfColor color, {bool isBold = false, bool isValueDouble = true}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4.0),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 14, // Slightly smaller font for PDF readability
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: PdfColors.grey800,
            ),
          ),
          pw.Text(
            isValueDouble ? '${value.toStringAsFixed(2)} $_currencyUnit' : value.toInt().toString(),
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}