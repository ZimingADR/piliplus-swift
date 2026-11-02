# 迁移路线图（Group 1 → 6）

状态以 GitHub Actions 的编译 + 单元测试为准；每一项都对应 Flutter 版
`lib/pages/` 下的真实模块。

## 总览

| 分组 | 目标 | 状态 |
| :--- | :--- | :--- |
| Group 1 | 核心播放与发现闭环（MVP） | ✅ 已交付（v0.1.1） |
| Group 2 | 登录、收藏、评论、关注、弹幕屏蔽 | 🚧 进行中 |
| Group 3 | UP 主空间、榜单、稍后再看、热门 | 🚧 进行中 |
| Group 4 | 动态、专栏、话题 | ⏳ 待开始 |
| Group 5 | 番剧、直播、音乐 | ⏳ 待开始 |
| Group 6 | 下载、WebDAV、SponsorBlock、小组件 | ⏳ 待开始 |

## Group 2 明细

| 模块 | 实现位置 | 状态 |
| :--- | :--- | :--- |
| `login`（二维码） | `UI/Features/Account/LoginScreen.swift`、`BiliClient.qrLogin*` | ✅ |
| `login`（短信 / 密码） | — | ⏳ Web 端限制，暂缓 |
| `mine` | `UI/Features/Account/MineScreen.swift` | ✅ 资料 / 统计 / 快捷入口 |
| `fav` / `fav_detail` / `fav_search` | `UI/Features/Favorites/*` | ⏳ |
| `fav_create` / `fav_sort` / `fav_folder_sort` | — | ⏳ |
| `main_reply` / `my_reply` | `UI/Features/Comments/*` | ⏳ |
| `emote` | — | ⏳ |
| `follow` / `follow_search` | `UI/Features/Follow/*` | ⏳ |
| `danmaku_block` | — | ⏳ |
| `login_devices` / `login_log` | — | ⏳ |
| `webview`（Geetest） | — | ⏳ 仅在触发风控时需要 |

## Group 3 明细

| 模块 | 实现位置 | 状态 |
| :--- | :--- | :--- |
| `hot` | `VideoFeedModel(.hot)` + `VideoFeedScreen` | ✅ |
| `rank` | `VideoFeedModel(.rank)` | ✅ |
| `later` / `later_search` | `LaterScreen` | ✅ 列表；加入 / 删除 ⏳ |
| `member` / `member_home` / `member_video` | `UI/Features/Member/MemberScreen.swift` | ✅ 资料 + 投稿分页 + 排序 |
| `member_profile` / `member_favorite` / `member_like_arc` 等 | — | ⏳ |
| `member_search` | — | ⏳ |
| `popular_series` / `popular_precious` | — | ⏳ |

## Liquid Glass 设计系统

| 能力 | 实现 |
| :--- | :--- |
| 光晕背景 | `LiquidBackground`（双色低饱和渐变 + 模糊） |
| 玻璃卡片 | `.liquidGlass(cornerRadius:tint:elevation:)`，材质 + 镜面描边 + 悬浮阴影 |
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
