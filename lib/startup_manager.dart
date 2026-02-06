import 'dart:io';

class StartupManager {
  static const String _label = 'com.clash_gatito.startup';

  static Future<bool> isEnabled() async {
    if (!Platform.isMacOS) return false;
    return File(_plistPath()).exists();
  }

  static Future<void> setEnabled(bool enabled) async {
    if (!Platform.isMacOS) return;
    final plistPath = _plistPath();
    if (enabled) {
      final execPath = _executablePath();
      final content = _plistContent(execPath);
      await File(plistPath).writeAsString(content);
    } else {
      final file = File(plistPath);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  static String _plistPath() {
    final home = Platform.environment['HOME'] ?? '';
    return '$home/Library/LaunchAgents/$_label.plist';
  }

  static String _executablePath() {
    // For macOS bundles, resolvedExecutable points to Contents/MacOS/<app>
    return Platform.resolvedExecutable;
  }

  static String _plistContent(String execPath) {
    return '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$_label</string>
  <key>ProgramArguments</key>
  <array>
    <string>$execPath</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <false/>
</dict>
</plist>
''';
  }

  // We intentionally avoid calling launchctl load/unload here because
  // it can spawn a new instance or terminate the running one. Writing
  // or deleting the LaunchAgent plist is enough for the next login.
}
