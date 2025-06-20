import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/constants.dart';
import '../../config/database_helper.dart';
import '../../models/membre.dart';
import 'member_contributions_statement_screen.dart';

// PDF generation imports
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw; // Use pw to avoid conflicts with Flutter widgets
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io'; // Needed for File class

class MembersBalanceScreen extends StatefulWidget {
  const MembersBalanceScreen({Key? key}) : super(key: key);

  @override
  State<MembersBalanceScreen> createState() => _MembersBalanceScreenState();
}

class _MembersBalanceScreenState extends State<MembersBalanceScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Membre> _members = [];
  Map<int, double> _membersContributions = {}; // Map: membreId -> totalContributions
  bool _isLoading = true;

  // Variables for date filtering
  DateTime? _startDateFilter;
  DateTime? _endDateFilter;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  // Variable for total balance
  double _totalBalance = 0.0; // Initialize total balance
  String _currencyUnit = 'USD'; // Valeur par défaut ou fallback

  @override
  void initState() {
    super.initState();
    _loadCurrencyUnit();
    // Default filter to current year if not already set.
    // This provides a sensible default for the total balance and PDF export.
    _startDateFilter ??= DateTime(DateTime.now().year, 1, 1);
    _endDateFilter ??= DateTime.now();
    _loadMembersAndContributions();
  }
  Future<void> _loadCurrencyUnit() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _currencyUnit = prefs.getString('currencyUnit') ?? 'USD';
    });
  }

  // Method to select date range filter
  Future<void> _selectDateRangeFilter(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      initialDateRange: (_startDateFilter != null && _endDateFilter != null)
          ? DateTimeRange(start: _startDateFilter!, end: _endDateFilter!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _startDateFilter = picked.start;
        _endDateFilter = picked.end;
      });
      _loadMembersAndContributions(); // Reload data with the new date range
    }
  }

  // Method to load members and their contributions
  Future<void> _loadMembersAndContributions() async {
    setState(() {
      _isLoading = true;
      _totalBalance = 0.0; // Reset total balance before recalculating
    });

    try {
      final List<Map<String, dynamic>> memberMaps = await _dbHelper.getAllMembres();
      _members = memberMaps.map((map) => Membre.fromMap(map)).toList();
      _membersContributions.clear(); // Clear the map before repopulating

      for (final membre in _members) {
        if (membre.id != null) {
          final total = await _dbHelper.getTotalContributionsForMember(
            membre.id!,
            startDate: _startDateFilter != null ? _dateFormat.format(_startDateFilter!) : null,
            endDate: _endDateFilter != null ? _dateFormat.format(_endDateFilter!) : null,
          );
          _membersContributions[membre.id!] = total;
          _totalBalance += total; // Add to the running total balance
        }
      }
    } catch (e) {
      // print('Error loading members and their balances: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // --- PDF Generation Function ---
  Future<void> _generateAndShareMembersBalancePdf() async {
    setState(() {
      _isLoading = true; // Show loading indicator during PDF generation
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
                  'Solde Total des Membres',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Date de génération : ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}'),
              if (_startDateFilter != null && _endDateFilter != null)
                pw.Text('Période filtrée : ${_dateFormat.format(_startDateFilter!)} au ${_dateFormat.format(_endDateFilter!)}'),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Solde Total de Tous les Membres :', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('${_totalBalance.toStringAsFixed(2)} $_currencyUnit', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green)),
                ],
              ),
              pw.Divider(),
              pw.SizedBox(height: 20),
              if (_members.isEmpty)
                pw.Center(child: pw.Text('Aucun membre enregistré.'))
              else
                pw.Table.fromTextArray(
                  headers: ['Nom', 'Prénom', 'Solde ($_currencyUnit)'],
                  data: _members.map((membre) => [
                    membre.nom,
                    membre.prenom,
                    (_membersContributions[membre.id] ?? 0.0).toStringAsFixed(2),
                  ]).toList(),
                  border: pw.TableBorder.all(color: PdfColors.grey),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  cellAlignment: pw.Alignment.centerLeft,
                  cellPadding: pw.EdgeInsets.all(5),
                ),
              pw.Align(
                alignment: pw.Alignment.bottomRight,
                child: pw.Text('Généré par l\'application $appName'),
              )
            ];
          },
        ),
      );

      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/solde_total_membres_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
      final file = File(path);
      await file.writeAsBytes(await pdf.save());

      await OpenFilex.open(path); // Open the PDF after saving

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Solde total des membres exporté en PDF et ouvert !')),
      );

    } catch (e) {
      // print('Error generating or opening PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate PDF: ${e.toString()}', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
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
        title: const Text('Solde des Membres'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectDateRangeFilter(context),
            tooltip: 'Filtrer par date',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMembersAndContributions,
            tooltip: 'Rafraîchir les soldes',
          ),
          // Button to export to PDF
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _generateAndShareMembersBalancePdf,
            tooltip: 'Exporter en PDF',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column( // Use Column to place the header card and total balance below the list
              children: [
                // --- HEADER CARD: PERIOD AND TOTAL BALANCE ---
                Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Période du relevé : ${_dateFormat.format(_startDateFilter!)} au ${_dateFormat.format(_endDateFilter!)}',
                            style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.grey[700]),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Solde Total des Membres :',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${_totalBalance.toStringAsFixed(2)} $_currencyUnit',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
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

                Expanded( // The member list takes available space
                  child: _members.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_alt_outlined, size: 60, color: Colors.grey),
                              SizedBox(height: 10),
                              Text(
                                'Aucun membre enregistré pour la période sélectionnée.',
                                style: TextStyle(fontSize: 16, color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8.0),
                          itemCount: _members.length,
                          itemBuilder: (context, index) {
                            final membre = _members[index];
                            final totalContributions = _membersContributions[membre.id] ?? 0.0; // Get balance or 0.0

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
                              elevation: 3,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.blue.shade100,
                                  child: Text(
                                    membre.prenom.isNotEmpty? membre.prenom[0].toUpperCase() : membre.nom[0].toUpperCase(), // First letter of first name
                                    style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Text(
                                  '${membre.prenom} ${membre.nom}',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text('Téléphone: ${membre.telephone ?? 'N/A'}'),
                                trailing: Text(
                                  '${totalContributions.toStringAsFixed(2)} $_currencyUnit',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green, // Contributions are generally positive
                                    fontSize: 16,
                                  ),
                                ),
                                isThreeLine: false, // No longer need 3 lines as period info is in header
                                onTap: () {
                                  if (membre.id != null) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => MemberContributionsStatementScreen(membre: membre),
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Impossible d\'afficher le relevé: ID du membre manquant.')),
                                    );
                                  }
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