import SwiftUI

@main
struct MouseJigglerApp: App {
    @StateObject private var jiggler = JigglerManager()

    var body: some Scene {
        MenuBarExtra {
            MenuView()
                .environmentObject(jiggler)
        } label: {
            MenuBarLabel(isRunning: jiggler.isRunning)
        }
        .menuBarExtraStyle(.menu)
    }
}

/// Animates between a static and active icon in the menu bar.
struct MenuBarLabel: View {
    let isRunning: Bool

    var body: some View {
        if isRunning {
            Image(systemName: "computermouse.fill")
                .symbolEffect(.pulse)
        } else {
            Image(systemName: "computermouse")
        }
    }
}
