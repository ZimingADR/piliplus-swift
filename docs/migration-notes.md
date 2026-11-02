# Flutter → Swift 迁移说明

参考实现：`C:\Users\ADR\codespace\just4fun\pilinara-ray`（Flutter / PiliPlus）。
本文件记录 Group 1 的逐文件对照、协议参数与算法移植细节，方便 Group 2+ 继续对照。

## 1. 文件对照

| Flutter | Swift | 说明 |
| :--- | :--- | :--- |
| `lib/utils/wbi_sign.dart` | `Core/Network/WbiSigner.swift` | 混淆表、`!'()*` 过滤、`encodeURIComponent` |
| `lib/models/common/audio_normalization.dart` | `Core/Audio/AudioNormalization.swift` | BewlyCat 三级滤镜，逐参数移植 |
| `lib/http/video.dart`（rcmd/playurl/view） | `Core/Network/BiliClient.swift` + `Models/*` | 请求参数与响应字段 |
| `lib/http/search.dart` | `Core/Network/BiliClient.swift` + `UI/Features/Search/*` | 热搜、联想、分类搜索 |
| `lib/utils/storage.dart` / `storage_pref.dart` | `Core/Storage/SettingsStore.swift` | Hive → UserDefaults |
| 播放历史（Hive） | `Core/Storage/PlaybackHistory.swift` | Hive → SwiftData |
| `lib/plugin/pl_player/*` | `Core/Engine/MPVEngine.swift`、`PlaybackController.swift` | 播放器封装与状态机 |
| `lib/grpc/dm.dart`（DmSegMobile） | `Models/Danmaku.swift` + `BiliClient.danmakuItems` | gRPC → HTTP `/x/v2/dm/web/seg.so` + 手写 protobuf 解码 |
| `lib/pages/home` | `UI/Features/Home/*` | GetX → Observation |
| `lib/pages/setting/pages/loudness_setting.dart` | `UI/Features/Settings/LoudnessSettingsScreen.swift` | 文案与参数区间保持一致 |

## 2. 接口参数（与 Flutter 版一致）

| 接口 | 方法 / 路径 | 关键参数 |
| :--- | :--- | :--- |
| 推荐流 | `GET /x/web-interface/wbi/index/top/feed/rcmd` | `version=1&feed_version=V8&homepage_ver=1&ps=12&fresh_idx&brush&fresh_type=4`，Wbi 签名 |
| 视频详情 | `GET /x/web-interface/wbi/view` | `bvid`（或 `aid`），Wbi 签名 |
| 播放地址 | `GET /x/player/wbi/playurl` | `cid&qn&fnval=4048&fourk=1&fnver=0&voice_balance&try_look=1&web_location=1315873&dm_img_*`；Wbi 签名 |
| 合流地址（PiP） | `GET /x/player/playurl` | `cid&qn=64&platform=html5&high_quality=1` |
| 分类搜索 | `GET /x/web-interface/wbi/search/type` | `search_type=video&keyword&page&page_size=20&order&platform=pc&web_location=1430654` |
| 热搜 | `GET /x/v2/search/trending/ranking` | `limit=30`；失败回退 `s.search.bilibili.com/main/hotword` |
| 联想 | `GET /x/web-interface/suggest` | `term&highlight=0&spmid=333.1365&web_location=333.1365` |
| 弹幕分段 | `GET /x/v2/dm/web/seg.so` | `type=1&oid=cid&pid=aid&segment_index=1..n`（每段 360s） |

Wbi 密钥来自 `/x/web-interface/nav` 的 `data.wbi_img.img_url/sub_url`，取文件名后
按混淆表拼接；与 Flutter 版一样按天缓存。

## 3. 数据模型差异

| 概念 | Flutter | Swift |
| :--- | :--- | :--- |
| 推荐卡片 | `RcmdVideoItemModel` | `VideoCard`（统一推荐/搜索/历史展示） |
| 播放信息 | `PlayUrlModel` + `dash.video/audio` | `PlayURLResult` + `VideoTrack` / `AudioTrack` |
| 弹幕 | protobuf `DanmakuElem` | `DanmakuItem` + `DanmakuItem.Mode` |
| 历史 | Hive `HistoryModel` | `PlaybackRecord`（SwiftData `@Model`） |
| 设置 | `Pref`（Hive） | `SettingsStore`（UserDefaults，`settings.*` 键） |

数字字段统一用 `FlexInt` / `FlexDouble` 宽松解码：B 站同一字段可能返回
`80`、`"80"` 或 `80.0`，这在 Flutter 版里是靠 `dynamic` 处理的。

## 4. 有意为之的差异

1. **弹幕传输**：Flutter 走 gRPC；Swift 用公开 HTTP protobuf 分段接口，避免
   gRPC 运行时依赖，同时保留 6 分钟分段的并发拉取。
2. **弹幕渲染**：Flutter 用自绘 canvas；Swift 用 CoreAnimation 图层，暂停/恢复
   只需调整父图层时序参数。
3. **画中画**：Flutter 侧由 fvp/mpv 插件能力决定；Swift 用 AVKit + 合流 MP4
   的接管方案（720P），退出时回写进度。
4. **状态管理**：GetX/Riverpod → Observation + `@MainActor`，不再有全局单例
   `GlobalData`，依赖显式注入 `AppEnvironment`。

## 5. 后续分组复用建议

- Group 2 登录：在 `BiliClient` 增加 Cookie/`SESSDATA` 注入点，`BiliCredentials`
  预留了 `buvid3/buvid4`；播放地址已支持 `voice_balance`。
- Group 3 榜单/空间：`VideoCard` 与 `VideoRow` 可直接复用，只需新增分页 Model。
- Group 5 直播：`MPVEngine` 可直接播放 FLV/HLS，画质切换沿用 `selectQuality` 思路。
- Group 6 下载：`PlayURLResult` 已带 `backupURLs` 与码率，可直接构建 DASH 下载任务。
