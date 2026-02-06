import 'dart:async';

import 'package:flutter/material.dart' hide Image;
import 'package:forui/forui.dart';
import 'package:nativeapi/nativeapi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ui/service/clash_service.dart';
import 'ui/service/diagnostics_service.dart';
import 'startup_manager.dart';
import 'ui/tray/tray_menu.dart';
import 'ui/app_page.dart';
import 'ui/layout/app_layout.dart';
import 'ui/pages/home_page.dart';
import 'ui/pages/init_page.dart';
import 'ui/pages/settings_page.dart';
import 'ui/pages/zdashboard_page.dart';

class TrayIconData {
  final int id;
  final TrayIcon trayIcon;
  final Menu contextMenu;
  int clickCount;
  int rightClickCount;
  int doubleClickCount;
  bool isVisible;
  String title;
  String tooltip;
  ContextMenuTrigger contextMenuTrigger;

  TrayIconData({
    required this.id,
    required this.trayIcon,
    required this.contextMenu,
    this.clickCount = 0,
    this.rightClickCount = 0,
    this.doubleClickCount = 0,
    this.isVisible = true,
    this.title = '',
    this.tooltip = '',
    this.contextMenuTrigger = ContextMenuTrigger.none,
  });

  void dispose() {
    trayIcon.dispose();
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final current = WindowManager.instance.getCurrent();
  current?.setSize(800, 650);
  current?.setMinimumSize(800, 650);
  current?.title = 'ClashGatito';
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clash Gatito',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      builder: (context, child) {
        return FTheme(
          data: FThemes.zinc.light,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const TrayIconExamplePage(),
    );
  }
}

class TrayIconExamplePage extends StatefulWidget {
  const TrayIconExamplePage({super.key});

  @override
  State<TrayIconExamplePage> createState() => _TrayIconExamplePageState();
}

class _TrayIconExamplePageState extends State<TrayIconExamplePage> {
  final List<TrayIconData> _trayIcons = [];
  final List<String> _eventHistory = [];
  int _nextIconId = 1;
  final List<String> _modes = ['Rule', 'Global', 'Direct'];
  final Map<String, List<String>> _providerNodes = {};
  final Map<String, String> _selectedProxyByGroup = {};
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  final TextEditingController _secretController = TextEditingController();
  final List<int> _refreshOptions = [1, 5, 10, 30];
  String? _proxiesTraffic;
  String? _proxiesExpire;
  String _selectedMode = 'Rule';
  String _clashHost = '';
  int _clashPort = 0;
  String _clashToken = '';
  bool _settingsLoaded = false;
  String? _settingsError;
  AppPage _currentPage = AppPage.home;
  bool _launchAtLogin = false;
  bool _launchAtLoginLoading = true;
  Timer? _refreshTimer;
  Duration _refreshInterval = const Duration(minutes: 10);
  ClashService? _clashService;
  final DiagnosticsService _diagnosticsService = DiagnosticsService();
  Map<String, String> _ipResults = {};
  Map<String, Duration?> _latencyResults = {};
  bool _ipLoading = false;
  bool _latencyLoading = false;
  bool _ipLoaded = false;
  bool _latencyLoaded = false;

  @override
  void initState() {
    super.initState();
    _addTrayIcon();
    _loadLaunchAtLogin();
    _startAutoRefresh();
    _loadSettings();
    _ensureDiagnosticsLoaded();
  }

  @override
  void dispose() {
    for (final trayIconData in _trayIcons) {
      trayIconData.dispose();
    }
    _refreshTimer?.cancel();
    _hostController.dispose();
    _portController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  void _addToHistory(String message) {
    setState(() {
      final timestamp = DateTime.now().toString().substring(11, 19);
      _eventHistory.insert(0, '[$timestamp] $message');
      if (_eventHistory.length > 50) {
        _eventHistory.removeLast();
      }
    });
  }

  Future<void> _loadLaunchAtLogin() async {
    final enabled = await StartupManager.isEnabled();
    if (!mounted) return;
    setState(() {
      _launchAtLogin = enabled;
      _launchAtLoginLoading = false;
    });
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      _refreshClashData(
        _trayIcons.isNotEmpty ? _trayIcons.first.trayIcon : null,
      );
    });
  }

  Future<void> _updateRefreshInterval(
    Duration interval, {
    bool logHistory = true,
  }) async {
    setState(() {
      _refreshInterval = interval;
    });
    _startAutoRefresh();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('refresh_interval_minutes', interval.inMinutes);
    if (logHistory) {
      _addToHistory('Auto refresh interval: ${interval.inMinutes} minutes');
    }
  }

  Future<void> _refreshIpResults({bool logHistory = true}) async {
    if (!mounted) return;
    setState(() {
      _ipLoading = true;
    });
    try {
      final randomSeed = DateTime.now().microsecondsSinceEpoch & 0x7fffffff;
      final results = await _diagnosticsService.fetchIpResults(
        upaiYunEndpoint:
            'https://pubstatic.b0.upaiyun.com/?_upnode&z=$randomSeed',
      );
      if (!mounted) return;
      setState(() {
        _ipResults = results;
        _ipLoading = false;
        _ipLoaded = true;
      });
      if (logHistory) {
        _addToHistory('IP check refreshed');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ipLoading = false;
        _ipLoaded = true;
      });
      if (logHistory) {
        _addToHistory('IP check failed: $e');
      }
    }
  }

  Future<void> _refreshLatencyResults({bool logHistory = true}) async {
    if (!mounted) return;
    setState(() {
      _latencyLoading = true;
    });
    try {
      final results = await _diagnosticsService.testLatencies([
        Uri.parse('https://www.baidu.com'),
        Uri.parse('https://github.com'),
        Uri.parse('https://www.youtube.com'),
        Uri.parse('https://music.163.com'),
      ]);
      if (!mounted) return;
      setState(() {
        _latencyResults = results;
        _latencyLoading = false;
        _latencyLoaded = true;
      });
      if (logHistory) {
        _addToHistory('Latency check refreshed');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _latencyLoading = false;
        _latencyLoaded = true;
      });
      if (logHistory) {
        _addToHistory('Latency check failed: $e');
      }
    }
  }

  Future<void> _setLaunchAtLogin(bool enabled) async {
    setState(() {
      _launchAtLoginLoading = true;
    });
    await StartupManager.setEnabled(enabled);
    if (!mounted) return;
    setState(() {
      _launchAtLogin = enabled;
      _launchAtLoginLoading = false;
    });
    if (_trayIcons.isNotEmpty) {
      _refreshTrayMenu(_trayIcons.first.trayIcon);
    }
    _addToHistory(
      enabled ? 'Launch at login enabled' : 'Launch at login disabled',
    );
  }

  void _addTrayIcon() {
    try {
      final trayIcon = TrayIcon();

      final icon = Image.fromAsset('assets/tray_icon.png');
      if (icon != null) {
        trayIcon.icon = icon;
      }

      final contextMenu = _createContextMenu(trayIcon);

      final trayIconData = TrayIconData(
        id: _nextIconId++,
        trayIcon: trayIcon,
        contextMenu: contextMenu,
        // title and tooltip are empty by default
        contextMenuTrigger: ContextMenuTrigger.clicked,
      );

      // Set up event listeners
      trayIcon.on<TrayIconClickedEvent>((event) {
        setState(() {
          trayIconData.clickCount++;
        });
      });

      trayIcon.on<TrayIconRightClickedEvent>((event) {
        setState(() {
          trayIconData.rightClickCount++;
        });
        _addToHistory(
          'Tray icon ${trayIconData.id} right clicked (${trayIconData.rightClickCount} times)',
        );
      });

      trayIcon.on<TrayIconDoubleClickedEvent>((event) {
        setState(() {
          trayIconData.doubleClickCount++;
        });
        _addToHistory(
          'Tray icon ${trayIconData.id} double clicked (${trayIconData.doubleClickCount} times)',
        );
      });

      // Set initial properties
      // trayIcon.title = trayIconData.title; // Set via UI
      // trayIcon.tooltip = trayIconData.tooltip; // Set via UI
      trayIcon.isVisible = trayIconData.isVisible;
      trayIcon.contextMenuTrigger = trayIconData.contextMenuTrigger;

      _trayIcons.add(trayIconData);

      _addToHistory('Tray icon ${trayIconData.id} created successfully');
    } catch (e) {
      _addToHistory('Error creating tray icon: $e');
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final host = prefs.getString('clash_host') ?? '';
    final port = prefs.getInt('clash_port') ?? 0;
    final token = prefs.getString('clash_secret') ?? '';
    final refreshMinutes =
        prefs.getInt('refresh_interval_minutes') ?? _refreshInterval.inMinutes;
    if (!mounted) return;
    setState(() {
      _clashHost = host;
      _clashPort = port;
      _clashToken = token;
      _settingsLoaded = true;
      _settingsError = null;
    });
    _syncSettingsControllers();
    await _updateRefreshInterval(
      Duration(minutes: refreshMinutes),
      logHistory: false,
    );
    _rebuildClashService();
    if (_isConfigured) {
      _loadClashConfig();
      _loadClashNodes();
    }
  }

  void _syncSettingsControllers() {
    _hostController.text = _clashHost;
    _portController.text = _clashPort == 0 ? '' : _clashPort.toString();
    _secretController.text = _clashToken;
  }

  bool get _isConfigured {
    return _clashHost.isNotEmpty && _clashPort > 0 && _clashToken.isNotEmpty;
  }

  String get _clashBaseUrl {
    if (!_isConfigured) return '';
    return 'http://$_clashHost:$_clashPort';
  }

  void _rebuildClashService() {
    if (_isConfigured) {
      _clashService = ClashService(baseUrl: _clashBaseUrl, token: _clashToken);
    } else {
      _clashService = null;
    }
  }

  int? _parsePort(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    final value = int.tryParse(trimmed);
    if (value == null || value <= 0) return null;
    return value;
  }

  Future<void> _saveSettings({required bool continueToHome}) async {
    final host = _hostController.text.trim();
    final port = _parsePort(_portController.text);
    final token = _secretController.text.trim();
    if (host.isEmpty || port == null || token.isEmpty) {
      setState(() {
        _settingsError = 'Please enter host, port, and secret.';
      });
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('clash_host', host);
    await prefs.setInt('clash_port', port);
    await prefs.setString('clash_secret', token);
    if (!mounted) return;
    setState(() {
      _clashHost = host;
      _clashPort = port;
      _clashToken = token;
      _settingsError = null;
      if (continueToHome) {
        _currentPage = AppPage.home;
      }
    });
    _rebuildClashService();
    _loadClashConfig();
    _loadClashNodes();
    _addToHistory('Settings updated: $host:$port');
  }

  Menu _createContextMenu(TrayIcon trayIcon) {
    return _buildTrayMenu(trayIcon);
  }

  void _refreshTrayMenu(TrayIcon trayIcon) {
    final contextMenu = _createContextMenu(trayIcon);
    trayIcon.contextMenu = contextMenu;
  }

  Future<void> _refreshClashData(TrayIcon? trayIcon) async {
    if (!_isConfigured) {
      _addToHistory('Refresh skipped: missing host/port/secret');
      return;
    }
    _addToHistory('Refreshing clash data...');
    await _loadClashConfig();
    await _loadClashNodes();
    if (trayIcon != null) {
      _refreshTrayMenu(trayIcon);
    } else if (_trayIcons.isNotEmpty) {
      _refreshTrayMenu(_trayIcons.first.trayIcon);
    }
  }

  void _ensureDiagnosticsLoaded() {
    if (!_ipLoaded && !_ipLoading) {
      _refreshIpResults(logHistory: false);
    }
    if (!_latencyLoaded && !_latencyLoading) {
      _refreshLatencyResults(logHistory: false);
    }
  }

  void _showMainWindow() {
    final windowManager = WindowManager.instance;
    final current = windowManager.getCurrent();
    if (current != null) {
      current.show();
      current.focus();
      return;
    }
    final windows = windowManager.getAll();
    if (windows.isNotEmpty) {
      windows.first.show();
      windows.first.focus();
    }
  }

  String _modeToClashValue(String mode) {
    final normalized = mode.trim().toLowerCase();
    switch (normalized) {
      case 'rule':
        return 'Rule';
      case 'global':
        return 'Global';
      case 'direct':
        return 'Direct';
      default:
        return 'Rule';
    }
  }

  String _clashValueToMode(String value) {
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'rule':
        return 'Rule';
      case 'global':
        return 'Global';
      case 'direct':
        return 'Direct';
      default:
        return 'Rule';
    }
  }

  Menu _buildTrayMenu(TrayIcon trayIcon) {
    return TrayMenuBuilder(
      modes: _modes,
      selectedMode: _selectedMode,
      groups: _providerNodes,
      selectedByGroup: _selectedProxyByGroup,
      traffic: _proxiesTraffic,
      expire: _proxiesExpire,
      launchAtLogin: _launchAtLogin,
      onShowWindow: _showHome,
      onOpenSettings: _openSettings,
      onOpenDashboard: _openDashboard,
      onRefresh: () => _refreshClashData(trayIcon),
      onLaunchAtLoginChanged: (value) => _setLaunchAtLogin(value),
      onModeSelected: (mode) => _setClashMode(mode, trayIcon),
      onNodeSelected: (group, node) => _setClashNode(group, node, trayIcon),
      onHistory: _addToHistory,
    ).build(trayIcon);
  }

  void _openDashboard() {
    if (!_isConfigured) {
      _showHome();
      setState(() {
        _currentPage = AppPage.settings;
      });
      _addToHistory('Open dashboard skipped: missing host/port/secret');
      return;
    }
    _showMainWindow();
    setState(() {
      _currentPage = AppPage.dashboard;
    });
  }

  void _openSettings() {
    _showMainWindow();
    setState(() {
      _currentPage = AppPage.settings;
    });
  }

  void _showHome() {
    _showMainWindow();
    setState(() {
      _currentPage = AppPage.home;
    });
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.popUntil((route) => route.isFirst);
    }
  }

  Future<void> _loadClashConfig() async {
    final service = _clashService;
    if (service == null) {
      return;
    }
    try {
      final response = await service.getConfigs();
      if (response.ok) {
        final data = response.data;
        final modeValue = data['mode']?.toString() ?? 'Rule';
        setState(() {
          _selectedMode = _clashValueToMode(modeValue);
        });
        if (_trayIcons.isNotEmpty) {
          _refreshTrayMenu(_trayIcons.first.trayIcon);
        }
        _addToHistory('Config loaded: current mode $modeValue');
      } else {
        _addToHistory(
          'Config load failed: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      _addToHistory('Config load error: $e');
    }
  }

  Future<void> _setClashMode(String mode, TrayIcon trayIcon) async {
    final service = _clashService;
    if (service == null) {
      _addToHistory('Switch mode skipped: missing host/port/secret');
      return;
    }
    final modeValue = _modeToClashValue(mode);
    try {
      final response = await service.patchConfigsMode(modeValue);
      if (response.ok) {
        setState(() {
          _selectedMode = mode;
        });
        _addToHistory('Mode switched to $modeValue (tray ${trayIcon.id})');
        _refreshTrayMenu(trayIcon);
      } else {
        _addToHistory(
          'Mode switch failed: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      _addToHistory('Mode switch error: $e');
    }
  }

  Future<void> _setClashNode(
    String group,
    String node,
    TrayIcon trayIcon,
  ) async {
    final service = _clashService;
    if (service == null) {
      _addToHistory('Switch node skipped: missing host/port/secret');
      return;
    }
    try {
      final response = await service.putProxy(group, node);
      if (response.ok) {
        setState(() {
          _selectedProxyByGroup[group] = node;
        });
        _addToHistory(
          'Proxy switched to $group -> $node (tray ${trayIcon.id})',
        );
        _refreshTrayMenu(trayIcon);
      } else {
        _addToHistory(
          'Proxy switch failed: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      _addToHistory('Proxy switch error: $e');
    }
  }

  Future<void> _loadClashNodes() async {
    final service = _clashService;
    if (service == null) {
      return;
    }
    try {
      final proxiesResponse = await service.getProxies();
      final proxiesMap = proxiesResponse.data['proxies'];
      if (proxiesMap is Map<String, dynamic>) {
        final temp = <String, List<String>>{};
        final selectedTemp = <String, String>{};
        final entries = _prioritizeGroupFirst(
          proxiesMap.entries.toList(),
          'Proxies',
        );
        String? traffic;
        String? expire;
        for (final entry in entries) {
          final value = entry.value;
          if (value is Map<String, dynamic> && value['type'] == 'Selector') {
            final all = value['all'];
            if (all is List) {
              final list = <String>[];
              for (final item in all) {
                if (item != null) {
                  final text = item.toString();
                  list.add(text);
                  if (entry.key == 'Proxies') {
                    if (traffic == null && text.startsWith('Traffic:')) {
                      traffic = text;
                    } else if (expire == null && text.startsWith('Expire:')) {
                      expire = text;
                    }
                  }
                }
              }
              if (list.isNotEmpty) {
                temp[entry.key] = _prioritizeProxiesFirst(
                  _dedupePreserveOrder(list),
                );
              }
            }
            final now = value['now'];
            if (now != null) {
              selectedTemp[entry.key] = now.toString();
            }
          }
        }
        if (temp.isNotEmpty) {
          setState(() {
            _providerNodes
              ..clear()
              ..addAll(temp);
            _selectedProxyByGroup
              ..clear()
              ..addAll(selectedTemp);
            _proxiesTraffic = traffic;
            _proxiesExpire = expire;
          });
          if (_trayIcons.isNotEmpty) {
            _refreshTrayMenu(_trayIcons.first.trayIcon);
          }
          _addToHistory('Proxies loaded: ${_providerNodes.length} groups');
        }
      }
    } catch (e) {
      _addToHistory('Load /proxies error: $e');
    }
  }

  List<String> _dedupePreserveOrder(List<String> items) {
    final seen = <String>{};
    final result = <String>[];
    for (final item in items) {
      if (seen.add(item)) {
        result.add(item);
      }
    }
    return result;
  }

  List<String> _prioritizeProxiesFirst(List<String> items) {
    if (!items.contains('Proxies')) {
      return items;
    }
    final result = <String>['Proxies'];
    for (final item in items) {
      if (item != 'Proxies') {
        result.add(item);
      }
    }
    return result;
  }

  List<MapEntry<String, dynamic>> _prioritizeGroupFirst(
    List<MapEntry<String, dynamic>> entries,
    String groupName,
  ) {
    final result = <MapEntry<String, dynamic>>[];
    final first = entries.where((entry) => entry.key == groupName);
    result.addAll(first);
    result.addAll(entries.where((entry) => entry.key != groupName));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (!_settingsLoaded) {
      return _buildLoadingPage();
    }

    if (!_isConfigured) {
      return _buildInitPage();
    }

    return _buildMainShell(context);
  }

  Widget _buildLoadingPage() {
    return const Center(child: Text('Loading settings...'));
  }

  Widget _buildInitPage() {
    return InitPage(
      hostController: _hostController,
      portController: _portController,
      secretController: _secretController,
      error: _settingsError,
      onSave: () => _saveSettings(continueToHome: true),
    );
  }

  Widget _buildMainShell(BuildContext context) {
    final colors = context.theme.colors;
    return AppLayout(
      currentPage: _currentPage,
      onSelectPage: (page) {
        if (page == AppPage.dashboard) {
          _openDashboard();
          return;
        }
        if (page == AppPage.home) {
          _ensureDiagnosticsLoaded();
        }
        setState(() => _currentPage = page);
      },
      child: Scaffold(
        body: Container(
          child: _buildPageContent(),
        ),
      ),
    );
  }

  Widget _buildPageContent() {
    switch (_currentPage) {
      case AppPage.home:
        return _buildHomePage();
      case AppPage.settings:
        return _buildSettingsPage();
      case AppPage.dashboard:
        return _buildDashboardPage();
    }
  }

  Widget _buildHomePage() {
    final selectedMain =
        _selectedProxyByGroup['GLOBAL'] ?? _selectedProxyByGroup['Proxies'];
    final entries = _selectedProxyByGroup.entries.toList();
    return HomePage(
      modes: _modes,
      selectedMode: _selectedMode,
      mainProxy: selectedMain,
      traffic: _proxiesTraffic,
      expire: _proxiesExpire,
      backend: _isConfigured ? '$_clashHost:$_clashPort' : 'Not configured',
      proxyEntries: entries,
      ipResults: _ipResults,
      latencyResults: _latencyResults,
      ipLoading: _ipLoading,
      latencyLoading: _latencyLoading,
      onModeSelected: (mode) {
        if (_trayIcons.isNotEmpty) {
          _setClashMode(mode, _trayIcons.first.trayIcon);
        }
      },
      onRefreshClash: () => _refreshClashData(
        _trayIcons.isNotEmpty ? _trayIcons.first.trayIcon : null,
      ),
      onRefreshIp: () => _refreshIpResults(),
      onRefreshLatency: () => _refreshLatencyResults(),
      onOpenDashboard: _openDashboard,
    );
  }

  Widget _buildSettingsPage() {
    return SettingsPage(
      hostController: _hostController,
      portController: _portController,
      secretController: _secretController,
      error: _settingsError,
      onSave: () => _saveSettings(continueToHome: false),
      refreshOptions: _refreshOptions,
      refreshMinutes: _refreshInterval.inMinutes,
      onRefreshMinutesChanged: (value) {
        _updateRefreshInterval(Duration(minutes: value));
      },
      launchAtLogin: _launchAtLogin,
      launchAtLoginLoading: _launchAtLoginLoading,
      onLaunchAtLoginChanged: (value) => _setLaunchAtLogin(value),
    );
  }

  Widget _buildDashboardPage() {
    if (!_isConfigured) {
      return const Center(child: Text('Please configure host/port/secret.'));
    }
    return ZDashboardPage(
      useLocalServer: false,
      host: _clashHost,
      port: _clashPort,
      secret: _clashToken,
    );
  }
}
