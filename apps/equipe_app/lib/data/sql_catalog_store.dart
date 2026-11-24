import 'dart:convert';
import 'package:caopanheiro_core/caopanheiro_core.dart' show readRecordNumber;

import 'package:sqflite/sqflite.dart';

import '../domain/models.dart';
import '../domain/models/team_company.dart';

class CachedCatalog {
  const CachedCatalog(this.services, this.updatedAt);
  final List<PetService> services;
  final DateTime updatedAt;
}

class CachedResource {
  const CachedResource(this.items, this.updatedAt);
  final List<Map<String, dynamic>> items;
  final DateTime updatedAt;
}

/// One device session, explicitly partitioned by Firebase UID and company.
class SqlCatalogStore {
  SqlCatalogStore(this.db);
  final Database db;

  static Future<SqlCatalogStore> open({
    DatabaseFactory? factory,
    String path = 'team_catalog_v1.db',
  }) async {
    final db = await (factory ?? databaseFactory).openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 7,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
          await db.rawQuery('PRAGMA secure_delete = ON');
        },
        onCreate: (db, version) async {
          await db.execute('CREATE TABLE session (uid TEXT PRIMARY KEY)');
          await db.execute('''CREATE TABLE companies (
            uid TEXT NOT NULL, tenant TEXT NOT NULL, name TEXT NOT NULL,
            user_name TEXT NOT NULL, role TEXT NOT NULL, roles_json TEXT,
            updated_at TEXT, record_number INTEGER, delegated_manager INTEGER NOT NULL DEFAULT 0, management_permissions TEXT,
            PRIMARY KEY (uid, tenant),
            FOREIGN KEY (uid) REFERENCES session(uid) ON DELETE CASCADE)''');
          await db.execute('''CREATE TABLE services (
            uid TEXT NOT NULL, tenant TEXT NOT NULL, id TEXT NOT NULL,
            name TEXT NOT NULL, description TEXT NOT NULL, record_number INTEGER,
            price_cents INTEGER NOT NULL CHECK(price_cents >= 0),
            duration INTEGER NOT NULL CHECK(duration > 0),
            active INTEGER NOT NULL CHECK(active IN (0, 1)),
            PRIMARY KEY (uid, tenant, id),
            FOREIGN KEY (uid, tenant) REFERENCES companies(uid, tenant)
              ON DELETE CASCADE)''');
          await _createSnapshots(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 6) {
            await db.execute(
              'ALTER TABLE companies ADD COLUMN management_permissions TEXT',
            );
          }
          if (oldVersion < 5) {
            await db.execute(
              'ALTER TABLE companies ADD COLUMN delegated_manager INTEGER NOT NULL DEFAULT 0',
            );
            if (oldVersion >= 2) {
              await db.delete(
                'resource_snapshots',
                where: 'resource = ?',
                whereArgs: ['professionals'],
              );
            }
          }
          if (oldVersion < 6) {
            await db.delete('companies', where: 'delegated_manager = 1');
            await db.rawDelete(
              'DELETE FROM session WHERE NOT EXISTS (SELECT 1 FROM companies WHERE companies.uid = session.uid)',
            );
          }
          if (oldVersion < 2) await _createSnapshots(db);
          if (oldVersion < 4) {
            await db.execute(
              'ALTER TABLE companies ADD COLUMN roles_json TEXT',
            );
          }
          if (oldVersion < 3) {
            await db.execute(
              'ALTER TABLE companies ADD COLUMN record_number INTEGER',
            );
            await db.execute(
              'ALTER TABLE services ADD COLUMN record_number INTEGER',
            );
          }
        },
      ),
    );
    return SqlCatalogStore(db);
  }

  static Future<void> _createSnapshots(DatabaseExecutor db) => db.execute('''
    CREATE TABLE resource_snapshots (
      uid TEXT NOT NULL, tenant TEXT NOT NULL, resource TEXT NOT NULL,
      payload TEXT NOT NULL, updated_at TEXT NOT NULL,
      PRIMARY KEY (uid, tenant, resource),
      FOREIGN KEY (uid, tenant) REFERENCES companies(uid, tenant) ON DELETE CASCADE)
  ''');

  Future<CachedResource?> resource(
    String uid,
    String tenant,
    String resource,
  ) async {
    final rows = await db.query(
      'resource_snapshots',
      where: 'uid = ? AND tenant = ? AND resource = ?',
      whereArgs: [uid, tenant, resource],
    );
    if (rows.isEmpty) return null;
    final value = rows.first;
    final items = (jsonDecode(value['payload'] as String) as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    return CachedResource(items, DateTime.parse(value['updated_at'] as String));
  }

  Future<void> replaceResource(
    String uid,
    String tenant,
    String resource,
    List<Map<String, dynamic>> items,
    DateTime time,
  ) => db.transaction((tx) async {
    await tx.insert('resource_snapshots', {
      'uid': uid,
      'tenant': tenant,
      'resource': resource,
      'payload': jsonEncode(items),
      'updated_at': time.toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  });

  Future<void> patchResourceItem(
    String uid,
    String tenant,
    String resource,
    Map<String, dynamic> item,
  ) => db.transaction((tx) async {
    final rows = await tx.query(
      'resource_snapshots',
      where: 'uid = ? AND tenant = ? AND resource = ?',
      whereArgs: [uid, tenant, resource],
    );
    // A single confirmed item cannot pretend to be a complete first download.
    if (rows.isEmpty) return;
    final items = (jsonDecode(rows.first['payload'] as String) as List)
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList();
    final index = items.indexWhere((value) => value['id'] == item['id']);
    if (index < 0) {
      items.add(item);
    } else {
      items[index] = item;
    }
    await tx.update(
      'resource_snapshots',
      {'payload': jsonEncode(items)},
      where: 'uid = ? AND tenant = ? AND resource = ?',
      whereArgs: [uid, tenant, resource],
    );
  });

  Future<void> removeResourceItem(
    String uid,
    String tenant,
    String resource,
    String id,
  ) => db.transaction((tx) async {
    final rows = await tx.query(
      'resource_snapshots',
      where: 'uid = ? AND tenant = ? AND resource = ?',
      whereArgs: [uid, tenant, resource],
    );
    if (rows.isEmpty) return;
    final items = (jsonDecode(rows.first['payload'] as String) as List)
        .where((item) => (item as Map)['id'] != id)
        .toList();
    await tx.update(
      'resource_snapshots',
      {'payload': jsonEncode(items)},
      where: 'uid = ? AND tenant = ? AND resource = ?',
      whereArgs: [uid, tenant, resource],
    );
  });

  Future<void> invalidateResource(
    String uid,
    String tenant,
    String resource,
  ) async {
    await db.delete(
      'resource_snapshots',
      where: 'uid = ? AND tenant = ? AND resource = ?',
      whereArgs: [uid, tenant, resource],
    );
  }

  /// A denied company cannot remain available through an older offline cache.
  Future<void> invalidateCompany(String uid, String tenant) async {
    await db.delete(
      'companies',
      where: 'uid = ? AND tenant = ?',
      whereArgs: [uid, tenant],
    );
  }

  Future<String?> get sessionUid async {
    final rows = await db.query('session', limit: 1);
    return rows.isEmpty ? null : rows.first['uid'] as String;
  }

  Future<void> clear() => db.transaction((tx) async {
    await tx.delete('session');
  });

  Future<List<TeamCompany>> companies(String uid) async {
    final rows = await db.query(
      'companies',
      where: 'uid = ?',
      whereArgs: [uid],
      orderBy: 'tenant',
    );
    return rows
        .map(
          (row) => TeamCompany(
            id: row['tenant'] as String,
            recordNumber: readRecordNumber(row['record_number']),
            name: row['name'] as String,
            user: InternalUser(
              name: row['user_name'] as String,
              managementDelegated: row['delegated_manager'] == 1,
              managementPermissions: row['management_permissions'] == null
                  ? null
                  : (jsonDecode(row['management_permissions'] as String)
                            as List)
                        .cast<String>(),
              role: TenantRole.fromApi(row['role'] as String),
              roles: row['roles_json'] == null
                  ? []
                  : (jsonDecode(row['roles_json'] as String) as List)
                        .map((v) => TenantRole.fromApi(v as String))
                        .toList(),
              canManageBlocks: ['MANAGER', 'ATTENDANT'].contains(row['role']),
            ),
          ),
        )
        .toList();
  }

  Future<void> replaceAccess(String uid, List<TeamCompany> values) =>
      db.transaction((tx) async {
        await tx.delete('session', where: 'uid != ?', whereArgs: [uid]);
        await tx.insert('session', {
          'uid': uid,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        final existing = await tx.query(
          'companies',
          where: 'uid = ?',
          whereArgs: [uid],
        );
        for (final row in existing) {
          if (!values.any((company) => company.id == row['tenant'])) {
            await tx.delete(
              'companies',
              where: 'uid = ? AND tenant = ?',
              whereArgs: [uid, row['tenant']],
            );
          }
        }
        for (final company in values) {
          final fields = {
            'name': company.name,
            'record_number': company.recordNumber,
            'user_name': company.user.name,
            'delegated_manager': company.user.managementDelegated ? 1 : 0,
            'management_permissions': company.user.managementPermissions == null
                ? null
                : jsonEncode(company.user.managementPermissions),
            'role': company.user.role.apiValue,
            'roles_json': jsonEncode(
              company.user.availableRoles.map((r) => r.apiValue).toList(),
            ),
          };
          final updated = await tx.update(
            'companies',
            fields,
            where: 'uid = ? AND tenant = ?',
            whereArgs: [uid, company.id],
          );
          if (updated == 0) {
            await tx.insert('companies', {
              'uid': uid,
              'tenant': company.id,
              ...fields,
            });
          }
        }
      });

  Map<String, Object?> _row(String uid, String tenant, PetService service) => {
    'uid': uid,
    'tenant': tenant,
    'id': service.id,
    'record_number': service.recordNumber,
    'name': service.name,
    'description': service.description,
    'price_cents': (service.price * 100).round(),
    'duration': service.duration,
    'active': service.active ? 1 : 0,
  };

  Future<void> replaceCatalog(
    String uid,
    String tenant,
    List<PetService> services,
    DateTime time,
  ) => db.transaction((tx) async {
    // The full paginated response is committed in one transaction.
    await tx.delete(
      'services',
      where: 'uid = ? AND tenant = ?',
      whereArgs: [uid, tenant],
    );
    final batch = tx.batch();
    for (final service in services) {
      batch.insert('services', _row(uid, tenant, service));
    }
    await batch.commit(noResult: true);
    final count = await tx.update(
      'companies',
      {'updated_at': time.toUtc().toIso8601String()},
      where: 'uid = ? AND tenant = ?',
      whereArgs: [uid, tenant],
    );
    if (count != 1) {
      throw StateError('Empresa não autorizada para cópia local.');
    }
  });

  Future<void> saveConfirmed(
    String uid,
    String tenant,
    PetService service,
  ) => db.transaction((tx) async {
    await tx.insert(
      'services',
      _row(uid, tenant, service),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    // Keep the time of the last complete catalog refresh, not this single item.
  });

  Future<CachedCatalog?> catalog(String uid, String tenant) async {
    final companies = await db.query(
      'companies',
      columns: ['updated_at'],
      where: 'uid = ? AND tenant = ?',
      whereArgs: [uid, tenant],
    );
    if (companies.isEmpty || companies.first['updated_at'] == null) return null;
    final rows = await db.query(
      'services',
      where: 'uid = ? AND tenant = ?',
      whereArgs: [uid, tenant],
      orderBy: 'id',
    );
    return CachedCatalog(
      rows
          .map(
            (row) => PetService(
              id: row['id'] as String,
              recordNumber: readRecordNumber(row['record_number']),
              name: row['name'] as String,
              description: row['description'] as String,
              duration: row['duration'] as int,
              price: (row['price_cents'] as int) / 100,
              active: row['active'] == 1,
            ),
          )
          .toList(),
      DateTime.parse(companies.first['updated_at'] as String),
    );
  }
}
