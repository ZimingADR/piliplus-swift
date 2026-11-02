import SwiftData
import SwiftUI

/// 播放历史：下拉即断点续播的入口，支持本地关键词过滤与单条删除。
struct HistoryScreen: View {
    @Environment(AppEnvironment.self) private var environment
    @Query(sort: \PlaybackRecord.updatedAt, order: .reverse)
    private var records: [PlaybackRecord]

    @State private var searchText = ""
    @State private var showsClearConfirmation = false

    private var filteredRecords: [PlaybackRecord] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return records }
        return records.filter {
            $0.title.localizedCaseInsensitiveContains(keyword)
                || $0.ownerName.localizedCaseInsensitiveContains(keyword)
        }
    }

    var body: some View {
        Group {
            if records.isEmpty {
                ContentUnavailableView {
                    Label("还没有观看记录", systemImage: "clock.arrow.circlepath")
                } description: {
                    Text("看过的视频会出现在这里，再次点击可从上次进度继续播放。")
                }
            } else {
                listContent
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle("历史")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, placement: .navigationBarDrawer, prompt: "搜索播放历史")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    showsClearConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(records.isEmpty)
                .accessibilityLabel("清空播放历史")
            }
        }
        .confirmationDialog("清空全部播放历史？", isPresented: $showsClearConfirmation) {
            Button("清空", role: .destructive) {
                environment.history.removeAll()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("该操作不可撤销。")
        }
    }

    private var listContent: some View {
        List {
            ForEach(filteredRecords) { record in
                Button {
                    resume(record)
                } label: {
                    VideoRow(
                        title: record.title,
                        coverURL: record.coverURL,
                        ownerName: record.ownerName,
                        bottomText: record.resumeText,
                        progress: record.progress,
                        durationText: VideoCard.formatDuration(Int(record.duration))
                    )
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        environment.history.remove(record)
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
                .accessibilityHint("从上次播放位置继续")
            }
        }
        .listStyle(.plain)
    }

    private func resume(_ record: PlaybackRecord) {
        environment.playerRequest = PlayerRequest(
            bvid: record.bvid,
            aid: record.aid,
            cid: record.cid
        )
    }
}
