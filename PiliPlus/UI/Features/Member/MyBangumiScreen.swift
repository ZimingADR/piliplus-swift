import SwiftUI

/// 我的追番/追剧列表。
struct MyBangumiScreen: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var showsLogin = false

    var body: some View {
        Group {
            if let mid = environment.account.profile?.mid {
                MemberBangumiScreen(mid: mid, title: "我的追番")
            } else {
                ZStack {
                    LiquidBackground()
                    ContentUnavailableView {
                        Label("登录后查看追番", systemImage: "tv")
                    } description: {
                        Text("追番列表与账号绑定。")
                    } actions: {
                        Button("扫码登录") { showsLogin = true }
                            .buttonStyle(GlassButtonStyle(tint: Glass.pink))
                    }
                }
            }
        }
        .sheet(isPresented: $showsLogin) { LoginScreen() }
    }
}
