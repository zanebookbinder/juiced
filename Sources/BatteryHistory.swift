import Foundation

struct Sample: Codable, Equatable {
    let t: Date
    let p: Int      // percent
    let c: Bool     // charging
}

/// Rolling 7-day, one-sample-per-minute battery log, persisted to Documents.
///
/// Samples only accrue while the app is alive (monitoring holds it in the
/// background), so a force-quit or a Stop leaves a gap in the series.
final class BatteryHistory: ObservableObject {

    @Published private(set) var samples: [Sample] = []

    private let retention: TimeInterval = 7 * 24 * 3600
    private let minInterval: TimeInterval = 55      // ~1 sample/minute
    private var unsaved = 0

    private let url: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("history.json")
    }()

    init() { load() }

    func record(percent: Int, charging: Bool, now: Date = Date()) {
        if let last = samples.last, now.timeIntervalSince(last.t) < minInterval { return }
        samples.append(Sample(t: now, p: percent, c: charging))
        prune(now: now)
        unsaved += 1
        if unsaved >= 5 { save() }                  // batch writes; at most 5 min lost on kill
    }

    func samples(since interval: TimeInterval, now: Date = Date()) -> [Sample] {
        let cutoff = now.addingTimeInterval(-interval)
        return samples.filter { $0.t >= cutoff }
    }

    func save() {
        unsaved = 0
        guard let data = try? JSONEncoder().encode(samples) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func prune(now: Date) {
        let cutoff = now.addingTimeInterval(-retention)
        if let first = samples.first, first.t < cutoff {
            samples.removeAll { $0.t < cutoff }
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Sample].self, from: data) else { return }
        samples = decoded
        prune(now: Date())
    }
}
