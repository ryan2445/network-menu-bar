import Darwin
import Foundation

// Test 1: Scaling boundary checks
func testScaling() {
  func scaled(_ bytesPerSec: Double) -> (Double, String) {
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

  let (bVal, bUnit) = scaled(500)
  assert(bUnit == "B/s" && bVal == 500, "Failed 500 B/s")

  let (_, subUnit) = scaled(999.9)
  assert(subUnit == "B/s", "Failed 999.9 B/s")

  let (_, kbUnit) = scaled(999.999)
  assert(kbUnit == "KB/s", "Failed threshold roll to KB/s, got \(kbUnit)")

  let (mbVal, mbUnit) = scaled(5_000_000)
  assert(mbUnit == "MB/s" && mbVal == 5.0, "Failed 5 MB/s")

  let (gbVal, gbUnit) = scaled(2_500_000_000)
  assert(gbUnit == "GB/s" && gbVal == 2.5, "Failed 2.5 GB/s")

  print("✓ Scaling tests passed")
}

// Test 2: 64-bit kernel interface statistics via NET_RT_IFLIST2
func testKernelInterfaceStats() {
  var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
  var len: Int = 0
  let res = sysctl(&mib, UInt32(mib.count), nil, &len, nil, 0)
  assert(res == 0 && len > 0, "sysctl NET_RT_IFLIST2 failed")

  let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: len)
  defer { buffer.deallocate() }

  let resData = sysctl(&mib, UInt32(mib.count), buffer, &len, nil, 0)
  assert(resData == 0, "sysctl buffer populate failed")

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

  assert(inBytes > 0, "Expected non-zero inBytes on active interface")
  print("✓ 64-bit Kernel Interface Stats query passed (In: \(inBytes), Out: \(outBytes))")
}

testScaling()
testKernelInterfaceStats()
print("All unit tests passed successfully!")
