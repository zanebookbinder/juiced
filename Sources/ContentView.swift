import SwiftUI

enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var scheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

struct ContentView: View {
    @StateObject private var monitor = ChargeMonitor()
    @AppStorage("appearance") private var appearance: Appearance = .system
    @State private var range: ChartRange = .day

    var body: some View {
        NavigationStack {
            List {
                statusSection
                historySection
                thresholdSection
                controlSection
                appearanceSection
            }
            .navigationTitle("Juiced")
        }
        .preferredColorScheme(appearance.scheme)
        .onAppear { if !monitor.running { monitor.start() } }
    }

    private var statusSection: some View {
        Section {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(monitor.watchName).font(.headline)
                    Text(monitor.running ? "Monitoring" : "Paused")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 4) {
                    if monitor.charging {
                        Image(systemName: "bolt.fill").foregroundStyle(.green)
                    }
                    Text(monitor.percent >= 0 ? "\(monitor.percent)%" : "—")
                        .font(.system(.title, design: .rounded)).bold()
                        .monospacedDigit()
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var historySection: some View {
        Section("History") {
            VStack(spacing: 8) {
                TabView(selection: $range) {
                    ForEach(ChartRange.allCases) { r in
                        HistoryChart(samples: monitor.history.samples(since: r.interval),
                                     range: r,
                                     ceiling: monitor.threshold,
                                     floor: monitor.floorLevel)
                            .padding(.trailing, 10)
                            .padding(.top, 6)
                            .tag(r)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 200)

                Picker("Range", selection: $range) {
                    ForEach(ChartRange.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            .padding(.vertical, 6)
        }
    }

    private var thresholdSection: some View {
        Section("Alerts") {
            HStack(spacing: 0) {
                wheel(title: "Charged at", selection: $monitor.threshold)
                Divider()
                wheel(title: "Low at", selection: $monitor.floorLevel)
            }
            .frame(height: 130)
        }
    }

    private func wheel(title: String, selection: Binding<Int>) -> some View {
        VStack(spacing: 0) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            // 100 at the top, 1 at the bottom.
            Picker(title, selection: selection) {
                ForEach(Array(stride(from: 100, through: 1, by: -1)), id: \.self) { v in
                    Text("\(v)%").tag(v)
                }
            }
            .pickerStyle(.wheel)
            .clipped()
        }
    }

    private var controlSection: some View {
        Section {
            Button {
                monitor.toggle()
            } label: {
                Label(monitor.running ? "Stop Monitoring" : "Start Monitoring",
                      systemImage: monitor.running ? "pause.circle.fill" : "play.circle.fill")
            }
            Button {
                monitor.sendTest()
            } label: {
                Label("Send Test Alert", systemImage: "bell.badge")
            }
        } footer: {
            Text("Monitoring keeps the app awake in the background so readings continue while your phone is locked.")
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: $appearance) {
                ForEach(Appearance.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }
}
