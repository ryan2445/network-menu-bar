import ServiceManagement
import SwiftUI

@main
struct NetMenuBarApp: App {
  @StateObject private var monitor = NetworkRateMonitor()
  @State private var launchAtLogin: Bool = (SMAppService.mainApp.status == .enabled)
  @State private var cachedImage: NSImage?
  @State private var lastRenderedKey: String = ""

  init() {
    Self.ensureLaunchAtLoginOnStartup()
  }

  var body: some Scene {
    MenuBarExtra {
      VStack(alignment: .leading, spacing: 8) {
        Text("Up:   \(monitor.uploadText)")
          .font(.system(.body, design: .monospaced))
        Text("Down: \(monitor.downloadText)")
          .font(.system(.body, design: .monospaced))

        Divider()

        Toggle("Launch at Login", isOn: $launchAtLogin)
          .onChange(of: launchAtLogin) { _, newValue in
            handleLaunchAtLoginChange(enabled: newValue)
          }

        if SMAppService.mainApp.status == .requiresApproval {
          Button("Open Login Items Settings…") {
            SMAppService.openSystemSettingsLoginItems()
          }
          .font(.caption)
        }

        Divider()

        Button("Quit") {
          NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
      }
      .padding(12)
    } label: {
      Image(nsImage: menuBarIcon(up: monitor.uploadCompact, down: monitor.downloadCompact))
    }
  }

  // MARK: - Launch at Login Management

  private static let explicitlyDisabledKey = "hasExplicitlyDisabledLaunchAtLogin"

  private static func ensureLaunchAtLoginOnStartup() {
    let explicitlyDisabled = UserDefaults.standard.bool(forKey: explicitlyDisabledKey)
    if !explicitlyDisabled {
      let service = SMAppService.mainApp
      if service.status != .enabled {
        do {
          try service.register()
        } catch {
          // If registration fails on startup (e.g. running unbundled in dev), log non-fatally
          NSLog("[NetMenuBar] Launch at login registration: %@", error.localizedDescription)
        }
      }
    }
  }

  private func handleLaunchAtLoginChange(enabled: Bool) {
    let service = SMAppService.mainApp
    do {
      if enabled {
        UserDefaults.standard.set(false, forKey: Self.explicitlyDisabledKey)
        try service.register()
      } else {
        UserDefaults.standard.set(true, forKey: Self.explicitlyDisabledKey)
        try service.unregister()
      }
    } catch {
      NSLog("[NetMenuBar] Failed to toggle launch at login: %@", error.localizedDescription)
      launchAtLogin = (service.status == .enabled)
    }
  }

  // MARK: - Menu Bar Image Rendering & Memoization

  private func menuBarIcon(up: String, down: String) -> NSImage {
    let key = "\(up)|\(down)"
    if let cached = cachedImage, lastRenderedKey == key {
      return cached
    }

    let image = Self.createVectorImage(up: up, down: down)
    DispatchQueue.main.async {
      self.cachedImage = image
      self.lastRenderedKey = key
    }
    return image
  }

  private static let monospacedFont = NSFont.monospacedDigitSystemFont(ofSize: 8, weight: .regular)

  private static func createVectorImage(up: String, down: String) -> NSImage {
    let width: CGFloat = 66
    let height: CGFloat = 22
    let text = "↑ \(up)\n↓ \(down)"

    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.lineBreakMode = .byClipping
    paragraphStyle.alignment = .left

    let textAttributes: [NSAttributedString.Key: Any] = [
      .font: monospacedFont,
      .foregroundColor: NSColor.labelColor,
      .paragraphStyle: paragraphStyle,
    ]
    let attributedString = NSAttributedString(string: text, attributes: textAttributes)
    let textSize = attributedString.size()

    // Modern drawingHandler creates a resolution-independent vector image
    // that renders sharply at Retina 2x/3x scale factors without blurry 1x rasterization.
    let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { bounds in
      let y = (bounds.height - textSize.height) / 2.0
      let rect = NSRect(x: 0, y: y, width: bounds.width, height: textSize.height)
      attributedString.draw(in: rect)
      return true
    }

    // Setting isTemplate to true enables automatic macOS menu bar styling,
    // including Dark Mode, Light Mode, and inverted selection colors when active.
    image.isTemplate = true
    return image
  }
}
