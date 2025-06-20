// lib/models/operation.dart
class Operation {
  int? id;
  String description;
  double montant;
  String date; // Format YYYY-MM-DD
  String typeOperation; // 'revenu' ou 'depense'
  String? categorie; // Utilisé pour les dépenses
  String? source;    // Utilisé pour les revenus
  String? payeePar;  // Utilisé pour les dépenses
  String? recuPar;   // Utilisé pour les revenus
  int? membreId;
  int synchronized; // 0 = non synchronisé, 1 = synchronisé

  Operation({
    this.id,
    required this.description,
    required this.montant,
    required this.date,
    required this.typeOperation,
    this.categorie,
    this.source,
    this.payeePar,
    this.recuPar,
    this.membreId, // <-- NOUVEAU
    this.synchronized = 0,
  }) : assert(typeOperation == 'revenu' || typeOperation == 'depense'); // Assure un type valide

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'description': description,
      'montant': montant,
      'date': date,
      'type_operation': typeOperation,
      'categorie': categorie,
      'source': source,
      'payee_par': payeePar,
      'recu_par': recuPar,
      'membreId': membreId, // <-- NOUVEAU
      'synchronized': synchronized,
    };
  }

  factory Operation.fromMap(Map<String, dynamic> map) {
    return Operation(
      id: map['id'],
      description: map['description'],
      montant: map['montant'],
      date: map['date'],
      typeOperation: map['type_operation'],
      categorie: map['categorie'],
      source: map['source'],
      payeePar: map['payee_par'],
      recuPar: map['recu_par'],
      synchronized: map['synchronized'],
    );
  }
}