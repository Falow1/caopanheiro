import 'dart:convert';

import 'package:sqflite/sqflite.dart';

class SqlSnapshot {
  const SqlSnapshot(this.items, this.updatedAt);
  final List<Map<String, dynamic>> items;
  final DateTime updatedAt;
}

/// Persistence infrastructure without authentication or application roles.
/// Adapters must check their retained Auth identity and canonical scope first.
class SqlSnapshotCache {
  SqlSnapshotCache._(this._db);
  final Database _db;
  Future<void> _serial = Future.value();
  Future<T> _run<T>(Future<T> Function() operation) {
    final result = _serial.then((_) => operation());
    _serial = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }

  static Future<SqlSnapshotCache> open(String name) async {
    if (!RegExp(r'^[a-z_0-9]+\.db$').hasMatch(name))
      throw const FormatException('Nome de banco inválido.');
    final db = await openDatabase(
      name,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys=ON');
        await db.rawQuery('PRAGMA secure_delete=ON');
      },
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE owner(uid TEXT PRIMARY KEY)');
        await db.execute(
          'CREATE TABLE scopes(uid TEXT NOT NULL,scope TEXT NOT NULL,payload TEXT NOT NULL,PRIMARY KEY(uid,scope),FOREIGN KEY(uid) REFERENCES owner(uid) ON DELETE CASCADE)',
        );
        await db.execute(
          'CREATE TABLE snapshots(uid TEXT NOT NULL,scope TEXT NOT NULL,resource TEXT NOT NULL,payload TEXT NOT NULL,updated_at TEXT NOT NULL,PRIMARY KEY(uid,scope,resource),FOREIGN KEY(uid,scope) REFERENCES scopes(uid,scope) ON DELETE CASCADE)',
        );
      },
    );
    return SqlSnapshotCache._(db);
  }

  Future<String?> get owner => _run(() async {
    final rows = await _db.query('owner', limit: 1);
    return rows.isEmpty ? null : rows.first['uid'] as String;
  });
  Future<void> clear() => _run(
    () => _db.transaction((tx) async {
      await tx.delete('owner');
    }),
  );
  Future<void> bind(String uid, List<Map<String, dynamic>> scopes) => _run(
    () => _db.transaction((tx) async {
      await tx.delete('owner', where: 'uid != ?', whereArgs: [uid]);
      await tx.insert('owner', {
        'uid': uid,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      final existing = await tx.query(
        'scopes',
        where: 'uid = ?',
        whereArgs: [uid],
      );
      for (final old in existing) {
        if (!scopes.any((scope) => scope['id'] == old['scope']))
          await tx.delete(
            'scopes',
            where: 'uid = ? AND scope = ?',
            whereArgs: [uid, old['scope']],
          );
      }
      for (final scope in scopes) {
        final id = scope['id'] as String;
        final payload = jsonEncode(scope);
        final updated = await tx.update(
          'scopes',
          {'payload': payload},
          where: 'uid = ? AND scope = ?',
          whereArgs: [uid, id],
        );
        if (updated == 0)
          await tx.insert('scopes', {
            'uid': uid,
            'scope': id,
            'payload': payload,
          });
      }
    }),
  );
  Future<List<Map<String, dynamic>>> scopes(String uid) => _run(() async {
    final rows = await _db.query(
      'scopes',
      where: 'uid = ?',
      whereArgs: [uid],
      orderBy: 'scope',
    );
    return rows
        .map(
          (row) => Map<String, dynamic>.from(
            jsonDecode(row['payload'] as String) as Map,
          ),
        )
        .toList();
  });
  Future<SqlSnapshot?> read(String uid, String scope, String resource) =>
      _run(() async {
        final rows = await _db.query(
          'snapshots',
          where: 'uid = ? AND scope = ? AND resource = ?',
          whereArgs: [uid, scope, resource],
        );
        if (rows.isEmpty) return null;
        final row = rows.single;
        return SqlSnapshot(
          (jsonDecode(row['payload'] as String) as List)
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList(),
          DateTime.parse(row['updated_at'] as String),
        );
      });
  Future<void> write(
    String uid,
    String scope,
    String resource,
    List<Map<String, dynamic>> items, {
    DateTime? updatedAt,
  }) => _run(
    () => _db.transaction((tx) async {
      await tx.insert('snapshots', {
        'uid': uid,
        'scope': scope,
        'resource': resource,
        'payload': jsonEncode(items),
        'updated_at': (updatedAt ?? DateTime.now().toUtc()).toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }),
  );
  Future<void> patch(
    String uid,
    String scope,
    String resource,
    Map<String, dynamic> item,
  ) => _run(
    () => _db.transaction((tx) async {
      final rows = await tx.query(
        'snapshots',
        where: 'uid = ? AND scope = ? AND resource = ?',
        whereArgs: [uid, scope, resource],
      );
      if (rows.isEmpty) return;
      final items = (jsonDecode(rows.single['payload'] as String) as List)
          .map((value) => Map<String, dynamic>.from(value as Map))
          .toList();
      final index = items.indexWhere((value) => value['id'] == item['id']);
      if (index < 0) {
        items.add(item);
      } else {
        items[index] = item;
      }
      await tx.update(
        'snapshots',
        {'payload': jsonEncode(items)},
        where: 'uid = ? AND scope = ? AND resource = ?',
        whereArgs: [uid, scope, resource],
      );
    }),
  );
  Future<void> invalidate(String uid, String scope, String resource) =>
      _run(() async {
        await _db.delete(
          'snapshots',
          where: 'uid = ? AND scope = ? AND resource = ?',
          whereArgs: [uid, scope, resource],
        );
      });
  Future<void> close() => _run(_db.close);
}
