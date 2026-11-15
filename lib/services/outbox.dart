import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

class ReminderDraft {
  const ReminderDraft({
    required this.id,
    required this.text,
    required this.queuedAt,
  });

  factory ReminderDraft.fromJson(Map<String, dynamic> json) => ReminderDraft(
        id: (json['id'] as num?)?.toInt() ?? 0,
        text: (json['text'] ?? '').toString(),
        queuedAt:
            DateTime.tryParse((json['queued_at'] ?? '').toString()) ?? DateTime.now(),
      );

  final int id;
  final String text;
  final DateTime queuedAt;

  Map<String, dynamic> toJson() =>
      {'id': id, 'text': text, 'queued_at': queuedAt.toIso8601String()};
}

class DraftOutbox {
  DraftOutbox._();
  static final DraftOutbox instance = DraftOutbox._();

  static const _prefsKey = 'reminder_drafts_v1';
  static const maxDrafts = 50;
  static const _flushTimeout = Duration(seconds: 15);

  List<ReminderDraft> _cache = const [];

  List<ReminderDraft> get pending => _cache;

  Future<List<ReminderDraft>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) {
      _cache = const [];
      return _cache;
    }
    try {
      final decoded = jsonDecode(raw);
      _cache = decoded is List
          ? decoded
              .whereType<Map<String, dynamic>>()
              .map(ReminderDraft.fromJson)
              .toList()
          : const [];
    } catch (_) {
      _cache = const [];
    }
    return _cache;
  }

  Future<ReminderDraft> add(String text) async {
    await load();
    final id = _cache.isEmpty
        ? 1
        : _cache.map((d) => d.id).reduce((a, b) => a > b ? a : b) + 1;
    final draft = ReminderDraft(id: id, text: text, queuedAt: DateTime.now());
    _cache = [..._cache, draft];
    if (_cache.length > maxDrafts) {
      _cache = _cache.sublist(_cache.length - maxDrafts);
    }
    await _save();
    return draft;
  }

  Future<void> remove(int id) async {
    await load();
    _cache = _cache.where((d) => d.id != id).toList();
    await _save();
  }

  Future<int> flush(GcalApi api) async {
    await load();
    var synced = 0;
    var i = 0;
    while (i < _cache.length) {
      final draft = _cache[i];
      try {
        await api.remind(draft.text, create: true).timeout(_flushTimeout);
        synced++;
      } catch (e) {
        if (e is! ApiException) break;
      }
      i++;
    }
    if (i > 0) _cache = _cache.sublist(i);
    await _save();
    return synced;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(_cache.map((d) => d.toJson()).toList()),
    );
  }
}