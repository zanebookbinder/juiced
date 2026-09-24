import Foundation
import AVFoundation
import UserNotifications

final class ChargeMonitor: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published var running = false
    @Published var threshold = 80      // notify at/above this while charging
    @Published var floorLevel = 20     // notify at/below this while off the charger

    @Published private(set) var watchName = "Apple Watch"
    @Published private(set) var percent = -1
    @Published private(set) var charging = false

    let history = BatteryHistory()

    private var timer: Timer?
    private var notified = false
    private var lowNotified = false
    private var player: AVAudioPlayer?

    override init() {
        super.init()
        // Without this, iOS silently swallows the banner while the app is frontmost.
        UNUserNotificationCenter.current().delegate = self
    }

    func userNotificationCenter(_ c: UNUserNotificationCenter,
                                willPresent n: UNNotification,
                                withCompletionHandler done: @escaping (UNNotificationPresentationOptions) -> Void) {
        done([.banner, .list])
    }

    /// Fires the real notification path immediately, ignoring watch state.
    func sendTest() {
        notify(title: "Watch ready", body: "\(watchName) at \(max(percent, 0))% — grab it.")
    }

    func toggle() { running ? stop() : start() }

    func start() {
        // -screenshots skips the permission prompt so the UI can be captured cleanly.
        if !ProcessInfo.processInfo.arguments.contains("-screenshots") {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
        }
        startKeepAlive()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in self?.tick() }
        timer?.tolerance = 5
        running = true
        tick()
    }

    func stop() {
        timer?.invalidate(); timer = nil
        player?.stop(); player = nil
        try? AVAudioSession.sharedInstance().setActive(false)
        history.save()
        running = false
    }

    func tick() {
        guard let w = WatchBattery.read() else { return }
        watchName = w.name
        percent = w.percent
        charging = w.charging
        history.record(percent: w.percent, charging: w.charging)

        if w.charging {
            lowNotified = false                              // back on the charger, re-arm the floor
            if w.percent >= threshold, !notified {
                notify(title: "Watch ready", body: "\(w.name) at \(w.percent)% — grab it.")
                notified = true
            }
        } else {
            notified = false                                 // unplugged, re-arm the ceiling
            if w.percent <= floorLevel, !lowNotified {
                notify(title: "Watch running low",
                       body: "\(w.name) at \(w.percent)% — charge it soon.")
                lowNotified = true
            } else if w.percent > floorLevel {
                lowNotified = false                          // rose back above the floor
            }
        }
    }

    private func notify(title: String, body: String) {
        let c = UNMutableNotificationContent()
        c.title = title
        c.body = body
        c.sound = nil
        // Silent but prominent: breaks through Focus and presents as an alert on
        // the watch (which is what triggers the haptic) rather than filing quietly.
        c.interruptionLevel = .timeSensitive
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: nil))
    }

    /// Silent looping audio keeps the process alive so the timer keeps firing.
    private func startKeepAlive() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.mixWithOthers])
        try? session.setActive(true)
        guard let url = Bundle.main.url(forResource: "silence", withExtension: "m4a") else { return }
        player = try? AVAudioPlayer(contentsOf: url)
        player?.numberOfLoops = -1
        player?.volume = 0
        player?.play()
    }
}
