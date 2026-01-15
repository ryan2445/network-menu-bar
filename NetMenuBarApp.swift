import ServiceManagement
import SwiftUI

@main

struct NetMenuBarApp: App {
  @StateObject private var monitor = NetworkRateMonitor()
  @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

  var body: some Scene {
    MenuBarExtra {
      VStack(spacing: 8) {
        Text("Up:   \(monitor.uploadText)")
        Text("Down: \(monitor.downloadText)")
        Divider()
        Toggle("Launch at Login", isOn: $launchAtLogin)
          .onChange(of: launchAtLogin) { _, newValue in
            do {
              if newValue {
                try SMAppService.mainApp.register()
              } else {
                try SMAppService.mainApp.unregister()
              }
            } catch {
              launchAtLogin = SMAppService.mainApp.status == .enabled
            }
          }
        Divider()
        Button("Quit") { NSApplication.shared.terminate(nil) }
      }.padding(12)
    } label: {
      Image(nsImage: createImage(up: monitor.uploadCompact, down: monitor.downloadCompact))
    }
  }

  private func createImage(up: String, down: String) -> NSImage {
    let width = 66
    let height = 22

    let text = "↑ \(up)\n↓ \(down)"
    let font = NSFont.monospacedSystemFont(ofSize: 8, weight: .regular)
    let textAttributes: [NSAttributedString.Key: Any] = [
      .font: font,
      .foregroundColor: NSColor.labelColor,
    ]
    let attributedString = NSAttributedString(string: text, attributes: textAttributes)

    let image = NSImage(size: NSSize(width: width, height: height))

    image.lockFocus()
    let textSize = attributedString.size()
    let y = (CGFloat(height) - textSize.height) / 2
    let rect = NSRect(x: 0, y: y, width: CGFloat(width), height: textSize.height)
    attributedString.draw(in: rect)
    image.unlockFocus()

    return image
  }
}
