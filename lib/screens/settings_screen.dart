import 'package:flutter/material.dart';

import '../services/settings_store.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _baseUrl;
  late final TextEditingController _token;
  late String _createFlow;

  @override
  void initState() {
    super.initState();
    _baseUrl = TextEditingController(text: SettingsStore.instance.baseUrl);
    _token = TextEditingController(text: SettingsStore.instance.token);
    _createFlow = SettingsStore.instance.createFlow;
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await SettingsStore.instance
        .save(baseUrl: _baseUrl.text, token: _token.text, createFlow: _createFlow);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved'), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'settings',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _baseUrl,
                keyboardType: TextInputType.url,
                autofillHints: const [AutofillHints.url],
                decoration: const InputDecoration(
                  labelText: 'Server base URL',
                  hintText: 'https://your-deployment.com',
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _token,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'API token',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Put the gcal-svr URL and the API_TOKEN you set in .env.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 28),
              Text(
                'Create flow',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: SettingsStore.createFlowPreview,
                    label: Text('Preview first'),
                    icon: Icon(Icons.preview_outlined),
                  ),
                  ButtonSegment(
                    value: SettingsStore.createFlowDirect,
                    label: Text('One-tap add'),
                    icon: Icon(Icons.event_available),
                  ),
                ],
                selected: {_createFlow},
                onSelectionChanged: (selection) {
                  setState(() => _createFlow = selection.first);
                },
              ),
              const SizedBox(height: 8),
              Text(
                _createFlow == SettingsStore.createFlowDirect
                    ? 'Speak or type, then "Add to Calendar" creates it in one tap (no preview step).'
                    : 'Preview the parsed reminder first, then confirm to add it.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}