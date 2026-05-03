import SwiftUI

struct MenuView: View {
    @EnvironmentObject var mouse: MouseManager

    var body: some View {
        VStack(spacing: 0) {
            statusSection
            Divider()
            controlsSection
            Divider()
            intervalSection
            Divider()
            footerSection
        }
        .frame(width: 280)
    }

    // MARK: - Sections

    private var statusSection: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.25))
                    .frame(width: 18, height: 18)
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
            }
            Text(statusText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(statusColor.opacity(0.07))
        .animation(.easeInOut(duration: 0.3), value: statusColor)
    }

    private var controlsSection: some View {
        VStack(spacing: 12) {
            Button {
                mouse.toggle()
            } label: {
                Label(
                    mouse.isRunning ? "Stop MrMouse" : "Start MrMouse",
                    systemImage: mouse.isRunning ? "stop.fill" : "play.fill"
                )
                .frame(maxWidth: .infinity)
                .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(mouse.isRunning ? .red : .green)
            .controlSize(.large)
            .keyboardShortcut("j", modifiers: [])

            VStack(spacing: 0) {
                toggleRow(
                    label: "Wild Wiggle",
                    icon: "waveform.path.ecg",
                    isOn: Binding(get: { mouse.wildMode }, set: { _ in mouse.toggleWildMode() })
                )
                Divider().padding(.leading, 42)
                toggleRow(
                    label: "Only when idle",
                    icon: "moon.zzz",
                    isOn: Binding(get: { mouse.idleOnly }, set: { _ in mouse.toggleIdleOnly() })
                )
            }
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }

    private var intervalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Jiggle every", icon: "clock.arrow.circlepath")

            Picker("Interval", selection: Binding(
                get: { mouse.selectedInterval },
                set: { mouse.setInterval($0) }
            )) {
                ForEach(mouse.intervals) { interval in
                    Text(shortLabel(interval.label)).tag(interval)
                }
            }
            .pickerStyle(.segmented)

            if mouse.idleOnly {
                sectionLabel("Start after idle for", icon: "timer")
                    .padding(.top, 4)

                Picker("Idle threshold", selection: Binding(
                    get: { mouse.idleThreshold },
                    set: { mouse.setIdleThreshold($0) }
                )) {
                    ForEach(mouse.idleThresholds) { threshold in
                        Text(shortLabel(threshold.label)).tag(threshold)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .animation(.easeInOut(duration: 0.2), value: mouse.idleOnly)
    }

    private var footerSection: some View {
        HStack {
            Text(mouse.jigglesThisSession == 0
                 ? "No jiggles yet"
                 : "Jiggled \(mouse.jigglesThisSession)× this session")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
            Button("Quit") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)
            .keyboardShortcut("q", modifiers: [])
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Helpers

    private func toggleRow(label: String, icon: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Label(label, systemImage: icon)
                .fontWeight(.medium)
        }
        .toggleStyle(.switch)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    private func sectionLabel(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
    }

    private var statusColor: Color {
        if !mouse.isRunning { return .gray }
        if mouse.isWaiting  { return .orange }
        return .green
    }

    private var statusText: String {
        if !mouse.isRunning { return "Inactive — mouse is resting" }
        if mouse.isWaiting  { return "Waiting — starts after \(mouse.idleThreshold.label) idle" }
        return mouse.wildMode
            ? "Wiggling wildly every \(mouse.selectedInterval.label)"
            : "Moving every \(mouse.selectedInterval.label)"
    }

    private func shortLabel(_ label: String) -> String {
        let parts = label.components(separatedBy: " ")
        guard let number = parts.first else { return label }
        if label.contains("second") { return number + "s" }
        if label.contains("minute") { return number + "m" }
        return label
    }
}
