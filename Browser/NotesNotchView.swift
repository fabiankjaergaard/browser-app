import Cocoa

protocol NotesNotchViewDelegate: AnyObject {
    func notesNotchDidUpdateText(_ text: String)
    func notesNotchDidRequestKeyboardShortcut()
}

// Custom NSPanel that can become key window for text input
class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return false
    }
}

class NotesNotchView: NSView {
    
    weak var delegate: NotesNotchViewDelegate?
    weak var contentViewController: ContentViewController?
    
    // UI Components
    private var notesIconView: NSView!
    private var notesIconLabel: NSTextField!
    private var dropdownWindow: KeyablePanel!
    private var notesContainer: NSView!
    private var textScrollView: NSScrollView!
    private var textView: NSTextView!
    private var statusLabel: NSTextField!
    private var characterCountLabel: NSTextField!
    
    // State
    private var isDropdownVisible = false
    private var mouseExitTimer: Timer?
    private var autoSaveTimer: Timer?
    private var lastSavedText = ""
    private var globalMouseMonitor: Any?
    private var globalClickMonitor: Any?
    private var isTextViewFocused = false
    
    // Constants
    private let maxCharacters = 1000
    private let dropdownWidth: CGFloat = 320
    private let dropdownHeight: CGFloat = 240
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
        loadSavedNotes()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView() 
        loadSavedNotes()
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        
        setupNotesIcon()
        setupDropdownWindow()
        setupLayout()
        setupTrackingArea()
    }
    
    private func setupNotesIcon() {
        notesIconView = NSView()
        notesIconView.translatesAutoresizingMaskIntoConstraints = false
        notesIconView.wantsLayer = true
        notesIconView.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.8).cgColor
        notesIconView.layer?.cornerRadius = 6
        notesIconView.layer?.borderWidth = 1
        notesIconView.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.3).cgColor
        
        // Modern minimal shadow
        notesIconView.shadow = NSShadow()
        notesIconView.shadow?.shadowOffset = NSSize(width: 0, height: 1)
        notesIconView.shadow?.shadowBlurRadius = 2
        notesIconView.shadow?.shadowColor = NSColor.black.withAlphaComponent(0.05)
        
        notesIconLabel = NSTextField(labelWithString: "")
        notesIconLabel.translatesAutoresizingMaskIntoConstraints = false
        notesIconLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        notesIconLabel.textColor = NSColor.labelColor.withAlphaComponent(0.8)
        notesIconLabel.alignment = .center
        notesIconLabel.stringValue = "✎"
        
        notesIconView.addSubview(notesIconLabel)
        addSubview(notesIconView)
    }
    
    private func setupDropdownWindow() {
        // Create a borderless panel that acts as dropdown
        dropdownWindow = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: dropdownWidth, height: dropdownHeight),
            styleMask: [.borderless],  // Remove nonactivatingPanel to allow keyboard input
            backing: .buffered,
            defer: false
        )
        
        dropdownWindow.isOpaque = false
        dropdownWindow.backgroundColor = NSColor.clear
        dropdownWindow.hasShadow = true
        dropdownWindow.level = .floating
        dropdownWindow.animationBehavior = .utilityWindow
        dropdownWindow.acceptsMouseMovedEvents = true
        
        // Setup the content view with notes editor
        setupNotesContainer()
        dropdownWindow.contentView = notesContainer
        
        // Initially hidden
        dropdownWindow.alphaValue = 0
    }
    
    private func setupNotesContainer() {
        notesContainer = NSView()
        notesContainer.wantsLayer = true
        
        // Modern frosted glass effect
        let visualEffect = NSVisualEffectView()
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 12
        visualEffect.translatesAutoresizingMaskIntoConstraints = false
        
        notesContainer.addSubview(visualEffect)
        
        // Header with title
        let headerLabel = NSTextField(labelWithString: "Quick Notes")
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        headerLabel.textColor = NSColor.labelColor
        
        // Setup text editor
        setupTextEditor()
        
        // Status and character count
        statusLabel = NSTextField(labelWithString: "")
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        statusLabel.textColor = NSColor.secondaryLabelColor
        
        characterCountLabel = NSTextField(labelWithString: "0/\(maxCharacters)")
        characterCountLabel.translatesAutoresizingMaskIntoConstraints = false
        characterCountLabel.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        characterCountLabel.textColor = NSColor.tertiaryLabelColor
        characterCountLabel.alignment = .right
        
        // Add all subviews
        notesContainer.addSubview(headerLabel)
        notesContainer.addSubview(textScrollView)
        notesContainer.addSubview(statusLabel)
        notesContainer.addSubview(characterCountLabel)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            // Visual effect background
            visualEffect.topAnchor.constraint(equalTo: notesContainer.topAnchor),
            visualEffect.leadingAnchor.constraint(equalTo: notesContainer.leadingAnchor),
            visualEffect.trailingAnchor.constraint(equalTo: notesContainer.trailingAnchor),
            visualEffect.bottomAnchor.constraint(equalTo: notesContainer.bottomAnchor),
            
            // Header
            headerLabel.topAnchor.constraint(equalTo: notesContainer.topAnchor, constant: 12),
            headerLabel.leadingAnchor.constraint(equalTo: notesContainer.leadingAnchor, constant: 16),
            
            // Text editor
            textScrollView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 8),
            textScrollView.leadingAnchor.constraint(equalTo: notesContainer.leadingAnchor, constant: 16),
            textScrollView.trailingAnchor.constraint(equalTo: notesContainer.trailingAnchor, constant: -16),
            textScrollView.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -8),
            
            // Status label
            statusLabel.leadingAnchor.constraint(equalTo: notesContainer.leadingAnchor, constant: 16),
            statusLabel.bottomAnchor.constraint(equalTo: notesContainer.bottomAnchor, constant: -12),
            
            // Character count
            characterCountLabel.trailingAnchor.constraint(equalTo: notesContainer.trailingAnchor, constant: -16),
            characterCountLabel.bottomAnchor.constraint(equalTo: notesContainer.bottomAnchor, constant: -12),
            characterCountLabel.leadingAnchor.constraint(greaterThanOrEqualTo: statusLabel.trailingAnchor, constant: 8)
        ])
    }
    
    private func setupTextEditor() {
        textScrollView = NSScrollView()
        textScrollView.translatesAutoresizingMaskIntoConstraints = false
        textScrollView.hasVerticalScroller = true
        textScrollView.hasHorizontalScroller = false
        textScrollView.autohidesScrollers = true
        textScrollView.borderType = .noBorder
        textScrollView.drawsBackground = false
        
        textView = NSTextView()
        textView.backgroundColor = NSColor.clear
        textView.textColor = NSColor.labelColor
        textView.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.delegate = self
        textView.string = ""
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        
        // Configure for proper text wrapping
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        
        if let textContainer = textView.textContainer {
            textContainer.containerSize = CGSize(width: dropdownWidth - 32, height: CGFloat.greatestFiniteMagnitude)
            textContainer.widthTracksTextView = true
        }
        
        textView.maxSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = CGSize(width: 0, height: 0)
        
        textScrollView.documentView = textView
    }
    
    private func setupLayout() {
        NSLayoutConstraint.activate([
            // Notes icon view - always visible, small and centered
            notesIconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            notesIconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            notesIconView.widthAnchor.constraint(equalToConstant: 24),
            notesIconView.heightAnchor.constraint(equalToConstant: 24),
            
            // Notes icon label - centered in icon view
            notesIconLabel.centerXAnchor.constraint(equalTo: notesIconView.centerXAnchor),
            notesIconLabel.centerYAnchor.constraint(equalTo: notesIconView.centerYAnchor)
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
    
    // MARK: - Mouse Events
    
    
    private func isMouseInSafeZone(_ mouseLocation: NSPoint) -> Bool {
        guard let window = self.window else { return false }
        
        // Get icon bounds in screen coordinates
        let iconFrame = notesIconView.frame
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
        
        // Position dropdown below the notes icon
        positionDropdownWindow()
        
        // Show dropdown
        dropdownWindow.orderFront(nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            
            // Animate dropdown in with fade
            dropdownWindow.animator().alphaValue = 1.0
            
            // Subtle scale effect on notes icon
            let scaleTransform = CATransform3DMakeScale(1.1, 1.1, 1.0)
            notesIconView.layer?.transform = scaleTransform
        }
        
        // Focus text view for immediate typing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            // Make panel key window to receive keyboard input
            self.dropdownWindow.makeKey()
            self.dropdownWindow.makeFirstResponder(self.textView)
            print("📝 Made notes panel key window and focused text view")
        }
        
        // Add tracking to dropdown window and start global monitoring
        setupDropdownTracking()
        startGlobalMouseMonitoring()
        startGlobalClickMonitoring()
    }
    
    private func hideDropdown() {
        guard isDropdownVisible else { return }
        isDropdownVisible = false
        
        // Save notes before hiding
        saveNotes()
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            
            // Animate dropdown out
            dropdownWindow.animator().alphaValue = 0.0
            
            // Reset notes icon scale
            notesIconView.layer?.transform = CATransform3DIdentity
            
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
        
        let iconFrame = notesIconView.frame
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
        // Add tracking area to dropdown window for immediate hiding when mouse exits
        guard let contentView = dropdownWindow.contentView else { return }
        
        let trackingArea = NSTrackingArea(
            rect: contentView.bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: ["dropdown": true]
        )
        contentView.addTrackingArea(trackingArea)
    }
    
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
            // Mouse exited dropdown area - hide immediately unless text is focused
            if !isTextViewFocused {
                hideDropdown()
            }
            return
        }
        
        // Mouse exited icon area - don't hide if dropdown is visible (user might move to dropdown)
        // The dropdown tracking will handle hiding when mouse exits dropdown
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        
        // Toggle dropdown on click
        if isDropdownVisible {
            print("📄 Click detected - hiding dropdown")
            hideDropdown()
        } else {
            print("📄 Click detected - showing dropdown")
            showDropdown()
        }
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
            print("📝 Click detected outside notes area - hiding dropdown")
            hideDropdown()
        }
    }
    
    private func handleGlobalMouseMove(_ event: NSEvent) {
        // Simplified - no longer needed for immediate hiding
    }
    
    // MARK: - Notes Management
    
    private func loadSavedNotes() {
        let savedText = UserDefaults.standard.string(forKey: "QuickNotes") ?? ""
        textView?.string = savedText
        lastSavedText = savedText
        updateCharacterCount()
        updateStatus("Loaded")
    }
    
    private func saveNotes() {
        let currentText = textView.string
        if currentText != lastSavedText {
            UserDefaults.standard.set(currentText, forKey: "QuickNotes")
            lastSavedText = currentText
            updateStatus("Saved")
            delegate?.notesNotchDidUpdateText(currentText)
        }
    }
    
    private func scheduleAutoSave() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.saveNotes()
        }
    }
    
    private func updateCharacterCount() {
        let count = textView.string.count
        characterCountLabel.stringValue = "\(count)/\(maxCharacters)"
        
        // Change color if approaching limit
        if count > maxCharacters * 8 / 10 {
            characterCountLabel.textColor = NSColor.systemOrange
        } else if count >= maxCharacters {
            characterCountLabel.textColor = NSColor.systemRed
        } else {
            characterCountLabel.textColor = NSColor.tertiaryLabelColor
        }
    }
    
    private func updateStatus(_ status: String) {
        statusLabel.stringValue = status
        
        // Clear status after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.statusLabel.stringValue = ""
        }
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
        autoSaveTimer?.invalidate()
        stopGlobalMouseMonitoring()
        stopGlobalClickMonitoring()
    }
}

// MARK: - NSTextViewDelegate
extension NotesNotchView: NSTextViewDelegate {
    
    func textDidBeginEditing(_ notification: Notification) {
        isTextViewFocused = true
        // Cancel any pending hide while user is typing
        mouseExitTimer?.invalidate()
        print("📝 Started editing notes - preventing auto-hide")
    }
    
    func textDidEndEditing(_ notification: Notification) {
        isTextViewFocused = false
        // Save notes when done editing
        saveNotes()
        print("📝 Finished editing notes - re-enabling auto-hide")
    }
    
    func textDidChange(_ notification: Notification) {
        updateCharacterCount()
        scheduleAutoSave()
        
        // Prevent exceeding character limit
        if textView.string.count > maxCharacters {
            let truncatedText = String(textView.string.prefix(maxCharacters))
            textView.string = truncatedText
            updateCharacterCount()
        }
        
        updateStatus("Typing...")
    }
    
    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        // Handle Escape key to close dropdown
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            hideDropdown()
            return true
        }
        return false
    }
}