import 'package:flutter/material.dart';

import '../controllers/settings_controller.dart';
import '../widgets/debug_badge.dart';

/// Edits API keys and the debug-mode switch.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.controller});

  final SettingsController controller;

  /// Creates the page state.
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

/// Loads saved settings into the text fields.
class _SettingsPageState extends State<SettingsPage> {
  final _wdgwarsController = TextEditingController();
  final _wardriftController = TextEditingController();
  bool _isLoading = true;
  bool _obscureWdgwars = true;
  bool _obscureWardrift = true;

  SettingsController get _settings => widget.controller;

  /// Loads settings and fills the key fields.
  @override
  void initState() {
    super.initState();
    _settings.load().then((_) {
      if (!mounted) return;
      _wdgwarsController.text = _settings.wdgwarsApiKey;
      _wardriftController.text = _settings.wardriftApiKey;
      setState(() => _isLoading = false);
    });
  }

  /// Disposes the text controllers.
  @override
  void dispose() {
    _wdgwarsController.dispose();
    _wardriftController.dispose();
    super.dispose();
  }

  /// Shows a snackbar with [message].
  void _toast(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  /// Obscured API key field with a show/hide toggle.
  Widget _keyField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
          tooltip: obscure ? 'Show API key' : 'Hide API key',
          onPressed: onToggle,
        ),
      ),
    );
  }

  /// Save button that shows a spinner while [saving].
  Widget _saveButton({
    required bool saving,
    required String label,
    required VoidCallback onPressed,
  }) {
    return FilledButton.icon(
      onPressed: saving ? null : onPressed,
      icon: saving
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.save),
      label: Text(label),
    );
  }

  /// Builds the key fields, save buttons and debug switch.
  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleLarge;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          DebugBadge(settings: _settings),
          const SizedBox(width: 12),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListenableBuilder(
              listenable: _settings,
              builder: (context, _) => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('WDGWars', style: titleStyle),
                  const SizedBox(height: 8),
                  _keyField(
                    controller: _wdgwarsController,
                    label: 'API key',
                    hint: 'Enter your WDGWars API key',
                    obscure: _obscureWdgwars,
                    onToggle: () =>
                        setState(() => _obscureWdgwars = !_obscureWdgwars),
                  ),
                  const SizedBox(height: 16),
                  _saveButton(
                    saving: _settings.isSavingWdgwars,
                    label: 'Save WDGWars API key',
                    onPressed: () async {
                      await _settings.saveWdgwarsApiKey(
                        _wdgwarsController.text,
                      );
                      if (mounted) _toast('WDGWars API key saved.');
                    },
                  ),
                  const SizedBox(height: 24),
                  Text('Wardrift', style: titleStyle),
                  const SizedBox(height: 8),
                  _keyField(
                    controller: _wardriftController,
                    label: 'Wardrift API Key',
                    hint: 'Enter your Wardrift API key',
                    obscure: _obscureWardrift,
                    onToggle: () =>
                        setState(() => _obscureWardrift = !_obscureWardrift),
                  ),
                  const SizedBox(height: 16),
                  _saveButton(
                    saving: _settings.isSavingWardrift,
                    label: 'Save Wardrift API Key',
                    onPressed: () async {
                      await _settings.saveWardriftApiKey(
                        _wardriftController.text,
                      );
                      if (mounted) _toast('Wardrift API key saved.');
                    },
                  ),
                  const SizedBox(height: 24),
                  Text('Developer', style: titleStyle),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Debug mode'),
                    subtitle: const Text(
                      'Skip uploading CSV files to WDGWars and Wardrift',
                    ),
                    value: _settings.debugMode,
                    onChanged: _settings.setDebugMode,
                  ),
                ],
              ),
            ),
    );
  }
}
