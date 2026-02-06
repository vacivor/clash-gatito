import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import 'settings_fields.dart';

class SettingsPage extends StatelessWidget {
  final TextEditingController hostController;
  final TextEditingController portController;
  final TextEditingController secretController;
  final String? error;
  final VoidCallback onSave;
  final List<int> refreshOptions;
  final int refreshMinutes;
  final ValueChanged<int> onRefreshMinutesChanged;
  final bool launchAtLogin;
  final bool launchAtLoginLoading;
  final ValueChanged<bool> onLaunchAtLoginChanged;

  const SettingsPage({
    required this.hostController,
    required this.portController,
    required this.secretController,
    required this.error,
    required this.onSave,
    required this.refreshOptions,
    required this.refreshMinutes,
    required this.onRefreshMinutesChanged,
    required this.launchAtLogin,
    required this.launchAtLoginLoading,
    required this.onLaunchAtLoginChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FCard(
            title: const Text('Clash Backend'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SettingsFields(
                  hostController: hostController,
                  portController: portController,
                  secretController: secretController,
                ),
                const SizedBox(height: 12),
                if (error != null)
                  Text(
                    error!,
                    style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
                  ),
                const SizedBox(height: 8),
                FButton(
                  onPress: onSave,
                  child: const Text('Save Settings'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FCard(
            title: const Text('Refresh'),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Auto refresh interval (minutes)'),
                ),
                DropdownButton<int>(
                  value: refreshMinutes,
                  items: refreshOptions
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.toString()),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      onRefreshMinutesChanged(value);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FCard(
            title: const Text('Launch At Login'),
            child: FSwitch(
              label: const Text('Launch at login (macOS)'),
              description: const Text('Start Clash Gatito when you sign in.'),
              value: launchAtLogin,
              enabled: !launchAtLoginLoading,
              onChange: launchAtLoginLoading ? null : onLaunchAtLoginChanged,
            ),
          ),
        ],
      ),
    );
  }
}
