import Cocoa

protocol MediaNotchViewDelegate: AnyObject {
    func mediaNotchDidPressPrevious()
    func mediaNotchDidPressPlayPause()
    func mediaNotchDidPressNext()
}

class MediaNotchView: NSView {
    
    weak var delegate: MediaNotchViewDelegate?
    weak var contentViewController: ContentViewController?
    
    // UI Components
    private var musicIconView: NSView!
    private var musicIconLabel: NSTextField!
    private var dropdownWindow: NSPanel!
    private var mediaControlsContainer: NSView!
    private var previousButton: NSButton!
    private var playPauseButton: NSButton!
    private var nextButton: NSButton!
    
    // State
    private var isDropdownVisible = false
    private var isPlaying = false
    private var hoverTimer: Timer?
    private var mouseExitTimer: Timer?
    private var globalMouseMonitor: Any?
    private var globalClickMonitor: Any?
    
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
        
        setupMusicIcon()
        setupDropdownWindow()
        setupLayout()
        setupTrackingArea()
    }
    
    private func setupMusicIcon() {
        musicIconView = NSView()
        musicIconView.translatesAutoresizingMaskIntoConstraints = false
        musicIconView.wantsLayer = true
        musicIconView.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.8).cgColor
        musicIconView.layer?.cornerRadius = 6
        musicIconView.layer?.borderWidth = 1
        musicIconView.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.3).cgColor
        
        // Modern minimal shadow
        musicIconView.shadow = NSShadow()
        musicIconView.shadow?.shadowOffset = NSSize(width: 0, height: 1)
        musicIconView.shadow?.shadowBlurRadius = 2
        musicIconView.shadow?.shadowColor = NSColor.black.withAlphaComponent(0.05)
        
        musicIconLabel = NSTextField(labelWithString: "♫")
        musicIconLabel.translatesAutoresizingMaskIntoConstraints = false
        musicIconLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        musicIconLabel.textColor = NSColor.labelColor.withAlphaComponent(0.8)
        musicIconLabel.alignment = .center
        
        musicIconView.addSubview(musicIconLabel)
        addSubview(musicIconView)
    }
    
    private func setupDropdownWindow() {
        // Create a borderless panel that acts as dropdown
        dropdownWindow = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 160, height: 60),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        dropdownWindow.isOpaque = false
        dropdownWindow.backgroundColor = NSColor.clear
        dropdownWindow.hasShadow = true
        dropdownWindow.level = .floating
        dropdownWindow.animationBehavior = .utilityWindow
        
        // Setup the content view with media controls
        setupMediaControlsContainer()
        dropdownWindow.contentView = mediaControlsContainer
        
        // Initially hidden
        dropdownWindow.alphaValue = 0
    }
    
    private func setupMediaControlsContainer() {
        mediaControlsContainer = NSView()
        mediaControlsContainer.wantsLayer = true
        
        // Modern frosted glass effect
        let visualEffect = NSVisualEffectView()
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 12
        visualEffect.translatesAutoresizingMaskIntoConstraints = false
        
        mediaControlsContainer.addSubview(visualEffect)
        
        NSLayoutConstraint.activate([
            visualEffect.topAnchor.constraint(equalTo: mediaControlsContainer.topAnchor),
            visualEffect.leadingAnchor.constraint(equalTo: mediaControlsContainer.leadingAnchor),
            visualEffect.trailingAnchor.constraint(equalTo: mediaControlsContainer.trailingAnchor),
            visualEffect.bottomAnchor.constraint(equalTo: mediaControlsContainer.bottomAnchor)
        ])
        
        setupMediaButtons()
    }
    
    private func setupMediaButtons() {
        // Previous button
        previousButton = createNotchButton(
            systemName: "backward.fill",
            action: #selector(previousPressed),
            tooltip: "Previous track"
        )
        
        // Play/Pause button (larger)
        playPauseButton = createNotchButton(
            systemName: "play.fill",
            action: #selector(playPausePressed),
            tooltip: "Play/Pause"
        )
        playPauseButton.layer?.cornerRadius = 18 // Larger for prominence
        
        // Next button
        nextButton = createNotchButton(
            systemName: "forward.fill",
            action: #selector(nextPressed),
            tooltip: "Next track"
        )
        
        mediaControlsContainer.addSubview(previousButton)
        mediaControlsContainer.addSubview(playPauseButton)
        mediaControlsContainer.addSubview(nextButton)
    }
    
    private func setupLayout() {
        NSLayoutConstraint.activate([
            // Music icon view - always visible, small and centered
            musicIconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            musicIconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            musicIconView.widthAnchor.constraint(equalToConstant: 24),
            musicIconView.heightAnchor.constraint(equalToConstant: 24),
            
            // Music icon label - centered in icon view
            musicIconLabel.centerXAnchor.constraint(equalTo: musicIconView.centerXAnchor),
            musicIconLabel.centerYAnchor.constraint(equalTo: musicIconView.centerYAnchor),
            
            // Layout for dropdown window content (media controls)
            previousButton.centerYAnchor.constraint(equalTo: mediaControlsContainer.centerYAnchor),
            previousButton.leadingAnchor.constraint(equalTo: mediaControlsContainer.leadingAnchor, constant: 16),
            previousButton.widthAnchor.constraint(equalToConstant: 28),
            previousButton.heightAnchor.constraint(equalToConstant: 28),
            
            // Play/Pause button (center and larger)
            playPauseButton.centerYAnchor.constraint(equalTo: mediaControlsContainer.centerYAnchor),
            playPauseButton.centerXAnchor.constraint(equalTo: mediaControlsContainer.centerXAnchor),
            playPauseButton.widthAnchor.constraint(equalToConstant: 36),
            playPauseButton.heightAnchor.constraint(equalToConstant: 36),
            
            // Next button
            nextButton.centerYAnchor.constraint(equalTo: mediaControlsContainer.centerYAnchor),
            nextButton.trailingAnchor.constraint(equalTo: mediaControlsContainer.trailingAnchor, constant: -16),
            nextButton.widthAnchor.constraint(equalToConstant: 28),
            nextButton.heightAnchor.constraint(equalToConstant: 28)
        ])
    }
    
    private func createNotchButton(systemName: String, action: Selector, tooltip: String) -> NSButton {
        let button = NSButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.image = NSImage(systemSymbolName: systemName, accessibilityDescription: tooltip)
        button.target = self
        button.action = action
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.toolTip = tooltip
        button.wantsLayer = true
        
        // Subtle styling
        button.contentTintColor = NSColor.controlAccentColor
        button.layer?.backgroundColor = NSColor.clear.cgColor
        button.layer?.cornerRadius = 14
        
        return button
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
    
    // MARK: - Mouse Events
    
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
            print("🎵 Click detected - hiding dropdown")
            hideDropdown()
        } else {
            print("🎵 Click detected - showing dropdown")
            showDropdown()
        }
    }
    
    private func isMouseInSafeZone(_ mouseLocation: NSPoint) -> Bool {
        guard let window = self.window else { return false }
        
        // Get icon bounds in screen coordinates
        let iconFrame = musicIconView.frame
        let iconInWindow = convert(iconFrame, to: nil)
        let iconInScreen = window.convertToScreen(NSRect(origin: iconInWindow.origin, size: iconInWindow.size))
        
        // Add padding around icon for easier access
        let iconSafeZone = iconInScreen.insetBy(dx: -10, dy: -10)
        
        // Get dropdown bounds if visible
        if isDropdownVisible {
            let dropdownFrame = dropdownWindow.frame
            // Add small padding around dropdown
            let dropdownSafeZone = dropdownFrame.insetBy(dx: -5, dy: -5)
            
            // Mouse is safe if it's in either zone
            return iconSafeZone.contains(mouseLocation) || dropdownSafeZone.contains(mouseLocation)
        }
        
        // Only check icon zone if dropdown not visible
        return iconSafeZone.contains(mouseLocation)
    }
    
    // MARK: - Dropdown Animation
    
    private func showDropdown() {
        guard !isDropdownVisible else { return }
        
        // Coordinate with other notches
        contentViewController?.notchWillShow(self)
        
        isDropdownVisible = true
        
        // Position dropdown below the music icon
        positionDropdownWindow()
        
        // Show dropdown
        dropdownWindow.orderFront(nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            
            // Animate dropdown in with scale and fade
            dropdownWindow.animator().alphaValue = 1.0
            
            // Subtle scale effect on music icon
            let scaleTransform = CATransform3DMakeScale(1.1, 1.1, 1.0)
            musicIconView.layer?.transform = scaleTransform
        }
        
        // Add tracking to dropdown window and start global monitoring
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
            
            // Animate dropdown out
            dropdownWindow.animator().alphaValue = 0.0
            
            // Reset music icon scale
            musicIconView.layer?.transform = CATransform3DIdentity
            
        }, completionHandler: { [weak self] in
            // Hide window after animation
            self?.dropdownWindow.orderOut(nil)
            self?.removeDropdownTracking()
            self?.stopGlobalMouseMonitoring()
            self?.stopGlobalClickMonitoring()
        })
    }
    
    private func positionDropdownWindow() {
        guard let window = self.window else { return }
        
        let iconFrame = musicIconView.frame
        let iconInWindow = convert(iconFrame, to: nil)
        let iconInScreen = window.convertToScreen(NSRect(origin: iconInWindow.origin, size: iconInWindow.size))
        let windowFrame = window.frame
        
        // Calculate desired position (centered under icon)
        var dropdownX = iconInScreen.midX - 80 // Center dropdown (width 160 / 2 = 80)
        let dropdownY = iconInScreen.minY - 70 // Just below icon with small gap
        
        // Ensure dropdown stays within window bounds
        let windowMinX = windowFrame.minX + 10 // 10px margin from left edge
        let windowMaxX = windowFrame.maxX - 160 - 10 // 10px margin from right edge
        
        // Clamp the x position to stay within window bounds
        dropdownX = max(windowMinX, min(dropdownX, windowMaxX))
        
        let dropdownFrame = NSRect(
            x: dropdownX,
            y: dropdownY,
            width: 160,
            height: 60
        )
        
        dropdownWindow.setFrame(dropdownFrame, display: false)
    }
    
    private func setupDropdownTracking() {
        // Add tracking area to dropdown window to keep it visible when hovering
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
        stopGlobalMouseMonitoring() // Ensure no duplicate monitors
        
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            // Periodically check if mouse is still in safe zone
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
        stopGlobalClickMonitoring() // Ensure no duplicate monitors
        
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
        
        // Check if click is inside the safe zone (icon + dropdown)
        if !isMouseInSafeZone(clickLocation) {
            // Click is outside safe zone, hide dropdown
            print("🎵 Click detected outside media area - hiding dropdown")
            hideDropdown()
        }
    }
    
    private func handleGlobalMouseMove(_ event: NSEvent) {
        // Simplified - no longer needed for immediate hiding
    }
    
    // MARK: - Button Actions
    
    @objc private func previousPressed() {
        animateButtonPress(previousButton)
        delegate?.mediaNotchDidPressPrevious()
    }
    
    @objc private func playPausePressed() {
        isPlaying.toggle()
        updatePlayPauseButton()
        animateButtonPress(playPauseButton)
        delegate?.mediaNotchDidPressPlayPause()
    }
    
    @objc private func nextPressed() {
        animateButtonPress(nextButton)
        delegate?.mediaNotchDidPressNext()
    }
    
    // MARK: - State Management
    
    func setPlayingState(_ playing: Bool) {
        isPlaying = playing
        updatePlayPauseButton()
        
        // Update music icon to reflect playing state
        musicIconLabel.stringValue = playing ? "♫" : "♪"
        musicIconLabel.textColor = playing ? NSColor.labelColor.withAlphaComponent(0.9) : NSColor.labelColor.withAlphaComponent(0.7)
    }
    
    private func updatePlayPauseButton() {
        let symbolName = isPlaying ? "pause.fill" : "play.fill"
        let tooltip = isPlaying ? "Pause" : "Play"
        
        playPauseButton.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: tooltip)
        playPauseButton.toolTip = tooltip
    }
    
    // MARK: - Animation Helpers
    
    private func animateButtonPress(_ button: NSButton) {
        guard let layer = button.layer else { return }
        
        let scaleAnimation = CAKeyframeAnimation(keyPath: "transform.scale")
        scaleAnimation.values = [1.0, 0.85, 1.0]
        scaleAnimation.keyTimes = [0, 0.5, 1.0]
        scaleAnimation.duration = 0.2
        scaleAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        layer.add(scaleAnimation, forKey: "buttonPress")
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        // Remove existing tracking areas
        trackingAreas.forEach { removeTrackingArea($0) }
        
        // Add new tracking area with current bounds
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
        // Clean up timers and monitors
        mouseExitTimer?.invalidate()
        hoverTimer?.invalidate()
        stopGlobalMouseMonitoring()
        stopGlobalClickMonitoring()
    }
}