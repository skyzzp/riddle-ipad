import SwiftUI

struct ContentView: View {
    let memory: Memory
    @State private var showSettings = false
    @State private var engineBox = EngineBox()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack(alignment: .topTrailing) {
            PageView(memory: memory, engineBox: engineBox)
                .ignoresSafeArea()

            // Hidden ~1.5s long-press target in the top-right corner.
            Color.clear
                .frame(width: 64, height: 64)
                .contentShape(Rectangle())
                .onLongPressGesture(minimumDuration: 1.5) { showSettings = true }
                .allowsHitTesting(!showSettings)
        }
        .preferredColorScheme(.light)   // a cream diary is never in dark mode
        .onAppear { if !AppConfig.isConfigured { showSettings = true } }
        .sheet(isPresented: $showSettings) {
            SettingsView(memory: memory) { showSettings = false }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: engineBox.engine?.didEnterBackground()
            case .active: engineBox.engine?.willEnterForeground()
            default: break
            }
        }
    }
}
