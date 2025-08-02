import Cocoa

protocol ThemeNotchViewDelegate: AnyObject {
    func themeNotchDidToggleTheme(_ isDarkMode: Bool)
}

enum AppTheme: String, CaseIterable {
    case light = "Light"
    case dark = "Dark"
    case auto = "Auto"
    
    var icon: String {
        switch self {
        case .light: return "☀️"
        case .dark: return "🌙"
        case .auto: return "◑"
        }
    }
    
    var symbol: String {
        switch self {
        case .light: return "○"
        case .dark: return "●"
        case .auto: return "◑"
        }
    }
    
    var displayName: String {
        return self.rawValue
    }
}

class ThemeNotchView: NSView {
    
    weak var delegate: ThemeNotchViewDelegate?
    weak var contentViewController: ContentViewController?
    
    // UI Components
    private var themeIconView: NSView!
    private var themeIconLabel: NSTextField!
    private var dropdownWindow: KeyablePanel!
    private var themeContainer: NSView!
    private var themeSegmentedControl: NSSegmentedControl!
    private var currentThemeLabel: NSTextField!
    private var statusLabel: NSTextField!
    
    // State
    private var isDropdownVisible = false
    private var mouseExitTimer: Timer?
    private var globalMouseMonitor: Any?
    private var globalClickMonitor: Any?
    private var currentTheme: AppTheme = .auto
    
    // Constants
    private let dropdownWidth: CGFloat = 200
    private let dropdownHeight: CGFloat = 140
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
        loadSavedTheme()
        updateSystemAppearance()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
        loadSavedTheme()
        updateSystemAppearance()
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        
        setupThemeIcon()
        setupDropdownWindow()
        setupLayout()
        setupTrackingArea()
    }
    
    private func setupThemeIcon() {
        themeIconView = NSView()
        themeIconView.translatesAutoresizingMaskIntoConstraints = false
        themeIconView.wantsLayer = true
        themeIconView.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.8).cgColor
        themeIconView.layer?.cornerRadius = 6
        themeIconView.layer?.borderWidth = 1
        themeIconView.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.3).cgColor
        
        // Modern minimal shadow
        themeIconView.shadow = NSShadow()
        themeIconView.shadow?.shadowOffset = NSSize(width: 0, height: 1)
        themeIconView.shadow?.shadowBlurRadius = 2
        themeIconView.shadow?.shadowColor = NSColor.black.withAlphaComponent(0.05)
        
        themeIconLabel = NSTextField(labelWithString: "◑")
        themeIconLabel.translatesAutoresizingMaskIntoConstraints = false
        themeIconLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        themeIconLabel.textColor = NSColor.labelColor.withAlphaComponent(0.8)
        themeIconLabel.alignment = .center
        
        themeIconView.addSubview(themeIconLabel)
        addSubview(themeIconView)
        
        updateThemeIcon()
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
        
        setupThemeContainer()
        dropdownWindow.contentView = themeContainer
        dropdownWindow.alphaValue = 0
    }
    
    private func setupThemeContainer() {
        themeContainer = NSView()
        themeContainer.wantsLayer = true
        
        let visualEffect = NSVisualEffectView()
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 12
        visualEffect.translatesAutoresizingMaskIntoConstraints = false
        
        themeContainer.addSubview(visualEffect)
        
        // Header
        let headerLabel = NSTextField(labelWithString: "Appearance")
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        headerLabel.textColor = NSColor.labelColor
        
        // Current theme label
        currentThemeLabel = NSTextField(labelWithString: "Current: Auto")
        currentThemeLabel.translatesAutoresizingMaskIntoConstraints = false
        currentThemeLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        currentThemeLabel.textColor = NSColor.secondaryLabelColor
        currentThemeLabel.alignment = .center
        
        // Theme selector
        themeSegmentedControl = NSSegmentedControl()
        themeSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        themeSegmentedControl.segmentCount = 3
        
        for (index, theme) in AppTheme.allCases.enumerated() {
            themeSegmentedControl.setLabel("\(theme.symbol) \(theme.rawValue)", forSegment: index)
        }
        
        themeSegmentedControl.selectedSegment = 2 // Default to Auto
        themeSegmentedControl.target = self
        themeSegmentedControl.action = #selector(themeChanged)
        
        // Status label
        statusLabel = NSTextField(labelWithString: "")
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = NSFont.systemFont(ofSize: 9, weight: .regular)
        statusLabel.textColor = NSColor.tertiaryLabelColor
        statusLabel.alignment = .center
        
        // Add all subviews
        themeContainer.addSubview(headerLabel)
        themeContainer.addSubview(currentThemeLabel)
        themeContainer.addSubview(themeSegmentedControl)
        themeContainer.addSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            // Visual effect background
            visualEffect.topAnchor.constraint(equalTo: themeContainer.topAnchor),
            visualEffect.leadingAnchor.constraint(equalTo: themeContainer.leadingAnchor),
            visualEffect.trailingAnchor.constraint(equalTo: themeContainer.trailingAnchor),
            visualEffect.bottomAnchor.constraint(equalTo: themeContainer.bottomAnchor),
            
            // Header
            headerLabel.topAnchor.constraint(equalTo: themeContainer.topAnchor, constant: 12),
            headerLabel.centerXAnchor.constraint(equalTo: themeContainer.centerXAnchor),
            
            // Current theme
            currentThemeLabel.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 8),
            currentThemeLabel.centerXAnchor.constraint(equalTo: themeContainer.centerXAnchor),
            
            // Theme selector
            themeSegmentedControl.topAnchor.constraint(equalTo: currentThemeLabel.bottomAnchor, constant: 12),
            themeSegmentedControl.leadingAnchor.constraint(equalTo: themeContainer.leadingAnchor, constant: 16),
            themeSegmentedControl.trailingAnchor.constraint(equalTo: themeContainer.trailingAnchor, constant: -16),
            
            // Status
            statusLabel.topAnchor.constraint(equalTo: themeSegmentedControl.bottomAnchor, constant: 8),
            statusLabel.centerXAnchor.constraint(equalTo: themeContainer.centerXAnchor),
            statusLabel.bottomAnchor.constraint(lessThanOrEqualTo: themeContainer.bottomAnchor, constant: -12)
        ])
        
        updateThemeDisplay()
    }
    
    private func setupLayout() {
        NSLayoutConstraint.activate([
            themeIconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            themeIconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            themeIconView.widthAnchor.constraint(equalToConstant: 24),
            themeIconView.heightAnchor.constraint(equalToConstant: 24),
            
            themeIconLabel.centerXAnchor.constraint(equalTo: themeIconView.centerXAnchor),
            themeIconLabel.centerYAnchor.constraint(equalTo: themeIconView.centerYAnchor)
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
    
    // MARK: - Theme Management
    
    @objc private func themeChanged() {
        guard let theme = AppTheme.allCases[safe: themeSegmentedControl.selectedSegment] else { return }
        
        currentTheme = theme
        updateThemeDisplay()
        updateThemeIcon()
        saveTheme()
        updateSystemAppearance()
        
        let isDarkMode = getEffectiveIsDarkMode()
        delegate?.themeNotchDidToggleTheme(isDarkMode)
        
        updateStatus("Applied \(theme.displayName) theme")
        
        print("🎨 Theme changed to: \(theme.rawValue)")
    }
    
    private func updateSystemAppearance() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let appearance: NSAppearance?
            
            switch self.currentTheme {
            case .light:
                appearance = NSAppearance(named: .aqua)
            case .dark:
                appearance = NSAppearance(named: .darkAqua)
            case .auto:
                appearance = nil // Use system default
            }
            
            // Apply to main window and all windows
            if let window = self.window {
                window.appearance = appearance
                
                // Also apply to other windows if needed
                for window in NSApplication.shared.windows {
                    window.appearance = appearance
                }
            }
        }
    }
    
    private func getEffectiveIsDarkMode() -> Bool {
        switch currentTheme {
        case .light:
            return false
        case .dark:
            return true
        case .auto:
            // Check system appearance
            let systemAppearance = NSApp.effectiveAppearance
            return systemAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        }
    }
    
    private func updateThemeDisplay() {
        currentThemeLabel.stringValue = "Current: \(currentTheme.displayName)"
        
        if let index = AppTheme.allCases.firstIndex(of: currentTheme) {
            themeSegmentedControl.selectedSegment = index
        }
        
        let isDarkMode = getEffectiveIsDarkMode()
        let effectiveTheme = isDarkMode ? "Dark" : "Light"
        if currentTheme == .auto {
            statusLabel.stringValue = "Following system (\(effectiveTheme))"
        } else {
            statusLabel.stringValue = ""
        }
    }
    
    private func updateThemeIcon() {
        themeIconLabel.stringValue = currentTheme.symbol
        
        // Update color based on current theme
        let isDarkMode = getEffectiveIsDarkMode()
        if currentTheme == .auto {
            themeIconLabel.textColor = NSColor.labelColor.withAlphaComponent(0.8)
        } else if isDarkMode {
            themeIconLabel.textColor = NSColor.white.withAlphaComponent(0.9)
        } else {
            themeIconLabel.textColor = NSColor.black.withAlphaComponent(0.9)
        }
    }
    
    private func saveTheme() {
        UserDefaults.standard.set(currentTheme.rawValue, forKey: "AppTheme")
    }
    
    private func loadSavedTheme() {
        if let savedTheme = UserDefaults.standard.string(forKey: "AppTheme"),
           let theme = AppTheme(rawValue: savedTheme) {
            currentTheme = theme
        } else {
            currentTheme = .auto
        }
        updateThemeDisplay()
        updateThemeIcon()
    }
    
    private func updateStatus(_ status: String) {
        statusLabel.stringValue = status
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            if self?.statusLabel.stringValue == status {
                if self?.currentTheme == .auto {
                    let effectiveTheme = self?.getEffectiveIsDarkMode() == true ? "Dark" : "Light"
                    self?.statusLabel.stringValue = "Following system (\(effectiveTheme))"
                } else {
                    self?.statusLabel.stringValue = ""
                }
            }
        }
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
            print("🎨 Click detected - hiding dropdown")
            hideDropdown()
        } else {
            print("🎨 Click detected - showing dropdown") 
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
            themeIconView.layer?.transform = scaleTransform
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            self.dropdownWindow.makeKey()
            print("🎨 Made theme panel key window")
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
            themeIconView.layer?.transform = CATransform3DIdentity
        }, completionHandler: { [weak self] in
            self?.dropdownWindow.orderOut(nil)
            self?.removeDropdownTracking()
            self?.stopGlobalMouseMonitoring()
            self?.stopGlobalClickMonitoring()
        })
    }
    
    private func positionDropdownWindow() {
        guard let window = self.window else { return }
        
        let iconFrame = themeIconView.frame
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
            print("🎨 Click detected outside theme area - hiding dropdown")
            hideDropdown()
        }
    }
    
    private func handleGlobalMouseMove(_ event: NSEvent) {
        // Simplified - no longer needed for immediate hiding
    }
    
    private func isMouseInSafeZone(_ mouseLocation: NSPoint) -> Bool {
        guard let window = self.window else { return false }
        
        let iconFrame = themeIconView.frame
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
    
    func getCurrentTheme() -> AppTheme {
        return currentTheme
    }
    
    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
        updateThemeDisplay()
        updateThemeIcon()
        saveTheme()
        updateSystemAppearance()
        
        let isDarkMode = getEffectiveIsDarkMode()
        delegate?.themeNotchDidToggleTheme(isDarkMode)
    }
    
    deinit {
        mouseExitTimer?.invalidate()
        stopGlobalMouseMonitoring()
        stopGlobalClickMonitoring()
    }
}