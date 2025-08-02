import Cocoa

class SettingsNotchView: NSView {
    
    weak var contentViewController: ContentViewController?
    
    // UI Components
    private var settingsIconView: NSView!
    private var settingsIconLabel: NSTextField!
    private var dropdownWindow: KeyablePanel!
    private var settingsContainer: NSView!
    
    // State
    private var isDropdownVisible = false
    private var mouseExitTimer: Timer?
    private var globalMouseMonitor: Any?
    private var globalClickMonitor: Any?
    
    // Constants
    private let dropdownWidth: CGFloat = 220
    private let dropdownHeight: CGFloat = 280
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        
        setupSettingsIcon()
        setupDropdownWindow()
        setupLayout()
        setupTrackingArea()
    }
    
    private func setupSettingsIcon() {
        settingsIconView = NSView()
        settingsIconView.translatesAutoresizingMaskIntoConstraints = false
        settingsIconView.wantsLayer = true
        settingsIconView.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.8).cgColor
        settingsIconView.layer?.cornerRadius = 6
        settingsIconView.layer?.borderWidth = 1
        settingsIconView.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.3).cgColor
        
        // Modern minimal shadow
        settingsIconView.shadow = NSShadow()
        settingsIconView.shadow?.shadowOffset = NSSize(width: 0, height: 1)
        settingsIconView.shadow?.shadowBlurRadius = 2
        settingsIconView.shadow?.shadowColor = NSColor.black.withAlphaComponent(0.05)
        
        settingsIconLabel = NSTextField(labelWithString: "⚙️")
        settingsIconLabel.translatesAutoresizingMaskIntoConstraints = false
        settingsIconLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        settingsIconLabel.textColor = NSColor.labelColor.withAlphaComponent(0.8)
        settingsIconLabel.alignment = .center
        
        settingsIconView.addSubview(settingsIconLabel)
        addSubview(settingsIconView)
    }
    
    private func setupDropdownWindow() {
        dropdownWindow = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: dropdownWidth, height: dropdownHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        dropdownWindow.isOpaque = false
        dropdownWindow.backgroundColor = NSColor.clear
        dropdownWindow.hasShadow = true
        dropdownWindow.level = .floating
        dropdownWindow.animationBehavior = .utilityWindow
        dropdownWindow.acceptsMouseMovedEvents = true
        
        setupSettingsContainer()
        dropdownWindow.contentView = settingsContainer
        dropdownWindow.alphaValue = 0
    }
    
    private func setupSettingsContainer() {
        settingsContainer = NSView()
        settingsContainer.wantsLayer = true
        
        let visualEffect = NSVisualEffectView()
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 12
        visualEffect.translatesAutoresizingMaskIntoConstraints = false
        
        settingsContainer.addSubview(visualEffect)
        
        // Header
        let headerLabel = NSTextField(labelWithString: "Notch Settings")
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        headerLabel.textColor = NSColor.labelColor
        
        // Create scroll view for toggles
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        
        // Create stack view for toggle switches
        let stackView = NSStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .vertical
        stackView.spacing = 8
        stackView.alignment = .leading
        
        // Create toggle switches for each notch
        let notchConfigs = [
            ("📄", "Notes", "notesNotchVisible"),
            ("📝", "Todo List", "todoNotchVisible"),
            ("🎵", "Media Controls", "mediaNotchVisible"),
            ("⏱️", "Timer", "timerNotchVisible"),
            ("🌤️", "Weather", "weatherNotchVisible"),
            ("📅", "Calendar", "calendarNotchVisible"),
            ("🎨", "Theme Switcher", "themeNotchVisible")
        ]
        
        for (emoji, title, key) in notchConfigs {
            let toggleContainer = createToggleSwitch(emoji: emoji, title: title, key: key)
            stackView.addArrangedSubview(toggleContainer)
        }
        
        scrollView.documentView = stackView
        
        // Add all subviews
        settingsContainer.addSubview(headerLabel)
        settingsContainer.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            // Visual effect background
            visualEffect.topAnchor.constraint(equalTo: settingsContainer.topAnchor),
            visualEffect.leadingAnchor.constraint(equalTo: settingsContainer.leadingAnchor),
            visualEffect.trailingAnchor.constraint(equalTo: settingsContainer.trailingAnchor),
            visualEffect.bottomAnchor.constraint(equalTo: settingsContainer.bottomAnchor),
            
            // Header
            headerLabel.topAnchor.constraint(equalTo: settingsContainer.topAnchor, constant: 16),
            headerLabel.centerXAnchor.constraint(equalTo: settingsContainer.centerXAnchor),
            
            // Scroll view
            scrollView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: settingsContainer.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: settingsContainer.trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: settingsContainer.bottomAnchor, constant: -16),
            
            // Stack view in scroll view
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.bottomAnchor.constraint(greaterThanOrEqualTo: scrollView.bottomAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }
    
    private func createToggleSwitch(emoji: String, title: String, key: String) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        // Emoji label
        let emojiLabel = NSTextField(labelWithString: emoji)
        emojiLabel.translatesAutoresizingMaskIntoConstraints = false
        emojiLabel.font = NSFont.systemFont(ofSize: 16)
        
        // Title label
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        titleLabel.textColor = NSColor.labelColor
        
        // Toggle switch (proper macOS toggle switch)
        let toggle = NSSwitch()
        toggle.translatesAutoresizingMaskIntoConstraints = false
        toggle.target = self
        toggle.action = #selector(toggleChanged(_:))
        toggle.identifier = NSUserInterfaceItemIdentifier(key)
        
        // Set initial state based on UserDefaults
        let settings = NotchSettings.shared
        switch key {
        case "notesNotchVisible":
            toggle.state = settings.notesNotchVisible ? .on : .off
        case "todoNotchVisible":
            toggle.state = settings.todoNotchVisible ? .on : .off
        case "mediaNotchVisible":
            toggle.state = settings.mediaNotchVisible ? .on : .off
        case "timerNotchVisible":
            toggle.state = settings.timerNotchVisible ? .on : .off
        case "weatherNotchVisible":
            toggle.state = settings.weatherNotchVisible ? .on : .off
        case "calendarNotchVisible":
            toggle.state = settings.calendarNotchVisible ? .on : .off
        case "themeNotchVisible":
            toggle.state = settings.themeNotchVisible ? .on : .off
        default:
            break
        }
        
        container.addSubview(emojiLabel)
        container.addSubview(titleLabel)
        container.addSubview(toggle)
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 32),
            
            emojiLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            emojiLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            emojiLabel.widthAnchor.constraint(equalToConstant: 24),
            
            titleLabel.leadingAnchor.constraint(equalTo: emojiLabel.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            toggle.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            toggle.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            toggle.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 8)
        ])
        
        return container
    }
    
    @objc private func toggleChanged(_ sender: NSSwitch) {
        guard let identifier = sender.identifier?.rawValue else { return }
        
        let isChecked = sender.state == .on
        let settings = NotchSettings.shared
        
        // Update settings
        switch identifier {
        case "notesNotchVisible":
            settings.notesNotchVisible = isChecked
        case "todoNotchVisible":
            settings.todoNotchVisible = isChecked
        case "mediaNotchVisible":
            settings.mediaNotchVisible = isChecked
        case "timerNotchVisible":
            settings.timerNotchVisible = isChecked
        case "weatherNotchVisible":
            settings.weatherNotchVisible = isChecked
        case "calendarNotchVisible":
            settings.calendarNotchVisible = isChecked
        case "themeNotchVisible":
            settings.themeNotchVisible = isChecked
        default:
            break
        }
        
        print("⚙️ \\(identifier) changed to: \\(isChecked)")
        
        // Update notch visibility
        contentViewController?.updateNotchVisibility()
    }
    
    private func setupLayout() {
        NSLayoutConstraint.activate([
            settingsIconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            settingsIconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            settingsIconView.widthAnchor.constraint(equalToConstant: 24),
            settingsIconView.heightAnchor.constraint(equalToConstant: 24),
            
            settingsIconLabel.centerXAnchor.constraint(equalTo: settingsIconView.centerXAnchor),
            settingsIconLabel.centerYAnchor.constraint(equalTo: settingsIconView.centerYAnchor)
        ])
    }
    
    private func setupTrackingArea() {
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }
    
    // MARK: - Mouse Events & Dropdown
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        
        // Check if this is from dropdown tracking area
        if let userInfo = event.trackingArea?.userInfo,
           let _ = userInfo["dropdown"] {
            // Mouse entered dropdown area - cancel any hide timers
            mouseExitTimer?.invalidate()
            return
        }
        
        // Mouse entered icon area
        mouseExitTimer?.invalidate()
        if !isDropdownVisible {
            showDropdown()
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        
        // Check if this is from dropdown tracking area
        if let userInfo = event.trackingArea?.userInfo,
           let _ = userInfo["dropdown"] {
            // Mouse exited dropdown area - hide immediately
            hideDropdown()
            return
        }
        
        // Mouse exited icon area - don't hide if dropdown is visible (user might move to dropdown)
        // The dropdown tracking will handle hiding when mouse exits dropdown
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        
        // Toggle dropdown on click
        if isDropdownVisible {
            print("⚙️ Click detected - hiding dropdown")
            hideDropdown()
        } else {
            print("⚙️ Click detected - showing dropdown") 
            showDropdown()
        }
    }
    
    private func showDropdown() {
        guard !isDropdownVisible else { return }
        
        contentViewController?.notchWillShow(self)
        isDropdownVisible = true
        
        positionDropdownWindow()
        dropdownWindow.orderFront(nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            dropdownWindow.animator().alphaValue = 1.0
            let scaleTransform = CATransform3DMakeScale(1.1, 1.1, 1.0)
            settingsIconView.layer?.transform = scaleTransform
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            self.dropdownWindow.makeKey()
            print("⚙️ Made settings panel key window")
        }
        
        setupDropdownTracking()
        startGlobalMouseMonitoring()
        startGlobalClickMonitoring()
    }
    
    private func hideDropdown() {
        guard isDropdownVisible else { return }
        isDropdownVisible = false
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            dropdownWindow.animator().alphaValue = 0.0
            settingsIconView.layer?.transform = CATransform3DIdentity
        }, completionHandler: { [weak self] in
            self?.dropdownWindow.orderOut(nil)
            self?.removeDropdownTracking()
            self?.stopGlobalMouseMonitoring()
            self?.stopGlobalClickMonitoring()
        })
    }
    
    private func positionDropdownWindow() {
        guard let window = self.window else { return }
        
        let iconFrame = settingsIconView.frame
        let iconInWindow = convert(iconFrame, to: nil)
        let iconInScreen = window.convertToScreen(NSRect(origin: iconInWindow.origin, size: iconInWindow.size))
        let windowFrame = window.frame
        
        // Calculate desired position (centered under icon)
        var dropdownX = iconInScreen.midX - (dropdownWidth * 0.5)
        let dropdownY = iconInScreen.minY - dropdownHeight - 10
        
        // Ensure dropdown stays within window bounds
        let windowMinX = windowFrame.minX + 10 // 10px margin from left edge
        let windowMaxX = windowFrame.maxX - dropdownWidth - 10 // 10px margin from right edge
        
        // Clamp the x position to stay within window bounds
        dropdownX = max(windowMinX, min(dropdownX, windowMaxX))
        
        let dropdownFrame = NSRect(
            x: dropdownX,
            y: dropdownY,
            width: dropdownWidth,
            height: dropdownHeight
        )
        
        dropdownWindow.setFrame(dropdownFrame, display: false)
    }
    
    private func setupDropdownTracking() {
        guard let contentView = dropdownWindow.contentView else { return }
        let trackingArea = NSTrackingArea(
            rect: contentView.bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: ["dropdown": true]
        )
        contentView.addTrackingArea(trackingArea)
    }
    
    private func removeDropdownTracking() {
        guard let contentView = dropdownWindow.contentView else { return }
        contentView.trackingAreas.forEach { contentView.removeTrackingArea($0) }
    }
    
    private func startGlobalMouseMonitoring() {
        stopGlobalMouseMonitoring()
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.handleGlobalMouseMove(event)
        }
    }
    
    private func stopGlobalMouseMonitoring() {
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseMonitor = nil
        }
    }
    
    private func startGlobalClickMonitoring() {
        stopGlobalClickMonitoring()
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.handleGlobalClick(event)
        }
    }
    
    private func stopGlobalClickMonitoring() {
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
    }
    
    private func handleGlobalClick(_ event: NSEvent) {
        guard isDropdownVisible else { return }
        let clickLocation = NSEvent.mouseLocation
        if !isMouseInSafeZone(clickLocation) {
            print("⚙️ Click detected outside settings area - hiding dropdown")
            hideDropdown()
        }
    }
    
    private func handleGlobalMouseMove(_ event: NSEvent) {
        // Simplified - no longer needed for immediate hiding
    }
    
    private func isMouseInSafeZone(_ mouseLocation: NSPoint) -> Bool {
        guard let window = self.window else { return false }
        
        let iconFrame = settingsIconView.frame
        let iconInWindow = convert(iconFrame, to: nil)
        let iconInScreen = window.convertToScreen(NSRect(origin: iconInWindow.origin, size: iconInWindow.size))
        let iconSafeZone = iconInScreen.insetBy(dx: -10, dy: -10)
        
        if isDropdownVisible {
            let dropdownFrame = dropdownWindow.frame
            let dropdownSafeZone = dropdownFrame.insetBy(dx: -5, dy: -5)
            return iconSafeZone.contains(mouseLocation) || dropdownSafeZone.contains(mouseLocation)
        }
        
        return iconSafeZone.contains(mouseLocation)
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }
    
    // MARK: - Public Interface
    
    func hideDropdownIfVisible() {
        if isDropdownVisible {
            hideDropdown()
        }
    }
    
    deinit {
        mouseExitTimer?.invalidate()
        stopGlobalMouseMonitoring()
        stopGlobalClickMonitoring()
    }
}