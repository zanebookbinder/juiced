import Foundation

struct WatchState {
    let name: String
    let percent: Int
    let charging: Bool
}

/// Reads the paired watch's battery via IOKit power sources.
///
/// BatteryCenter (the obvious route) is blocked for an unentitled app: its
/// connectedDevices list stays empty. IOKit's *by-type* call is not — it returns
/// every accessory source. Note that IOPSCopyPowerSourcesInfo/List give only the
/// phone's internal battery; type 0 is what exposes accessories.
enum WatchBattery {

    private typealias ByTypeFn = @convention(c) (Int32) -> Unmanaged<CFArray>?
    private static let handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY)

    static func allSources() -> [[String: Any]] {
        guard let h = handle, let s = dlsym(h, "IOPSCopyPowerSourcesByType") else { return [] }
        let byType = unsafeBitCast(s, to: ByTypeFn.self)
        return (byType(0)?.takeRetainedValue() as? [Any] ?? []).compactMap { $0 as? [String: Any] }
    }

    static func read() -> WatchState? {
        if let real = liveRead() { return real }
        #if targetEnvironment(simulator)
        // The simulator has no accessory power sources; sample data so the UI is
        // exercisable (and screenshottable) without a device.
        return WatchState(name: "Zane's Apple Watch", percent: 99, charging: false)
        #else
        return nil
        #endif
    }

    private static func liveRead() -> WatchState? {
        // "Accessory Category" == Watch is the reliable discriminator; filtering by
        // name would collide with AirPods and break if the watch is renamed.
        guard let d = allSources().first(where: { ($0["Accessory Category"] as? String) == "Watch" })
        else { return nil }

        let pct = (d["Current Capacity"] as? Int) ?? -1
        let max = (d["Max Capacity"] as? Int) ?? 100
        // Two independent charging signals; the watch reports both.
        let charging = ((d["Is Charging"] as? Int) ?? 0) == 1
            || (d["Power Source State"] as? String) == "AC Power"

        return WatchState(name: (d["Name"] as? String) ?? "Apple Watch",
                          percent: max > 0 ? Int(round(Double(pct) / Double(max) * 100)) : pct,
                          charging: charging)
    }

}
