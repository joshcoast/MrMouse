import Combine
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
        .menuBarExtraStyle(.window)
    }
}

/// Shows the mouse in the menu bar: outline when stopped, filled when
/// running, and wiggling side to side in wild mode.
struct MenuBarLabel: View {
    let isRunning: Bool
    let isWild: Bool

    @State private var tiltLeft = false
    private let wiggle = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    var body: some View {
        Image(imageName)
            .onReceive(wiggle) { _ in
                if isRunning && isWild { tiltLeft.toggle() }
            }
    }

    private var imageName: String {
        guard isRunning else { return "MenuBarMouse" }
        guard isWild else { return "MenuBarMouseFill" }
        return tiltLeft ? "MenuBarMouseTiltLeft" : "MenuBarMouseTiltRight"
    }
}
