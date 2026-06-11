# Inputo Web UI Discussion Handover Prompt

Copy this prompt into a new conversation when discussing the future hybrid web UI direction.

```text
我们继续讨论 Inputo，仓库在 /Users/wnbot/Projects/Inputo。

请先阅读：
- README.md
- Docs/ARCHITECTURE.md
- Docs/DEVELOPMENT.md
- Docs/HANDOVER.md
- Docs/HANDOVER_WEB_UI_DISCUSSION.md

项目背景：
Inputo 是一个 macOS 原生、类似 Spotlight 的系统级 AI 输入源。用户通过自定义快捷键或菜单栏唤起，在 Inputo 内输入/粘贴文本，用 OpenAI-compatible provider 做文本转换，只有用户点击 Copy 时才写入剪贴板，然后通过 app anchors 跳回目标应用。

v1 隐私边界：
- 不自动粘贴
- 不保存输入历史
- 不保存生成历史
- 不执行 MCP/tools
- 不读取窗口标题
- 不截图
- 不默认请求屏幕录制权限

当前实现状态：
- Xcode `Inputo` app target 保持很薄，只做 lifecycle/menu/window hosting。
- 产品代码在 `InputoModules` local SwiftPM package。
- `InputoCore` 是 Foundation-only，包含 provider config、recipes、OpenAI-compatible request/response/prompt 逻辑。
- `InputoMacPlatform` 负责 macOS services：Keychain、clipboard、hotkey、settings、app anchors。
- `InputoComposerFeature` 负责当前 native composer/settings UI 和 feature orchestration。
- `AppState` 已通过小 service protocols 做 dependency injection，并有 fake services 和单元测试。
- Provider 调用已经跑通，app sandbox 已加 network client entitlement。
- Settings 里有 neutral connection test，不再用翻译作为连通性测试。
- 当前 composer 是 SwiftUI 单列紧凑布局：anchors、preview、preset/instruction、input、actions。

架构规则：
- 保持 Xcode app + local SwiftPM package 结构。
- `Inputo` Xcode target 必须保持薄，只做 lifecycle/menu/window hosting。
- 产品代码放在 `InputoModules`。
- `InputoCore` 保持 Foundation-only，方便未来用 Rust/C++ 重写 core 以便在 Windows 上复用。
- `InputoMacPlatform` 负责 macOS services。
- 不使用 CocoaPods、Carthage、XcodeGen 或 project generator。
- 遵循最新 Apple SwiftUI/AppKit 应用规范。

这次新对话的目标：
我们要讨论是否以及如何在当前 native 基础上接入 web UI。不是全量改成 web，也不是马上实现。倾向方向是 native shell + web-rendered product surfaces：
- native shell 继续负责菜单栏、快捷键、窗口、app anchors、Keychain、clipboard、sandbox/permissions。
- Swift/Core/Platform 继续负责 provider、settings、privacy-sensitive services。
- web UI 可能只渲染 composer，或者 composer + settings。
- 如果使用 web，优先考虑 `WKWebView` 嵌入，并通过窄的 typed bridge 与 Swift 通信。

请重点讨论：
1. web UI 是否值得引入，以及相比纯 SwiftUI 的收益和代价。
2. web UI 的边界：只做 composer，还是 composer + settings。
3. frontend 技术栈选择：plain HTML/CSS/TS、React、Svelte、Solid、Tauri-like bundle 思路等。
4. Swift-to-web bridge 设计：命令、事件、DTO、错误处理、测试策略。
5. 打包和开发体验：静态资源是否提交、是否需要 Node build step、Xcode build 如何集成。
6. macOS 体验风险：启动速度、内存、键盘焦点、IME、accessibility、深浅色、窗口透明/毛玻璃。
7. 开源社区角度：贡献门槛、review 复杂度、长期维护成本。
8. 和未来 Windows 版本的关系：web UI 是否能复用，core/provider contracts 如何保持稳定。

请先给出架构分析和可选方案，不要直接改代码，除非我明确要求开始实现。

如果后续进入实现阶段，每次改动后必须验证：
`swift test --package-path InputoModules`
`xcodebuild -project Inputo.xcodeproj -scheme Inputo -configuration Debug -derivedDataPath .build/XcodeDerivedData CODE_SIGNING_ALLOWED=NO build`
```

## Discussion Bias

The current bias is to finish and validate the native v0.1 flow before adding a web runtime. The web path is worth exploring for open-source contribution, faster UI iteration, and richer preview/dev tooling, but it should not weaken Inputo's native privacy and platform-service boundaries.

## Non-Goals For The Discussion

- Do not propose replacing the whole macOS app with Electron.
- Do not move Keychain, clipboard, hotkey, app activation, or permissions into web code.
- Do not add automatic paste, history, screenshot, window-title capture, MCP/tool execution, or broader OS access as part of the web UI discussion.
- Do not introduce a project generator.
