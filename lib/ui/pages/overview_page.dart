import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import 'top_glass_bar.dart';

class OverviewPage extends StatelessWidget {
  final List<String> modes;
  final String selectedMode;
  final String? mainProxy;
  final String? traffic;
  final String? expire;
  final String backend;
  final Map<String, String> ipResults;
  final Map<String, Duration?> latencyResults;
  final bool ipLoading;
  final bool latencyLoading;
  final ValueChanged<String> onModeSelected;
  final VoidCallback onRefreshClash;
  final VoidCallback onRefreshIp;
  final VoidCallback onRefreshLatency;
  final VoidCallback onOpenDashboard;

  const OverviewPage({
    required this.modes,
    required this.selectedMode,
    required this.mainProxy,
    required this.traffic,
    required this.expire,
    required this.backend,
    required this.ipResults,
    required this.latencyResults,
    required this.ipLoading,
    required this.latencyLoading,
    required this.onModeSelected,
    required this.onRefreshClash,
    required this.onRefreshIp,
    required this.onRefreshLatency,
    required this.onOpenDashboard,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFBFBFB),
      child: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FCard(
                    title: const Text('Status'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildKeyValue('Mode', selectedMode),
                        if (mainProxy != null)
                          _buildKeyValue('Main Proxy', mainProxy!),
                        if (traffic != null)
                          _buildKeyValue('Traffic', traffic!),
                        if (expire != null)
                          _buildKeyValue('Expire', expire!),
                        _buildKeyValue('Backend', backend),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  FCard(
                    title: Row(
                      children: [
                        const Text('IP Check'),
                        const Spacer(),
                        FButton.icon(
                          onPress: ipLoading ? null : onRefreshIp,
                          child: const Icon(FIcons.refreshCw),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      ipLoading ? 'Refreshing...' : 'Public IP providers',
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: ipResults.isEmpty
                          ? const [Text('No IP results yet.')]
                          : ipResults.entries
                              .map(
                                (entry) =>
                                    _buildKeyValue(entry.key, entry.value),
                              )
                              .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FCard(
                    title: Row(
                      children: [
                        const Text('Latency Check'),
                        const Spacer(),
                        FButton.icon(
                          onPress: latencyLoading ? null : onRefreshLatency,
                          child: const Icon(FIcons.refreshCw),
                        ),
                      ],
                    ),
                    subtitle: const Text('Site reachability'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: latencyResults.isEmpty
                          ? const [Text('No latency results yet.')]
                          : latencyResults.entries
                              .map(
                                (entry) => _buildKeyValue(
                                  entry.key,
                                  _formatLatency(entry.value),
                                  valueColor: _latencyColor(entry.value),
                                ),
                              )
                              .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyValue(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: valueColor ?? const Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatLatency(Duration? latency) {
    if (latency == null) return 'Timeout';
    return '${latency.inMilliseconds} ms';
  }

  Color _latencyColor(Duration? latency) {
    if (latency == null) return const Color(0xFFDC2626);
    final ms = latency.inMilliseconds;
    if (ms < 500) return const Color(0xFF16A34A);
    if (ms < 1000) return const Color(0xFFF59E0B);
    return const Color(0xFFDC2626);
  }
}
