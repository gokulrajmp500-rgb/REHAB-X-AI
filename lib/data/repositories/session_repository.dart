import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/pose_models.dart';

abstract interface class SessionRepository {
  Future<List<SessionRecord>> readAll(String athleteId);
  Future<SessionRecord?> read(String id);
  Future<void> create(SessionRecord session);
  Future<void> update(SessionRecord session);
  Future<void> delete(String id);
  Future<void> clear(String athleteId);
}

class LocalSessionRepository implements SessionRepository {
  LocalSessionRepository(this.preferences);
  final SharedPreferences preferences;
  static const _key = 'movement_sessions';
  static const _schemaKey = 'local_data_schema_version';
  static const schemaVersion = 1;

  @override
  Future<List<SessionRecord>> readAll(String athleteId) async => _read().where((session) => session.athleteId == athleteId).toList()
    ..sort((first, second) => second.timestamp.compareTo(first.timestamp));

  @override
  Future<SessionRecord?> read(String id) async {
    for (final session in _read()) {
      if (session.id == id) return session;
    }
    return null;
  }

  @override
  Future<void> create(SessionRecord session) async {
    final sessions = _read()..removeWhere((item) => item.id == session.id)..add(session);
    await _write(sessions);
  }

  @override
  Future<void> update(SessionRecord session) => create(session);

  @override
  Future<void> delete(String id) async {
    final sessions = _read()..removeWhere((session) => session.id == id);
    await _write(sessions);
  }

  @override
  Future<void> clear(String athleteId) async {
    final sessions = _read()..removeWhere((session) => session.athleteId == athleteId);
    await _write(sessions);
  }

  List<SessionRecord> _read() {
    if ((preferences.getInt(_schemaKey) ?? 0) < schemaVersion) preferences.setInt(_schemaKey, schemaVersion);
    final raw = preferences.getString(_key);
    if (raw == null) return [];
    try {
      final values = jsonDecode(raw) as List<dynamic>;
      return values.map((value) => SessionRecord.fromJson(Map<String, Object?>.from(value as Map))).where((session) => session.id.isNotEmpty && session.exercise.isNotEmpty).toList();
    } on Object {
      return [];
    }
  }

  Future<void> _write(List<SessionRecord> sessions) => preferences.setString(_key, jsonEncode(sessions.map((session) => session.toJson()).toList()));
}