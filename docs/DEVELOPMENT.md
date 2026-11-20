# 开发、签名与发布

## 环境

- macOS 14 及以上。
- Swift 6.2 或兼容版本。
- 当前无完整 Xcode 时仍可构建 AppKit/SwiftUI 应用并运行 `ShoupingChecks`。
- 若要运行 XCTest、归档 Xcode 工程或正式公证，需要安装完整 Xcode。

## 常用命令

```zsh
# 构建化验程序
swift run -c debug ShoupingChecks

# 构建 arm64 + x86_64 的 .app
./Scripts/build_app.sh

# 生成 DMG
./Scripts/package_dmg.sh

# 安装到 /Applications 并打开
./Scripts/install_local.sh
```

默认会构建通用二进制。若要缩短本机调试时间：

```zsh
BUILD_UNIVERSAL=0 ./Scripts/build_app.sh
```

## 签名

正式发布必须使用 Apple Developer Program 的 Developer ID Application 证书：

```zsh
DEVELOPER_ID_APPLICATION='Developer ID Application: Example (TEAMID)' \
  ./Scripts/build_app.sh
```

本机开发可使用一个稳定名称的本地代码签名身份：

```zsh
LOCAL_SIGNING_IDENTITY='Shouping Local Development' \
LOCAL_SIGNING_KEYCHAIN="$HOME/Library/Keychains/ShoupingDev.keychain-db" \
  ./Scripts/build_app.sh
```

如果默认钥匙串搜索列表中存在名为 `Shouping Local Development` 的身份，构建脚本会自动使用它。

本地自签名足以保持普通应用签名一致，但不能替代 Apple 开发证书通过所有 TCC 检查。尤其要验证：

- `AXIsProcessTrusted()`
- `CGPreflightListenEventAccess()`
- 键盘事件 tap 的创建和销毁

## 正式发布清单

1. 用 Developer ID 签名主应用和 `ShoupingAgent`。
2. 对 `.app` 运行 codesign 严格验证。
3. 提交 Apple notarization。
4. 对公证后的 DMG 做 Gatekeeper 验证。
5. 在至少 macOS 14、当前稳定版和 macOS 26 上回归。
6. 在单屏、双屏、三屏、合盖唤醒和显示器热插拔上回归。
7. 撤回辅助功能权限，确认自动降级到标准遮挡。
8. 关闭主应用，确认规则有效时 LaunchAgent 能恢复。
9. 关闭后台恢复并卸载，确认 Login Item 和 LaunchAgent 均被移除。

## 安全约束

- 不使用私有 API。
- 不采集键盘内容。
- 输入事件过滤器只在专注屏显示时创建。
- helper 不联网。
- 任何权限异常都应优先恢复可操作状态。
