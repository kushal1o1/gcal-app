import 'package:flutter/material.dart';

import '../services/api.dart';
import '../services/mic_controller.dart';
import '../services/outbox.dart';
import '../services/settings_store.dart';
import '../services/widget_sync.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.mic});

  final MicController mic;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _edit = TextEditingController();

  bool _busy = false;
  bool _offline = false;
  String _error = '';
  ReminderResult? _preview;

  @override
  void initState() {
    super.initState();
    widget.mic.addListener(_mirrorMic);
  }

  @override
  void dispose() {
    widget.mic.removeListener(_mirrorMic);
    _edit.dispose();
    super.dispose();
  }

  void _mirrorMic() {
    if (!mounted) return;
    final t = widget.mic.text;
    if (_edit.text == t) return;
    _edit.value = TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: t.length),
    );
  }

  void _onTyped(String value) => widget.mic.setText(value);

  Future<void> _previewReminder() async {
    final text = _edit.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final result = await GcalApi.fromStore().remind(text);
      if (!mounted) return;
      setState(() => _preview = result);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() {
        _offline = true;
        _error = '';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _queueDraft() async {
    final text = _edit.text.trim();
    if (text.isEmpty) return;
    await DraftOutbox.instance.add(text);
    if (!mounted) return;
    final pending = DraftOutbox.instance.pending.length;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        pending == 1
            ? 'Offline — saved as draft, will sync when online.'
            : 'Offline — saved as draft ($pending pending), will sync when online.',
      ),
      behavior: SnackBarBehavior.floating,
    ));
    setState(() {
      _offline = false;
      _preview = null;
      _edit.clear();
    });
    widget.mic.setText('');
  }

  Future<void> _createReminder() async {
    final text = _edit.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final result = await GcalApi.fromStore().remind(text, create: true);
      await syncUpcomingWidget();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Created: ${result.summary} (${result.startsAt})'),
        behavior: SnackBarBehavior.floating,
      ));
      setState(() {
        _preview = null;
        _edit.clear();
      });
      widget.mic.setText('');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      await _queueDraft();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _directFlow =>
      SettingsStore.instance.createFlow == SettingsStore.createFlowDirect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = _preview;

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _AsciiArt(),
                const SizedBox(height: 28),
                TextField(
                  controller: _edit,
                  minLines: 1,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: _onTyped,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 17,
                    fontFamily: 'monospace',
                  ),
                  decoration: const InputDecoration(hintText: 'type it or say it…'),
                ),
                const SizedBox(height: 8),
                AnimatedBuilder(
                  animation: widget.mic,
                  builder: (context, _) => Text(
                    widget.mic.listening ? 'listening…' : ' ',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.secondary),
                  ),
                ),
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
                if (_offline) ...[
                  const SizedBox(height: 12),
                  _OfflineCard(onSave: _busy ? null : _queueDraft),
                ],
                if (preview != null && !_directFlow) ...[
                  const SizedBox(height: 16),
                  _ConfirmCard(
                    preview: preview,
                    onCreate: _busy ? null : _createReminder,
                    onCancel: _busy ? null : () => setState(() => _preview = null),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy
                        ? null
                        : (_directFlow ? _createReminder : _previewReminder),
                    child: Text(
                      _busy
                          ? 'Working...'
                          : (_directFlow ? 'OK' : 'Remind'),
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

const List<String> _asciiLines = [
  ' ███   ███   ███  █    ',
  '█   █ █   █ █   █ █    ',
  '█     █     █   █ █    ',
  '█ ██  █     █████ █    ',
  '█   █ █     █   █ █    ',
  '█   █ █   █ █   █ █    ',
  ' ███   ███  █   █ █████',
];

/// The landing page's GCAL block, mono blue with a soft glow and a static
/// caret. No animation - it sits there, like a terminal that is idle.
class _AsciiArt extends StatelessWidget {
  const _AsciiArt();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: _asciiLines.join('\n'),
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontFamily: 'monospace',
              fontSize: 16,
              height: 1.2,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.5),
                  blurRadius: 6,
                ),
                Shadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.25),
                  blurRadius: 18,
                ),
              ],
            ),
          ),
          TextSpan(
            text: '▌',
            style: TextStyle(
              color: theme.colorScheme.secondary,
              fontFamily: 'monospace',
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _OfflineCard extends StatelessWidget {
  const _OfflineCard({required this.onSave});

  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'no internet — going to draft',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.secondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'it syncs to your calendar when you are back online.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: onSave,
              child: const Text('Save as draft'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmCard extends StatelessWidget {
  const _ConfirmCard({
    required this.preview,
    required this.onCreate,
    required this.onCancel,
  });

  final ReminderResult preview;
  final VoidCallback? onCreate;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_note, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    preview.summary,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              preview.startsAt,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            if (preview.critical || preview.recurring)
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (preview.critical) const _Tag(label: 'URGENT', critical: true),
                  if (preview.recurring) const _Tag(label: 'repeats'),
                ],
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onCreate,
                    icon: const Icon(Icons.check),
                    label: const Text('OK'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.critical = false});

  final String label;
  final bool critical;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = critical
        ? theme.colorScheme.secondary
        : theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: critical
            ? theme.colorScheme.secondary.withValues(alpha: 0.14)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}