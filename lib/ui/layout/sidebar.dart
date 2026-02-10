import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_page.dart';

class Sidebar extends StatelessWidget {
  final AppPage currentPage;
  final ValueChanged<AppPage> onSelect;

  const Sidebar({
    required this.currentPage,
    required this.onSelect,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return SizedBox(
      width: 58,
      child: Container(
        color: colors.primaryForeground,
        padding: const EdgeInsets.only(top: 20, bottom: 20),
        child: Column(
          children: [
            _buildIconButton(
              icon: FIcons.audioLines,
              selected: currentPage == AppPage.overview,
              onPressed: () => onSelect(AppPage.overview),
            ),
            const SizedBox(height: 12),
            _buildIconButton(
              icon: FIcons.layoutDashboard,
              selected: currentPage == AppPage.proxies,
              onPressed: () => onSelect(AppPage.proxies),
            ),
            const SizedBox(height: 12),
            _buildIconButton(
              icon: FIcons.activity,
              selected: currentPage == AppPage.dashboard,
              onPressed: () => onSelect(AppPage.dashboard),
            ),
            const Spacer(),
            _buildIconButton(
              icon: FIcons.settings,
              selected: currentPage == AppPage.settings,
              onPressed: () => onSelect(AppPage.settings),
            ),
            const SizedBox(height: 12),
            _buildIconButton(
              icon: FIcons.github,
              selected: false,
              onPressed: () {
                launchUrl(
                  Uri.parse('https://github.com/vacivor/clash-gatito'),
                  mode: LaunchMode.externalApplication,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    return FButton.icon(
      onPress: onPressed,
      selected: selected,
      child: Icon(icon),
    );
  }
}
