## MacFalcon

Native macOS system monitoring and process management · 原生 macOS 系统监视与进程管理

### Install / 安装

Download the Apple Silicon DMG, open it, and drag MacFalcon to Applications. Requires an Apple Silicon Mac and macOS 13 or later. The app is ad-hoc signed and is **not signed with Developer ID or notarized by Apple**. macOS will show a security warning; if you trust the download, try to open it once, then use System Settings → Privacy & Security → Open Anyway.

下载 Apple Silicon DMG，打开后将 MacFalcon 拖入“应用程序”。需要 Apple Silicon 芯片及 macOS 13 或更高版本。此应用为临时签名，**未使用 Developer ID 签名，也未经 Apple 公证**。首次打开会出现安全提示；确认信任下载来源后，可先尝试打开，再前往“系统设置 → 隐私与安全性 → 仍要打开”。

### Changes / 更新

- Add in-app update checks, background downloads, and installation with Sparkle.
- Verify both update feeds and downloaded packages with EdDSA signatures.
- 新增应用内更新检查、后台下载和安装功能。
- 更新源及下载包均使用 EdDSA 签名验证。

This is the first Sparkle-enabled release. Install it once from this page; subsequent versions can update in the app.

这是首个支持 Sparkle 自动更新的正式版本，请先从本页面安装；后续版本可在应用内更新。

### Highlights / 主要功能

- Process list, tree and app groups; process actions and priority rules.
- CPU, memory, disk and network monitoring, with available GPU and battery metrics.
- On-demand port and open-file diagnostics; seven-day local history.
- Menu bar, light/dark appearance, Chinese and English.
- 进程列表、进程树和应用分组；进程操作及优先级规则。
- CPU、内存、磁盘、网络，以及设备支持时的 GPU 和电池指标。
- 按需查询端口与文件占用；本机保留七天历史。
- 菜单栏、浅色与深色外观、中英文界面。

All operations use current-user permissions. Hardware coverage and protected-process visibility vary. See the README for limitations.

所有操作使用当前用户权限；硬件支持和受保护进程的可见性因系统而异，限制详见 README。
