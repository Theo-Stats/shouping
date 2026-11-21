# 开发、签名与发布

## 环境

- macOS 14 及以上。
- Swift 6.2 或兼容版本。
- Xcode 27.2 位于 `/Volumes/kioxiaTC10/Applications/Xcode-27.2/Xcode.app`。
- 构建脚本检测到该路径时会自动设置 `DEVELOPER_DIR`，不修改系统全局默认工具链。
- 外接盘未挂载时，仍可回退到 Command Line Tools 构建应用和运行 `ShoupingChecks`。
- Xcode 首次启动、必需组件和 macOS 27.2 SDK 已完成安装。
- Xcode 的 Apple Accounts 页面尚未登录；创建 Apple Development 证书需要用户本人登录。

## 常用命令

```zsh
# 构建化验程序
swift run -c debug ShoupingChecks
swift test

# 构建 arm64 + x86_64 的 .app
./Scripts/build_app.sh

# 生成 DMG
./Scripts/package_dmg.sh

# 安装到 /Applications 并打开
./Scripts/install_local.sh
```

默认会构建通用二进制。脚本优先使用外接盘中的完整 Xcode。若要缩短本机调试时间：

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
