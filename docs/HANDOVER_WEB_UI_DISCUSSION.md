# Inputo Phase 4 Web UI Discussion Handover Prompt

Copy this prompt into a new conversation when discussing Phase 4 Web composer engineering, the React/TypeScript/Vite migration, or a later Web agent surface.

```text
我们继续讨论 Inputo，仓库在 /Users/wnbot/Projects/Inputo。

请先阅读：
- README.md
- docs/ARCHITECTURE.md
- docs/DEVELOPMENT.md
- docs/HANDOVER.md
- docs/WEB_COMPOSER.md
- docs/HANDOVER_WEB_UI_DISCUSSION.md

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
- 产品代码在 `apps/macos/InputoModules` local SwiftPM package。
- `InputoCore` 是 Foundation-only，包含 provider config、recipes、OpenAI-compatible request/response/prompt 逻辑。
- `InputoMacPlatform` 负责 macOS services：Keychain、clipboard、hotkey、settings、app anchors。
- `InputoComposerFeature` 负责当前 Web composer host/assets、native settings UI 和 feature orchestration。
- `AppState` 已通过小 service protocols 做 dependency injection，并有 fake services 和单元测试。
- Provider 调用已经跑通，app sandbox 已加 network client entitlement。
- Settings 里有 neutral connection test，不再用翻译作为连通性测试。
- 当前 composer 是 native shell + bundled `WKWebView` body：native 保留 header、Jump anchors、Settings、panel behavior 和 platform services；Web body 渲染 preview、preset/instruction、input、actions。
- Phase 3 使用 checked-in static HTML/CSS/JS，不使用 React、TypeScript、Vite、Node build step 或远程资源。
- Phase 4 已引入 React + TypeScript + Vite source workspace，位置是 `packages/web-composer`；app runtime 仍加载 checked-in bundled local static assets。
- Web-to-native 只通过 `InputoNativeBridgeHost` / `InputoNativeBridgeMessageHandling`；native-to-Web events 通过 `InputoBridgeEventEmitter`。
- Web 侧使用 non-persistent data store、bundled local static assets、restrictive CSP，并由 WK host 阻止 `http`/`https` 资源加载。

架构规则：
- 保持当前 monorepo 结构。
- `Inputo` Xcode target 必须保持薄，只做 lifecycle/menu/window hosting。
- 产品代码放在 `apps/macos/InputoModules`。
- `InputoCore` 保持 Foundation-only，方便未来用 Rust/C++ 重写 core 以便在 Windows 上复用。
- `InputoMacPlatform` 负责 macOS services。
- 不使用 CocoaPods、Carthage、XcodeGen 或 project generator。
- 遵循最新 Apple SwiftUI/AppKit 应用规范。

这次新对话的目标：
我们正在继续 Phase 4：React + TypeScript + Vite source workspace 已落在 `packages/web-composer`。不是全量改成 web，也不是移动 native settings / Jump anchors / platform services。当前方向仍是 native shell + web-rendered product surfaces：
- native shell 继续负责菜单栏、快捷键、窗口、app anchors、Keychain、clipboard、sandbox/permissions。
- Swift/Core/Platform 继续负责 provider、settings、privacy-sensitive services。
- web UI 当前只渲染 composer body；settings 和 Jump anchors 仍保持 native。
- React + TypeScript + Vite 只作为前端源码和本地开发工具；app runtime 仍加载 bundled local static assets，Xcode app target 仍保持薄且不依赖 dev server。

请重点讨论：
1. `packages/web-composer` 如何继续输出到现有 `Resources/WebComposer`。
2. 如何保持 Xcode 离线 build：不在 Xcode target 中运行 `npm install`，不依赖 dev server，不下载远程资源。
3. Web UI 边界：Phase 4 继续只做 composer，settings 和 Jump anchors 仍保持 native。
4. Swift-to-web bridge 的命令、事件、DTO、错误处理、测试策略如何继续收窄。
5. 打包和开发体验：静态资源如何提交或生成，Node build step 如何不污染 Xcode app target。
6. macOS 体验风险：启动速度、内存、键盘焦点、IME、accessibility、深浅色、窗口透明/毛玻璃。
7. 开源社区角度：贡献门槛、review 复杂度、长期维护成本。
8. 和未来 Windows 版本的关系：web UI 是否能复用，core/provider contracts 如何保持稳定。

请先给出架构分析和可选方案，不要直接改代码，除非我明确要求开始实现。

如果后续进入实现阶段，每次改动后必须验证：
`swift test --package-path apps/macos/InputoModules`
`xcodebuild -project apps/macos/Inputo.xcodeproj -scheme Inputo -configuration Debug -derivedDataPath .build/XcodeDerivedData CODE_SIGNING_ALLOWED=NO build`
```

## Discussion Bias

The current bias is to add frontend source tooling only after the minimal bundled Web composer has proven the native/Web boundary. Phase 4 should improve maintainability and contributor ergonomics without weakening Inputo's native privacy and platform-service boundaries.

## Non-Goals For The Discussion

- Do not propose replacing the whole macOS app with Electron.
- Do not move Keychain, clipboard, hotkey, app activation, or permissions into web code.
- Do not add automatic paste, history, screenshot, window-title capture, MCP/tool execution, or broader OS access as part of the web UI discussion.
- Do not introduce a project generator.
