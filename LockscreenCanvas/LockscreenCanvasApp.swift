import SwiftUI

@main
struct LockscreenCanvasApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .preferredColorScheme(.light)
                .tint(Theme.accent)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if model.session == nil {
                WelcomeView()
            } else {
                HomeView()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            model.handle(phase)
        }
    }
}
