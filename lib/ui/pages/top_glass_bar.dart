import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

class TopGlassBar extends StatelessWidget {
  final List<String> modes;
  final String selectedMode;
  final ValueChanged<String> onModeSelected;
  final VoidCallback onRefresh;
  final VoidCallback onOpenDashboard;

  const TopGlassBar({
    required this.modes,
    required this.selectedMode,
    required this.onModeSelected,
    required this.onRefresh,
    required this.onOpenDashboard,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC).withOpacity(0.78),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 300,
                child: FSelect<String>(
                  items: {for (final mode in modes) mode: mode},
                  control: FSelectControl.lifted(
                    value: selectedMode,
                    onChange: (value) {
                      if (value != null && value != selectedMode) {
                        onModeSelected(value);
                      }
                    },
                  ),
                ),
              ),
              const Spacer(),
              FButton.icon(
                onPress: onRefresh,
                child: const Icon(FIcons.refreshCw),
              ),
              const SizedBox(width: 12),
              FButton.icon(
                onPress: onOpenDashboard,
                child: const Icon(FIcons.activity),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
