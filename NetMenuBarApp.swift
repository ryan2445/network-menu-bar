import SwiftUI

@main

struct NetMenuBarApp: App {
  @StateObject private var monitor = NetworkRateMonitor()

  var body: some Scene {
    MenuBarExtra {
      VStack(spacing: 8) {
        Text("Down: \(monitor.downloadText)")
        Text("Up:   \(monitor.uploadText)")
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
      .foregroundColor: NSColor.labelColor
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
