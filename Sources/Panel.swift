import AppKit

/// The popover that opens from the status item. Everything but "launch at login" lives here.
final class PanelView: NSView, NSTextFieldDelegate {
    var onStartPause: () -> Void = {}
    var onReset: () -> Void = {}
    var onGear: (NSButton) -> Void = { _ in }
    var onDurationsChanged: () -> Void = {}

    private let display = NSTextField()
    private var displayWidth = NSLayoutConstraint()
    private let unit = NSTextField(labelWithString: L("panel.minutes"))
    private let presetRow = NSStackView()
    private let restField = NSTextField()
    private let restUnit = NSTextField(labelWithString: L("panel.minutes"))
    private let restSwitch = NSSwitch()
    private let startButton = NSButton()
    private let resetButton = NSButton()

    init() {
        super.init(frame: .zero)
        build()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Build

    private func build() {
        display.font = .monospacedDigitSystemFont(ofSize: 40, weight: .semibold)
        display.alignment = .center
        display.isBordered = false
        display.drawsBackground = false
        display.focusRingType = .none
        display.delegate = self
        display.target = self
        display.action = #selector(focusCommitted)
        // An editable NSTextField reports no intrinsic width, so hugging cannot size it and it
        // stretches across the row. Measure the text instead — see sizeDisplay().
        display.usesSingleLineMode = true
        displayWidth = display.widthAnchor.constraint(equalToConstant: 90)
        displayWidth.isActive = true

        unit.font = .systemFont(ofSize: 15)
        unit.textColor = .secondaryLabelColor
        unit.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        let displayRow = NSStackView(views: [display, unit])
        displayRow.orientation = .horizontal
        displayRow.alignment = .firstBaseline
        displayRow.spacing = 4
        // The row must hug its contents too, or it spans the panel and pushes "min" to the edge.
        displayRow.setHuggingPriority(.required, for: .horizontal)

        presetRow.orientation = .horizontal
        presetRow.distribution = .fillEqually
        presetRow.spacing = 6
        for minutes in [25, 45, 50] {
            let chip = NSButton(title: "\(minutes)", target: self, action: #selector(presetTapped(_:)))
            chip.bezelStyle = .rounded
            chip.tag = minutes
            presetRow.addArrangedSubview(chip)
        }

        let restLabel = NSTextField(labelWithString: L("panel.break"))
        restField.alignment = .right
        restField.delegate = self
        restField.target = self
        restField.action = #selector(restCommitted)
        restField.widthAnchor.constraint(equalToConstant: 40).isActive = true
        restUnit.textColor = .secondaryLabelColor
        restSwitch.target = self
        restSwitch.action = #selector(restToggled)

        let restRow = NSStackView(views: [restLabel, restField, restUnit, NSView(), restSwitch])
        restRow.orientation = .horizontal
        restRow.spacing = 6

        startButton.bezelStyle = .rounded
        startButton.controlSize = .large
        startButton.keyEquivalent = "\r"
        startButton.target = self
        startButton.action = #selector(startTapped)

        resetButton.bezelStyle = .inline
        resetButton.isBordered = false
        resetButton.title = L("panel.reset")
        resetButton.contentTintColor = .secondaryLabelColor
        resetButton.target = self
        resetButton.action = #selector(resetTapped)

        let gear = NSButton(image: NSImage(systemSymbolName: "gearshape", accessibilityDescription: L("gear.label"))!,
                            target: self,
                            action: #selector(gearTapped(_:)))
        gear.bezelStyle = .inline
        gear.isBordered = false
        gear.contentTintColor = .secondaryLabelColor

        let footer = NSStackView(views: [resetButton, NSView(), gear])
        footer.orientation = .horizontal

        let stack = NSStackView(views: [displayRow, presetRow, separator(), restRow, startButton, footer])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 12, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 240),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            presetRow.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -32),
            restRow.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -32),
            startButton.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -32),
            footer.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -32),
        ])
    }

    private func separator() -> NSView {
        let line = NSBox()
        line.boxType = .separator
        line.widthAnchor.constraint(equalToConstant: 208).isActive = true
        return line
    }

    // MARK: - State

    /// `editable` means the timer is untouched, so the big number is the focus duration to start.
    func update(remaining: Int, running: Bool, editable: Bool) {
        if editable {
            display.isEditable = true
            display.integerValue = Settings.focusMinutes
            unit.isHidden = false
        } else {
            display.isEditable = false
            display.stringValue = String(format: "%02d:%02d", remaining / 60, remaining % 60)
            unit.isHidden = true
        }
        sizeDisplay()
        presetRow.isHidden = !editable

        let hasBreak = Settings.restMinutes > 0
        restSwitch.state = hasBreak ? .on : .off
        restField.isEnabled = hasBreak
        restField.stringValue = hasBreak ? "\(Settings.restMinutes)" : "–"
        restUnit.textColor = hasBreak ? .secondaryLabelColor : .tertiaryLabelColor

        startButton.title = L(running ? "panel.pause" : "panel.start")
        resetButton.isHidden = editable
    }

    /// Width the field cannot report itself. Keeps "min" tucked against the number in both states.
    private func sizeDisplay() {
        let text = display.attributedStringValue.size().width
        displayWidth.constant = max(ceil(text) + 8, 60)
    }

    // MARK: - Actions

    @objc private func focusCommitted() {
        Settings.focusMinutes = Settings.focusRange.clamping(display.integerValue)
        onDurationsChanged()
    }

    @objc private func restCommitted() {
        Settings.restMinutes = Settings.restRange.clamping(restField.integerValue)
        onDurationsChanged()
    }

    @objc private func presetTapped(_ sender: NSButton) {
        Settings.focusMinutes = sender.tag
        onDurationsChanged()
    }

    /// The switch is just a shortcut for "0 minutes" — no separate stored flag.
    @objc private func restToggled() {
        Settings.restMinutes = (restSwitch.state == .on) ? Settings.lastRestMinutes : 0
        onDurationsChanged()
    }

    @objc private func startTapped() { onStartPause() }
    @objc private func resetTapped() { onReset() }
    @objc private func gearTapped(_ sender: NSButton) { onGear(sender) }
}
