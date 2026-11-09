# MacFalcon releases

[中文](#中文) · [English](#english)

## 中文

Release 工作流只发布 **Developer ID 签名并经 Apple 公证**的通用 DMG；缺少凭据时会失败，不会悄悄发布未公证的安装包。GitHub SSH 密钥只能用于 Git 推送，不能替代 Apple 签名凭据。

### 一次性准备

1. 加入 Apple Developer Program，创建 **Developer ID Application** 证书及包含私钥的 `.p12`；记录证书签名身份和 Team ID。
2. 为 Apple 账户创建 app-specific password。不要把证书、私钥或密码提交到仓库，也不要在聊天中发送。
3. 在 GitHub 仓库 **Settings → Secrets and variables → Actions → New repository secret** 中设置：

| Secret | 内容 |
| --- | --- |
| `APPLE_SIGNING_IDENTITY` | Developer ID Application 完整签名身份，例如 `Developer ID Application: Name (TEAMID)` |
| `APPLE_CERTIFICATE_BASE64` | 包含私钥的 `.p12` 文件的 Base64 文本 |
| `APPLE_CERTIFICATE_PASSWORD` | `.p12` 导出密码 |
| `APPLE_ID` | 用于公证的 Apple 账户 |
| `APPLE_TEAM_ID` | Apple Developer Team ID |
| `APPLE_APP_SPECIFIC_PASSWORD` | Apple 账户的 app-specific password |

通过安全渠道在本机将 `.p12` 编码后粘贴到 GitHub Secret；不要把生成的文本或 `.p12` 写入项目目录。确认仓库允许 GitHub Actions，并允许工作流写入 Contents。建议保护发布 tag，限制可创建 tag 的人员，因为发布工作流可以使用签名证书。

### 发布版本

1. 更新 `VERSION`，提交并推送变更；值必须是 `MAJOR.MINOR.PATCH`。
2. 等待主分支的 **Build and test** 工作流通过。
3. 创建并推送相同版本的 tag，例如 `git tag v0.1.0 && git push origin v0.1.0`。
4. **Signed release** 工作流会运行测试、构建 arm64 + x86_64、签名、公证并装订应用和 DMG，然后发布 DMG、SHA-256 校验文件和自动生成的版本说明。缺少任一密钥、公证失败或 Release 已存在时会停止，不会覆盖现有 Release。
5. 在干净的 Apple Silicon 和 Intel Mac 上下载、打开 DMG，验证 Gatekeeper、拖放安装、运行和升级；在 Intel 真机通过前，不要宣称两种架构都经过运行验证。

工作流需要网络访问 Apple 公证服务。证书过期、撤销或密码变更后需要更新相应 Secret。对已有版本的修复应使用新版本和新 tag。

## English

The release workflow publishes a universal DMG **only after Developer ID signing and Apple notarization**. Missing credentials fail the workflow; it never silently publishes an unnotarized package. A GitHub SSH key authenticates Git pushes but cannot replace Apple signing credentials.

1. Join the Apple Developer Program and obtain a **Developer ID Application** certificate exported as a `.p12` with its private key. Create an app-specific password for notarization.
2. Add the six repository Actions secrets listed in the table above. Never commit certificates or passwords or share them in chat. Allow Actions and Contents write access; protect release tags so only trusted maintainers can use the signing credentials.
3. Update `VERSION` (`MAJOR.MINOR.PATCH`), commit, push, and wait for CI. Push the matching tag, for example `v0.1.0`.
4. The workflow tests, builds arm64 and x86_64, signs and notarizes both the app and DMG, staples their tickets, and publishes the DMG and checksum. It refuses to overwrite an existing release.
5. Test the downloaded package and upgrade on clean Apple Silicon and Intel Macs. Intel has only been compiled so far, not runtime-tested on physical hardware.
