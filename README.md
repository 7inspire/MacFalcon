<div align="center">
  <img src="Assets/AppIcon-preview.png" width="96" alt="MacFalcon icon">
  <h1>MacFalcon</h1>
  <p><strong>一款轻量级的 Mac 活动监视器替代工具，速度快如猎隼。</strong><br>A lightweight Mac Activity Monitor alternative, fast like a Falcon.</p>
  <p><a href="README.md">简体中文</a> · <a href="README.en.md">English</a> · <a href="https://github.com/7inspire/MacFalcon/releases">下载 Releases</a></p>
  <p><img alt="macOS 13+" src="https://img.shields.io/badge/macOS-13%2B-242d30"> <img alt="Apple Silicon and Intel" src="https://img.shields.io/badge/Apple%20Silicon%20%2B%20Intel-universal-176f59"> <a href="LICENSE"><img alt="MIT License" src="https://img.shields.io/badge/license-MIT-176f59"></a></p>
</div>

![MacFalcon artwork: a clearer view of your Mac](Assets/banner.svg)

MacFalcon 将进程管理、性能监控和日常排障放进一个原生应用。它使用 SwiftUI 和 macOS 系统接口，数据保存在本机，不依赖 Electron 或后台特权服务。本项目为独立实现。

## 界面预览

**外观与采样设置** — 选择界面模式、强调色、语言和刷新间隔。

![MacFalcon 外观与采样设置界面](Assets/screenshots/settings-zh.jpg)

**诊断** — 按需查找连接、端口和文件占用。

![MacFalcon 诊断界面](Assets/screenshots/diagnostics-zh.jpg)

## 下载与安装

1. 在 [Releases](https://github.com/7inspire/MacFalcon/releases) 下载最新的 `MacFalcon-<版本>-universal.dmg`。
2. 打开磁盘映像，将 **MacFalcon** 拖到 **Applications**，再从应用程序文件夹打开。

目前发布包使用临时签名，**未经 Developer ID 签名或 Apple 公证**。首次打开时 macOS 会显示安全提示；确认下载来源可信后，可先尝试打开，再前往“系统设置 → 隐私与安全性 → 仍要打开”。这一操作会为该应用建立安全例外；受管理设备可能不允许。详见 [Apple 说明](https://support.apple.com/zh-cn/102445)。系统要求为 **macOS 13 或更新版本**，通用构建包含 Apple Silicon 和 Intel 架构。Intel 架构已编译，尚需在真实 Intel Mac 上进行运行验证。

可选校验：将下载的 DMG 与 `SHA256SUMS.txt` 放在同一目录，运行 `shasum -a 256 -c SHA256SUMS.txt`。

## 能做什么

| 功能 | 说明 |
| --- | --- |
| 进程 | 列表、树状和应用分组；搜索与排序，查看参数、资源、父进程和线程；确认后结束进程或进程树，调整 nice 和设置规则。 |
| 性能 | CPU 与逐核心、内存、交换空间、磁盘容量与吞吐量、网络速率；支持的设备可显示 GPU 利用率和电池信息。 |
| 排障 | 按需查询 TCP/UDP 连接与端口，查找文件或目录的占用进程。 |
| 历史 | 本机保存最多 7 天的分钟级采样与当时最活跃的进程，可查看和清除。 |
| 系统集成 | 菜单栏、可选登录启动、当前用户 launchd 服务查看与控制。 |
| 个性化 | 跟随系统、浅色或深色模式，四种强调色；支持简体中文、英文及跟随系统语言。 |

默认每 3 秒采样；窗口隐藏或最小化时暂停采样，可在设置中选择每分钟后台采样。按 `⌘1` 至 `⌘8` 切换页面。实际资源开销因设备、进程数量和刷新间隔而异。


## 从源码构建

需要 macOS 13+ 和 Xcode 或 Xcode Command Line Tools：

```sh
git clone https://github.com/7inspire/MacFalcon.git
cd MacFalcon
swift test
./scripts/build-app.sh
open dist/MacFalcon.app
```

默认构建当前机器架构；运行 `MACFALCON_UNIVERSAL=1 ./scripts/build-app.sh` 构建通用版本。本地构建仅使用临时签名，不等同于公证后的发行包。发布流程和签名配置见 [发布指南](docs/RELEASING.md)。

## 隐私与限制

- 采样数据和历史记录保存在本机，应用没有遥测或自动更新。历史数据库位于 `~/Library/Application Support/MacFalcon/history.sqlite3`。从旧版 Pulse 升级时会复制历史并迁移支持的设置，保留旧数据。
- 所有操作使用当前用户权限；受保护的进程、文件、端口和服务可能不可见或无法操作。文件和连接查询按需调用系统 `lsof`；目录递归扫描可能较慢。
- GPU 利用率、电池容量等来自设备注册表，支持情况依机型而异，不等同于 Apple 官方健康评估。网络汇总可能重复计算 VPN 或虚拟接口；应用分组内存会重复计算共享页。
- 进程树终止根据快照操作且不是原子操作；结束进程和停止服务可能造成数据丢失或服务重启。CPU 温度、功耗、SMART 明细及每进程网络流量尚未实现。详见 [功能路线图](ROADMAP.md)。

## 反馈与许可证

欢迎通过 [Issues](https://github.com/7inspire/MacFalcon/issues) 提交问题和建议。MacFalcon 使用 [MIT License](LICENSE)。
