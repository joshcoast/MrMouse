import SwiftUI

struct MenuView: View {
    @EnvironmentObject var jiggler: JigglerManager

    var body: some View {
        // Status row
        statusRow

        Divider()

        // Toggle
        Button(jiggler.isRunning ? "Stop Jiggling" : "Start Jiggling") {
            jiggler.toggle()
        }
        .keyboardShortcut("j", modifiers: [])

        Divider()

        // Interval submenu
        Menu("Interval: \(jiggler.selectedInterval.label)") {
            ForEach(jiggler.intervals) { option in
                Button {
                    jiggler.setInterval(option)
                } label: {
                    HStack {
                        Text(option.label)
                        if jiggler.selectedInterval == option {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }

        Divider()

        Button("Quit Mouse Jiggler") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: [])
    }

    // MARK: - Subviews

    @ViewBuilder
    private var statusRow: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(jiggler.isRunning ? Color.green : Color.secondary.opacity(0.4))
                .frame(width: 8, height: 8)
                .padding(.leading, 2)

            if jiggler.isRunning {
                Text("Jiggling every \(jiggler.selectedInterval.label)")
                    .font(.callout)
            } else {
                Text("Inactive — mouse is resting")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
