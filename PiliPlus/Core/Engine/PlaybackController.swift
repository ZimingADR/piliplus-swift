import AVKit
import Foundation
import Observation
import QuartzCore

/// 播放器状态机与业务编排。
///
/// 职责边界：
/// - `MPVEngine` 只管 libmpv 本身；
/// - 本类型负责取流、断点续播、弹幕加载、音量平衡注入、历史落库与锁屏信息；
/// - 视图只读取状态并调用命令方法。
@MainActor
@Observable
final class PlaybackController {
    enum LoadState: Equatable {
        case idle
        case loading
        case ready
        case failed(String)
    }

    // MARK: - 状态

    private(set) var loadState: LoadState = .idle
    private(set) var detail: VideoDetail?
    private(set) var sourceCard: VideoCard?
    private(set) var currentPageIndex = 0
    private(set) var currentTime: Double = 0
    private(set) var duration: Double = 0
    private(set) var isPlaying = false
    private(set) var isBuffering = false
    private(set) var availableQualities: [VideoQuality] = []
    private(set) var selectedQuality = BiliQuality.defaultQuality
    private(set) var danmakuItems: [DanmakuItem] = []
    private(set) var measurement: LoudnessMeasurement?
    private(set) var loudnessSummary = AudioNormalization.summary(rawCode: "0")
    private(set) var isPiPActive = false

    var danmakuVisible: Bool {
        didSet { settings.danmakuEnabled = danmakuVisible }
    }

    var errorMessage: String?

    // MARK: - 互动状态

    enum ActionOutcome: Sendable {
        case success(String)
        case needsLogin
        case failure(String)
    }

    private(set) var isLiked = false
    private(set) var isFavorited = false
    private(set) var isInWatchLater = false
    private(set) var isFollowing = false
    private(set) var coinCount = 0

    // MARK: - 依赖

    @ObservationIgnored private let client: BiliClient
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let history: PlaybackHistoryStore
    @ObservationIgnored private let audioSession: AudioSessionCoordinator
    @ObservationIgnored private let account: AccountStore
    @ObservationIgnored private(set) var engine = MPVEngine()
    @ObservationIgnored let pictureInPicture = PictureInPictureManager()

    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var danmakuTask: Task<Void, Never>?
    @ObservationIgnored private var hasSurface = false
    @ObservationIgnored private var pendingStream: PendingStream?
    @ObservationIgnored private var lastHistorySave = Date.distantPast
    @ObservationIgnored private var hasStartedPlayback = false
    @ObservationIgnored private var lastNowPlayingUpdate = Date.distantPast
    @ObservationIgnored private var didPreparePlayback = false

    private struct PendingStream {
        let videoURL: URL
        let audioURL: URL?
        let startAt: Double
        let playURL: PlayURLResult
    }

    private struct PGCContext {
        let season: PGCSeason
        let episodes: [PGCEpisode]
    }

    @ObservationIgnored private var pgcContext: PGCContext?

    init(
        client: BiliClient,
        settings: SettingsStore,
        history: PlaybackHistoryStore,
        audioSession: AudioSessionCoordinator,
        account: AccountStore
    ) {
        self.client = client
        self.settings = settings
        self.history = history
        self.audioSession = audioSession
        self.account = account
        danmakuVisible = settings.danmakuEnabled
        selectedQuality = settings.defaultQuality
        configureRemoteCommands()
    }

    // MARK: - 展示信息

    var title: String {
        detail?.title ?? sourceCard?.title ?? "正在加载"
    }

    var ownerName: String {
        detail?.owner?.name ?? sourceCard?.ownerName ?? ""
    }

    var ownerMid: Int? {
        detail?.owner?.mid
    }

    var coverURL: URL? {
        detail?.coverURL ?? sourceCard?.coverURL
    }

    var currentPage: VideoDetail.Page? {
        guard let pages = detail?.displayPages, pages.indices.contains(currentPageIndex) else {
            return nil
        }
        return pages[currentPageIndex]
    }

    var pages: [VideoDetail.Page] {
        detail?.displayPages ?? []
    }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(currentTime / duration, 0), 1)
    }

    var timeText: String {
        "\(VideoCard.formatDuration(Int(currentTime))) / \(VideoCard.formatDuration(Int(duration)))"
    }

    // MARK: - 互动

    func toggleLike() async -> ActionOutcome {
        guard account.isLoggedIn else { return .needsLogin }
        guard let aid = detail?.aid else { return .failure("缺少视频信息") }
        do {
            try await client.setVideoLike(aid: aid, isLiked: !isLiked)
            isLiked.toggle()
            return .success(isLiked ? "已点赞" : "已取消点赞")
        } catch {
            return .failure(actionMessage(for: error))
        }
    }

    func addCoin() async -> ActionOutcome {
        guard account.isLoggedIn else { return .needsLogin }
        guard let aid = detail?.aid else { return .failure("缺少视频信息") }
        guard coinCount < 2 else { return .failure("最多投两枚硬币") }
        do {
            try await client.addVideoCoin(aid: aid, multiply: 1, alsoLike: !isLiked)
            coinCount += 1
            isLiked = true
            return .success("已投币")
        } catch {
            return .failure(actionMessage(for: error))
        }
    }

    func toggleFavorite() async -> ActionOutcome {
        guard account.isLoggedIn, let mid = account.profile?.mid else { return .needsLogin }
        guard let aid = detail?.aid else { return .failure("缺少视频信息") }
        do {
            let folders = try await client.favoriteFolders(mid: mid)
            guard let folder = folders.first else {
                return .failure("请先在网页端创建收藏夹")
            }
            try await client.favoriteVideo(
                aid: aid,
                addMediaIDs: isFavorited ? [] : [folder.id],
                delMediaIDs: isFavorited ? [folder.id] : []
            )
            isFavorited.toggle()
            return .success(isFavorited ? "已收藏到「\(folder.title)」" : "已取消收藏")
        } catch {
            return .failure(actionMessage(for: error))
        }
    }

    func toggleWatchLater() async -> ActionOutcome {
        guard account.isLoggedIn else { return .needsLogin }
        guard let detail else { return .failure("缺少视频信息") }
        do {
            if isInWatchLater {
                try await client.removeFromWatchLater(aids: [detail.aid])
            } else {
                try await client.addToWatchLater(aid: detail.aid, bvid: detail.bvid)
            }
            isInWatchLater.toggle()
            return .success(isInWatchLater ? "已加入稍后再看" : "已移出稍后再看")
        } catch {
            return .failure(actionMessage(for: error))
        }
    }

    func toggleFollow() async -> ActionOutcome {
        guard account.isLoggedIn else { return .needsLogin }
        guard let mid = ownerMid else { return .failure("缺少 UP 主信息") }
        do {
            try await client.modifyRelation(mid: mid, follow: !isFollowing)
            isFollowing.toggle()
            return .success(isFollowing ? "已关注" : "已取消关注")
        } catch {
            return .failure(actionMessage(for: error))
        }
    }

    private func actionMessage(for error: any Error) -> String {
        (error as? any LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    // MARK: - 画中画

    var isPictureInPictureSupported: Bool { pictureInPicture.isSupported }
    var pictureInPictureLayer: AVPlayerLayer? { pictureInPicture.playerLayer }

    func togglePictureInPicture() {
        if isPiPActive || pictureInPicture.isActive {
            finishPictureInPicture()
        } else {
            Task { await beginPictureInPicture() }
        }
    }

    private func beginPictureInPicture() async {
        guard pictureInPicture.isSupported,
              let detail,
              let page = currentPage else { return }

        let start = currentTime
        engine.pause()
        isPlaying = false

        do {
            let url = try await client.muxedPlayURL(
                bvid: detail.bvid,
                aid: detail.aid,
                cid: page.cid
            )
            guard pictureInPicture.prepare(url: url, at: start) != nil else { return }

            // AVPictureInPictureController 需要图层进入视图层级后才可能可用。
            for _ in 0 ..< 12 {
                if pictureInPicture.start() {
                    isPiPActive = true
                    return
                }
                if Task.isCancelled { break }
                try? await Task.sleep(for: .milliseconds(200))
            }
            engine.play()
            isPlaying = true
        } catch {
            engine.play()
            isPlaying = true
        }
    }

    private func finishPictureInPicture() {
        guard isPiPActive || pictureInPicture.isActive else { return }
        let resumeAt = pictureInPicture.finish()
        isPiPActive = false
        engine.seek(to: resumeAt)
        engine.play()
        isPlaying = true
        updateNowPlaying(force: true)
    }

    // MARK: - 生命周期

    func attachSurface(_ layer: CAMetalLayer) {
        guard !hasSurface else { return }
        hasSurface = true
        do {
            try engine.attach(layer: layer)
            if pendingStream != nil {
                preparePlaybackIfNeeded()
            }
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    func start(card: VideoCard) {
        sourceCard = card
        resetState()
        loadState = .loading

        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let detail = try await client.videoDetail(bvid: card.bvid, aid: card.aid)
                self.detail = detail
                let pageIndex = self.preferredPageIndex(for: card, in: detail)
                self.currentPageIndex = pageIndex
                try await self.prepare(pageIndex: pageIndex, startAt: nil)
            } catch {
                if Cancellation.isCancellation(error) { return }
                self.fail(error)
            }
        }
    }

    func start(bvid: String, aid: Int? = nil, cid: Int? = nil) {
        sourceCard = nil
        resetState()
        loadState = .loading

        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let detail = try await client.videoDetail(bvid: bvid, aid: aid)
                self.detail = detail
                var pageIndex = 0
                if let cid, let index = detail.displayPages.firstIndex(where: { $0.cid == cid }) {
                    pageIndex = index
                }
                self.currentPageIndex = pageIndex
                try await self.prepare(pageIndex: pageIndex, startAt: nil)
            } catch {
                if Cancellation.isCancellation(error) { return }
                self.fail(error)
            }
        }
    }

    /// 番剧播放：把季/集映射成统一的 `VideoDetail` 分P结构，复用播放器状态机。
    func startPGC(season: PGCSeason, episode: PGCEpisode) {
        sourceCard = nil
        resetState()
        loadState = .loading
        pgcContext = PGCContext(season: season, episodes: season.episodes)

        let pages = season.episodes.enumerated().map { index, item in
            VideoDetail.Page(
                cid: item.cid ?? 0,
                page: index + 1,
                part: item.displayTitle,
                duration: FlexInt(item.duration)
            )
        }
        detail = VideoDetail(
            bvid: episode.bvid,
            aid: episode.aid ?? 0,
            cid: episode.cid,
            title: season.title,
            pic: season.coverURL?.absoluteString,
            desc: season.evaluate,
            duration: FlexInt(pages.reduce(0) { $0 + ($1.duration?.value ?? 0) }),
            pubdate: nil,
            tname: "番剧",
            owner: VideoDetail.Owner(mid: nil, name: season.title, face: nil),
            stat: nil,
            pages: pages
        )
        currentPageIndex = season.episodes.firstIndex(of: episode) ?? 0

        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.prepare(pageIndex: self.currentPageIndex, startAt: nil)
            } catch {
                if Cancellation.isCancellation(error) { return }
                self.fail(error)
            }
        }
    }

    func stop() {        saveProgress(force: true)
        pollTask?.cancel()
        loadTask?.cancel()
        danmakuTask?.cancel()
        pollTask = nil
        engine.stop()
        audioSession.clearNowPlaying()
        isPlaying = false
    }

    func detachEngine() {
        engine.shutdown()
        hasSurface = false
    }

    // MARK: - 播放命令

    func togglePlayPause() {
        guard case .ready = loadState else { return }
        engine.togglePause()
        isPlaying = !engine.isPaused
        updateNowPlaying(force: true)
    }

    func play() {
        engine.play()
        isPlaying = true
    }

    func pause() {
        engine.pause()
        isPlaying = false
        saveProgress(force: true)
    }

    func seek(to seconds: Double) {
        let target = min(max(seconds, 0), max(duration - 0.5, 0))
        engine.seek(to: target)
        currentTime = target
        updateNowPlaying(force: true)
    }

    func seek(by offset: Double) {
        seek(to: currentTime + offset)
    }

    func setDanmakuVisible(_ visible: Bool) {
        danmakuVisible = visible
    }

    func selectQuality(_ quality: Int) {
        guard quality != selectedQuality || hasStartedPlayback == false else { return }
        selectedQuality = quality
        guard detail != nil else { return }

        let resumePosition = currentTime
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.prepare(
                    pageIndex: self.currentPageIndex,
                    startAt: resumePosition
                )
                self.updateLoudnessSummary()
            } catch {
                if Cancellation.isCancellation(error) { return }
                self.fail(error)
            }
        }
    }

    func selectPage(index: Int) {
        guard let pages = detail?.displayPages, pages.indices.contains(index) else { return }
        let previous = currentPageIndex
        guard previous != index else { return }
        currentPageIndex = index
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.prepare(pageIndex: index, startAt: 0)
            } catch {
                if Cancellation.isCancellation(error) { return }
                self.fail(error)
            }
        }
    }

    // MARK: - 取流与起播

    private func prepare(pageIndex: Int, startAt: Double?) async throws {
        guard let detail else { return }
        let pages = detail.displayPages
        guard pages.indices.contains(pageIndex) else {
            throw BiliAPIError(code: -6, message: "视频分P信息异常")
        }
        let page = pages[pageIndex]

        let quality = clampedQuality(settings.defaultQuality)
        let result: PlayURLResult
        if let pgc = pgcContext, pgc.episodes.indices.contains(pageIndex) {
            result = try await client.pgcPlayURL(
                episode: pgc.episodes[pageIndex],
                seasonID: pgc.season.seasonID,
                quality: quality
            )
        } else {
            result = try await client.playURL(
                bvid: detail.bvid,
                aid: detail.aid,
                cid: page.cid,
                quality: quality
            )
        }

        guard let videoTrack = result.videoTrack(
            preferring: quality,
            codec: settings.codecPreference
        ) else {
            throw BiliAPIError(code: -7, message: "没有可用清晰度")
        }

        availableQualities = result.availableQualities
        selectedQuality = videoTrack.quality
        measurement = result.measurement
        updateLoudnessSummary()

        let resumePosition = startAt ?? resumePositionIfNeeded(detail: detail, page: page)
        pendingStream = PendingStream(
            videoURL: videoTrack.url,
            audioURL: result.audioTrack()?.url,
            startAt: resumePosition,
            playURL: result
        )
        didPreparePlayback = false
        preparePlaybackIfNeeded()
        let danmakuPID: Int
        if let pgc = pgcContext, pgc.episodes.indices.contains(pageIndex) {
            danmakuPID = pgc.episodes[pageIndex].id
        } else {
            danmakuPID = detail.aid
        }
        loadDanmaku(cid: page.cid, pid: danmakuPID, duration: result.duration)
    }

    private func preparePlaybackIfNeeded() {
        guard hasSurface, let stream = pendingStream, !didPreparePlayback else { return }
        didPreparePlayback = true

        let filter = AudioNormalization.mpvAudioFilter(
            rawCode: settings.audioNormalizationMode,
            targetLUFS: settings.loudnessTargetLUFS,
            strength: settings.loudnessStrength,
            measurement: measurement
        )
        engine.setAudioFilter(filter)
        engine.load(videoURL: stream.videoURL)
        if let audioURL = stream.audioURL {
            engine.attachAudioTrack(audioURL)
        }
        audioSession.activate()
        hasStartedPlayback = false
        duration = stream.playURL.duration
        startPolling()
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                self.tick()
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
    }

    private func tick() {
        guard hasSurface else { return }

        // 画中画期间由系统播放器接管，MPV 保持暂停；退出时回写进度。
        if isPiPActive {
            if !pictureInPicture.isActive {
                finishPictureInPicture()
            }
            return
        }

        updatePlaybackState()
    }

    private func updatePlaybackState() {
        if engine.isFileLoaded {
            engine.materializeAudioTrackIfNeeded()

            if !hasStartedPlayback {
                hasStartedPlayback = true
                if let startAt = pendingStream?.startAt, startAt > 1 {
                    engine.seek(to: startAt)
                }
                engine.play()
                loadState = .ready
            }
        }

        let time = engine.currentTime
        if time.isFinite {
            currentTime = time
        }
        let engineDuration = engine.duration
        if engineDuration > 0 {
            duration = engineDuration
        }
        isPlaying = engine.isFileLoaded && !engine.isPaused
        isBuffering = engine.isBuffering

        if engine.hasEnded, isPlaying {
            isPlaying = false
            saveProgress(force: true)
        }

        if Date.now.timeIntervalSince(lastHistorySave) > 10 {
            saveProgress()
        }
        updateNowPlaying(force: false)
    }

    // MARK: - 断点续播与历史

    private func preferredPageIndex(for card: VideoCard, in detail: VideoDetail) -> Int {
        if let cid = card.cid,
           let index = detail.displayPages.firstIndex(where: { $0.cid == cid }) {
            return index
        }
        if let record = history.record(bvid: detail.bvid),
           detail.displayPages.indices.contains(record.pageIndex) {
            return record.pageIndex
        }
        return 0
    }

    private func resumePositionIfNeeded(detail: VideoDetail, page: VideoDetail.Page) -> Double {
        guard settings.resumePlaybackEnabled,
              let record = history.record(bvid: detail.bvid),
              record.cid == page.cid,
              record.position > 5 else {
            return 0
        }
        // 距离结尾 5 秒内不再续播，避免一打开就结束。
        let length = record.duration > 0 ? record.duration : detail.durationSeconds
        if length > 0, length - record.position < 5 {
            return 0
        }
        return record.position
    }

    func saveProgress(force: Bool = false) {
        guard let detail, let page = currentPage else { return }
        let position = currentTime
        guard position > 3 || force else { return }
        guard duration > 0 else { return }

        let snapshot = PlaybackSnapshot(
            bvid: detail.bvid,
            aid: detail.aid,
            cid: page.cid,
            title: detail.title,
            coverURLString: detail.pic ?? "",
            ownerName: detail.owner?.name ?? "",
            duration: duration,
            position: position,
            pageIndex: currentPageIndex,
            pageTitle: page.part ?? "P\(page.page)"
        )
        history.upsert(snapshot)
        lastHistorySave = .now
    }

    // MARK: - 弹幕

    private func loadDanmaku(cid: Int, pid: Int, duration: Double) {
        danmakuTask?.cancel()
        danmakuTask = Task { [weak self] in
            guard let self else { return }
            do {
                let items = try await client.danmakuItems(cid: cid, pid: pid, duration: duration)
                guard !Task.isCancelled else { return }
                self.danmakuItems = items
            } catch {
                // 弹幕失败不影响视频播放。
                self.danmakuItems = []
            }
        }
    }

    // MARK: - 音量平衡

    func updateLoudnessSummary() {
        loudnessSummary = AudioNormalization.summary(
            rawCode: settings.audioNormalizationMode,
            targetLUFS: settings.loudnessTargetLUFS,
            strength: settings.loudnessStrength,
            measurement: measurement
        )
        guard hasStartedPlayback else { return }
        engine.setAudioFilter(
            AudioNormalization.mpvAudioFilter(
                rawCode: settings.audioNormalizationMode,
                targetLUFS: settings.loudnessTargetLUFS,
                strength: settings.loudnessStrength,
                measurement: measurement
            )
        )
    }

    // MARK: - 锁屏 / 远程控制

    private func configureRemoteCommands() {
        audioSession.onTogglePlayPause = { [weak self] in
            self?.togglePlayPause()
        }
        audioSession.onSeekTo = { [weak self] position in
            self?.seek(to: position)
        }
        audioSession.onSkip = { [weak self] offset in
            self?.seek(by: offset)
        }
    }

    private func updateNowPlaying(force: Bool) {
        guard isPlaying || force else { return }
        guard Date.now.timeIntervalSince(lastNowPlayingUpdate) > 1 || force else { return }
        lastNowPlayingUpdate = .now
        audioSession.updateNowPlaying(
            title: title,
            artist: ownerName,
            duration: duration,
            elapsed: currentTime,
            isPlaying: isPlaying,
            coverURL: coverURL
        )
    }

    // MARK: - 辅助

    private func resetState() {
        pollTask?.cancel()
        danmakuTask?.cancel()
        engine.stop()
        pgcContext = nil
        pendingStream = nil
        hasStartedPlayback = false
        didPreparePlayback = false
        loadState = .loading
        errorMessage = nil
        danmakuItems = []
        availableQualities = []
        currentTime = 0
        duration = 0
        isPlaying = false
    }

    private func fail(_ error: any Error) {
        let message = (error as? any LocalizedError)?.errorDescription ?? error.localizedDescription
        loadState = .failed(message)
        errorMessage = message
    }

    private func clampedQuality(_ quality: Int) -> Int {
        let supported = availableQualities.map(\.id)
        guard !supported.isEmpty else { return quality }
        if supported.contains(quality) { return quality }
        return supported.min(by: { abs($0 - quality) < abs($1 - quality) }) ?? quality
    }
}
