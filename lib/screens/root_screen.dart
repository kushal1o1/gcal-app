import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api.dart';
import '../services/connection.dart';
import '../services/mic_controller.dart';
import '../services/outbox.dart';
import '../services/widget_sync.dart';
import 'events_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

/// App shell in the landing's layout: tabs are Events / Home / Settings, but
/// there is no stock navigation bar. Instead a floating rounded "pill" bar
/// holds an events icon (left) and a settings icon (right) with the mic
/// raised above the pill's center. Home is always the mic tab.
class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  final MicController _mic = MicController();
  final ValueNotifier<int> _eventsTick = ValueNotifier(0);
  final ConnectionWatch _connection = ConnectionWatch();

  Timer? _flushTimer;
  int _index = 1;

  @override
  void initState() {
    super.initState();
    _mic.init();
    syncUpcomingWidget();
    _connection.addListener(_onConnectionChanged);
    _flushTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _flushDrafts(),
    );
  }

  @override
  void dispose() {
    _flushTimer?.cancel();
    _connection.removeListener(_onConnectionChanged);
    _connection.dispose();
    _mic.dispose();
    _eventsTick.dispose();
    super.dispose();
  }

  void _onConnectionChanged() {
    if (_connection.online) _flushDrafts();
  }

  Future<void> _flushDrafts() async {
    if (!_connection.online) return;
    final drafts = await DraftOutbox.instance.load();
    if (drafts.isEmpty) return;
    final synced = await DraftOutbox.instance.flush(GcalApi.fromStore());
    if (synced <= 0 || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        synced == 1
            ? 'Synced 1 draft to your calendar.'
            : 'Synced $synced drafts to your calendar.',
      ),
      behavior: SnackBarBehavior.floating,
    ));
    _eventsTick.value++;
    syncUpcomingWidget();
  }

  void _goto(int i) {
    if (_index == i) return;
    setState(() => _index = i);
    if (i == 0) _eventsTick.value++;
  }

  Future<void> _onMicPressed() async {
    if (!_mic.available) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Speech recognition is not available here.'),
      ));
      return;
    }
    if (_index != 1) setState(() => _index = 1);
    if (_mic.listening) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.mediumImpact();
    }
    await _mic.toggle();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          EventsScreen(refreshTick: _eventsTick),
          HomeScreen(mic: _mic),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 6),
          child: SizedBox(
            height: 100,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
              Container(
                height: 58,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(29),
                  border: Border.all(color: theme.colorScheme.outline),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _PillIcon(
                        tooltip: 'Events',
                        selected: _index == 0,
                        icon: _index == 0
                            ? Icons.event_note
                            : Icons.event_note_outlined,
                        onTap: () => _goto(0),
                      ),
                    ),
                    const SizedBox(width: 64),
                    Expanded(
                      child: _PillIcon(
                        tooltip: 'Settings',
                        selected: _index == 2,
                        icon: _index == 2
                            ? Icons.settings
                            : Icons.settings_outlined,
                        onTap: () => _goto(2),
                      ),
                    ),
                  ],
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -37),
                child: AnimatedBuilder(
                  animation: _mic,
                  builder: (context, _) => _MicButton(
                    active: _mic.listening,
                    onTap: _onMicPressed,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _PillIcon extends StatelessWidget {
  const _PillIcon({
    required this.tooltip,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      iconSize: 22,
      icon: Icon(
        icon,
        color: selected
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = active ? theme.colorScheme.secondary : theme.colorScheme.primary;
    final icon = active
        ? theme.colorScheme.onSecondary
        : theme.colorScheme.onPrimary;
    return InkResponse(
      onTap: onTap,
      radius: 44,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack,
        scale: active ? 1.08 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: active ? 66 : 62,
          height: active ? 66 : 62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: active ? 26 : 14,
                spreadRadius: active ? 4 : 1,
              ),
            ],
          ),
          child: Icon(
            active ? Icons.graphic_eq : Icons.mic,
            color: icon,
            size: 30,
          ),
        ),
      ),
    );
  }
}