# PiliPlus · Swift

PiliPlus 的纯 Swift 原生重写版（iOS / iPadOS），目标是在保留
[PiliPlus](https://github.com/ZimingADR/PiliNara) Flutter 版功能语义的前提下，
用 SwiftUI + Swift 6 + MPVKit 重新实现一套原生播放客户端。

当前开发阶段：**Group 1 — 核心播放与发现体验闭环（MVP）**。

## Group 1 范围

| # | 模块 | 说明 |
| :-: | :--- | :--- |
| 1 | `main` | App 生命周期、全局依赖注入、崩溃防护 |
| 2 | `home` | 首页架构，iPhone 底部悬浮玻璃 TabBar / iPad 双栏 |
| 3 | `rcmd` | 推荐流、下拉刷新、无限分页 |
| 4 | `video` | MPVKit 播放内核、分P 选集、清晰度切换、手势、全屏 |
| 5 | `danmaku` | CoreAnimation 弹幕渲染、开关、字号、透明度、速度 |
| 6 | `audio_normalization` | BewlyCat 三级 `lavfi` 音量平衡（volume + dynaudnorm + alimiter） |
| 7–10 | `search` / `search_trending` / `search_result` / `search_panel` | 搜索入口、热搜、结果分页、快速搜索浮层 |
| 11–12 | `history` / `history_search` | SwiftData 播放历史与断点续播、本地过滤 |
| 13–15 | `setting` / `loudness_setting` / `about` | 播放偏好、音量平衡二级页、关于页 |

## 技术栈

- **Swift 6**（严格并发），SwiftUI，Observation
- **MPVKit**（libmpv + FFmpeg）负责 DASH 双轨播放、硬解、`af` 滤镜
- **SwiftData** 负责播放历史；**UserDefaults** 负责偏好设置
- **Swift Testing** 负责单元测试
- **XcodeGen** 生成工程（`project.yml` 是唯一工程定义来源，`.xcodeproj` 不入库）
- **GitHub Actions**（macOS runner）完成编译、测试与产物打包

## 本地开发

工程文件由 XcodeGen 生成，因此本仓库不提交 `.xcodeproj`：

```bash
brew install xcodegen
xcodegen generate --spec project.yml
open PiliPlus.xcodeproj
```

> Windows 环境无法运行 Xcode，Swift 侧的编译与测试统一交给 GitHub Actions 完成。

## CI

`.github/workflows/ci.yml` 在每次 push 到 `main` 与 PR 时执行：

1. `xcodegen generate`
2. `xcodebuild -resolvePackageDependencies`（拉取 MPVKit 二进制框架，带缓存）
3. 模拟器 Debug 编译（`CODE_SIGNING_ALLOWED=NO`）
4. 在可用 iPhone 模拟器上运行 Swift Testing 单元测试

后续会追加 `release.yml`：归档未签名 `.ipa` 并发布到 GitHub Releases。

## 目录结构

```text
PiliPlus/
├── App/            # 入口、根导航、全局环境
├── Core/
│   ├── Network/    # BiliClient、Wbi 签名、接口路由
│   ├── Engine/     # MPVKit 封装与 Metal 图层桥接
│   ├── Audio/      # BewlyCat 音量平衡与音频会话
│   ├── Danmaku/    # 弹幕解析、轨道调度、渲染层
│   └── Storage/    # SwiftData 模型与仓储
├── Models/         # 纯 Swift 领域模型（Sendable）
├── UI/
│   ├── DesignSystem/
│   ├── Components/
│   └── Features/
└── Supporting/     # Info.plist、隐私清单、Assets
```

## 文档

- [架构设计](docs/architecture.md)
- [Group 1 验收清单](docs/group1-acceptance.md)
- [迁移说明（Flutter → Swift 对照）](docs/migration-notes.md)

## 声明

本项目仅供学习与技术交流，不提供、不存储任何音视频内容；所有内容版权归
哔哩哔哩及其原始作者所有。请勿用于商业用途。
