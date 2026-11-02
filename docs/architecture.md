# 架构设计

> 目标：在 Group 1 内交付一个**无需登录即可日常使用**的原生播放器，同时为
> Group 2~6 预留清晰的扩展边界。

## 1. 分层

```text
┌────────────────────────────────────────────────────────────┐
│ UI (SwiftUI)                                               │
│  RootView / HomeScreen / SearchScreen / HistoryScreen ...   │
│  只读 @Observable 状态 + 调用命令方法                        │
├────────────────────────────────────────────────────────────┤
│ Feature Models (@MainActor @Observable)                    │
│  HomeFeedModel / SearchModel / PlaybackController           │
├────────────────────────────────────────────────────────────┤
│ Core                                                       │
│  Network: BiliClient(actor) / WbiSigner / Endpoint 模型     │
│  Engine:  MPVEngine / PlaybackController / PiPManager       │
│  Audio:   AudioNormalization / AudioSessionCoordinator      │
│  Danmaku: DanmakuDecoder / DanmakuCanvasView                │
│  Storage: SettingsStore(UserDefaults) / SwiftData History   │
├────────────────────────────────────────────────────────────┤
│ Models (Sendable structs)                                  │
└────────────────────────────────────────────────────────────┘
```

依赖方向永远向下：UI 不直接触网，网络层不感知 SwiftUI。

## 2. 并发模型

- **Swift 6 严格并发**（`SWIFT_STRICT_CONCURRENCY=complete`），显式固定
  `SWIFT_DEFAULT_ACTOR_ISOLATION=nonisolated`，避免不同 Xcode 版本的默认隔离差异。
- `BiliClient` 是 `actor`：请求、Wbi 密钥缓存、protobuf 解码都在 actor 内完成，
  对外只返回 `Sendable` 值类型。
- 所有 UI 状态（`AppEnvironment`、`SettingsStore`、`PlaybackHistoryStore`、
  `PlaybackController`、各 Feature Model）都是 `@MainActor @Observable`。
- `URLSession.data(for:)` 本身是 nonisolated async，网络 IO 不会占用主线程。
- 弹幕渲染不依赖主线程逐帧绘制：CoreAnimation 在渲染服务器上运行动画，
  主线程只在状态刷新（约 5Hz）时投放新弹幕。

## 3. 播放链路

```text
点击卡片
  → BiliClient.videoDetail (/x/web-interface/wbi/view)     获取分P、cid
  → BiliClient.playURL   (/x/player/wbi/playurl, fnval=4048, fourk=1)
  → 选择视频轨（按清晰度 + 解码偏好）与最高码率音频轨
  → MPVEngine.load(videoURL) + attachAudioTrack(audioURL)
  → 文件 loaded 后 audio-add select → seek 断点 → play
  → 每 200ms 轮询 time-pos/duration/pause，驱动 UI 与历史落库
```

- 双轨：视频与音频分别来自 DASH，`audio-add` 在文件加载完成后执行，避免
  “no file loaded” 竞态。
- 防盗链：`http-header-fields` 注入 Referer / Origin / UA。
- 断点续播：每 10 秒与退出时把 `PlaybackSnapshot` 写入 SwiftData；再次打开
  同一 bvid 且 cid 相同时从上次秒数起播（距离结尾 5 秒内则从头开始）。

## 4. 音量平衡（BewlyCat）

`AudioNormalization` 是纯函数，移植自 Flutter 版 `audio_normalization.dart`：

1. **跨视频基准对齐**：用服务端 `volume.measured_i` 与目标 LUFS 计算预增益，
   按强度做 75%~100% 加权，限制在 `[-18 dB, +9 dB]`；
2. **视频内动态平滑**：`dynaudnorm`，高斯窗口 5~11 帧、`gate` 对应 -50 LUFS；
3. **防爆音**：`alimiter`，5ms 前瞻、-1 dBFS 上限、PTS 延迟补偿。

最终以 `af=lavfi=[...]` 下发给 mpv。算法有固定向量单测，保证与 Dart 版逐字节一致。

## 5. 弹幕

- 数据：`/x/v2/dm/web/seg.so` 返回 protobuf `DmSegMobileReply`，用手写的极简
  varint 解析器解码（不引入 SwiftProtobuf 代码生成，减少构建复杂度）。
- 渲染：每条弹幕一个 `CATextLayer` + `CABasicAnimation`；滚动/顶部/底部三种
  轨道由 `DanmakuCanvasView` 分配，碰撞检测使用“轨道可用时间”而非逐帧遍历。
- 暂停/恢复通过父图层 `speed` / `timeOffset` / `beginTime` 实现，避免逐条修改动画。
- Seek 时清空图层并从新时间点重新投放。

## 6. 画中画

MPV 渲染到 `CAMetalLayer`，无法直接接入 AVKit。Group 1 的方案是：

- 进入画中画时请求 `platform=html5` 的**合流 MP4**（最高 720P），交给
  `AVPictureInPictureController` + `AVPlayerLayer`；
- MPV 暂停，避免双路音频；
- 退出画中画时把 AVPlayer 的进度 seek 回 MPV，恢复原始清晰度。

代价是画中画期间最高 720P，换来真实、可用的系统画中画与锁屏控制。

## 7. 构建与 CI

- `project.yml`（XcodeGen）是工程唯一事实来源，`.xcodeproj` 不提交。
- GitHub Actions 的 `xcode-27` 镜像负责：选择 **Xcode 27.1 / iOS 27.1 SDK** →
  生成工程 → 解析 MPVKit 二进制 → 模拟器编译 → 在 iOS 27.1 模拟器上跑 Swift Testing。
  Windows 本地不承担 Swift 编译。
- 部署目标为 **iOS 27.1**，界面直接使用系统 Liquid Glass API
  （`.glassEffect`、`GlassEffectContainer`、玻璃按钮），不再用 `ultraThinMaterial` 模拟。
- MPVKit 以 SPM 二进制目标引入（LGPL 版本），缓存 `SourcePackages` 与 SwiftPM 缓存。

## 8. 错误处理与降级

- 接口错误统一为 `BiliAPIError(code:message:)`，`code != 0` 直接抛出并展示。
- SwiftData 容器创建失败时自动降级为内存存储，保证 App 可启动。
- 弹幕加载失败不影响播放；画中画失败会自动恢复 MPV 播放。
- 音量平衡滤镜构建是纯函数，参数越界全部 clamp，不会产生非法 mpv 参数。
