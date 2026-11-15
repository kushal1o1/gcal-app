import 'package:flutter/material.dart';

import '../services/api.dart';
import '../services/outbox.dart';
import '../services/widget_sync.dart';
import '../widgets/gcal_logo.dart';

enum EventFilter { all, recurring, critical, normal }

extension on EventFilter {
  String get label => switch (this) {
        EventFilter.all => 'All',
        EventFilter.recurring => 'Recurring',
        EventFilter.critical => 'Critical',
        EventFilter.normal => 'Normal',
      };
}

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key, this.refreshTick});

  /// Bumped by the shell each time this tab is opened, so the list reloads
  /// (served from the session cache) instead of showing stale events.
  final ValueNotifier<int>? refreshTick;

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  static const _limitSteps = [20, 50, 100, 500];

  EventFilter _filter = EventFilter.all;
  List<GcalEvent> _events = const [];
  bool _loading = true;
  bool _busy = false;
  bool _hasMore = false;
  int _limit = 20;
  String? _error;
  List<ReminderDraft> _drafts = const [];
  bool _syncingDrafts = false;

  GcalApi get _api => GcalApi.fromStore();

  @override
  void initState() {
    super.initState();
    widget.refreshTick?.addListener(_onRefreshTick);
    _load();
    _loadDrafts();
  }

  @override
  void dispose() {
    widget.refreshTick?.removeListener(_onRefreshTick);
    super.dispose();
  }

  void _onRefreshTick() {
    if (!mounted) return;
    _load();
    _loadDrafts();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final EventsPage page;
      final api = _api;
      switch (_filter) {
        case EventFilter.all:
          page = await api.listEvents(limit: _limit);
        case EventFilter.recurring:
          page = await api.listEvents(recurringOnly: true, limit: _limit);
        case EventFilter.critical:
          page = await api.listEvents(criticalOnly: true, limit: _limit);
        case EventFilter.normal:
          page = await api.listEvents(normalOnly: true, limit: _limit);
      }
      if (!mounted) return;
      setState(() {
        _events = page.events;
        _hasMore = page.hasMore;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not reach the server. Check settings.';
        _loading = false;
      });
    }
  }

  void _selectFilter(EventFilter f) {
    if (f == _filter) return;
    setState(() {
      _filter = f;
      _limit = 20;
      _hasMore = false;
    });
    _load();
  }

  Future<void> _loadMore() async {
    if (_busy || !_hasMore) return;
    final next = _limitSteps.firstWhere((s) => s > _limit, orElse: () => _limit);
    if (next == _limit) return;
    setState(() => _limit = next);
    await _load();
  }

  Future<void> _onEventTap(GcalEvent event) async {
    if (_busy) return;
    final isMasterList = _filter == EventFilter.recurring;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => _EventSheet(event: event, isMasterList: isMasterList),
    );
    if (!mounted || action == null) return;

    if (action.startsWith('profile:')) {
      final profile = action.substring(8);
      final reminders = profile == 'critical'
          ? _profileCritical()
          : _profileNormal();
      await _perform(
        () => _api.editReminders(id: event.id, reminders: reminders),
        'Reminders updated.',
      );
      return;
    }
    switch (action) {
      case 'single':
        await _perform(
          () => _api.deleteEvent(id: event.id),
          'Deleted "${event.summary}".',
        );
      case 'one':
        await _perform(
          () => _api.deleteEvent(id: event.id),
          'Deleted the next occurrence.',
        );
      case 'series':
        await _perform(
          () => _api.deleteEvent(id: event.masterId, deleteSeries: true),
          'Deleted the entire series.',
        );
    }
  }

  Future<void> _perform(
      Future<void> Function() op, String successMessage) async {
    setState(() => _busy = true);
    try {
      await op();
      syncUpcomingWidget();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(successMessage),
        behavior: SnackBarBehavior.floating,
      ));
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.message),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Delete failed. Check server.'),
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _bulkDelete(String kind) async {
    final label = kind == 'recurring' ? 'recurring' : 'critical';
    final body = kind == 'recurring'
        ? 'This deletes every recurring series (all occurrences). '
        : 'This deletes every critical event (series deleted once, singles by id). ';
    final ok = await _confirm(
      'Delete all $label events',
      '$body Continue?',
    );
    if (!ok) return;

    setState(() => _busy = true);
    try {
      final result = await _api.bulkDelete(kind);
      syncUpcomingWidget();
      if (!mounted) return;
      final extra = result.failed > 0 ? ' (${result.failed} failed)' : '';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Deleted ${result.deleted} $label events$extra'),
        behavior: SnackBarBehavior.floating,
      ));
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.message),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Bulk delete failed. Check server.'),
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String body) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _loadDrafts() async {
    final drafts = await DraftOutbox.instance.load();
    if (mounted) setState(() => _drafts = drafts);
  }

  Future<void> _refreshAll() async {
    await _loadDrafts();
    await _load();
  }

  Future<void> _discardDraft(ReminderDraft draft) async {
    await DraftOutbox.instance.remove(draft.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Draft discarded.'),
      behavior: SnackBarBehavior.floating,
    ));
    await _loadDrafts();
  }

  Future<void> _syncDrafts() async {
    if (_syncingDrafts) return;
    setState(() => _syncingDrafts = true);
    try {
      final synced = await DraftOutbox.instance.flush(_api);
      syncUpcomingWidget();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          synced > 0
              ? (synced == 1 ? 'Synced 1 draft.' : 'Synced $synced drafts.')
              : 'Nothing synced yet — check the server.',
        ),
        behavior: SnackBarBehavior.floating,
      ));
      await _loadDrafts();
      await _load();
    } finally {
      if (mounted) setState(() => _syncingDrafts = false);
    }
  }

  Widget _buildDraftHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            'drafts (${_drafts.length})',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.secondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _syncingDrafts ? null : _syncDrafts,
            icon: _syncingDrafts
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync, size: 18),
            label: const Text('sync now'),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftTile(ThemeData theme, ReminderDraft draft) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      draft.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _queuedAtText(draft.queuedAt),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Discard draft',
                onPressed: _busy ? null : () => _discardDraft(draft),
                icon: const Icon(Icons.close, size: 20),
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _queuedAtText(DateTime t) {
    final local = t.toLocal();
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final m = '${local.minute}'.padLeft(2, '0');
    final am = local.hour < 12 ? 'AM' : 'PM';
    return 'queued $h:$m $am';
  }

  static List<GcalReminder> _profileNormal() =>
      [GcalReminder(method: 'popup', minutes: 0)];

  static List<GcalReminder> _profileCritical() => [
        GcalReminder(method: 'email', minutes: 24 * 60),
        GcalReminder(method: 'popup', minutes: 60),
        GcalReminder(method: 'email', minutes: 0),
        GcalReminder(method: 'popup', minutes: 0),
      ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 8, 4),
            child: Row(
              children: [
                Text(
                  'events',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 10),
                Text(
                  '(${_events.length})',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  tooltip: 'More',
                  icon: Icon(Icons.more_horiz, color: theme.colorScheme.onSurfaceVariant),
                  onSelected: (value) {
                    if (value == 'recurring') _bulkDelete('recurring');
                    if (value == 'critical') _bulkDelete('critical');
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'recurring',
                      child: Text('Delete all recurring…'),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'critical',
                      child: Text('Delete all critical…'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final f in EventFilter.values) ...[
                    ChoiceChip(
                      label: Text(f.label),
                      selected: _filter == f,
                      showCheckmark: false,
                      onSelected: (_) => _selectFilter(f),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
          Expanded(child: _buildBody(theme)),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_drafts.isNotEmpty) {
      return RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          children: [
            _buildDraftHeader(theme),
            for (final d in _drafts) _buildDraftTile(theme, d),
            const SizedBox(height: 12),
            _eventSection(theme),
          ],
        ),
      );
    }
    if (_loading && _events.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: _ErrorBlock(message: _error!, onRetry: _load),
      );
    }
    if (_events.isEmpty) {
      return Center(
        child: _EmptyBlock(label: _filter.label.toLowerCase()),
      );
    }
    final showLoadMore = _hasMore && _limit < 500;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        itemCount: _events.length + (showLoadMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == _events.length) {
            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Center(
                child: FilledButton.tonalIcon(
                  onPressed: _busy ? null : _loadMore,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.expand_more),
                  label: const Text('Load more'),
                ),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _EventTile(event: _events[i], onTap: _onEventTap),
          );
        },
      ),
    );
  }

  Widget _eventSection(ThemeData theme) {
    if (_loading && _events.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(0, 48, 0, 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return _ErrorBlock(message: _error!, onRetry: _load);
    }
    if (_events.isEmpty) {
      return _EmptyBlock(label: _filter.label.toLowerCase());
    }
    final showLoadMore = _hasMore && _limit < 500;
    return Column(
      children: [
        for (var i = 0; i < _events.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _EventTile(event: _events[i], onTap: _onEventTap),
          ),
        if (showLoadMore)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Center(
              child: FilledButton.tonalIcon(
                onPressed: _busy ? null : _loadMore,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more),
                label: const Text('Load more'),
              ),
            ),
          ),
      ],
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            style: TextStyle(color: theme.colorScheme.error),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const GcalLogo(size: 56),
          const SizedBox(height: 20),
          Text(
            '~ no $label events',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'say a reminder on Home.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event, required this.onTap});

  final GcalEvent event;
  final ValueChanged<GcalEvent> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCritical = event.critical;
    final typeLabel = isCritical
        ? 'Critical'
        : event.recurring
            ? 'Recurring'
            : 'Normal';

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onTap(event),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _timeOf(event),
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    if (event.recurrenceDisplay.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          event.recurrenceDisplay,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _Badge(
                label: typeLabel,
                critical: isCritical,
                recurring: event.recurring,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.critical, required this.recurring});

  final String label;
  final bool critical;
  final bool recurring;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color bg;
    final Color fg;
    if (critical) {
      bg = theme.colorScheme.secondary.withValues(alpha: 0.14);
      fg = theme.colorScheme.secondary;
    } else if (recurring) {
      bg = theme.colorScheme.primary.withValues(alpha: 0.14);
      fg = theme.colorScheme.primary;
    } else {
      bg = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6);
      fg = theme.colorScheme.onSurfaceVariant;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EventSheet extends StatefulWidget {
  const _EventSheet({required this.event, required this.isMasterList});

  final GcalEvent event;
  final bool isMasterList;

  @override
  State<_EventSheet> createState() => _EventSheetState();
}

class _EventSheetState extends State<_EventSheet> {
  late String _profile = widget.event.critical ? 'critical' : 'normal';
  bool _deleteMode = false;
  String? _deleteChoice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final event = widget.event;
    final original = event.critical ? 'critical' : 'normal';
    final scope = !event.recurring
        ? 'this event'
        : widget.isMasterList
            ? 'whole series'
            : 'this occurrence';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '${_timeOf(event)} · $scope',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Text(
              'reminder profile',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            RadioGroup<String>(
              groupValue: _profile,
              onChanged: (v) => setState(() => _profile = v!),
              child: Column(
                children: [
                  RadioListTile<String>(
                    value: 'normal',
                    title: const Text('Normal'),
                    subtitle: const Text('popup at time'),
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                  RadioListTile<String>(
                    value: 'critical',
                    title: const Text('Critical'),
                    subtitle: const Text('email 1d · popup 1h · at time'),
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            if (_profile != original) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop('profile:$_profile'),
                  child: const Text('Save'),
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 8),
            if (!_deleteMode)
              TextButton.icon(
                onPressed: () => setState(() {
                  _deleteMode = true;
                  _deleteChoice = null;
                }),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.secondary,
                ),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete'),
              )
            else ...[
              Text(
                'what to delete?',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              RadioGroup<String>(
                groupValue: _deleteChoice,
                onChanged: (v) => setState(() => _deleteChoice = v),
                child: Column(
                  children: [
                    if (event.recurring)
                      RadioListTile<String>(
                        value: 'one',
                        title: const Text('Just this occurrence'),
                        subtitle: const Text('only the next upcoming one'),
                        contentPadding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    if (event.recurring)
                      RadioListTile<String>(
                        value: 'series',
                        title: const Text('Whole series'),
                        subtitle: const Text('all future occurrences'),
                        contentPadding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    if (!event.recurring)
                      RadioListTile<String>(
                        value: 'single',
                        title: const Text('Delete this event'),
                        contentPadding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _deleteChoice == null
                      ? null
                      : () => Navigator.of(context).pop(_deleteChoice),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.secondary,
                    foregroundColor: theme.colorScheme.onSecondary,
                  ),
                  child: const Text('Delete'),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _deleteMode = false),
                child: const Text('Cancel'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _timeOf(GcalEvent event) =>
    event.time.isNotEmpty ? event.time : event.startsAt;