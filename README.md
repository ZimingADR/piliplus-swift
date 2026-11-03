# PiliPlus · Swift

[![CI](https://github.com/ZimingADR/piliplus-swift/actions/workflows/ci.yml/badge.svg)](https://github.com/ZimingADR/piliplus-swift/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/ZimingADR/piliplus-swift)](https://github.com/ZimingADR/piliplus-swift/releases)

PiliPlus 的纯 Swift 原生重写版（iOS / iPadOS），目标是在保留
[PiliPlus](https://github.com/ZimingADR/PiliNara) Flutter 版功能语义的前提下，
用 SwiftUI + Swift 6 + MPVKit 重新实现一套原生播放客户端。

当前进度：**Group 1 已交付；Group 2 / 3 核心链路、Group 4 动态/专栏、
Group 5 番剧/直播、Group 6 下载/WebDAV/SponsorBlock/App Intents/小组件/实时活动已可用**
（扫码登录、收藏夹（含新建/搜索/排序）、关注（含搜索）、评论区（含楼中楼/点赞/表情）、
点赞投币收藏、稍后再看、热门、排行榜（分区/周期）、入站必刷、每周必看、
UP 主空间（含公开收藏夹/专栏/合集/点赞/音频/追番）、UP 主搜索、
动态信息流（点赞/转发/评论/发布图文/投票/分类筛选）与专栏阅读、话题、
番剧索引/季详情/选集播放/长评、直播列表（含搜索/分区/关注开播）与直播间、离线下载、
WebDAV 历史/设置同步、广告片段跳过、弹幕屏蔽词、仅音频模式、运行日志面板、设置搜索、
账号安全（登录设备/历史）、AI 视频总结、私信、DLNA 投屏（发现 + SOAP）、
Siri 快捷指令与 `piliplus://` 深链、桌面「继续观看」小组件、锁屏与灵动岛实时活动），
界面全面升级为 **Liquid Glass** 风格。完整进度见 [迁移路线图](docs/roadmap.md)。

最新构建：**v0.3.0（Build 4，iOS 27.1）**，含 Widget Extension 与灵动岛实时活动。

> 无需登录即可刷首页推荐、搜索任意视频、播放 DASH 视频流、使用 BewlyCat
> 音量平衡、开关弹幕、后台播放与画中画，并自动记住播放进度；登录后解锁
> 收藏、关注、评论与稍后再看。

## 系统要求

- **iOS / iPadOS 27.1 及以上**（`IPHONEOS_DEPLOYMENT_TARGET = 27.1`）。
- 使用 **iOS 27.1 SDK**（Xcode 27.1）构建；CI 运行在 GitHub Actions 的
  `xcode-27` 预览镜像上，并显式 `xcode-select` 到 `Xcode_27.1.app`。
- 界面基于系统原生 **Liquid Glass**（`glassEffect` / `GlassEffectContainer`），
  不再使用材质模拟。

## 安装（SideStore / AltStore）

订阅源（SideStore / AltStore / LiveContainer 通用）：

```text
https://raw.githubusercontent.com/ZimingADR/piliplus-swift/main/altstore.json
```

在 iOS 设备上用 Safari 打开下面的一键订阅链接，即可把源添加到 SideStore：

```text
sidestore://source?url=https://raw.githubusercontent.com/ZimingADR/piliplus-swift/main/altstore.json
```

- Release 产物是**未签名 IPA**，SideStore / AltStore 会在设备上用你的证书重签后安装。
- 每次推送 `v*` tag，`.github/workflows/release.yml` 会自动归档 IPA、运行
  `scripts/update_altstore_source.py` 更新 `altstore.json`（版本号、大小、SHA-256、
  下载地址）并提交回 `main`，订阅源因此始终指向最新版本。
- 也可以从 [Releases](https://github.com/ZimingADR/piliplus-swift/releases) 手动下载 IPA。

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

`.github/workflows/release.yml` 在推送 `v*` tag（或手动触发）时归档未签名
`.ipa`，计算 SHA-256 并发布到 GitHub Releases。未签名产物需要自行用 AltStore /
SideStore / TrollStore 或开发者证书重签后安装。

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

## 交付边界（未完成项）

以下功能尚未实现，避免误解为「全部完成」：

- **DLNA 内置代理**：当前投屏依赖设备直连 CDN，跨网/防盗链场景需后续加入本地 HTTP 代理
- **专栏列表、独立音频专区/音乐模式**

已完成范围见 [迁移路线图](docs/roadmap.md)。

## 文档

- [架构设计](docs/architecture.md)
- [Group 1 验收清单](docs/group1-acceptance.md)
- [迁移说明（Flutter → Swift 对照）](docs/migration-notes.md)

## 声明

本项目仅供学习与技术交流，不提供、不存储任何音视频内容；所有内容版权归
哔哩哔哩及其原始作者所有。请勿用于商业用途。
