<div align="center">
  <img src="Assets/AppIcon-preview.png" width="96" alt="MacFalcon icon">
  <h1>MacFalcon</h1>
  <p><strong>A clearer view of your Mac.</strong><br>A native, privacy-minded system monitor for macOS.</p>
  <p><a href="README.md">简体中文</a> · <a href="README.en.md">English</a> · <a href="https://github.com/7inspire/MacFalcon/releases">Download Releases</a></p>
  <p><img alt="macOS 13+" src="https://img.shields.io/badge/macOS-13%2B-242d30"> <img alt="Apple Silicon and Intel" src="https://img.shields.io/badge/Apple%20Silicon%20%2B%20Intel-universal-176f59"> <a href="LICENSE"><img alt="MIT License" src="https://img.shields.io/badge/license-MIT-176f59"></a></p>
</div>

![MacFalcon artwork: a clearer view of your Mac](Assets/banner.svg)

MacFalcon brings process management, performance monitoring, and everyday diagnostics together in one native app. Built with SwiftUI and macOS system APIs, it keeps data on your Mac and requires neither Electron nor a privileged background service. Its feature direction is inspired by [Argus](https://github.com/Ray-lea/Argus), a Windows project; this is an independent implementation.

## Download and install

1. Download the latest `MacFalcon-<version>-universal.dmg` from [Releases](https://github.com/7inspire/MacFalcon/releases).
2. Open the disk image, drag **MacFalcon** to **Applications**, and open it from your Applications folder.

Official release packages are intended to be signed with Developer ID and notarized by Apple; no package will be presented as an official release until those steps are complete. Requires **macOS 13 or later**. Universal builds contain Apple Silicon and Intel binaries; the Intel build has been compiled but still needs testing on a physical Intel Mac.

Optional integrity check: place the downloaded DMG and `SHA256SUMS.txt` in the same directory, then run `shasum -a 256 -c SHA256SUMS.txt`.

## Features

| Feature | What it does |
| --- | --- |
| Processes | List, tree, or app groups; search and sort; inspect arguments, resources, parent, and threads; confirm before ending processes or trees; adjust nice and configure rules. |
| Performance | CPU and per-core usage, memory and swap, disk capacity and throughput, network speeds; GPU utilization and battery information where supported. |
| Diagnostics | Inspect TCP/UDP connections and ports on demand, and find processes holding a file or folder. |
| History | Keep up to seven days of minute-level samples and the busiest processes locally; browse or clear them. |
| System integration | Menu bar, optional launch at login, and current-user launchd service inspection and control. |
| Personalization | System, light, and dark appearance; four accent colors; English, Simplified Chinese, or the system language. |

The default sampling interval is three seconds. Sampling pauses while all windows are hidden or minimized; an optional setting enables once-per-minute background sampling. Use `⌘1` through `⌘8` to navigate. Actual resource usage depends on hardware, process count, page, and interval.

## Build from source

Requires macOS 13+ and Xcode or Xcode Command Line Tools:

```sh
git clone https://github.com/7inspire/MacFalcon.git
cd MacFalcon
swift test
./scripts/build-app.sh
open dist/MacFalcon.app
```

The default build targets the host architecture; use `MACFALCON_UNIVERSAL=1 ./scripts/build-app.sh` for a universal build. Local builds are ad-hoc signed and are not notarized releases. See the [release guide](docs/RELEASING.md) for signing and distribution.

## Privacy and limitations

- Samples and history stay on your Mac. There is no telemetry or automatic update check. History is stored at `~/Library/Application Support/MacFalcon/history.sqlite3`. On upgrade from the earlier Pulse build, supported settings and history are copied while the old data is retained.
- Operations run with the current user's permissions; protected processes, files, ports, and services can be hidden or inaccessible. File and connection diagnostics invoke the system `lsof` on demand; recursive folder scans may be slow.
- GPU utilization, battery capacity, and related readings come from device registry properties and vary by hardware; they are not Apple's official battery-health assessment. Network totals may double-count VPN or virtual interfaces; app-group memory sums may double-count shared pages.
- Ending a process tree uses a snapshot and is not atomic; ending processes or stopping services can lose data or trigger restarts. CPU temperature, power, SMART details, and per-process network traffic are not implemented. See the [roadmap](ROADMAP.md).

## Feedback and license

Please use [Issues](https://github.com/7inspire/MacFalcon/issues) for bug reports and ideas. MacFalcon is available under the [MIT License](LICENSE).
