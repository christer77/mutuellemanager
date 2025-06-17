// lib/models/membre.dart
class Membre {
  int? id; // L'ID de la base de données locale
  String? numeroAffiliation;
  String nom;
  String postNom;
  String prenom;
  String? telephone;
  String? adresse;
  String? profession;
  String? activiteActuelle;
  int synchronized; // 0 = non synchronisé, 1 = synchronisé

  Membre({
    this.id,
    this.numeroAffiliation,
    required this.nom,
    required this.postNom,
    required this.prenom,
    this.telephone,
    this.adresse,
    this.profession,
    this.activiteActuelle,
    this.synchronized = 0,
  });

  // Convertit un Membre en Map pour l'insertion/mise à jour en base de données
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'numero_affiliation': numeroAffiliation,
      'nom': nom,
      'post_nom': postNom,
      'prenom': prenom,
      'telephone': telephone,
      'adresse': adresse,
      'profession': profession,
      'activite_actuelle': activiteActuelle,
      'synchronized': synchronized,
    };
  }

  // Crée un Membre à partir d'un Map (venant de la base de données)
  factory Membre.fromMap(Map<String, dynamic> map) {
    return Membre(
      id: map['id'],
      numeroAffiliation: map['numero_affiliation'],
      nom: map['nom'],
      postNom: map['post_nom'],
      prenom: map['prenom'],
      telephone: map['telephone'],
      adresse: map['adresse'],
      profession: map['profession'],
      activiteActuelle: map['activite_actuelle'],
      synchronized: map['synchronized'],
    );
  }
}