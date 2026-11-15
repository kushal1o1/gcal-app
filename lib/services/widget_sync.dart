import 'dart:convert';

import 'package:home_widget/home_widget.dart';

import 'api.dart';

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String widgetTimeLabel(String isoOrRaw) {
  final dt = DateTime.tryParse(isoOrRaw);
  if (dt == null || isoOrRaw.trim().isEmpty) return isoOrRaw.trim();
  final t = dt.toLocal();
  final h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final minute = t.minute.toString().padLeft(2, '0');
  final ap = t.hour < 12 ? 'AM' : 'PM';
  return '${_months[t.month - 1]} ${t.day} · $h12:$minute $ap';
}

/// Pushes the next 3 upcoming events (title + human "Nov 8 · 9:00 AM" time)
/// to the home-screen widget. Fire-and-forget: widget sync must never break
/// an app flow, so every failure is swallowed.
Future<void> syncUpcomingWidget() async {
  try {
    final page = await GcalApi.fromStore().listEvents(limit: 3);
    final items = page.events.take(3).map((e) {
      final iso = e.startsAtIso.isNotEmpty ? e.startsAtIso : e.startsAt;
      return {'title': e.summary, 'time': widgetTimeLabel(iso)};
    }).toList();
    await HomeWidget.saveWidgetData<String>('events_json', jsonEncode(items));
    await HomeWidget.updateWidget(name: 'HomeWidgetReceiver');
  } catch (_) {
    // Best-effort sync; ignore failures.
  }
}