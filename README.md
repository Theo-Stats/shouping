# 守屏（Shouping）

一款本地优先的 macOS 使用时间与专注管理应用。它通过多显示器全屏遮罩、应用白名单、定时规则和每日额度，帮助用户把电脑暂时留在重要任务上。

## 当前状态

已完成可安装的 `0.1.0` MVP：

- 快速专注：15、25、45 分钟。
- 工作日或每日定时限制，支持跨午夜。
- 每日活跃使用额度。
- 连续使用与强制休息。
- 应用白名单和从专注屏直接启动允许应用。
- 多显示器覆盖窗口，支持不同 Space 和全屏应用场景。
- 菜单栏常驻、预览、临时解锁和提前结束。
- 本地前台应用统计，不采集窗口标题、屏幕画面和按键内容。
- 登录启动。
- 规则生效时由 LaunchAgent 恢复主应用。
- 强制模式框架与安全降级。

## 运行

本地构建：

```zsh
./Scripts/build_app.sh
./Scripts/package_dmg.sh
./Scripts/install_local.sh
```

构建产物：

- 应用：`build/守屏.app`
- 安装镜像：`build/守屏-0.1.0.dmg`
- 已安装版本：`/Applications/守屏.app`

应用以菜单栏图标启动；关闭设置窗口不会结束守屏。

## 验证

```zsh
swift build -c debug
swift run -c debug ShoupingChecks
```

已验证 UI、快速专注、定时专注、自动恢复、白名单启动和后台恢复。详细记录见 [docs/TEST_LOG.md](docs/TEST_LOG.md)。

## 已知边界

- 当前本机只有 Command Line Tools，没有完整 Xcode，因此 XCTest 文件保留但未接入 SwiftPM。替代验收程序为 `ShoupingChecks`。
- 强制键盘拦截的代码与 UI 已完成；但本地自签名构建无法取得 macOS TCC 对辅助功能事件过滤器的信任。应用会明确提示并自动降级为全屏遮挡。发布强制模式需要 Apple Development 或 Developer ID 签名后重新实测。
- 当前测试机只有单台内置显示器。代码按每块 `NSScreen` 建立独立窗口，最终发布前仍需在双屏和三屏真机上回归。
- 当前 DMG 使用本地开发签名，不能直接作为面向公众的公证发行包。

## 文档

- [产品调研与开发计划](不做电脑控-Mac调研与开发计划.md)
- [工程实施计划](实施计划.md)
- [开发、签名与发布](docs/DEVELOPMENT.md)
- [验收记录](docs/TEST_LOG.md)
