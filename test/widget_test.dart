import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:gcal_app/services/api.dart';

void main() {
  test('ReminderResult parses a create payload', () {
    final result = ReminderResult.fromJson({
      'summary': 'service my bike',
      'starts_at': '2026-11-08 9:00 AM',
      'starts_at_iso': '2026-11-08T09:00:00+05:45',
      'critical': false,
      'recurring': false,
      'amount': 45,
      'unit': 'D',
      'event_id': 'abc123',
      'created': true,
    });

    expect(result.summary, 'service my bike');
    expect(result.startsAt, '2026-11-08 9:00 AM');
    expect(result.recurring, isFalse);
    expect(result.eventId, 'abc123');
    expect(result.created, isTrue);
  });

  test('GcalEvent parses list payload', () {
    final event = GcalEvent.fromJson({
      'id': 'inst1',
      'master_id': 'master1',
      'summary': 'pay rent',
      'critical': true,
      'recurring': true,
      'starts_at': '2026-09-25 8:30 PM',
      'starts_at_iso': '2026-09-25T20:30:00+05:45',
      'time': '8:30 PM, 25-Sep',
      'recurrence_display': 'Every 1 month',
    });

    expect(event.id, 'inst1');
    expect(event.masterId, 'master1');
    expect(event.critical, isTrue);
    expect(event.recurring, isTrue);
    expect(event.time, '8:30 PM, 25-Sep');
    expect(event.recurrenceDisplay, 'Every 1 month');
  });

  test('GcalEvent parses reminders and has_more unwraps into EventsPage', () {
    final event = GcalEvent.fromJson({
      'id': 'inst2',
      'master_id': 'master2',
      'summary': 'ocean eyes',
      'critical': true,
      'recurring': true,
      'time': '8:00 PM, 26-Sep',
      'recurrence_display': 'Every 40 days',
      'reminders': [
        {'method': 'email', 'minutes': 1440},
        {'method': 'popup', 'minutes': 60},
        {'method': 'email', 'minutes': 0},
        {'method': 'popup', 'minutes': 0},
      ],
    });

    expect(event.critical, isTrue);
    expect(event.reminders, hasLength(4));
    expect(event.reminders.first.method, 'email');
    expect(event.reminders.first.minutes, 1440);

    final api = GcalApi(baseUrl: 'http://x', token: 't');
    final resp = http.Response(
      jsonEncode({
        'success': true,
        'message': '4 events found',
        'data': {
          'count': 4,
          'has_more': true,
          'events': [event.id],
        },
      }),
      200,
    );
    final data = api.decodeResponse(resp)['events'];
    expect(data, isA<List>());
  });

  test('decodeResponse unwraps the success envelope', () {
    final api = GcalApi(baseUrl: 'http://x', token: 't');
    final resp = http.Response(
      jsonEncode({
        'success': true,
        'message': '5 events found',
        'data': {'count': 1, 'events': []},
      }),
      200,
    );

    final data = api.decodeResponse(resp);
    expect(data['count'], 1);
  });

  test('decodeResponse surfaces message on failure', () {
    final api = GcalApi(baseUrl: 'http://x', token: 't');
    final resp = http.Response(
      jsonEncode({'success': false, 'message': 'unauthorized', 'data': null}),
      401,
    );

    expect(
      () => api.decodeResponse(resp),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'statusCode', 401)
          .having((e) => e.message, 'message', 'unauthorized')),
    );
  });
}