import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../app_page.dart';
import 'sidebar.dart';

class AppLayout extends StatelessWidget {
  final AppPage currentPage;
  final ValueChanged<AppPage> onSelectPage;
  final Widget child;

  const AppLayout({
    required this.currentPage,
    required this.onSelectPage,
    required this.child,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            Sidebar(currentPage: currentPage, onSelect: onSelectPage),
            Expanded(
              child: Container(
                color: colors.background,
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }
}
