# MVP 验收记录

日期：2026-11-20  
环境：macOS 26.2，Apple Silicon，Swift 6.2.4，Command Line Tools macOSX.sdk 26.2

## 自动检查

命令：

```zsh
swift build -c debug
swift run -c debug ShoupingChecks
```

结果：

- Debug 构建通过。
- Release 构建通过。
- arm64 构建通过。
- x86_64 交叉构建通过。
- 主应用和后台 agent 均生成 arm64 + x86_64 通用二进制。
- `ShoupingChecks: 8 checks passed`。
- 检查项覆盖普通日程、跨午夜日程、临时解锁、每日额度、应用级筛选、使用数据持久化和跨日重置。

## 界面验证

- 主窗口和五个功能区能正常显示。
- 规则页可修改强度、时长、日程、每日额度和连续使用。
- 应用页能打开原生应用选择器并保存白名单应用。
- 权限页能读取并显示辅助功能、输入监控状态。

## 专注屏验证

- 10 秒预览遮罩能够出现并在结束后自动恢复。
- 快速专注重启应用后仍能按结束时间恢复。
- 定时规则到点后自动出现遮罩。
- 白名单中的“计算器”能在遮罩页直接启动。
- 启动允许应用后遮罩隐藏；应用本身仍运行。
- 遮罩覆盖系统菜单栏和桌面区域。

## 后台恢复验证

- 在配置中建立有效专注规则。
- 关闭主应用进程。
- 运行打包后的 `ShoupingAgent`。
- agent 成功执行 `/usr/bin/open -gj 守屏.app --args --background`。
- 主应用在后台启动并恢复遮罩。
- `SMAppService.agent(plistName:)` 成功注册，`launchctl` 显示 `com.example.shouping.agent`，15 秒周期。
- `SMAppService.mainApp` 登录项注册成功。

## 输入拦截验证

- 强制模式 UI 可以启用并显示实际状态。
- 权限不可用时，事件过滤器创建失败，界面显示“键盘拦截不可用，当前仍受全屏遮挡保护”。
- 应用不会因为权限失败而阻断退出；应急按钮仍可使用。
- 当前自签名构建在系统设置中可以被勾选，但 `AXIsProcessTrusted()` 和 `CGPreflightListenEventAccess()` 仍返回 false。
- 结论：事件 tap 的最后验收必须使用 Apple Development 或 Developer ID 证书重新签名，在真实 TCC 授权后完成。

## 发行包验证

- `codesign --verify --deep --strict` 通过。
- DMG 中应用包含主程序、后台 agent、LaunchAgent plist 和 AppIcon。
- `hdiutil verify` 返回 checksum valid。
- 当前签名身份为本地自签名，正式对外分发前必须替换为 Developer ID 并完成公证。

## 尚未完成

- 双屏和三屏真机矩阵。
- Apple Development/Developer ID 下的 TCC 键盘拦截实测。
- 完整 Xcode XCTest。
- 正式公证和 Gatekeeper 验证。
