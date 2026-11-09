# MacFalcon releases

[中文](#中文) · [English](#english)

## 中文

默认 Release 流程**不需要 Apple Developer Program**：GitHub Actions 构建 arm64 + x86_64 通用 DMG，以临时签名（ad-hoc）保护包的完整性，并生成 SHA-256 校验文件。临时签名不能证明开发者身份；发行包未经 Apple 公证。macOS 首次打开时会出现安全提示，用户在确认下载来源可信后，需要按照 [Apple 的说明](https://support.apple.com/zh-cn/102445)手动在“系统设置 → 隐私与安全性”允许打开。受管理的 Mac 可能不允许此操作。

### 免费发布

1. 更新 `VERSION` 为 `MAJOR.MINOR.PATCH` 格式，提交并推送到 `main`；等待 **Build and test** 通过。
2. 创建并推送匹配版本的 tag，例如 `git tag v0.1.0`，然后 `git push origin v0.1.0`。
3. **Release (ad-hoc signed)** 工作流自动测试、构建通用应用、打包并验证 DMG，然后将 DMG、`SHA256SUMS.txt` 和中英文说明发布到 GitHub Releases。仓库需允许 Actions 且允许工作流写入 Contents。若 Release 已存在，工作流会停止，不覆盖现有资产。
4. 从 Releases 下载并在干净的 Apple Silicon 和 Intel Mac 上验证安装与首次启动。Intel 已编译，但目前还没有 Intel 真机运行验证。

### 可选：以后改为 Developer ID 与公证

如以后加入 Apple Developer Program，可使用手动触发的 **Optional notarized release** 工作流。它要求一个尚未发布的版本 tag，不能覆盖现有 Release；不要同时用默认工作流为同一个 tag 发布。需要在仓库 **Settings → Secrets and variables → Actions** 设置下列 Secrets：

| Secret | 内容 |
| --- | --- |
| `APPLE_SIGNING_IDENTITY` | Developer ID Application 完整签名身份 |
| `APPLE_CERTIFICATE_BASE64` | 含私钥的 `.p12` Base64 文本 |
| `APPLE_CERTIFICATE_PASSWORD` | `.p12` 导出密码 |
| `APPLE_ID` | Apple 账户 |
| `APPLE_TEAM_ID` | Apple Developer Team ID |
| `APPLE_APP_SPECIFIC_PASSWORD` | Apple app-specific password |

不要将证书、私钥或密码提交到仓库，也不要在聊天中发送。保护发布 tag 并限制工作流使用者。公证后仍需在两种架构的干净机器上验证。可使用 `scripts/notarize-release.sh` 进行同样的本地流程。

## English

The default release workflow **does not require the Apple Developer Program**. GitHub Actions builds a universal DMG with an ad-hoc signature and SHA-256 checksum. Ad-hoc signing does not establish developer identity and the app is not notarized by Apple. On first launch macOS shows a security warning. If you trust the download, follow [Apple's instructions](https://support.apple.com/en-us/102445) to open it via System Settings → Privacy & Security. Managed devices may not permit this exception.

Update `VERSION`, push to `main`, then push the matching version tag (for example `v0.1.0`). **Release (ad-hoc signed)** tests, builds, packages, and publishes the DMG and checksum. Existing releases are never overwritten. Verify downloads on clean Apple Silicon and Intel machines; Intel has only been compiled so far.

If you later obtain a Developer ID Application certificate and Apple notarization credentials, the manually triggered **Optional notarized release** workflow supports a new, unpublished tag. It requires the six secrets in the table above. Do not commit or share credentials in chat. Protect release tags and restrict who can run signing workflows.
