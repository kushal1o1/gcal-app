import 'dart:convert';

import 'package:http/http.dart' as http;

import 'settings_store.dart';

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  @override
  String toString() => message;
}

class ReminderResult {
  ReminderResult({
    required this.summary,
    required this.startsAt,
    required this.startsAtIso,
    required this.critical,
    required this.recurring,
    this.eventId,
    this.created = false,
  });

  factory ReminderResult.fromJson(Map<String, dynamic> json) {
    return ReminderResult(
      summary: (json['summary'] ?? '').toString(),
      startsAt: (json['starts_at'] ?? '').toString(),
      startsAtIso: (json['starts_at_iso'] ?? '').toString(),
      critical: json['critical'] == true,
      recurring: json['recurring'] == true,
      eventId: json['event_id']?.toString(),
      created: json['created'] == true,
    );
  }

  final String summary;
  final String startsAt;
  final String startsAtIso;
  final bool critical;
  final bool recurring;
  final String? eventId;
  final bool created;
}

class GcalReminder {
  GcalReminder({required this.method, required this.minutes});

  factory GcalReminder.fromJson(Map<String, dynamic> json) {
    return GcalReminder(
      method: (json['method'] ?? '').toString(),
      minutes: (json['minutes'] is num) ? (json['minutes'] as num).toInt() : 0,
    );
  }

  final String method;
  final int minutes;
}

class GcalEvent {
  GcalEvent({
    required this.id,
    required this.masterId,
    required this.summary,
    required this.critical,
    required this.recurring,
    this.startsAt = '',
    this.startsAtIso = '',
    this.time = '',
    this.recurrenceDisplay = '',
    this.reminders = const [],
  });

  factory GcalEvent.fromJson(Map<String, dynamic> json) {
    final rawReminders = json['reminders'];
    return GcalEvent(
      id: (json['id'] ?? '').toString(),
      masterId: (json['master_id'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      critical: json['critical'] == true,
      recurring: json['recurring'] == true,
      startsAt: (json['starts_at'] ?? '').toString(),
      startsAtIso: (json['starts_at_iso'] ?? '').toString(),
      time: (json['time'] ?? '').toString(),
      recurrenceDisplay: (json['recurrence_display'] ?? '').toString(),
      reminders: rawReminders is List
          ? rawReminders
              .whereType<Map<String, dynamic>>()
              .map(GcalReminder.fromJson)
              .toList()
          : const [],
    );
  }

  final String id;
  final String masterId;
  final String summary;
  final bool critical;
  final bool recurring;
  final String startsAt;
  final String startsAtIso;
  final String time;
  final String recurrenceDisplay;
  final List<GcalReminder> reminders;
}

class EventsPage {
  EventsPage({required this.events, required this.hasMore});

  final List<GcalEvent> events;
  final bool hasMore;
}

class BulkDeleteResult {
  BulkDeleteResult({required this.deleted, required this.failed});

  final int deleted;
  final int failed;
}

class _ListCacheEntry {
  _ListCacheEntry(this.events, this.hasMore, this.expiresAt);

  final List<GcalEvent> events;
  final bool hasMore;
  final DateTime expiresAt;
}

class GcalApi {
  GcalApi({required this.baseUrl, required this.token})
      : _client = http.Client();

  /// Session-scoped list cache so tab switches / refreshes feel instant.
  /// Shared across instances (they are created on demand via [fromStore])
  /// and invalidated by every mutation.
  static final Map<String, _ListCacheEntry> _listCache = {};
  static const Duration _listCacheTtl = Duration(seconds: 12);

  factory GcalApi.fromStore() =>
      GcalApi(baseUrl: SettingsStore.instance.baseUrl, token: SettingsStore.instance.token);

  final String baseUrl;
  final String token;
  final http.Client _client;

  Uri _uri(String path) =>
      Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}$path');

  String _listKey(int limit, bool recurringOnly, bool criticalOnly, bool normalOnly) =>
      '$baseUrl|$limit|$recurringOnly|$criticalOnly|$normalOnly';

  static void _invalidateListCache() => _listCache.clear();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  /// Unwraps the `{success, message, data}` envelope: returns `data` on
  /// success, throws [ApiException] with the server's `message` otherwise.
  Map<String, dynamic> decodeResponse(http.Response response) {
    Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      decoded = null;
    }

    if (decoded is! Map<String, dynamic>) {
      throw ApiException(
        response.statusCode,
        'Server responded with HTTP ${response.statusCode}',
      );
    }

    final success = decoded['success'] == true;
    final message = (decoded['message'] ?? 'Unexpected server response').toString();
    if (!success || response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, message);
    }

    final data = decoded['data'];
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<ReminderResult> remind(String text, {bool create = false}) async {
    final response = await _client
        .post(
          _uri('/api/remind'),
          headers: _headers,
          body: jsonEncode({'text': text, 'create': create}),
        )
        .timeout(const Duration(seconds: 60));

    final result = ReminderResult.fromJson(decodeResponse(response));
    if (result.created) _invalidateListCache();
    return result;
  }

  Future<EventsPage> listEvents({
    int limit = 20,
    bool recurringOnly = false,
    bool criticalOnly = false,
    bool normalOnly = false,
  }) async {
    final key = _listKey(limit, recurringOnly, criticalOnly, normalOnly);
    final cached = _listCache[key];
    final now = DateTime.now();
    if (cached != null && cached.expiresAt.isAfter(now)) {
      return EventsPage(events: cached.events, hasMore: cached.hasMore);
    }
    _listCache.remove(key);

    final response = await _client
        .get(
          _uri('/api/events').replace(
            queryParameters: {
              'limit': '$limit',
              if (recurringOnly) 'recurring_only': '1',
              if (criticalOnly) 'critical_only': '1',
              if (normalOnly) 'normal_only': '1',
            },
          ),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 30));

    final data = decodeResponse(response);
    final raw = data['events'];
    final events = raw is List
        ? raw
            .whereType<Map<String, dynamic>>()
            .map(GcalEvent.fromJson)
            .toList()
        : const <GcalEvent>[];
    final page = EventsPage(events: events, hasMore: data['has_more'] == true);
    _listCache[key] =
        _ListCacheEntry(events, page.hasMore, now.add(_listCacheTtl));
    return page;
  }

  Future<void> deleteEvent({required String id, bool deleteSeries = false}) async {
    _invalidateListCache();
    final response = await _client
        .post(
          _uri('/api/events/delete'),
          headers: _headers,
          body: jsonEncode({'id': id, 'delete_series': deleteSeries}),
        )
        .timeout(const Duration(seconds: 30));

    decodeResponse(response);
  }

  Future<void> editReminders({
    required String id,
    required List<GcalReminder> reminders,
    bool useDefault = false,
  }) async {
    _invalidateListCache();
    final response = await _client
        .post(
          _uri('/api/events/edit'),
          headers: _headers,
          body: jsonEncode({
            'id': id,
            'use_default': useDefault,
            'reminders': reminders
                .map((r) => {'method': r.method, 'minutes': r.minutes})
                .toList(),
          }),
        )
        .timeout(const Duration(seconds: 30));

    decodeResponse(response);
  }

  Future<BulkDeleteResult> bulkDelete(String kind) async {
    _invalidateListCache();
    final response = await _client
        .post(
          _uri('/api/events/bulk-delete'),
          headers: _headers,
          body: jsonEncode({'kind': kind}),
        )
        .timeout(const Duration(seconds: 60));

    final data = decodeResponse(response);
    return BulkDeleteResult(
      deleted: (data['deleted'] is num) ? (data['deleted'] as num).toInt() : 0,
      failed: (data['failed'] is num) ? (data['failed'] as num).toInt() : 0,
    );
  }
}