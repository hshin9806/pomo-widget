import AppKit
import UserNotifications

enum Phase {
    case focus, rest

    var color: NSColor { self == .focus ? .systemRed : .systemGreen }
}

/// A press that moves drags the window; a press released in place acts as a click.
final class DraggableButton: NSButton {
    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        let start = event.locationInWindow
        while true {
            guard let next = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) else { return }
            if next.type == .leftMouseUp {
                sendAction(action, to: target)
                return
            }
            if abs(next.locationInWindow.x - start.x) + abs(next.locationInWindow.y - start.y) > 3 {
                window.performDrag(with: event)
                return
            }
        }
    }
}

final class AppController: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private let widgetWindow: NSPanel = {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 96, height: 30),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        return panel
    }()
    private let widgetButton = DraggableButton()
    private let popover = NSPopover()
    private let panel = PanelView()
    private var timer: Timer?
    private var phase = Phase.focus
    private var remaining = 0
    private var running = false
    private var canNotify = false

    private var duration: Int {
        (phase == .focus ? Settings.focusMinutes : Settings.restMinutes) * 60
    }

    /// Nothing has started yet, so the panel's big number is a duration to edit rather than a countdown.
    private var isEditable: Bool {
        !running && phase == .focus && remaining == duration
    }

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async { self.canNotify = granted }
        }

        panel.onStartPause = { [weak self] in self?.toggle() }
        panel.onReset = { [weak self] in self?.reset() }
        panel.onGear = { [weak self] in self?.showGearMenu($0) }
        panel.onDurationsChanged = { [weak self] in self?.durationsChanged() }

        let host = NSViewController()
        host.view = panel
        popover.contentViewController = host
        popover.behavior = .transient

        widgetButton.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        widgetButton.isBordered = false
        widgetButton.target = self
        widgetButton.action = #selector(togglePopover)

        let backdrop = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 96, height: 30))
        backdrop.material = .hudWindow
        backdrop.state = .active
        backdrop.wantsLayer = true
        backdrop.layer?.cornerRadius = 15
        widgetButton.translatesAutoresizingMaskIntoConstraints = false
        backdrop.addSubview(widgetButton)
        NSLayoutConstraint.activate([
            widgetButton.centerXAnchor.constraint(equalTo: backdrop.centerXAnchor),
            widgetButton.centerYAnchor.constraint(equalTo: backdrop.centerYAnchor),
        ])
        widgetWindow.contentView = backdrop

        if let screen = NSScreen.main {
            let area = screen.visibleFrame
            widgetWindow.setFrameOrigin(NSPoint(x: area.maxX - widgetWindow.frame.width - 12,
                                                y: area.maxY - widgetWindow.frame.height - 12))
        }
        widgetWindow.orderFrontRegardless()

        remaining = duration
        render()
    }

    // Show the banner even if the app happens to be frontmost.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               willPresent notification: UNNotification,
                               withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    // MARK: - Popover

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        render()
        // Without activating, the popover never becomes key and its text fields ignore typing.
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: widgetButton.bounds, of: widgetButton, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func showGearMenu(_ sender: NSButton) {
        let menu = NSMenu()

        let login = NSMenuItem(title: L("gear.launchAtLogin"), action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        login.target = self
        login.state = Settings.launchesAtLogin ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: L("gear.quit"), action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height), in: sender)
    }

    @objc private func toggleLaunchAtLogin() {
        Settings.launchesAtLogin.toggle()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Timer

    private func toggle() {
        running ? pause() : start()
    }

    private func start() {
        running = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        // Keep counting while a menu is open.
        RunLoop.main.add(timer!, forMode: .common)
        render()
    }

    private func pause() {
        running = false
        timer?.invalidate()
        timer = nil
        render()
    }

    private func reset() {
        pause()
        phase = .focus
        remaining = duration
        render()
    }

    private func tick() {
        remaining -= 1
        if remaining > 0 {
            render()
        } else {
            finish()
        }
    }

    /// Announce the finished phase, then queue up the next one (paused, ready to start).
    /// With breaks off, focus simply runs back into focus.
    private func finish() {
        pause()
        let finished = phase
        if finished == .focus && Settings.restMinutes > 0 {
            phase = .rest
        } else {
            phase = .focus
        }
        remaining = duration
        render()
        announce(finished)
    }

    private func announce(_ finished: Phase) {
        NSSound(named: "Glass")?.play()

        let title: String
        let body: String
        if finished == .focus {
            title = L("notification.focusDone.title")
            body = Settings.restMinutes > 0
                ? L("notification.focusDone.body", Settings.restMinutes)
                : L("notification.focusDone.bodyNoBreak")
        } else {
            title = L("notification.restDone.title")
            body = L("notification.restDone.body", Settings.focusMinutes)
        }

        guard canNotify else {
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = body
            alert.runModal()
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        )
    }

    /// A new duration takes effect immediately when idle, otherwise from the next round.
    private func durationsChanged() {
        // Turning breaks off mid-break leaves nowhere to be: fall back to focus.
        if phase == .rest && Settings.restMinutes == 0 {
            pause()
            phase = .focus
            remaining = duration
        } else if !running {
            remaining = duration
        }
        render()
    }

    // MARK: - UI

    private func render() {
        panel.update(remaining: remaining, running: running, editable: isEditable)

        let fraction = duration > 0 ? Double(remaining) / Double(duration) : 0
        widgetButton.image = ringImage(remaining: fraction,
                                       color: running ? phase.color : .systemGray)
        widgetButton.imagePosition = .imageLeading
        widgetButton.title = String(format: " %02d:%02d", remaining / 60, remaining % 60)
    }

    /// A ring that empties clockwise as the phase runs down.
    private func ringImage(remaining: Double, color: NSColor) -> NSImage {
        let size = 14.0
        let width = 2.5
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            let center = NSPoint(x: size / 2, y: size / 2)
            let radius = (size - width) / 2

            let track = NSBezierPath()
            track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
            track.lineWidth = width
            color.withAlphaComponent(0.25).setStroke()
            track.stroke()

            if remaining > 0 {
                let arc = NSBezierPath()
                arc.appendArc(withCenter: center,
                              radius: radius,
                              startAngle: 90,
                              endAngle: 90 - 360 * remaining,
                              clockwise: true)
                arc.lineWidth = width
                arc.lineCapStyle = .round
                color.setStroke()
                arc.stroke()
            }
            return true
        }
        image.isTemplate = false
        return image
    }
}

let app = NSApplication.shared
let controller = AppController()
app.delegate = controller
app.setActivationPolicy(.accessory)
app.run()
