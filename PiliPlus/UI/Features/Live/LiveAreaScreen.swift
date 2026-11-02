import SwiftUI

/// 直播分区：一级分区切换 + 分区直播间。
struct LiveAreaScreen: View {
    @Environment(AppEnvironment.self) private var environment

    @State private var areas: [LiveArea] = []
    @State private var selectedAreaID: Int?
    @State private var rooms: [LiveRoom] = []
    @State private var isLoadingRooms = false
    @State private var phase: Phase = .idle

    private enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    var body: some View {
        ZStack {
            LiquidBackground()
            VStack(spacing: 0) {
                switch phase {
                case .idle, .loading:
                    LoadingStateView(style: .loading)
                case .failed(let message):
                    LoadingStateView(style: .failure(message)) {
                        Task { await loadAreas() }
                    }
                case .loaded:
                    areaChips
                    roomsContent
                }
            }
        }
        .navigationTitle("直播分区")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadAreas() }
    }

    private var areaChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(areas) { area in
                    Button {
                        guard selectedAreaID != area.id else { return }
                        selectedAreaID = area.id
                        Task { await loadRooms(areaID: area.id) }
                    } label: {
                        Text(area.name)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                selectedAreaID == area.id
                                    ? Glass.pink.opacity(0.28)
                                    : Color.white.opacity(0.08),
                                in: .capsule
                            )
                            .overlay {
                                if selectedAreaID == area.id {
                                    Capsule().stroke(Glass.pink.opacity(0.6), lineWidth: 1)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private var roomsContent: some View {
        if isLoadingRooms {
            LoadingStateView(style: .loading)
        } else if rooms.isEmpty {
            ContentUnavailableView {
                Label("该分区暂无直播", systemImage: "dot.radiowaves.left.and.right")
            } description: {
                Text("换个分区看看。")
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(rooms) { room in
                        NavigationLink {
                            LiveRoomScreen(room: room)
                        } label: {
                            roomRow(room)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.vertical, 10)
            }
        }
    }

    private func roomRow(_ room: LiveRoom) -> some View {
        HStack(spacing: 12) {
            RemoteImage(url: room.coverURL)
                .frame(width: 116, height: 68)
                .clipShape(.rect(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(room.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(room.uname)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(room.areaName)
                    if !room.watchedText.isEmpty {
                        Text(room.watchedText)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .liquidGlass(cornerRadius: 16, elevation: 0.6)
    }

    private func loadAreas() async {
        phase = .loading
        do {
            areas = try await environment.client.liveAreas()
            guard let first = areas.first else {
                phase = .loaded
                return
            }
            selectedAreaID = first.id
            phase = .loaded
            await loadRooms(areaID: first.id)
        } catch {
            phase = .failed((error as? any LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    private func loadRooms(areaID: Int) async {
        isLoadingRooms = true
        do {
            rooms = try await environment.client.liveAreaRooms(parentAreaID: areaID)
        } catch {
            rooms = []
        }
        isLoadingRooms = false
    }
}
