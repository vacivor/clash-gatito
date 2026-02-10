import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import 'top_glass_bar.dart';

class ProxyGroup {
  final String name;
  final List<String> nodes;
  final String? selected;

  const ProxyGroup({
    required this.name,
    required this.nodes,
    this.selected,
  });
}

class ProxiesPage extends StatefulWidget {
  final List<String> modes;
  final String selectedMode;
  final List<ProxyGroup> groups;
  final ValueChanged<String> onModeSelected;
  final void Function(String group, String node) onSelectNode;
  final VoidCallback onRefreshClash;
  final VoidCallback onOpenDashboard;

  const ProxiesPage({
    required this.modes,
    required this.selectedMode,
    required this.groups,
    required this.onModeSelected,
    required this.onSelectNode,
    required this.onRefreshClash,
    required this.onOpenDashboard,
    super.key,
  });

  @override
  State<ProxiesPage> createState() => _ProxiesPageState();
}

class _ProxiesPageState extends State<ProxiesPage>
    with TickerProviderStateMixin {
  final Set<String> _expandedGroups = {};
  String? _hoveredNodeKey;
  String? _pressedNodeKey;

  void _toggleGroup(String name) {
    setState(() {
      if (_expandedGroups.contains(name)) {
        _expandedGroups.remove(name);
      } else {
        _expandedGroups.add(name);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFBFBFB),
      child: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 72, 16, 24),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 720 ? 2 : 1;
                  final spacing = 8.0;
                  final cardWidth =
                      (constraints.maxWidth - spacing * (columns - 1)) /
                          columns;
                  if (widget.groups.isEmpty) {
                    return const Text('No proxy data yet.');
                  }
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: widget.groups
                        .map(
                          (group) => _buildGroupCard(group, cardWidth),
                        )
                        .toList(),
                  );
                },
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: TopGlassBar(
              modes: widget.modes,
              selectedMode: widget.selectedMode,
              onModeSelected: widget.onModeSelected,
              onRefresh: widget.onRefreshClash,
              onOpenDashboard: widget.onOpenDashboard,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(ProxyGroup group, double width) {
    final expanded = _expandedGroups.contains(group.name);
    return SizedBox(
      width: width,
      child: GestureDetector(
        onTap: () => _toggleGroup(group.name),
        child: FCard(
          title: Text(group.name),
          subtitle: Text(
            group.selected == null
                ? 'Selector (${group.nodes.length})'
                : 'Selector (${group.nodes.length}) · ${group.selected}',
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: group.nodes
                          .map(
                            (node) => _buildNodeCard(
                              group: group.name,
                              node: node,
                              selected: node == group.selected,
                            ),
                          )
                          .toList(),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  Widget _buildNodeCard({
    required String group,
    required String node,
    required bool selected,
  }) {
    final key = '$group::$node';
    final isHovered = _hoveredNodeKey == key;
    final isPressed = _pressedNodeKey == key;
    final baseColor =
        selected ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final hoverColor =
        selected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final borderColor =
        selected ? const Color(0xFF0F172A) : const Color(0xFFE5E7EB);
    final hoverBorderColor =
        selected ? const Color(0xFF0F172A) : const Color(0xFFCBD5F5);

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredNodeKey = key),
      onExit: (_) => setState(() {
        if (_hoveredNodeKey == key) _hoveredNodeKey = null;
      }),
      child: GestureDetector(
        onTap: selected ? null : () => widget.onSelectNode(group, node),
        onTapDown: selected ? null : (_) => setState(() => _pressedNodeKey = key),
        onTapUp: selected
            ? null
            : (_) => setState(() {
                  if (_pressedNodeKey == key) _pressedNodeKey = null;
                }),
        onTapCancel: selected
            ? null
            : () => setState(() {
                  if (_pressedNodeKey == key) _pressedNodeKey = null;
                }),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 90),
          scale: isPressed ? 0.98 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isHovered ? hoverColor : baseColor,
              border: Border.all(
                color: isHovered ? hoverBorderColor : borderColor,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              node,
              style: TextStyle(
                fontSize: 12,
                color: selected
                    ? const Color(0xFFF8FAFC)
                    : const Color(0xFF111827),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
