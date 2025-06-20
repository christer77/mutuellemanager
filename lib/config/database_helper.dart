// lib/database_helper.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import 'constants.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  // Constructeur privé pour le singleton
  DatabaseHelper._internal();

  // Point d'accès unique à l'instance de la classe (Singleton)
  factory DatabaseHelper() {
    return _instance;
  }

  // Getter pour la base de données
  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  // Initialisation de la base de données
  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'mutualite_app.db'); // Nom du fichier de la base de données

    return await openDatabase(
      path,
      version: dbVersion, // La version de votre base de données
      onCreate: (db, version) async {
        // Crée la table 'mutualites' lors de la première installation de l'app
        await db.execute(
          '''
          CREATE TABLE mutualites(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nom_mutualite TEXT,
            nom_responsable TEXT,
            telephone TEXT,
            adresse TEXT,
            id_national TEXT UNIQUE,
            rccm TEXT UNIQUE,
            dateCreation TEXT, -- Format YYYY-MM-DD
            synchronized INTEGER DEFAULT 0
          )
          ''',
        );
        await db.execute(
          '''
          CREATE TABLE membres(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            numero_affiliation TEXT UNIQUE,
            nom TEXT,
            post_nom TEXT,
            prenom TEXT,
            telephone TEXT,
            adresse TEXT,
            profession TEXT,
            activite_actuelle TEXT,
            dateAdhesion TEXT DEFAULT NULL, -- Format YYYY-MM-DD
            statut TEXT DEFAULT "Actif",
            synchronized INTEGER DEFAULT 0
          )
          ''',
        );

        await db.execute(
          '''
          CREATE TABLE operations(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            description TEXT,
            montant REAL,
            date TEXT, -- Format YYYY-MM-DD
            type_operation TEXT NOT NULL, -- 'revenu' ou 'depense'
            categorie TEXT, -- Pour les dépenses
            source TEXT,    -- Pour les revenus
            payee_par TEXT, -- Pour les dépenses
            recu_par TEXT,  -- Pour les revenus
            membreId INTEGER,
            synchronized INTEGER DEFAULT 0
          )
          '''
        );

        await db.execute('''
          CREATE TABLE users(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            password TEXT NOT NULL, -- Stocker les mots de passe hachés en production !
            role TEXT DEFAULT 'user'
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Logique de migration si vous modifiez la structure de votre base de données
        // au fil du temps (par exemple, ajout de colonnes, nouvelles tables)
        
        if (oldVersion < 2) {
          // await db.execute('ALTER TABLE membres ADD COLUMN dateAdhesion TEXT;');
          // await db.execute('ALTER TABLE membres ADD COLUMN statut TEXT DEFAULT "Actif";');
        }
      },
    );
  }

  // --- Opérations CRUD pour la table 'mutualites' ---

  Future<int> insertMutualite(Map<String, dynamic> mutualite) async {
    final db = await database;
    return await db.insert(
      'mutualites',
      mutualite,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getUnsyncedMutualites() async {
    final db = await database;
    return await db.query(
      'mutualites',
      where: 'synchronized = ?',
      whereArgs: [0],
    );
  }

  Future<int> updateMutualite(Map<String, dynamic> mutualite) async {
    Database db = await database;
    int id = mutualite['id'];
    return await db.update('mutualites', mutualite, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateMutualiteSynchronizedStatus(int id, int status) async {
    final db = await database;
    return await db.update(
      'mutualites',
      {'synchronized': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getAllMutualites() async {
    final db = await database;
    return await db.query('mutualites');
  }

  Future<Map<String, dynamic>?> getMutualiteById(int id) async {
    Database db = await database;
    List<Map<String, dynamic>> results = await db.query(
      'mutualites',
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<Map<String, dynamic>?> getMutualite() async {
    Database db = await database;
    List<Map<String, dynamic>> results = await db.query('mutualites', limit: 1);
    return results.isNotEmpty ? results.first : null;
  }

  // --- NOUVELLES Opérations CRUD pour la table 'membres' ---

  Future<int> insertMembre(Map<String, dynamic> membre) async {
    final db = await database;
    return await db.insert(
      'membres',
      membre,
      conflictAlgorithm: ConflictAlgorithm.replace, // Ou .abort si vous voulez empêcher l'insertion si unique conflict
    );
  }

  Future<List<Map<String, dynamic>>> getAllMembres() async {
    final db = await database;
    return await db.query('membres');
  }

  Future<int> updateMembre(Map<String, dynamic> membre) async {
    final db = await database;
    return await db.update(
      'membres',
      membre,
      where: 'id = ?',
      whereArgs: [membre['id']],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> deleteMembre(int id) async {
    final db = await database;
    return await db.delete(
      'membres',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getUnsyncedMembres() async {
    final db = await database;
    return await db.query(
      'membres',
      where: 'synchronized = ?',
      whereArgs: [0],
    );
  }

  Future<int> updateMembreSynchronizedStatus(int id, int status) async {
    final db = await database;
    return await db.update(
      'membres',
      {'synchronized': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- NOUVELLES Opérations CRUD pour la table 'operations' ---
  Future<int> insertOperation(Map<String, dynamic> operation) async {
    final db = await database;
    return await db.insert('operations', operation);
  }
  
  
  /// Récupère le total des cotisations d'un membre, *éventuellement* filtrées par date.
  /// - `membreId`: L'ID du membre.
  /// - `startDate`, `endDate`: Dates au format 'YYYY-MM-DD' pour filtrer par période, ou null pour ignorer.
  Future<double> getTotalContributionsForMember(int membreId, {String? startDate, String? endDate}) async {
    Database db = await database;
    List<String> whereClauses = ['type_operation = ?', 'membreId = ?'];
    List<dynamic> whereArgs = ['revenu', membreId];

    if (startDate != null && startDate.isNotEmpty && endDate != null && endDate.isNotEmpty) {
      whereClauses.add('date BETWEEN ? AND ?');
      whereArgs.addAll([startDate, endDate]);
    }

    String whereString = whereClauses.join(' AND ');

    final List<Map<String, dynamic>> result = await db.query(
      'operations',
      columns: ['SUM(montant) as total'],
      where: whereString,
      whereArgs: whereArgs,
    );

    if (result.isNotEmpty && result[0]['total'] != null) {
      return result[0]['total'] as double;
    }
    return 0.0;
  }

  Future<List<Map<String, dynamic>>> getMemberContributionStatement(int membreId) async {
    Database db = await database;
    return await db.query(
      'operations',
      where: 'type_operation = ? AND source = ? AND membreId = ?',
      whereArgs: ['revenu', 'Cotisation Membre', membreId],
      orderBy: 'date DESC, id DESC', // Trier par date descendante et ID pour la stabilité
    );
  }

  /// Récupère le relevé des cotisations pour un membre, avec un solde de report et un filtre par date.
  /// Retourne un Map contenant le 'soldeReport' et la 'operations' pour la période.
  /// `startDate` et `endDate` doivent être au format 'YYYY-MM-DD'.
  Future<Map<String, dynamic>> getMemberContributionStatementWithReport(
    int membreId, {
    String? startDate,
    String? endDate,
  }) async {
    Database db = await database;

    // 1. Calcul du solde de report (cotisations AVANT la startDate)
    double soldeReport = 0.0;
    if (startDate != null && startDate.isNotEmpty) {
      final List<Map<String, dynamic>> reportResult = await db.query(
        'operations',
        columns: ['SUM(montant) as total'],
        where: 'type_operation = ? AND source = ? AND membreId = ? AND date < ?',
        whereArgs: ['revenu', 'Cotisation Membre', membreId, startDate],
      );
      if (reportResult.isNotEmpty && reportResult[0]['total'] != null) {
        soldeReport = reportResult[0]['total'] as double;
      }
    }

    // 2. Récupération des opérations pour la période sélectionnée
    List<String> whereClauses = ['type_operation = ?', 'source = ?', 'membreId = ?'];
    List<dynamic> whereArgs = ['revenu', 'Cotisation Membre', membreId];

    if (startDate != null && startDate.isNotEmpty && endDate != null && endDate.isNotEmpty) {
      whereClauses.add('date BETWEEN ? AND ?');
      whereArgs.addAll([startDate, endDate]);
    }

    String whereString = whereClauses.join(' AND ');

    final List<Map<String, dynamic>> periodOperations = await db.rawQuery(
      'SELECT * FROM operations WHERE $whereString ORDER BY date ASC, id ASC', // Tri ascendant pour le relevé
      whereArgs,
    );

    return {
      'soldeReport': soldeReport,
      'operations': periodOperations,
    };
  }

  Future<List<Map<String, dynamic>>> getAllOperations() async {
    final db = await database;
    return await db.query('operations', orderBy: 'date DESC, id DESC'); // Trier par date puis par ID
  }

  /// Récupère toutes les opérations ou les opérations filtrées.
  /// - `typeOperation`: 'revenu', 'depense', ou null pour tous.
  /// - `source`: Nom de la source (ex: 'Cotisation Membre', 'Don'), ou null pour toutes.
  /// - `startDate`, `endDate`: Dates au format 'YYYY-MM-DD' pour filtrer par période, ou null pour ignorer.
  Future<List<Map<String, dynamic>>> getFilteredOperations({
    String? typeOperation,
    String? source,
    String? startDate,
    String? endDate,
  }) async {
    Database db = await database;
    List<String> whereClauses = [];
    List<dynamic> whereArgs = [];

    if (typeOperation != null && typeOperation.isNotEmpty) {
      whereClauses.add('type_operation = ?');
      whereArgs.add(typeOperation);
    }
    if (source != null && source.isNotEmpty) {
      whereClauses.add('source = ?');
      whereArgs.add(source);
    }
    if (startDate != null && startDate.isNotEmpty && endDate != null && endDate.isNotEmpty) {
      whereClauses.add('date BETWEEN ? AND ?');
      whereArgs.add(startDate);
      whereArgs.add(endDate);
    }

    String whereString = whereClauses.isEmpty ? '' : 'WHERE ${whereClauses.join(' AND ')}';

    return await db.rawQuery(
      'SELECT * FROM operations $whereString ORDER BY date DESC, id DESC', // Tri par date, puis par ID pour l'ordre stable
      whereArgs,
    );
  }

  /// Récupère toutes les sources d'opérations uniques pour le filtre.
  Future<List<String>> getAllOperationSources() async {
    Database db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'operations',
      columns: ['DISTINCT source'], // Récupère les valeurs distinctes de la colonne source
      where: 'source IS NOT NULL AND source != ?', // Exclut les sources nulles ou vides si besoin
      whereArgs: [''], // Exclut les sources vides
    );
    // Convertit la liste de maps en liste de String, filtrant les nulls
    return result.map((e) => e['source'] as String).where((source) => source.isNotEmpty).toList();
  }

  Future<int> updateOperation(Map<String, dynamic> operation) async {
    final db = await database;
    return await db.update('operations', operation, where: 'id = ?', whereArgs: [operation['id']]);
  }
  Future<int> deleteOperation(int id) async {
    final db = await database;
    return await db.delete('operations', where: 'id = ?', whereArgs: [id]);
  }
  Future<List<Map<String, dynamic>>> getUnsyncedOperations() async {
    final db = await database;
    return await db.query('operations', where: 'synchronized = ?', whereArgs: [0]);
  }
  Future<int> updateOperationSynchronizedStatus(int id, int status) async {
    final db = await database;
    return await db.update('operations', {'synchronized': status}, where: 'id = ?', whereArgs: [id]);
  }

  Future<double> getTotalExpenses() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery('SELECT SUM(montant) as total FROM operations WHERE type_operation = ?', ['depense']);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getTotalIncomes() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery('SELECT SUM(montant) as total FROM operations WHERE type_operation = ?', ['revenu']);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Calcule le total des cotisations (revenus de source 'Cotisation Membre').
  Future<double> getTotalCotisations() async {
    Database db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'operations',
      columns: ['SUM(montant) as total'],
      where: 'type_operation = ? AND source = ?',
      whereArgs: ['revenu', 'Cotisation Membre'],
    );

    if (result.isNotEmpty && result[0]['total'] != null) {
      return result[0]['total'] as double;
    }
    return 0.0;
  }

  /// Calcule le total des autres revenus (revenus qui ne sont pas des cotisations).
  Future<double> getTotalOtherRevenus() async {
    Database db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'operations',
      columns: ['SUM(montant) as total'],
      where: 'type_operation = ? AND source != ?', // Filtrer les revenus dont la source n'est PAS 'Cotisation Membre'
      whereArgs: ['revenu', 'Cotisation Membre'],
    );

    if (result.isNotEmpty && result[0]['total'] != null) {
      return result[0]['total'] as double;
    }
    return 0.0;
  }


  /// Récupère les dernières opérations (cotisations et dépenses) triées par date.
  /// Vous pouvez ajuster le nombre d'opérations à récupérer avec `limit`.
  Future<List<Map<String, dynamic>>> getRecentOperations({int limit = 5}) async {
    Database db = await database;
    return await db.query(
      'operations',
      orderBy: 'date DESC',
      limit: limit,
    );
  }

  // Si vous voulez aussi afficher les derniers membres enregistrés, ajoutez ceci :
  /// Récupère les derniers membres enregistrés.
  Future<List<Map<String, dynamic>>> getRecentMembers({int limit = 3}) async {
    Database db = await database;
    return await db.query(
      'membres',
      orderBy: 'dateAdhesion DESC',
      limit: limit,
    );
  }

  // ******************************************************
  // ******************** STATISTIQUE *********************
  // ******************************************************
  /// Récupère le total des revenus pour une période donnée.
  /// `startDate` et `endDate` doivent être au format 'YYYY-MM-DD'.
  Future<double> getTotalRevenusByPeriod(String? startDate, String? endDate) async {
    Database db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'operations',
      columns: ['SUM(montant) as total'],
      where: 'type_operation = ? AND date BETWEEN ? AND ?',
      whereArgs: ['revenu', startDate, endDate],
    );
    return (result.isNotEmpty && result[0]['total'] != null) ? result[0]['total'] as double : 0.0;
  }

  /// Récupère le total des dépenses pour une période donnée.
  /// `startDate` et `endDate` doivent être au format 'YYYY-MM-DD'.
  Future<double> getTotalDepensesByPeriod(String? startDate, String? endDate) async {
    Database db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'operations',
      columns: ['SUM(montant) as total'],
      where: 'type_operation = ? AND date BETWEEN ? AND ?',
      whereArgs: ['depense', startDate, endDate],
    );
    return (result.isNotEmpty && result[0]['total'] != null) ? result[0]['total'] as double : 0.0;
  }

  /// Récupère les cotisations agrégées par mois pour une année donnée.
  /// Retourne une liste de Map: [{'month': 'MM', 'total': X.X}]
  Future<List<Map<String, dynamic>>> getMonthlyCotisations(int year) async {
    Database db = await database;
    // SQLite n'a pas de fonction MONTH() directe sur les dates TEXT.
    // On peut utiliser SUBSTR pour extraire le mois et SUM pour le total.
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT
        SUBSTR(date, 6, 2) AS month,
        SUM(montant) AS total
      FROM operations
      WHERE type_operation = ?
        AND source = ?
        AND SUBSTR(date, 1, 4) = ?
      GROUP BY month
      ORDER BY month ASC;
    ''', ['revenu', 'Cotisation Membre', year.toString()]);

    return result.map((row) => {
      'month': row['month'] as String,
      'total': row['total'] as double,
    }).toList();
  }

  /// Récupère la répartition des revenus par source pour une période donnée.
  Future<List<Map<String, dynamic>>> getRevenueDistributionBySource(String startDate, String endDate) async {
    Database db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'operations',
      columns: ['source', 'SUM(montant) as total'],
      where: 'type_operation = ? AND date BETWEEN ? AND ?',
      whereArgs: ['revenu', startDate, endDate],
      groupBy: 'source',
    );
    return result.map((row) => {
      'source': row['source'] as String,
      'total': row['total'] as double,
    }).toList();
  }

  /// Récupère le nombre total de membres.
  Future<int> getTotalMembersCount() async {
    Database db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'membres',
      columns: ['COUNT(*) as count'],
    );
    return (result.isNotEmpty && result[0]['count'] != null) ? result[0]['count'] as int : 0;
  }

  /// Récupère le nombre de membres par statut.
  Future<List<Map<String, dynamic>>> getMembersCountByStatus() async {
    Database db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'membres',
      columns: ['statut', 'COUNT(*) as count'],
      groupBy: 'statut',
    );
    return result.map((row) => {
      'statut': row['statut'] as String,
      'count': row['count'] as int,
    }).toList();
  }

  //************************************************************************************ */
  // --- Opérations CRUD sur l'Utilisateur (NOUVEAU) ---
  //************************************************************************************ */
  Future<int> insertUser(Map<String, dynamic> user) async {
    Database db = await database;
    // Pour la production, hacher le mot de passe avant de l'insérer
    // String hashedPassword = sha256.convert(utf8.encode(user['password'])).toString();
    // user['password'] = hashedPassword;
    return await db.insert('users', user, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    Database db = await database;
    return await db.query('users');
  }

  // Vous utiliseriez cela pour la validation de connexion
  Future<Map<String, dynamic>?> validateUser(String username, String password) async {
    Database db = await database;
    // Pour la production, hacher le mot de passe d'entrée et comparer avec le hachage stocké
    // String hashedPassword = sha256.convert(utf8.encode(password)).toString();
    List<Map<String, dynamic>> results = await db.query(
      'users',
      where: 'username = ? AND password = ?', // Remplacer par la comparaison du mot de passe haché
      whereArgs: [username, password],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<bool> checkUserPassword(String username, String password) async {
    Database db = await database;
    // IMPORTANT: Si vous hachez les mots de passe, hachez le `password` reçu ici
    // pour la comparaison.
    // String hashedPassword = sha256.convert(utf8.encode(password)).toString();
    List<Map<String, dynamic>> results = await db.query(
      'users',
      where: 'username = ? AND password = ?', // Utilisez le hash ici si le stockage est haché
      whereArgs: [username, password], // Utilisez le hash ici si le stockage est haché
    );
    return results.isNotEmpty;
  }

  // NOUVEAU: Mettre à jour le mot de passe de l'utilisateur
  Future<int> updateUserPassword(String username, String newPassword) async {
    Database db = await database;
    // IMPORTANT: Hachez le newPassword avant de le stocker en production!
    // String hashedNewPassword = sha256.convert(utf8.encode(newPassword)).toString();
    return await db.update(
      'users',
      {'password': newPassword}, // Utilisez le hash ici si le stockage est haché
      where: 'username = ?',
      whereArgs: [username],
    );
  }

  Future<Map<String, dynamic>?> getUserByUsername(String username) async {
    Database db = await database;
    List<Map<String, dynamic>> results = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    Database db = await database;
    return await db.query('users');
  }

  Future<int> deleteAll(String tableName) async {
    Database db = await database;
    return await db.delete(tableName);
  }

  
  

}