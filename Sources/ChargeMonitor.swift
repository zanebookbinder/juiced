import Foundation
import AVFoundation
import UserNotifications
import BackgroundTasks

final class ChargeMonitor: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = ChargeMonitor()
    static let refreshTaskID = "com.zanebookbinder.Juiced.refresh"

    @Published var running = false
    @Published var threshold = 80      // notify at/above this while charging
    @Published var floorLevel = 20     // notify at/below this while off the charger

    @Published private(set) var watchName = "Apple Watch"
    @Published private(set) var percent = -1
    @Published private(set) var charging = false
    @Published private(set) var lastReading: Date?

    let history = BatteryHistory()

    private var timer: Timer?
    private var notified = false
    private var lowNotified = false
    private var player: AVAudioPlayer?

    override init() {
        super.init()
        // Without this, iOS silently swallows the banner while the app is frontmost.
        UNUserNotificationCenter.current().delegate = self
        observeAudioLifecycle()
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
        scheduleRefresh()
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
        keepAliveWatchdog()
        guard let w = WatchBattery.read() else { return }
        watchName = w.name
        percent = w.percent
        charging = w.charging
        lastReading = Date()
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

    // MARK: - Keepalive
    //
    // Silent looping audio keeps the process alive so the timer keeps firing.
    // It is fragile: a phone call, Siri, or a media-services reset stops playback,
    // and once the app is no longer producing audio iOS suspends it and the timer
    // never fires again. Everything below exists to notice that and restart.

    private func startKeepAlive() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("KEEPALIVE session error: \(error)")
        }
        guard let url = Bundle.main.url(forResource: "silence", withExtension: "m4a") else { return }
        player = try? AVAudioPlayer(contentsOf: url)
        player?.numberOfLoops = -1
        player?.volume = 0
        if player?.play() != true { print("KEEPALIVE play() failed") }
    }

    private func restartKeepAlive() {
        player?.stop()
        player = nil
        startKeepAlive()
    }

    /// Cheap check on every tick: if playback died, the process is on borrowed time.
    private func keepAliveWatchdog() {
        guard running, player?.isPlaying != true else { return }
        print("KEEPALIVE watchdog: playback stopped, restarting")
        restartKeepAlive()
    }

    private func observeAudioLifecycle() {
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(handleInterruption(_:)),
                       name: AVAudioSession.interruptionNotification, object: nil)
        nc.addObserver(self, selector: #selector(handleMediaReset),
                       name: AVAudioSession.mediaServicesWereResetNotification, object: nil)
    }

    /// A call or Siri interrupts playback; iOS does NOT resume it for us.
    @objc private func handleInterruption(_ n: Notification) {
        guard running,
              let raw = n.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        if type == .ended { restartKeepAlive() }
    }

    /// The audio server crashed; every session and player object is now invalid.
    @objc private func handleMediaReset() {
        guard running else { return }
        player = nil
        restartKeepAlive()
    }

    // MARK: - Background refresh backstop
    //
    // If the keepalive loses anyway and iOS suspends us, this is the only way back:
    // iOS relaunches the app in the background, we take a reading and restart the
    // keepalive. It does not run at all after a force-quit from the app switcher.

    func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do { try BGTaskScheduler.shared.submit(request) }
        catch { print("BGTask submit failed: \(error)") }
    }

    @MainActor
    func backgroundRefresh() async {
        scheduleRefresh()          // always chain the next one first
        if running { restartKeepAlive() }
        tick()
        history.save()
    }
}
