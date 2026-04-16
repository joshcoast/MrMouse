import SwiftUI

@main
struct MrMouseApp: App {
    @StateObject private var mouse = MouseManager()

    var body: some Scene {
        MenuBarExtra {
            MenuView()
                .environmentObject(mouse)
        } label: {
            MenuBarLabel(isRunning: mouse.isRunning, isWild: mouse.wildMode)
        }
        .menuBarExtraStyle(.menu)
    }
}

/// Animates between a static and active icon in the menu bar.
struct MenuBarLabel: View {
    let isRunning: Bool
    let isWild: Bool

    var body: some View {
        if isRunning {
            if #available(macOS 14.0, *) {
                if isWild {
                    Image(systemName: "computermouse.fill")
                        .symbolEffect(.bounce.byLayer, options: .repeating)
                } else {
                    Image(systemName: "computermouse.fill")
                        .symbolEffect(.pulse)
                }
            } else {
                Image(systemName: "computermouse.fill")
            }
        } else {
            Image(systemName: "computermouse")
        }
    }
}
