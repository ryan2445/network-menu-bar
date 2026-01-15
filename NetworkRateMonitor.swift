import Foundation
import SystemConfiguration

@MainActor
final class NetworkRateMonitor: ObservableObject {
  @Published private(set) var downloadBytesPerSecond: Double = 0
  @Published private(set) var uploadBytesPerSecond: Double = 0

  private var task: Task<Void, Never>?
  private var lastSample: (timestamp: TimeInterval, inputBytes: UInt64, outBytes: UInt64)?

  var downloadText: String { formatRate(bytesPerSec: downloadBytesPerSecond) }
  var uploadText: String { formatRate(bytesPerSec: uploadBytesPerSecond) }
  var downloadCompact: String { formatCompact(bytesPerSec: downloadBytesPerSecond) }
  var uploadCompact: String { formatCompact(bytesPerSec: uploadBytesPerSecond) }

  init(sampleInterval: TimeInterval = 5.0) {
    task = Task {
      while !Task.isCancelled {
        await self.updateRates()
        try? await Task.sleep(for: .seconds(sampleInterval))
      }
    }
  }

  deinit {
    task?.cancel()
  }

  private func updateRates() async {
    let now = Date().timeIntervalSince1970
    let totals = await Task.detached { Self.readTotals() }.value

    guard let last = lastSample else {
      lastSample = (now, totals.inBytes, totals.outBytes)
      return
    }

    let time_diff = now - last.timestamp
    guard time_diff > 0 else { return }

    let input_difference = totals.inBytes &- last.inputBytes
    let output_difference = totals.outBytes &- last.outBytes

    lastSample = (now, totals.inBytes, totals.outBytes)

    self.downloadBytesPerSecond = Double(input_difference) / time_diff
    self.uploadBytesPerSecond = Double(output_difference) / time_diff
  }

  // Reads total in/out bytes across interfaces (excluding loopback)
  private nonisolated static func readTotals() -> (inBytes: UInt64, outBytes: UInt64) {
    var interfaces: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&interfaces) == 0 else {
      return (0, 0)
    }
    defer { freeifaddrs(interfaces) }

    var inBytes: UInt64 = 0
    var outBytes: UInt64 = 0

    var currentInterface = interfaces
    while currentInterface != nil {
      let interface = currentInterface!.pointee

      // Only consider link-layer stats
      let flags = Int32(interface.ifa_flags)
      let isUp = (flags & IFF_UP) != 0
      let isRunning = (flags & IFF_RUNNING) != 0
      let isLoopback = (flags & IFF_LOOPBACK) != 0

      if isUp && isRunning && !isLoopback {
        if let data = interface.ifa_data {
          // if_data holds byte counters
          let ifd = data.assumingMemoryBound(to: if_data.self).pointee
          inBytes &+= UInt64(ifd.ifi_ibytes)
          outBytes &+= UInt64(ifd.ifi_obytes)
        }
      }

      currentInterface = interface.ifa_next
    }

    return (inBytes, outBytes)
  }

  private func formatCompact(bytesPerSec: Double) -> String {
    let (value, unit) = scaled(bytesPerSec)
    return String(format: "%6.2f %@", value, unit)
  }

  private func formatRate(bytesPerSec: Double) -> String {
    let (value, unit) = scaled(bytesPerSec)
    let mbps = (bytesPerSec * 8) / 1_000_000.0
    return String(format: "%.2f %@  (%.2f Mbps)", value, unit, mbps)
  }

  private func scaled(_ bytesPerSec: Double) -> (Double, String) {
    let absVal = abs(bytesPerSec)
    switch absVal {
    case 0..<1_000:
      return (bytesPerSec, "B/s")
    case 1_000..<1_000_000:
      return (bytesPerSec / 1_000, "KB/s")
    case 1_000_000..<1_000_000_000:
      return (bytesPerSec / 1_000_000, "MB/s")
    default:
      return (bytesPerSec / 1_000_000_000, "GB/s")
    }
  }
}
