import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class SettingsFields extends StatelessWidget {
  final TextEditingController hostController;
  final TextEditingController portController;
  final TextEditingController secretController;

  const SettingsFields({
    required this.hostController,
    required this.portController,
    required this.secretController,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FTextField(
          label: const Text('Host'),
          hint: '192.168.50.1',
          textInputAction: TextInputAction.next,
          control: FTextFieldControl.managed(controller: hostController),
        ),
        const SizedBox(height: 10),
        FTextField(
          label: const Text('Port'),
          hint: '9090',
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          control: FTextFieldControl.managed(controller: portController),
        ),
        const SizedBox(height: 10),
        FTextField(
          label: const Text('Secret'),
          hint: 'Bearer token',
          obscureText: true,
          control: FTextFieldControl.managed(controller: secretController),
        ),
      ],
    );
  }
}
