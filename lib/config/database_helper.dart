// lib/database_helper.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

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
      version: 2, // La version de votre base de données
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
            synchronized INTEGER DEFAULT 0
          )
          ''',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Logique de migration si vous modifiez la structure de votre base de données
        // au fil du temps (par exemple, ajout de colonnes, nouvelles tables)
        if (oldVersion < 2) {
          // Exemple: Si on passe à la version 2, ajouter une nouvelle table 'membres'
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
              synchronized INTEGER DEFAULT 0
            )
            '''
          );
        }
        // ... ajoutez d'autres blocs if pour les versions suivantes
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

}