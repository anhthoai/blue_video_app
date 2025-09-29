import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class StorageService {
  static late SharedPreferences _prefs;
  static late Database _database;

  // Initialize services
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _initDatabase();
  }

  // Initialize database
  static Future<void> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'blue_video_app.db');

    _database = await openDatabase(path, version: 1, onCreate: _createTables);
  }

  // Create database tables
  static Future<void> _createTables(Database db, int version) async {
    // Users table
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        email TEXT,
        username TEXT,
        phone_number TEXT,
        avatar_url TEXT,
        bio TEXT,
        is_verified INTEGER,
        is_vip INTEGER,
        vip_level INTEGER,
        coin_balance INTEGER,
        follower_count INTEGER,
        following_count INTEGER,
        video_count INTEGER,
        like_count INTEGER,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // Videos table
    await db.execute('''
      CREATE TABLE videos (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        title TEXT,
        description TEXT,
        video_url TEXT,
        thumbnail_url TEXT,
        duration INTEGER,
        view_count INTEGER,
        like_count INTEGER,
        comment_count INTEGER,
        share_count INTEGER,
        is_public INTEGER,
        is_featured INTEGER,
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');

    // Comments table
    await db.execute('''
      CREATE TABLE comments (
        id TEXT PRIMARY KEY,
        video_id TEXT,
        user_id TEXT,
        content TEXT,
        parent_id TEXT,
        like_count INTEGER,
        created_at TEXT,
        FOREIGN KEY (video_id) REFERENCES videos (id),
        FOREIGN KEY (user_id) REFERENCES users (id),
        FOREIGN KEY (parent_id) REFERENCES comments (id)
      )
    ''');

    // Chat messages table
    await db.execute('''
      CREATE TABLE chat_messages (
        id TEXT PRIMARY KEY,
        chat_id TEXT,
        sender_id TEXT,
        content TEXT,
        message_type TEXT,
        is_read INTEGER,
        created_at TEXT,
        FOREIGN KEY (sender_id) REFERENCES users (id)
      )
    ''');

    // User follows table
    await db.execute('''
      CREATE TABLE user_follows (
        id TEXT PRIMARY KEY,
        follower_id TEXT,
        following_id TEXT,
        created_at TEXT,
        FOREIGN KEY (follower_id) REFERENCES users (id),
        FOREIGN KEY (following_id) REFERENCES users (id)
      )
    ''');

    // Video likes table
    await db.execute('''
      CREATE TABLE video_likes (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        video_id TEXT,
        created_at TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id),
        FOREIGN KEY (video_id) REFERENCES videos (id)
      )
    ''');
  }

  // SharedPreferences methods
  static Future<void> setString(String key, String value) async {
    await _prefs.setString(key, value);
  }

  static String? getString(String key) {
    return _prefs.getString(key);
  }

  static Future<void> setInt(String key, int value) async {
    await _prefs.setInt(key, value);
  }

  static int? getInt(String key) {
    return _prefs.getInt(key);
  }

  static Future<void> setBool(String key, bool value) async {
    await _prefs.setBool(key, value);
  }

  static bool? getBool(String key) {
    return _prefs.getBool(key);
  }

  static Future<void> setDouble(String key, double value) async {
    await _prefs.setDouble(key, value);
  }

  static double? getDouble(String key) {
    return _prefs.getDouble(key);
  }

  static Future<void> setStringList(String key, List<String> value) async {
    await _prefs.setStringList(key, value);
  }

  static List<String>? getStringList(String key) {
    return _prefs.getStringList(key);
  }

  static Future<void> remove(String key) async {
    await _prefs.remove(key);
  }

  static Future<void> clear() async {
    await _prefs.clear();
  }

  // Database methods
  static Future<int> insert(String table, Map<String, dynamic> data) async {
    return await _database.insert(table, data);
  }

  static Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    return await _database.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  static Future<int> update(
    String table,
    Map<String, dynamic> data, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    return await _database.update(
      table,
      data,
      where: where,
      whereArgs: whereArgs,
    );
  }

  static Future<int> delete(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    return await _database.delete(table, where: where, whereArgs: whereArgs);
  }

  static Future<void> execute(String sql, [List<dynamic>? arguments]) async {
    await _database.execute(sql, arguments);
  }

  static Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<dynamic>? arguments,
  ]) async {
    return await _database.rawQuery(sql, arguments);
  }

  // Close database
  static Future<void> close() async {
    await _database.close();
  }
}
