import SwiftUI

/// 根导航：iPhone 使用悬浮玻璃 TabBar，iPad 使用双栏。
struct RootView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selection: AppTab = .home
    @State private var searchTarget: DeepLinkSearchTarget?
    @State private var showsLinkedHistory = false

    var body: some View {
        @Bindable var environment = environment

        Group {
            if horizontalSizeClass == .regular {
                splitLayout
            } else {
                compactLayout
            }
        }
        .fullScreenCover(item: $environment.playerRequest) { request in
            PlayerScreen(request: request)
        }
        .sheet(item: $searchTarget) { target in
            SearchPanelSheet(initialKeyword: target.keyword)
        }
        .sheet(isPresented: $showsLinkedHistory) {
            NavigationStack {
                HistoryScreen()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("完成") { showsLinkedHistory = false }
                        }
                    }
            }
            .presentationDetents([.large])
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .tint(Glass.pink)
        .task {
            await environment.account.restore()
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard let route = DeepLinkRoute.parse(url) else { return }
        switch route {
        case .home:
            selection = .home
        case .history:
            showsLinkedHistory = true
        case .search(let keyword):
            selection = .home
            searchTarget = DeepLinkSearchTarget(keyword: keyword)
        case .video(let bvid, let cid):
            selection = .home
            environment.playerRequest = PlayerRequest(bvid: bvid, aid: nil, cid: cid)
        }
    }

    // MARK: - iPhone

    private var compactLayout: some View {
        TabView(selection: $selection) {
            ForEach(AppTab.allCases) { tab in
                NavigationStack {
                    screen(for: tab)
                        .toolbar(.hidden, for: .navigationBar)
                        .toolbar(.hidden, for: .tabBar)
                        .safeAreaInset(edge: .bottom) {
                            Color.clear.frame(height: 68)
                        }
                }
                .tag(tab)
            }
        }
        .overlay(alignment: .bottom) {
            GlassTabBar(selection: $selection)
                .padding(.horizontal, 40)
                .padding(.bottom, 4)
        }
    }

    // MARK: - iPad

    private var splitLayout: some View {
        NavigationSplitView {
            List(AppTab.allCases, selection: Binding(
                get: { selection },
                set: { if let tab = $0 { selection = tab } }
            )) { tab in
                Label(tab.title, systemImage: tab.icon)
                    .tag(tab)
            }
            .navigationTitle("PiliPlus")
            .listStyle(.sidebar)
        } detail: {
            NavigationStack {
                screen(for: selection)
                    .toolbar(.hidden, for: .navigationBar)
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    // MARK: - Screens

    @ViewBuilder
    private func screen(for tab: AppTab) -> some View {
        switch tab {
        case .home:
            HomeScreen()
        case .dynamics:
            DynamicsScreen()
        case .discover:
            DiscoverScreen()
        case .mine:
            MineScreen()
        }
    }
}

#Preview {
    RootView()
        .environment(AppEnvironment.preview())
        .modelContainer(AppEnvironment.preview().modelContainer)
}

private struct DeepLinkSearchTarget: Identifiable {
    let id = UUID()
    let keyword: String
}
