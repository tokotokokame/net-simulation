// lib/storage/topology_storage.dart
import 'dart:convert';
import 'dart:developer';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/topology.dart';
import '../models/device.dart';
import '../models/link.dart';
import 'demo_topologies.dart';

class TopologyMeta {
  final String id, name;
  final int deviceCount;
  final DateTime createdAt;
  const TopologyMeta({required this.id, required this.name,
      required this.deviceCount, required this.createdAt});
}

class TopologyStorage {
  Database? _db;

  Future<Database> _open() async {
    if (_db != null) return _db!;
    final dbPath = p.join(await getDatabasesPath(), 'net_sim_v4.db');
    _db = await openDatabase(dbPath, version: 1, onCreate: (db, _) => db.execute('''
      CREATE TABLE topologies (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        data TEXT NOT NULL,
        deviceCount INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )'''));
    return _db!;
  }

  Future<void> saveTopology(Topology t) async {
    final db = await _open();
    final data = jsonEncode({
      'devices': t.devices.map((d) => d.toJson()).toList(),
      'links': t.links.map((l) => l.toJson()).toList(),
    });
    await db.insert('topologies', {
      'id': t.id, 'name': t.name, 'data': data,
      'deviceCount': t.devices.length,
      'createdAt': t.createdAt.toIso8601String(),
      'updatedAt': t.updatedAt.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    log('Saved topology: ${t.id} (${t.devices.length} devices)', name: 'Storage');
  }

  Future<Topology?> loadTopology(String id) async {
    final db = await _open();
    final rows = await db.query('topologies', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  Future<List<TopologyMeta>> listTopologies() async {
    final db = await _open();
    final rows = await db.query('topologies',
        columns: ['id', 'name', 'deviceCount', 'createdAt'],
        orderBy: 'updatedAt DESC');
    return rows.map((r) => TopologyMeta(
      id: r['id'] as String,
      name: r['name'] as String,
      deviceCount: r['deviceCount'] as int,
      createdAt: DateTime.parse(r['createdAt'] as String),
    )).toList();
  }

  Future<void> deleteTopology(String id) async {
    final db = await _open();
    await db.delete('topologies', where: 'id = ?', whereArgs: [id]);
    log('Deleted topology: $id', name: 'Storage');
  }

  /// Seeds the five demo topologies on first launch.
  /// Safe to call multiple times — skips any demo already present.
  Future<void> seedDemoTopologiesIfNeeded() async {
    final db = await _open();
    for (final topo in allDemoTopologies) {
      final rows = await db.query('topologies',
          columns: ['id'], where: 'id = ?', whereArgs: [topo.id]);
      if (rows.isEmpty) {
        await saveTopology(topo);
        log('Seeded demo topology: ${topo.name}', name: 'Storage');
      }
    }
  }

  Topology _fromRow(Map<String, dynamic> row) {
    final map = jsonDecode(row['data'] as String) as Map<String, dynamic>;
    return Topology(
      id: row['id'] as String,
      name: row['name'] as String,
      devices: (map['devices'] as List).map((d) => Device.fromJson(d as Map<String, dynamic>)).toList(),
      links: (map['links'] as List).map((l) => Link.fromJson(l as Map<String, dynamic>)).toList(),
      createdAt: DateTime.parse(row['createdAt'] as String),
      updatedAt: DateTime.parse(row['updatedAt'] as String),
    );
  }
}

final topologyStorageProvider = Provider<TopologyStorage>((_) => TopologyStorage());
