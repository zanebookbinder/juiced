import SwiftUI

struct ContentView: View {
    @StateObject private var monitor = ChargeMonitor()
    @State private var showDump = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(monitor.status).font(.title3).bold()

            HStack(spacing: 0) {
                VStack {
                    Text("Charged at").font(.subheadline).foregroundStyle(.secondary)
                    // 100 at the top, 1 at the bottom.
                    Picker("Threshold", selection: $monitor.threshold) {
                        ForEach(Array(stride(from: 100, through: 1, by: -1)), id: \.self) { v in
                            Text("\(v)%").tag(v)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 140)
                }
                VStack {
                    Text("Low at").font(.subheadline).foregroundStyle(.secondary)
                    Picker("Floor", selection: $monitor.floorLevel) {
                        ForEach(Array(stride(from: 100, through: 1, by: -1)), id: \.self) { v in
                            Text("\(v)%").tag(v)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 140)
                }
            }

            Button(monitor.running ? "Stop monitoring" : "Start monitoring") { monitor.toggle() }
                .buttonStyle(.borderedProminent)

            HStack {
                Button("Refresh now") { monitor.tick() }.buttonStyle(.bordered)
                Button("Test alert") { monitor.sendTest() }.buttonStyle(.bordered)
            }

            Toggle("Debug dump", isOn: $showDump)
            if showDump {
                ScrollView {
                    Text(WatchBattery.debugDump())
                        .font(.system(.caption2, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Spacer()
        }
        .padding()
        .onAppear { if !monitor.running { monitor.start() } }
    }
}
