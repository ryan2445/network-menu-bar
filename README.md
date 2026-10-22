# Network Menu Bar

A lightweight, high-performance macOS menu bar application that displays real-time network upload and download speeds.

![macOS 14+](https://img.shields.io/badge/macOS-14.0%2B-blue)
![Swift 6](https://img.shields.io/badge/Swift-6.3-orange.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

---

## 🚀 Installation

### Option 1: Drag & Drop (Recommended)

1. Download `NetworkMenuBar.dmg` from the latest [GitHub Releases](https://github.com/ryan/network-menu-bar/releases).
2. Double-click the DMG and drag **Network Menu Bar** into your **Applications** folder.
3. Launch **Network Menu Bar** from Applications or Spotlight.

> **Note on macOS Security:**
> If macOS displays an unidentified developer warning on first launch, right-click **Network Menu Bar.app** in Applications and select **Open**, or run:
>
> ```bash
> xattr -cr "/Applications/Network Menu Bar.app"
> ```

### Option 2: Build & Install from Source

Requirements: macOS 14.0 or later with Swift / Xcode Command Line Tools installed.

```bash
# Clone the repository
git clone https://github.com/ryan/network-menu-bar.git
cd network-menu-bar

# Build the release bundle
./build-app.sh

# Copy to Applications
cp -r "Network Menu Bar.app" /Applications/
```

To also generate the distribution DMG and ZIP packages locally:

```bash
./build-app.sh --dmg 1.0.0
```

---

## 📄 License

MIT License. See [LICENSE](LICENSE) for details if applicable.
