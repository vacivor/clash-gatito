import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow, NSWindowDelegate {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.delegate = self

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()

    // Startup: no focus, no mouse interaction, fully transparent, then close.
    DispatchQueue.main.async {
      self.ignoresMouseEvents = true
      self.alphaValue = 0.0
      self.performClose(nil)
    }
  }

  override func makeKeyAndOrderFront(_ sender: Any?) {
    self.ignoresMouseEvents = false
    self.alphaValue = 1.0
    NSApp.setActivationPolicy(.regular)
    super.makeKeyAndOrderFront(sender)
  }

  override func orderFront(_ sender: Any?) {
    self.ignoresMouseEvents = false
    self.alphaValue = 1.0
    NSApp.setActivationPolicy(.regular)
    super.orderFront(sender)
  }

  func windowShouldClose(_ sender: NSWindow) -> Bool {
    // Hide window and Dock icon, keep the app running.
    self.orderOut(nil)
    NSApp.setActivationPolicy(.accessory)
    return false
  }
}
