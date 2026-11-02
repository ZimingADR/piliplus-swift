# Group 1 验收清单

Group 1 的目标（引自迁移指南）：*无需登录即可刷推荐、搜视频、秒开 DASH、
享受 BewlyCat 音量平衡、开闭弹幕、画中画与后台播放，并自动记住播放进度。*

## 1. 模块完成度

| # | 模块 | 实现位置 | 状态 |
| :-: | :--- | :--- | :---: |
| 1 | `main` | `PiliPlus/App/PiliPlusApp.swift`、`AppEnvironment.swift` | ✅ |
| 2 | `home` | `App/RootView.swift`、`UI/Components/GlassTabBar.swift` | ✅ iPhone 悬浮 TabBar / iPad 双栏 |
| 3 | `rcmd` | `UI/Features/Home/*`、`Core/Network/BiliClient.swift` | ✅ 下拉刷新 + 无限分页 |
| 4 | `video` | `Core/Engine/*`、`UI/Features/Player/*` | ✅ 分P、清晰度、手势、全屏 |
| 5 | `danmaku` | `Models/Danmaku.swift`、`Core/Danmaku/*` | ✅ CoreAnimation 渲染 + 参数面板 |
| 6 | `audio_normalization` | `Core/Audio/AudioNormalization.swift` | ✅ 三级滤镜 + 单测 |
| 7–10 | `search` / `search_trending` / `search_result` / `search_panel` | `UI/Features/Search/*` | ✅ 热搜、联想、分页结果、浮层 |
| 11–12 | `history` / `history_search` | `UI/Features/History/*`、`Core/Storage/PlaybackHistory.swift` | ✅ SwiftData + 本地过滤 |
| 13 | `setting` | `UI/Features/Settings/SettingsScreen.swift` | ✅ |
| 14 | `loudness_setting` | `UI/Features/Settings/LoudnessSettingsScreen.swift` | ✅ |
| 15 | `about` | `UI/Features/Settings/AboutScreen.swift` | ✅ |

## 2. 验收矩阵（对照迁移指南）

| 检验维度 | 基准 | 实现说明 | 验证方式 |
| :--- | :--- | :--- | :--- |
| 启动与浏览 | 冷启动即出推荐卡片，连续下拉 5 页无白屏 | 首屏 12 条，分页去重 + 空页补拉（最多 3 次） | CI 编译 + 真机手动 |
| 视频播放 | 1080P DASH 双轨、分P 点击即切 | `fnval=4048&fourk=1`，`audio-add` 在 loaded 后执行 | 真机 `test.stream` 播放 3 小时合集 |
| 音量平衡 | 默认 -18 LUFS / 75%，无破音 | `volume` + `dynaudnorm` + `alimiter`，算法与 Dart 版逐字节一致 | `AudioNormalizationTests`（6 条） |
| 弹幕 | 大弹幕量流畅、可开关、字号可调 | CA 图层 + 轨道时间分配 + 区域上限 | 真机 10 万弹幕视频，Instruments 帧率 |
| 后台与画中画 | 上划进 PiP，锁屏音频不断 | MPV 暂停后由 AVPlayer 接管合流 MP4；退出回写进度 | 真机锁屏 / 多任务 |
| 历史续播 | 01:25 退出，重进提示并续播 | 每 10s + 退出时落库，±5s 容差 | `PlaybackHistoryTests` + 真机杀进程 |

## 3. 已自动化的验证

CI（`.github/workflows/ci.yml`）在 macOS runner 上执行：

1. `xcodegen generate --spec project.yml`
2. `xcodebuild -resolvePackageDependencies`（MPVKit 二进制 + 缓存）
3. 模拟器 Debug 编译（unsigned）
4. `xcodebuild test`：WBI 官方向量、音量平衡滤镜、弹幕 protobuf 解码、
   视频卡片格式化、SwiftData 历史 upsert/删除/清空

## 4. 已知限制

- **画中画分辨率**：受 AVKit 限制使用 `platform=html5` 合流流，最高 720P。
- **iOS 27.1 Liquid Glass**：部署目标为 iOS 27.1，TabBar、卡片与控件直接使用
  系统 `glassEffect`，与 iOS 26/27 的原生玻璃表现一致；旧系统不再支持。
- **登录态**：Group 1 全匿名，1080P 为服务端匿名上限；4K/HDR 需 Group 2 登录。
- **弹幕高级类型**：BAS / 代码 / 逆向弹幕按设计丢弃，仅渲染滚动、顶部、底部。

## 5. 手动验收脚本

1. 冷启动 → 首页出现推荐卡片；下拉刷新 3 次；连续上拉 5 页。
2. 打开任意视频 → 观察首帧时间；拖动进度条、双击左右快进、竖向调亮度/音量。
3. 打开弹幕开关与弹幕设置，调字号/透明度/速度；播放高密度弹幕视频观察流畅度。
4. 设置 → 音量平衡 → 拖动目标响度与强度，返回播放器检查顶栏摘要。
5. 播放至 1 分钟以上 → 上划进桌面（画中画）→ 锁屏 → 检查通知中心封面与进度。
6. 回到 App 退出播放器 → 历史页出现记录 → 重新点击，确认从上次位置继续。
7. iPad 上确认双栏布局；转动设备确认播放器横屏。
