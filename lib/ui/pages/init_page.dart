import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import 'settings_fields.dart';

class InitPage extends StatelessWidget {
  final TextEditingController hostController;
  final TextEditingController portController;
  final TextEditingController secretController;
  final String? error;
  final VoidCallback onSave;

  const InitPage({
    required this.hostController,
    required this.portController,
    required this.secretController,
    required this.error,
    required this.onSave,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: FCard(
          title: const Text('Connect to Clash Backend'),
          subtitle: const Text('Enter host, port, and secret to continue.'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
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
                  child: const Text('Save & Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
