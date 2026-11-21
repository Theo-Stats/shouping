# MVP 验收记录

日期：2026-11-21

环境：macOS 27.2.1，Apple Silicon，Xcode 27.2，Swift 6.4.2，macOS SDK 27.2

## 自动检查

命令：

```zsh
swift build -c debug
swift run -c debug ShoupingChecks
```

结果：

- Debug 构建通过。
- Release 构建通过。
- XCTest 7 项通过，0 失败。
- 删除全部 iOS Simulator 运行库后，macOS 项目的 XCTest 仍为 6 项通过。
- arm64 构建通过。
- x86_64 交叉构建通过。
- 主应用和后台 agent 均生成 arm64 + x86_64 通用二进制。
- `ShoupingChecks: 14 checks passed`。
- 检查项覆盖普通日程、跨午夜日程、临时解锁、每日额度、应用级筛选、使用数据持久化和跨日重置。

## 界面验证

- 主窗口和五个功能区能正常显示。
- 规则页可修改强度、时长、日程、每日额度和连续使用。
- 规则页可独立关闭暂停和跳过；两项关闭后，专注屏不再提供对应操作，紧急快捷键提示也隐藏。
- 应用页能打开原生应用选择器并保存白名单应用。
- 权限页能读取并显示辅助功能、输入监控状态。

## 专注屏验证

- 10 秒预览遮罩能够出现并在结束后自动恢复。
- 快速专注重启应用后仍能按结束时间恢复。
- 定时规则到点后自动出现遮罩。
- 白名单中的“计算器”能在遮罩页直接启动。
- 启动允许应用后遮罩隐藏；应用本身仍运行。
- 遮罩覆盖系统菜单栏和桌面区域。
- 首页可设置 1–720 分钟自定义专注，实际以 1 分钟和 17 分钟验证。
- 预览页“暂停 5 分钟”修复后不会在下一秒重新出现。
- 预览页“结束预览”修复后不会重新出现。
- 暂停和跳过为独立开关；旧配置缺少这两个字段时默认均开启，不会在升级后意外锁死。

## 后台恢复验证

- 在配置中建立有效专注规则。
- 关闭主应用进程。
- 运行打包后的 `ShoupingAgent`。
- agent 成功执行 `/usr/bin/open -gj 守屏.app --args --background`。
- 主应用在后台启动并恢复遮罩。
- `SMAppService.agent(plistName:)` 成功注册，`launchctl` 显示 `com.example.shouping.agent`，5 秒周期。
- `SMAppService.mainApp` 登录项注册成功。
- `sfltool dumpbtm` 显示主应用与后台 agent 都是 `enabled, allowed, notified`。
- 专注生效时对主进程执行强制终止；5 秒检查周期内出现新的进程并恢复专注屏。

## 输入拦截验证

- 强制模式 UI 可以启用并显示实际状态。
- 使用 Apple Development 证书重新签名并重置旧 TCC 记录后，辅助功能和输入监控均成功授权。
- 权限页显示“两项权限已生效”。
- “实际测试”成功创建并销毁键盘事件过滤器。
- 强制专注屏显示“键盘拦截已开启”。
- 0.1.3 新增暂停和跳过独立开关，旧配置文件缺少新字段时默认均允许，避免升级后意外锁死。
- 错误或缺失权限时会安全降级为全屏遮挡，鼠标仍可操作应急按钮。
- `Control + Command + U` 的按键匹配逻辑已加入单元测试；当前自动化输入注入未触发系统快捷键路径，正式触控板/键盘需在实机回归。

## 发行包验证

- `codesign --verify --deep --strict` 通过。
- DMG 中应用包含主程序、后台 agent、LaunchAgent plist 和 AppIcon。
- `hdiutil verify` 返回 checksum valid。
- 当前主应用和 helper 均由 Apple Development、WWDR G3 和 Apple Root CA 链签名。
- Apple Development 适合本机测试；正式对外分发前必须替换为 Developer ID并完成公证。

## 尚未完成

- 双屏和三屏真机矩阵。
- 正式公证和 Gatekeeper 验证。
