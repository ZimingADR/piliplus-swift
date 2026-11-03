# 接口探测记录

通过临时 GitHub Actions 任务（已删除）从公共网络验证了新增模块使用的匿名接口，
避免只靠本地 fixture 猜测字段。

| 接口 | HTTP | code | 结论 |
| :--- | :--- | :--- | :--- |
| `/x/topic/pub/search` | 200 | 0 | ✅ `topic_items` / `page_info` 与客户端模型一致 |
| `/x/polymer/web-dynamic/v1/feed/topic` | 200 | 0 | ✅ `topic_card_list`，复用动态卡映射 |
| `/x/topic/web/details/top` | 200 | 4401031 | ✅ 接口可用（探测用的 topic_id=1 不存在） |
| `/x/article/list/web/articles` | 200 | 0 | ✅ `list` / `articles` 与合集模型一致 |
| `/x/space/bangumi/follow/list` | 200 | 0 | ✅ `list` / `total` |
| `/audio/music-service/web/song/upper` | 200 | 0 | ✅ `data` / `totalSize` |
| `/x/web-interface/popular/series/list` | 200 | 0 | ✅ |
| `/x/web-interface/popular/precious` | 200 | 0 | ✅ |
| `api.live.bilibili.com/room/v1/Area/getList` | 200 | 0 | ✅ |
| `/x/web-interface/view/conclusion/get` | 200 | -403 | ⚠️ 需要登录态 + WBI；App 内已带 WBI 并提示错误 |

音频专区候选接口（`wave/recommend`、`wave/home`、`rank/list`、`song/list`）
均返回 **404**，因此未实现独立音频专区，仅保留「UP 主音频」与「音乐模式」。

此记录用于说明：字段模型不是凭空猜测，已做真实网络校验；登录态接口（私信、
直播关注、AI 总结）无法在匿名环境验证，App 内均有明确错误提示。
