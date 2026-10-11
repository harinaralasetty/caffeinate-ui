import AppKit
import CaffeinateUICore

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private let awake: AwakeController
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private var timer: Timer?
    private var statusRow: NSMenuItem!
    private var streakRow: NSMenuItem!
    private var awardsRow: NSMenuItem!
    private var awardsWindow: AwardsWindowController!
    private var systemMenu: ModeMenu!
    private var displayMenu: ModeMenu!
    private var externalRow: NSMenuItem!
    private var externalSystemRow: NSMenuItem!
    private var externalDisplayRow: NSMenuItem!
    private var lastError: String?
    private var onRow: NSMenuItem!
    private var offRow: NSMenuItem!
    private var changing = false
    private var detailsSignature: [String] = []

    override init() {
        var catalogError: String?
        let awards: [CaffeinateUIAward]
        do {
            guard let resources = Bundle.main.resourceURL else { throw AwardCatalog.Failure.invalidCatalog }
            awards = try AwardCatalog.read(from: resources.appendingPathComponent("Badges/catalog.json"))
        } catch {
            awards = []
            catalogError = "Badge catalog unavailable: \(error.localizedDescription)"
        }
        let session = AwakeSession(awards: awards, defaults: .standard)
        awake = AwakeController(backend: PowerAssertions(), preferences: AwakePreferences(), session: session,
                                cliClock: CLIActivityClock(defaults: .standard))
        super.init()
        lastError = catalogError
        menu.delegate = self
        menu.autoenablesItems = false
        statusRow = add("Caffeinate UI: Off")
        streakRow = add("Awake streak: 00:00:00")
        streakRow.toolTip = "One uninterrupted session from Caffeinate UI or CLI caffeinate. No qualifying assertions, quit/relaunch or system sleep resets it. Display sleep and screen lock do not."
        awardsWindow = AwardsWindowController(awards: session.awards)
        awardsRow = add("Show Awards…", action: #selector(showAwards))
        menu.addItem(.separator())
        onRow = add("Turn On", action: #selector(turnOn), key: "a")
        onRow.toolTip = "Starts system wake prevention. The display control remains independent."
        offRow = add("Turn Off", action: #selector(turnOff), key: "o")
        offRow.toolTip = "Releases app assertions and stops your standalone Terminal caffeinate sessions. Wrapped commands, watched jobs and other apps are preserved."
        menu.addItem(.separator())
        systemMenu = modeMenu(.system, title: "System awake",
                              tip: "Keeps the Mac from idle sleep. Optional auto-off timer; the display control is separate.")
        displayMenu = modeMenu(.display, title: "Display awake",
                               tip: "Keeps the display on. With a timer, macOS sleeps the display on its normal schedule afterwards.")
        menu.addItem(.separator())
        externalSystemRow = add("Other system assertions: none")
        externalDisplayRow = add("Other display assertions: none")
        externalRow = add("Other Sleep Assertions")
        menu.addItem(.separator())
        add("About Caffeinate UI", action: #selector(about))
        add("Quit Caffeinate UI", action: #selector(quit), key: "q")
        item.menu = menu
        item.button?.imagePosition = .imageOnly
        item.button?.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        do { try awake.restorePreferences() }
        catch { lastError = error.localizedDescription }
        refresh()
        let notifications = NSWorkspace.shared.notificationCenter
        notifications.addObserver(self, selector: #selector(systemWillSleep), name: NSWorkspace.willSleepNotification, object: nil)
        notifications.addObserver(self, selector: #selector(systemDidWake), name: NSWorkspace.didWakeNotification, object: nil)
        let tick = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.timerTick() }
        }
        // Common modes keep the timer visible while the menu is tracking.
        RunLoop.main.add(tick, forMode: .common)
        timer = tick
    }

    @discardableResult private func add(_ title: String, action: Selector? = nil, key: String = "") -> NSMenuItem {
        let row = NSMenuItem(title: title, action: action, keyEquivalent: key)
        row.target = action == nil ? nil : self
        row.isEnabled = action != nil
        menu.addItem(row)
        return row
    }

    func menuWillOpen(_ menu: NSMenu) { refresh() }

    private func timerTick() {
        do { try awake.expireTimers() }
        catch { lastError = error.localizedDescription }
        refresh()
    }

    private static let presets: [(title: String, seconds: TimeInterval)] = [
        ("15 minutes", 900), ("30 minutes", 1800), ("1 hour", 3600), ("2 hours", 7200), ("4 hours", 14400)
    ]

    private struct ModeMenu {
        let mode: AwakeMode, title: String
        let row, header, stop, timerSeparator, indefinite, off, offSeparator: NSMenuItem
    }

    private final class ModeChoice: NSObject {
        let mode: AwakeMode, seconds: TimeInterval
        init(_ mode: AwakeMode, _ seconds: TimeInterval) { self.mode = mode; self.seconds = seconds }
    }

    /// One row per mode whose submenu is built once and updated in place, so it stays open while counting down.
    private func modeMenu(_ mode: AwakeMode, title: String, tip: String) -> ModeMenu {
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        @discardableResult func item(_ title: String, _ action: Selector?, seconds: TimeInterval = 0) -> NSMenuItem {
            let row = NSMenuItem(title: title, action: action, keyEquivalent: "")
            row.target = action == nil ? nil : self
            row.isEnabled = action != nil
            row.representedObject = ModeChoice(mode, seconds)
            submenu.addItem(row)
            return row
        }
        func separator() -> NSMenuItem { let row = NSMenuItem.separator(); submenu.addItem(row); return row }
        let header = item("", nil)
        let stop = item("Stop timer, keep on", #selector(stopTimer(_:)))
        let timerSeparator = separator()
        let indefinite = item("Until turned off", #selector(startIndefinitely(_:)))
        for preset in Self.presets { item(preset.title, #selector(startTimed(_:)), seconds: preset.seconds) }
        item("Custom…", #selector(startCustom(_:)))
        let offSeparator = separator()
        let off = item("Turn off", #selector(stopMode(_:)))
        let row = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        row.isEnabled = true
        row.toolTip = tip
        row.submenu = submenu
        menu.addItem(row)
        return ModeMenu(mode: mode, title: title, row: row, header: header, stop: stop, timerSeparator: timerSeparator,
                        indefinite: indefinite, off: off, offSeparator: offSeparator)
    }

    private func update(_ modeMenu: ModeMenu) {
        let enabled = awake.isEnabled(modeMenu.mode)
        let remaining = awake.timers.remaining(modeMenu.mode)
        modeMenu.row.title = "\(modeMenu.title): \(enabled ? "On" : "Off")" + (remaining.map { " · \(AwakeTimers.label(seconds: $0)) left" } ?? "")
        modeMenu.row.isEnabled = !changing
        modeMenu.header.title = remaining.map { "Auto-off in \(AwakeTimers.label(seconds: $0))" } ?? ""
        modeMenu.header.isHidden = remaining == nil
        modeMenu.stop.isHidden = remaining == nil
        modeMenu.timerSeparator.isHidden = remaining == nil
        modeMenu.indefinite.state = enabled && remaining == nil ? .on : .off
        modeMenu.off.isHidden = !enabled
        modeMenu.offSeparator.isHidden = !enabled
    }

    /// Asks for whole minutes; returns nil when cancelled or invalid.
    private func askDuration(_ title: String) -> TimeInterval? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = "Enter whole minutes, from 1 to 1440 (24 hours)."
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        field.placeholderString = "Minutes"
        alert.accessoryView = field
        alert.addButton(withTitle: "Start")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        guard let seconds = AwakeTimers.parseMinutes(field.stringValue) else {
            lastError = AwakeTimerError.invalidDuration.localizedDescription
            refresh()
            return nil
        }
        return seconds
    }

    private func refreshSession() {
        guard let session = awake.session else { return }
        streakRow.title = awake.cliClock.durationLabel.map { "CLI session: \($0)" } ?? "Awake streak: \(session.durationLabel)"
        streakRow.toolTip = "Current CLI assertion time counts toward awards, including time before Caffeinate UI opened. Recovered CLI time may include system sleep. Overlaps count once."
        awardsRow.title = "Show Awards… (\(session.earnedIDs.count)/\(session.awards.count))"
        awardsWindow.presentation.update(from: session)
        awardsWindow.presentation.cliDuration = awake.cliClock.durationLabel
    }

    @objc private func systemWillSleep() { awake.session?.systemWillSleep(); refreshSession() }
    @objc private func systemDidWake() { awake.session?.systemDidWake(active: awake.isSessionActive); refresh() }

    static func statusTitle(appActive: Bool, cliActive: Bool, otherActive: Bool = false) -> String {
        AwakeMenuState(appActive: appActive, cliActive: cliActive, otherActive: otherActive).title
    }

    private func refresh() {
        var entries: [SleepAssertion] = []
        var snapshotError = false
        do {
            let snapshot = try AssertionSnapshot.read()
            entries = snapshot.external(to: getpid())
            awake.observeExternalAssertions(entries, onACPower: snapshot.onACPower)
        } catch {
            snapshotError = true
        }
        refreshSession()
        let cliActive = !awake.externalCaffeinate.isEmpty
        let controls = AwakeMenuState(appActive: awake.isActive, cliActive: cliActive)
        statusRow.title = controls.title
        onRow.isEnabled = controls.canTurnOn && !changing
        offRow.isEnabled = controls.canTurnOff && !changing
        update(systemMenu)
        update(displayMenu)
        item.button?.image = CupIcon.make(steaming: controls.steaming)
        let details = NSMenu()
        if !snapshotError {
            let system = entries.filter(\.keepsSystemAwake).count
            let display = entries.filter(\.keepsDisplayAwake).count
            externalSystemRow.title = system > 0 ? "Other apps also keep system awake (\(system))" : "No other system sleep assertions"
            externalDisplayRow.title = display > 0 ? "Other apps also keep display awake (\(display))" : "No other display sleep assertions"
            statusRow.title = Self.statusTitle(appActive: awake.isActive, cliActive: cliActive,
                                             otherActive: system > 0 || display > 0)
            for entry in entries {
                let process = NSRunningApplication(processIdentifier: entry.pid)?.localizedName ?? (entry.name == "caffeinate command-line tool" ? "caffeinate" : "PID \(entry.pid)")
                let mode = entry.keepsDisplayAwake ? "display" : "system"
                let row = NSMenuItem(title: "\(process.prefix(16)): \(mode)", action: nil, keyEquivalent: "")
                row.toolTip = "PID \(entry.pid): \(entry.name) [\(entry.type)]"
                details.addItem(row)
            }
            if entries.isEmpty { details.addItem(NSMenuItem(title: "No other sleep assertions", action: nil, keyEquivalent: "")) }
        } else {
            externalSystemRow.title = "Other assertions: unavailable"
            externalDisplayRow.title = "Could not read display status"
            details.addItem(NSMenuItem(title: "Status read failed", action: nil, keyEquivalent: ""))
        }
        let soonest = AwakeMode.allCases.compactMap { awake.timers.remaining($0) }.min()
        if let soonest { statusRow.title += " · auto-off in \(AwakeTimers.label(seconds: soonest))" }
        let barTitle = soonest.map { " " + AwakeTimers.label(seconds: $0).replacingOccurrences(of: " ", with: "") } ?? ""
        if item.button?.title != barTitle {
            item.button?.title = barTitle
            item.button?.imagePosition = barTitle.isEmpty ? .imageOnly : .imageLeft
            item.length = barTitle.isEmpty ? NSStatusItem.squareLength : NSStatusItem.variableLength
        }
        if let lastError {
            let row = NSMenuItem(title: "Last action failed", action: nil, keyEquivalent: "")
            row.toolTip = lastError; details.addItem(row)
            statusRow.title += " — last action failed"
        }
        if snapshotError { statusRow.title = "Caffeinate UI: sleep status unavailable" }
        if changing { statusRow.title = "Caffeinate UI: turning off…" }
        // Replacing an open submenu every second can collapse it; swap only on change.
        let signature = details.items.map { "\($0.title)\u{0}\($0.toolTip ?? "")" }
        if signature != detailsSignature {
            externalRow.submenu = details
            detailsSignature = signature
        }
        externalRow.isEnabled = true
        let steamHelp = cliActive ? " Turn Off also stops verified standalone CLI sessions; protected workloads remain active and are reported." : ""
        item.button?.toolTip = "\(statusRow.title). App controls: system \(awake.isEnabled(.system) ? "on" : "off"), display \(awake.isEnabled(.display) ? "on" : "off").\(steamHelp)\(lastError.map { " " + $0 } ?? "")"
        item.button?.setAccessibilityLabel(statusRow.title)
    }

    private func perform(_ operation: () throws -> Void) {
        do { try operation(); lastError = nil }
        catch {
            lastError = error.localizedDescription
            let alert = NSAlert()
            alert.messageText = "Could not change awake mode"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
        refresh()
    }
    @objc func showAwards() { refresh(); awardsWindow.show() }
    @objc private func turnOn() { perform { try awake.set(.system, enabled: true) } }
    @objc private func turnOff() {
        guard !changing else { return }
        changing = true
        refresh()
        Task { @MainActor in
            do { try await awake.turnOffAll(using: StandaloneCLIStopper()); lastError = nil }
            catch { lastError = error.localizedDescription }
            changing = false
            refresh()
        }
    }
    private func choice(_ sender: NSMenuItem) -> ModeChoice? { sender.representedObject as? ModeChoice }
    @objc private func startTimed(_ sender: NSMenuItem) {
        guard let choice = choice(sender) else { return }
        perform { try awake.set(choice.mode, for: choice.seconds) }
    }
    @objc private func startCustom(_ sender: NSMenuItem) {
        guard let choice = choice(sender),
              let seconds = askDuration(choice.mode == .system ? "Keep the system awake for how long?" : "Keep the display awake for how long?") else { return }
        perform { try awake.set(choice.mode, for: seconds) }
    }
    @objc private func startIndefinitely(_ sender: NSMenuItem) {
        guard let choice = choice(sender) else { return }
        perform { try awake.set(choice.mode, enabled: true); awake.timers.cancel(choice.mode) }
    }
    @objc private func stopTimer(_ sender: NSMenuItem) {
        guard let choice = choice(sender) else { return }
        awake.timers.cancel(choice.mode)
        refresh()
    }
    @objc private func stopMode(_ sender: NSMenuItem) {
        guard let choice = choice(sender) else { return }
        perform { try awake.set(choice.mode, enabled: false) }
    }
    @objc private func about() {
        let alert = NSAlert()
        alert.messageText = "Caffeinate UI"
        alert.informativeText = "Steam and On mean Caffeinate UI or CLI caffeinate holds a system or display sleep assertion. Turn On starts system wake prevention; the display control is separate. The System awake and Display awake menus add an optional auto-off timer, shown in the menu and next to the icon, that releases only the app's own assertion; timers are not kept across relaunch. Turn Off releases app assertions and stops your verified standalone CLI caffeinate sessions. Wrapped commands, watched jobs and other applications are preserved; any session that cannot safely stop is reported and keeps steam visible. Quit releases only app assertions. Other apps may still prevent idle sleep.\n\nAwake streak measures one uninterrupted session while either control or a CLI caffeinate system/display assertion is active. No qualifying assertions, app-only quit/relaunch or system sleep resets progress. A current CLI session recovers earlier elapsed time, including possible sleep; overlaps count once. Display sleep and locking do not reset progress. Earned awards stay saved locally.\n\nYour choices are restored after relaunch. Quit releases assertions without changing those choices. Login startup is managed by the project's login script. Screen locking and security settings remain in effect. Lid closure, low battery and forced sleep can override idle-sleep assertions."
        alert.runModal()
    }
    @objc private func quit() { NSApp.terminate(nil) }
    func shutdown() {
        timer?.invalidate()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        try? awake.turnOff(persist: false)
        awake.session?.update(active: false)
    }
}
