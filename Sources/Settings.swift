import AppKit
import ServiceManagement

/// Persisted durations. A break of 0 minutes means "no break" — focus runs back to back.
enum Settings {
    static let focusRange = 1...120
    static let restRange = 0...60

    static var focusMinutes: Int {
        get { UserDefaults.standard.object(forKey: "focusMinutes") as? Int ?? 25 }
        set { UserDefaults.standard.set(newValue, forKey: "focusMinutes") }
    }

    static var restMinutes: Int {
        get { UserDefaults.standard.object(forKey: "restMinutes") as? Int ?? 5 }
        set {
            UserDefaults.standard.set(newValue, forKey: "restMinutes")
            if newValue > 0 { lastRestMinutes = newValue }
        }
    }

    /// What the break switch restores when it is turned back on.
    private(set) static var lastRestMinutes: Int {
        get { UserDefaults.standard.object(forKey: "lastRestMinutes") as? Int ?? 5 }
        set { UserDefaults.standard.set(newValue, forKey: "lastRestMinutes") }
    }

    static var launchesAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                newValue ? try SMAppService.mainApp.register()
                         : try SMAppService.mainApp.unregister()
            } catch {
                NSLog("launch at login failed: \(error)")
            }
        }
    }
}

extension ClosedRange where Bound == Int {
    func clamping(_ value: Int) -> Int {
        Swift.min(Swift.max(value, lowerBound), upperBound)
    }
}
