# 迁移路线图（Group 1 → 6）

状态以 GitHub Actions 的编译 + 单元测试为准；每一项都对应 Flutter 版
`lib/pages/` 下的真实模块。

## 总览

| 分组 | 目标 | 状态 |
| :--- | :--- | :--- |
| Group 1 | 核心播放与发现闭环（MVP） | ✅ 已交付（v0.1.1） |
| Group 2 | 登录、收藏、评论、关注、弹幕屏蔽 | 🚧 主要链路已可用（收藏 / 关注 / 评论 / 互动） |
| Group 3 | UP 主空间、榜单、稍后再看、热门 | 🚧 热门 / 排行 / 稍后 / UP 主投稿已可用 |
| Group 4 | 动态、专栏、话题 | 🚧 动态信息流 / 详情 / 专栏阅读已可用 |
| Group 5 | 番剧、直播、音乐 | 🚧 番剧索引/季详情/播放、直播列表/直播间已可用 |
| Group 6 | 下载、WebDAV、SponsorBlock、小组件 | 🚧 离线下载 / WebDAV / SponsorBlock / 仅音频已可用 |

## Group 2 明细

| 模块 | 实现位置 | 状态 |
| :--- | :--- | :--- |
| `login`（二维码） | `UI/Features/Account/LoginScreen.swift`、`BiliClient.qrLogin*` | ✅ |
| `login`（短信 / 密码） | — | ⏳ Web 端限制，暂缓 |
| `mine` | `UI/Features/Account/MineScreen.swift` | ✅ 资料 / 统计 / 快捷入口 |
| `fav` / `fav_detail` | `UI/Features/Favorites/*` | ✅ 列表 + 分页详情 |
| `fav_create` | `FavoritesScreen` 工具栏 | ✅ 新建公开收藏夹 |
| `fav_sort` / `fav_folder_sort` / `fav_search` | — | ⏳ |
| `main_reply` | `UI/Features/Comments/CommentsSheet.swift` | ✅ 主楼分页 + 发表 + 点赞 |
| `my_reply`（楼中楼） | `UI/Features/Comments/RepliesSheet.swift` | ✅ 子回复分页 + 回复输入 |
| `emote` | `EmoteCatalog` + 评论表情面板 | ✅ 常用表情码插入 |
| `follow` | `UI/Features/Follow/*`、`MemberScreen` 关注按钮 | ✅ 列表 + 关注 / 取关 |
| `follow_search` | — | ⏳ |
| `danmaku_block` | — | ⏳ |
| `login_devices` / `login_log` | — | ⏳ |
| `webview`（Geetest） | — | ⏳ 仅在触发风控时需要 |
| 视频互动 | 播放器「更多」菜单 | ✅ 点赞 / 投币 / 收藏 / 稍后再看 / 关注 |

## Group 3 明细

| 模块 | 实现位置 | 状态 |
| :--- | :--- | :--- |
| `hot` | `VideoFeedModel(.hot)` + `VideoFeedScreen` | ✅ |
| `rank` | `VideoFeedModel(.rank)` | ✅ |
| `later` / `later_search` | `LaterScreen` + 播放器菜单 | ✅ 列表 + 加入 / 移除 |
| `member` / `member_home` / `member_video` | `UI/Features/Member/MemberScreen.swift` | ✅ 资料 + 投稿分页 + 排序 |
| `member_profile` / `member_favorite` / `member_like_arc` 等 | — | ⏳ |
| `member_search` | — | ⏳ |
| `popular_series` / `popular_precious` | — | ⏳ |

## Group 4 明细

| 模块 | 实现位置 | 状态 |
| :--- | :--- | :--- |
| `dynamics` | `UI/Features/Dynamics/*` | ✅ 关注动态、分页、图文/视频/专栏卡片 |
| `dynamics_detail` | `DynamicDetailScreen` | ✅ 单条动态展开 + 评论区入口 |
| 动态评论 | `CommentsSheet(source: .dynamic)`、`dynamicComments` | ✅ type=17 分页 / 点赞 / 楼中楼 |
| `article` | `UI/Features/Article/ArticleScreen.swift` | ✅ WKWebView 渲染 + 原生头部 |
| 动态互动 | 卡片点赞 + `RepostSheet` 转发 | ✅ 点赞 / 转发（发布原动态 ⏳） |
| `dynamics_tab` / `dynamics_topic` / `dynamics_create` | — | ⏳ |
| `article_list` | — | ⏳ |
| `group_panel` / `msg_feed_top` / `fan` | — | ⏳ |

## Group 5 明细

| 模块 | 实现位置 | 状态 |
| :--- | :--- | :--- |
| `pgc` | `UI/Features/PGC/PGCScreen.swift` | ✅ 季详情 + 剧集选集 + PGC 播放 |
| `pgc` 播放 | `PlaybackController.startPGC` + `BiliClient.pgcPlayURL` | ✅ web v2 / 旧版回退 |
| `pgc_index` | `PGCScreen` | ✅ 索引分页（海报网格） |
| `pgc_review` | — | ⏳ |
| `live` | `UI/Features/Live/LiveScreen.swift` | ✅ 推荐列表分页 |
| `live_room` | `LiveRoomScreen` + MPV | ✅ FLV/HLS 直播流 |
| `live_area` / `live_search` / `live_follow` | — | ⏳ |
| `audio` / `music` | — | ⏳ |
| `subscription` / `save_panel` | — | ⏳ |

## Group 6 明细

| 模块 | 实现位置 | 状态 |
| :--- | :--- | :--- |
| `download` | `Core/Download/DownloadManager.swift`、`UI/Features/Downloads/*` | ✅ DASH 双轨下载 / 离线播放 / 删除 |
| `sponsor_block` | `Core/SponsorBlock/SponsorBlockService.swift` + 播放器自动跳过 | ✅ 支持片头/片尾/赞助/求三连等分类 |
| 仅音频（听视频） | 播放器菜单 + `vid=no` | ✅ 封面占位 + 偏好持久化 |
| `webdav` | `Core/WebDAV/WebDAVSyncService.swift`、`WebDAVSyncScreen` | ✅ 历史 + 设置备份 / 恢复（Basic Auth） |
| App Intents / Siri / 深链 | `AppIntents/PiliPlusIntents.swift`、`Core/DeepLink/DeepLinkRoute.swift` | ✅ 打开推荐/历史、搜索视频、`piliplus://` 路由 |
| 桌面小组件 | `PiliPlusWidgets/` + `Shared/SharedRecentPlayback` | ✅ 小/中号「继续观看」，App Group 共享最近历史、点击续播 |
| 灵动岛 Live Activity | `Shared/PlaybackActivityAttributes`、`Core/Activity/*`、`PiliPlusWidgets/PlaybackLiveActivity` | ✅ 锁屏卡片 + 灵动岛紧凑/展开/最小布局，实时进度 |
| `whisper` / `dlna` / `ai_chat` / `log_table` | — | ⏳ |

## Liquid Glass 设计系统

| 能力 | 实现 |
| :--- | :--- |
| 光晕背景 | `LiquidBackground`（双色低饱和渐变 + 模糊） |
| 玻璃卡片 | `.liquidGlass(...)` → 原生 `.glassEffect(.regular.tint(_:), in: .rect(...))` + 镜面描边 + 悬浮阴影 |
| 玻璃按钮 | `GlassButtonStyle`、`GlassIconButton`、`GlassChip` |
| 玻璃分段控件 | `GlassSegmentedControl`（matchedGeometry 弹簧切换） |
| 玻璃 TabBar | `GlassTabBar`（悬浮胶囊 + 选中胶囊） |
| 屏幕 / 列表背景 | `.liquidScreen()` / `.liquidList()` |

## 工程约束

- Swift 6 严格并发；UI 状态全部 `@MainActor @Observable`。
- 网络层唯一入口 `BiliClient`（actor），登录 Cookie 由 `AccountStore`
  持久化到 Keychain，登录态变化后重新获取 Wbi 密钥。
- 每次提交都必须通过 macOS runner 的模拟器编译 + 全部单元测试；
  发布 tag 会自动更新 `altstore.json` 并发布未签名 IPA。
