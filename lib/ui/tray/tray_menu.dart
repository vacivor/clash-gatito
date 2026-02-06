import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:nativeapi/nativeapi.dart';

class TrayMenuBuilder {
  final List<String> modes;
  final String selectedMode;
  final Map<String, List<String>> groups;
  final Map<String, String> selectedByGroup;
  final String? traffic;
  final String? expire;
  final bool launchAtLogin;
  final VoidCallback onShowWindow;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenDashboard;
  final VoidCallback onRefresh;
  final ValueChanged<bool> onLaunchAtLoginChanged;
  final void Function(String mode) onModeSelected;
  final void Function(String group, String node) onNodeSelected;
  final void Function(String message) onHistory;

  const TrayMenuBuilder({
    required this.modes,
    required this.selectedMode,
    required this.groups,
    required this.selectedByGroup,
    required this.traffic,
    required this.expire,
    required this.launchAtLogin,
    required this.onShowWindow,
    required this.onOpenSettings,
    required this.onOpenDashboard,
    required this.onRefresh,
    required this.onLaunchAtLoginChanged,
    required this.onModeSelected,
    required this.onNodeSelected,
    required this.onHistory,
  });

  Menu build(TrayIcon trayIcon) {
    final contextMenu = Menu();

    contextMenu.addCallbackListener<MenuOpenedEvent>((event) {
      onHistory('Context menu opened for tray icon ${trayIcon.id}');
    });
    contextMenu.addCallbackListener<MenuClosedEvent>((event) {
      onHistory('Context menu closed for tray icon ${trayIcon.id}');
    });

    final showItem = MenuItem('Dashboard...');
    final settingsItem = MenuItem('Settings');
    final dashboardItem = MenuItem('Web Dashboard...');
    final trafficItem = _buildTrafficItem();
    final expireItem = _buildExpireItem();
    final refreshItem = MenuItem('Refresh');
    final separatorItem = MenuItem('', MenuItemType.separator);
    final separatorItem1 = MenuItem('', MenuItemType.separator);
    final separatorItem2 = MenuItem('', MenuItemType.separator);
    final modeSubmenuItem = _buildModeSubmenu(trayIcon);
    final nodeSubmenuItem = _buildNodeSubmenu(trayIcon);
    final startupItem = _buildLaunchItem();
    final quitItem = MenuItem('Quit');

    showItem.on<MenuItemClickedEvent>((event) {
      onHistory('Dashboard clicked for tray icon ${trayIcon.id}');
      onShowWindow();
    });

    settingsItem.on<MenuItemClickedEvent>((event) {
      onHistory('Settings clicked for tray icon ${trayIcon.id}');
      onOpenSettings();
    });

    dashboardItem.on<MenuItemClickedEvent>((event) {
      onHistory('Web Dashboard clicked for tray icon ${trayIcon.id}');
      onOpenDashboard();
    });

    refreshItem.on<MenuItemClickedEvent>((event) {
      onRefresh();
    });

    startupItem.on<MenuItemClickedEvent>((event) {
      onLaunchAtLoginChanged(!launchAtLogin);
    });

    quitItem.on<MenuItemClickedEvent>((event) {
      onHistory('Quit clicked for tray icon ${trayIcon.id}');
      exit(0);
    });

    if (trafficItem != null) {
      contextMenu.addItem(trafficItem);
    }
    if (expireItem != null) {
      contextMenu.addItem(expireItem);
    }
    contextMenu.addItem(modeSubmenuItem);
    contextMenu.addItem(nodeSubmenuItem);
    contextMenu.addItem(refreshItem);
    contextMenu.addItem(separatorItem);
    contextMenu.addItem(startupItem);
    contextMenu.addItem(separatorItem1);
    contextMenu.addItem(showItem);
    contextMenu.addItem(settingsItem);
    contextMenu.addItem(dashboardItem);
    contextMenu.addItem(separatorItem2);
    contextMenu.addItem(quitItem);

    trayIcon.contextMenu = contextMenu;
    return contextMenu;
  }

  MenuItem _buildModeSubmenu(TrayIcon trayIcon) {
    final modeMenu = Menu();
    for (final mode in modes) {
      final label = _checkedLabel(selectedMode == mode, mode);
      final item = MenuItem(label);
      item.on<MenuItemClickedEvent>((event) {
        onModeSelected(mode);
      });
      modeMenu.addItem(item);
    }

    final modeMenuItem = MenuItem('Mode', MenuItemType.submenu);
    modeMenuItem.submenu = modeMenu;
    return modeMenuItem;
  }

  MenuItem _buildNodeSubmenu(TrayIcon trayIcon) {
    final nodeMenu = Menu();
    for (final entry in groups.entries) {
      final groupName = entry.key;
      final providerMenu = Menu();
      final selectedInGroup = selectedByGroup[groupName];
      for (final node in entry.value) {
        final label = _checkedLabel(selectedInGroup == node, node);
        final item = MenuItem(label);
        item.on<MenuItemClickedEvent>((event) {
          onNodeSelected(groupName, node);
        });
        providerMenu.addItem(item);
      }
      final providerItem = MenuItem(groupName, MenuItemType.submenu);
      providerItem.submenu = providerMenu;
      nodeMenu.addItem(providerItem);
    }

    final nodeMenuItem = MenuItem('Proxies', MenuItemType.submenu);
    nodeMenuItem.submenu = nodeMenu;
    return nodeMenuItem;
  }

  MenuItem _buildLaunchItem() {
    final label = _checkedLabel(launchAtLogin, 'Launch at Login');
    return MenuItem(label);
  }

  String _checkedLabel(bool selected, String text) {
    return selected ? '✓\u00A0$text' : text;
  }

  MenuItem? _buildTrafficItem() {
    if (traffic == null) {
      return null;
    }
    return MenuItem(traffic!);
  }

  MenuItem? _buildExpireItem() {
    if (expire == null) {
      return null;
    }
    return MenuItem(expire!);
  }
}
