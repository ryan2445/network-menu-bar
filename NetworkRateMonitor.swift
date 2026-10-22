import Darwin
import Foundation

/// Snapshot representing a point-in-time network rate measurement.
public struct NetworkRateSnapshot: Sendable, Equatable {
  public let downloadBytesPerSecond: Double
  public let uploadBytesPerSecond: Double
  public let downloadText: String
  public let uploadText: String
  public let downloadCompact: String
  public let uploadCompact: String

  public init(
    downloadBytesPerSecond: Double = 0,
    uploadBytesPerSecond: Double = 0,
    downloadText: String = "0.00 B/s  (0.00 Mbps)",
    uploadText: String = "0.00 B/s  (0.00 Mbps)",
    downloadCompact: String = "  0.00 B/s",
    uploadCompact: String = "  0.00 B/s"
  ) {
    self.downloadBytesPerSecond = downloadBytesPerSecond
    self.uploadBytesPerSecond = uploadBytesPerSecond
    self.downloadText = downloadText
    self.uploadText = uploadText
    self.downloadCompact = downloadCompact
    self.uploadCompact = uploadCompact
  }
}

@MainActor
public final class NetworkRateMonitor: ObservableObject {
  @Published public private(set) var snapshot: NetworkRateSnapshot = NetworkRateSnapshot()

  // Backward-compatible accessors
  public var downloadBytesPerSecond: Double { snapshot.downloadBytesPerSecond }
  public var uploadBytesPerSecond: Double { snapshot.uploadBytesPerSecond }
  public var downloadText: String { snapshot.downloadText }
  public var uploadText: String { snapshot.uploadText }
  public var downloadCompact: String { snapshot.downloadCompact }
  public var uploadCompact: String { snapshot.uploadCompact }

  private var task: Task<Void, Never>?
  private var lastSample: (timestamp: TimeInterval, inputBytes: UInt64, outBytes: UInt64)?

  public init(sampleInterval: TimeInterval = 5.0) {
    task = Task { [weak self] in
      while !Task.isCancelled {
        await self?.updateRates()
        try? await Task.sleep(for: .seconds(sampleInterval))
      }
    }
  }

  deinit {
    task?.cancel()
  }

  public func updateRates() async {
    let now = Date().timeIntervalSince1970
    // Query 64-bit interface statistics directly via sysctl kernel call (sub-millisecond)
    let totals = Self.readTotals()

    guard let last = lastSample else {
      lastSample = (now, totals.inBytes, totals.outBytes)
      return
    }

    let timeDiff = now - last.timestamp
    guard timeDiff > 0 else { return }

    // Using true 64-bit counters from if_data64, avoiding 32-bit rollover false spikes
    let inputDifference = totals.inBytes >= last.inputBytes
      ? (totals.inBytes - last.inputBytes)
      : 0
    let outputDifference = totals.outBytes >= last.outBytes
      ? (totals.outBytes - last.outBytes)
      : 0

    lastSample = (now, totals.inBytes, totals.outBytes)

    let downRate = Double(inputDifference) / timeDiff
    let upRate = Double(outputDifference) / timeDiff

    let newSnapshot = NetworkRateSnapshot(
      downloadBytesPerSecond: downRate,
      uploadBytesPerSecond: upRate,
      downloadText: Self.formatRate(bytesPerSec: downRate),
      uploadText: Self.formatRate(bytesPerSec: upRate),
      downloadCompact: Self.formatCompact(bytesPerSec: downRate),
      uploadCompact: Self.formatCompact(bytesPerSec: upRate)
    )

    // Atomically update snapshot once per interval, avoiding redundant SwiftUI invalidations
    if self.snapshot != newSnapshot {
      self.snapshot = newSnapshot
    }
  }

  /// Reads total network byte counters using 64-bit kernel statistics (NET_RT_IFLIST2).
  /// Excludes loopback and down/inactive interfaces.
  public nonisolated static func readTotals() -> (inBytes: UInt64, outBytes: UInt64) {
    if let totals = readTotalsSysctl() {
      return totals
    }
    return readTotalsGetifaddrs()
  }

  private nonisolated static func readTotalsSysctl() -> (inBytes: UInt64, outBytes: UInt64)? {
    var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
    var len: Int = 0
    guard sysctl(&mib, UInt32(mib.count), nil, &len, nil, 0) == 0, len > 0 else {
      return nil
    }

    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: len)
    defer { buffer.deallocate() }

    guard sysctl(&mib, UInt32(mib.count), buffer, &len, nil, 0) == 0 else {
      return nil
    }

    var inBytes: UInt64 = 0
    var outBytes: UInt64 = 0
    var cursor = buffer
    let end = buffer + len

    while cursor < end {
      let msg = cursor.withMemoryRebound(to: if_msghdr2.self, capacity: 1) { $0.pointee }
      guard msg.ifm_msglen > 0 else { break }

      if msg.ifm_type == RTM_IFINFO2 {
        let flags = Int32(msg.ifm_flags)
        let isUp = (flags & IFF_UP) != 0
        let isRunning = (flags & IFF_RUNNING) != 0
        let isLoopback = (flags & IFF_LOOPBACK) != 0

        if isUp && isRunning && !isLoopback {
          inBytes &+= msg.ifm_data.ifi_ibytes
          outBytes &+= msg.ifm_data.ifi_obytes
        }
      }

      cursor += Int(msg.ifm_msglen)
    }

    return (inBytes, outBytes)
  }

  /// Fallback reader using getifaddrs, strictly filtering for AF_LINK interfaces.
  private nonisolated static func readTotalsGetifaddrs() -> (inBytes: UInt64, outBytes: UInt64) {
    var interfaces: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&interfaces) == 0, let first = interfaces else {
      return (0, 0)
    }
    defer { freeifaddrs(first) }

    var inBytes: UInt64 = 0
    var outBytes: UInt64 = 0
    var current: UnsafeMutablePointer<ifaddrs>? = first

    while let ptr = current {
      let interface = ptr.pointee

      if let addr = interface.ifa_addr, addr.pointee.sa_family == UInt8(AF_LINK) {
        let flags = Int32(interface.ifa_flags)
        let isUp = (flags & IFF_UP) != 0
        let isRunning = (flags & IFF_RUNNING) != 0
        let isLoopback = (flags & IFF_LOOPBACK) != 0

        if isUp && isRunning && !isLoopback, let data = interface.ifa_data {
          let ifd = data.assumingMemoryBound(to: if_data.self).pointee
          inBytes &+= UInt64(ifd.ifi_ibytes)
          outBytes &+= UInt64(ifd.ifi_obytes)
        }
      }

      current = interface.ifa_next
    }

    return (inBytes, outBytes)
  }

  public static func formatCompact(bytesPerSec: Double) -> String {
    let (value, unit) = scaled(bytesPerSec)
    return String(format: "%6.2f %@", value, unit)
  }

  public static func formatRate(bytesPerSec: Double) -> String {
    let (value, unit) = scaled(bytesPerSec)
    let mbps = (bytesPerSec * 8.0) / 1_000_000.0
    return String(format: "%.2f %@  (%.2f Mbps)", value, unit, mbps)
  }

  public static func scaled(_ bytesPerSec: Double) -> (Double, String) {
    let absVal = abs(bytesPerSec)
    if absVal < 999.995 {
      return (bytesPerSec, "B/s")
    } else if absVal < 999_995.0 {
      return (bytesPerSec / 1_000.0, "KB/s")
    } else if absVal < 999_995_000.0 {
      return (bytesPerSec / 1_000_000.0, "MB/s")
    } else {
      return (bytesPerSec / 1_000_000_000.0, "GB/s")
    }
  }
}
