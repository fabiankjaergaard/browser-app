import Cocoa
import UserNotifications

protocol TimerNotchViewDelegate: AnyObject {
    func timerNotchDidComplete(_ type: TimerType)
    func timerNotchDidStart(_ type: TimerType)
    func timerNotchDidStop()
}

enum TimerType: String, CaseIterable {
    case work = "Work"
    case shortBreak = "Short Break"
    case longBreak = "Long Break"
    case custom = "Custom"
    
    var defaultDuration: TimeInterval {
        switch self {
        case .work: return 25 * 60 // 25 minutes
        case .shortBreak: return 5 * 60 // 5 minutes
        case .longBreak: return 15 * 60 // 15 minutes
        case .custom: return 10 * 60 // 10 minutes default
        }
    }
    
    var color: NSColor {
        switch self {
        case .work: return .systemRed
        case .shortBreak: return .systemGreen
        case .longBreak: return .systemBlue
        case .custom: return .systemPurple
        }
    }
    
    var emoji: String {
        switch self {
        case .work: return "💼"
        case .shortBreak: return "☕"
        case .longBreak: return "🍽️"
        case .custom: return "⏱️"
        }
    }
}

enum TimerState {
    case idle
    case running
    case paused
    case completed
}

class TimerNotchView: NSView {
    
    weak var delegate: TimerNotchViewDelegate?
    weak var contentViewController: ContentViewController?
    
    // UI Components
    private var timerIconView: NSView!
    private var timerIconLabel: NSTextField!
    private var dropdownWindow: KeyablePanel!
    private var timerContainer: NSView!
    private var progressView: TimerProgressView!
    private var timeLabel: NSTextField!
    private var typeLabel: NSTextField!
    private var controlsStack: NSStackView!
    private var playPauseButton: NSButton!
    private var stopButton: NSButton!
    private var typeSegmentedControl: NSSegmentedControl!
    private var customTimeField: NSTextField!
    private var sessionCountLabel: NSTextField!
    
    // State
    private var isDropdownVisible = false
    private var mouseExitTimer: Timer?
    private var globalMouseMonitor: Any?
    private var globalClickMonitor: Any?
    
    // Timer state
    private var timer: Timer?
    private var timerState: TimerState = .idle
    private var currentType: TimerType = .work
    private var totalDuration: TimeInterval = 0
    private var remainingTime: TimeInterval = 0
    private var completedSessions: Int = 0
    
    // Constants
    private let dropdownWidth: CGFloat = 280
    private let dropdownHeight: CGFloat = 280
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
        loadSavedState()
        requestNotificationPermission()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
        loadSavedState()
        requestNotificationPermission()
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        
        setupTimerIcon()
        setupDropdownWindow()
        setupLayout()
        setupTrackingArea()
    }
    
    private func setupTimerIcon() {
        timerIconView = NSView()
        timerIconView.translatesAutoresizingMaskIntoConstraints = false
        timerIconView.wantsLayer = true
        timerIconView.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.8).cgColor
        timerIconView.layer?.cornerRadius = 6
        timerIconView.layer?.borderWidth = 1
        timerIconView.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.3).cgColor
        
        // Modern minimal shadow
        timerIconView.shadow = NSShadow()
        timerIconView.shadow?.shadowOffset = NSSize(width: 0, height: 1)
        timerIconView.shadow?.shadowBlurRadius = 2
        timerIconView.shadow?.shadowColor = NSColor.black.withAlphaComponent(0.05)
        
        timerIconLabel = NSTextField(labelWithString: "○")
        timerIconLabel.translatesAutoresizingMaskIntoConstraints = false
        timerIconLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        timerIconLabel.textColor = NSColor.labelColor.withAlphaComponent(0.8)
        timerIconLabel.alignment = .center
        
        timerIconView.addSubview(timerIconLabel)
        addSubview(timerIconView)
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
        
        setupTimerContainer()
        dropdownWindow.contentView = timerContainer
        dropdownWindow.alphaValue = 0
    }
    
    private func setupTimerContainer() {
        timerContainer = NSView()
        timerContainer.wantsLayer = true
        
        // Modern frosted glass effect
        let visualEffect = NSVisualEffectView()
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 12
        visualEffect.translatesAutoresizingMaskIntoConstraints = false
        
        timerContainer.addSubview(visualEffect)
        
        // Header
        let headerLabel = NSTextField(labelWithString: "Pomodoro Timer")
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        headerLabel.textColor = NSColor.labelColor
        
        // Progress view (circular)
        progressView = TimerProgressView()
        progressView.translatesAutoresizingMaskIntoConstraints = false
        
        // Time display
        timeLabel = NSTextField(labelWithString: "25:00")
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.font = NSFont.monospacedSystemFont(ofSize: 24, weight: .medium)
        timeLabel.textColor = NSColor.labelColor
        timeLabel.alignment = .center
        
        // Type label
        typeLabel = NSTextField(labelWithString: "Work Session")
        typeLabel.translatesAutoresizingMaskIntoConstraints = false
        typeLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        typeLabel.textColor = NSColor.secondaryLabelColor
        typeLabel.alignment = .center
        
        // Timer type selector
        typeSegmentedControl = NSSegmentedControl()
        typeSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        typeSegmentedControl.segmentCount = 4
        for (index, type) in TimerType.allCases.enumerated() {
            typeSegmentedControl.setLabel("\(type.emoji) \(type.rawValue)", forSegment: index)
        }
        typeSegmentedControl.selectedSegment = 0
        typeSegmentedControl.target = self
        typeSegmentedControl.action = #selector(timerTypeChanged)
        
        // Custom time field
        customTimeField = NSTextField()
        customTimeField.translatesAutoresizingMaskIntoConstraints = false
        customTimeField.placeholderString = "Minutes"
        customTimeField.font = NSFont.systemFont(ofSize: 12)
        customTimeField.target = self
        customTimeField.action = #selector(customTimeChanged)
        customTimeField.isHidden = true
        
        // Control buttons
        playPauseButton = createControlButton(title: "▶️", action: #selector(playPausePressed))
        stopButton = createControlButton(title: "⏹️", action: #selector(stopPressed))
        
        controlsStack = NSStackView(views: [playPauseButton, stopButton])
        controlsStack.translatesAutoresizingMaskIntoConstraints = false
        controlsStack.orientation = .horizontal
        controlsStack.spacing = 12
        controlsStack.distribution = .fillEqually
        
        // Session counter
        sessionCountLabel = NSTextField(labelWithString: "Sessions: 0")
        sessionCountLabel.translatesAutoresizingMaskIntoConstraints = false
        sessionCountLabel.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        sessionCountLabel.textColor = NSColor.tertiaryLabelColor
        sessionCountLabel.alignment = .center
        
        // Add all subviews
        timerContainer.addSubview(headerLabel)
        timerContainer.addSubview(progressView)
        timerContainer.addSubview(timeLabel)
        timerContainer.addSubview(typeLabel)
        timerContainer.addSubview(typeSegmentedControl)
        timerContainer.addSubview(customTimeField)
        timerContainer.addSubview(controlsStack)
        timerContainer.addSubview(sessionCountLabel)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            // Visual effect background
            visualEffect.topAnchor.constraint(equalTo: timerContainer.topAnchor),
            visualEffect.leadingAnchor.constraint(equalTo: timerContainer.leadingAnchor),
            visualEffect.trailingAnchor.constraint(equalTo: timerContainer.trailingAnchor),
            visualEffect.bottomAnchor.constraint(equalTo: timerContainer.bottomAnchor),
            
            // Header
            headerLabel.topAnchor.constraint(equalTo: timerContainer.topAnchor, constant: 12),
            headerLabel.centerXAnchor.constraint(equalTo: timerContainer.centerXAnchor),
            
            // Progress view
            progressView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 16),
            progressView.centerXAnchor.constraint(equalTo: timerContainer.centerXAnchor),
            progressView.widthAnchor.constraint(equalToConstant: 80),
            progressView.heightAnchor.constraint(equalToConstant: 80),
            
            // Time label (centered in progress view)
            timeLabel.centerXAnchor.constraint(equalTo: progressView.centerXAnchor),
            timeLabel.centerYAnchor.constraint(equalTo: progressView.centerYAnchor),
            
            // Type label
            typeLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 8),
            typeLabel.centerXAnchor.constraint(equalTo: timerContainer.centerXAnchor),
            
            // Timer type selector
            typeSegmentedControl.topAnchor.constraint(equalTo: typeLabel.bottomAnchor, constant: 12),
            typeSegmentedControl.leadingAnchor.constraint(equalTo: timerContainer.leadingAnchor, constant: 16),
            typeSegmentedControl.trailingAnchor.constraint(equalTo: timerContainer.trailingAnchor, constant: -16),
            
            // Custom time field
            customTimeField.topAnchor.constraint(equalTo: typeSegmentedControl.bottomAnchor, constant: 8),
            customTimeField.centerXAnchor.constraint(equalTo: timerContainer.centerXAnchor),
            customTimeField.widthAnchor.constraint(equalToConstant: 80),
            
            // Controls
            controlsStack.topAnchor.constraint(equalTo: customTimeField.bottomAnchor, constant: 16),
            controlsStack.centerXAnchor.constraint(equalTo: timerContainer.centerXAnchor),
            controlsStack.widthAnchor.constraint(equalToConstant: 100),
            
            // Session counter
            sessionCountLabel.topAnchor.constraint(equalTo: controlsStack.bottomAnchor, constant: 12),
            sessionCountLabel.centerXAnchor.constraint(equalTo: timerContainer.centerXAnchor),
            sessionCountLabel.bottomAnchor.constraint(lessThanOrEqualTo: timerContainer.bottomAnchor, constant: -12)
        ])
        
        updateTimerDisplay()
    }
    
    private func createControlButton(title: String, action: Selector) -> NSButton {
        let button = NSButton()
        button.title = title
        button.font = NSFont.systemFont(ofSize: 18)
        button.bezelStyle = .regularSquare
        button.isBordered = true
        button.target = self
        button.action = action
        return button
    }
    
    private func setupLayout() {
        NSLayoutConstraint.activate([
            timerIconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            timerIconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            timerIconView.widthAnchor.constraint(equalToConstant: 24),
            timerIconView.heightAnchor.constraint(equalToConstant: 24),
            
            timerIconLabel.centerXAnchor.constraint(equalTo: timerIconView.centerXAnchor),
            timerIconLabel.centerYAnchor.constraint(equalTo: timerIconView.centerYAnchor)
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
    
    // MARK: - Timer Logic
    
    @objc private func timerTypeChanged() {
        guard let type = TimerType.allCases[safe: typeSegmentedControl.selectedSegment] else { return }
        currentType = type
        
        // Show/hide custom time field
        customTimeField.isHidden = (type != .custom)
        
        if timerState == .idle {
            totalDuration = type.defaultDuration
            remainingTime = totalDuration
            updateTimerDisplay()
        }
        
        typeLabel.stringValue = type.rawValue
        updateTimerIcon()
    }
    
    @objc private func customTimeChanged() {
        guard currentType == .custom,
              let minutes = Int(customTimeField.stringValue),
              minutes > 0 else { return }
        
        if timerState == .idle {
            totalDuration = TimeInterval(minutes * 60)
            remainingTime = totalDuration
            updateTimerDisplay()
        }
    }
    
    @objc private func playPausePressed() {
        switch timerState {
        case .idle:
            startTimer()
        case .running:
            pauseTimer()
        case .paused:
            resumeTimer()
        case .completed:
            resetTimer()
        }
    }
    
    @objc private func stopPressed() {
        stopTimer()
    }
    
    private func startTimer() {
        guard remainingTime > 0 else { return }
        
        timerState = .running
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.timerTick()
        }
        
        delegate?.timerNotchDidStart(currentType)
        updateUI()
        
        print("⏱️ Started \(currentType.rawValue) timer for \(formatTime(totalDuration))")
    }
    
    private func pauseTimer() {
        timer?.invalidate()
        timer = nil
        timerState = .paused
        updateUI()
        
        print("⏱️ Paused timer at \(formatTime(remainingTime))")
    }
    
    private func resumeTimer() {
        startTimer()
        print("⏱️ Resumed timer at \(formatTime(remainingTime))")
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        timerState = .idle
        remainingTime = totalDuration
        
        delegate?.timerNotchDidStop()
        updateUI()
        
        print("⏱️ Stopped timer")
    }
    
    private func resetTimer() {
        timer?.invalidate()
        timer = nil
        timerState = .idle
        remainingTime = totalDuration
        updateUI()
    }
    
    private func timerTick() {
        remainingTime -= 1
        
        if remainingTime <= 0 {
            timerCompleted()
        } else {
            updateTimerDisplay()
            updateTimerIcon()
        }
    }
    
    private func timerCompleted() {
        timer?.invalidate()
        timer = nil
        timerState = .completed
        remainingTime = 0
        
        // Increment session counter for work sessions
        if currentType == .work {
            completedSessions += 1
            saveState()
        }
        
        // Send notification
        sendCompletionNotification()
        
        delegate?.timerNotchDidComplete(currentType)
        updateUI()
        
        print("⏱️ \(currentType.rawValue) timer completed!")
        
        // Auto-suggest next timer type
        suggestNextTimer()
    }
    
    private func suggestNextTimer() {
        // Pomodoro technique: work -> short break -> work -> short break -> work -> long break
        if currentType == .work {
            let nextType: TimerType = (completedSessions % 4 == 0) ? .longBreak : .shortBreak
            currentType = nextType
            totalDuration = nextType.defaultDuration
            remainingTime = totalDuration
            
            if let index = TimerType.allCases.firstIndex(of: nextType) {
                typeSegmentedControl.selectedSegment = index
            }
            
            typeLabel.stringValue = "\(nextType.rawValue) (Suggested)"
            updateTimerDisplay()
            updateTimerIcon()
        }
    }
    
    // MARK: - UI Updates
    
    private func updateUI() {
        updateTimerDisplay()
        updateTimerIcon()
        updateControls()
        updateSessionCounter()
    }
    
    private func updateTimerDisplay() {
        timeLabel.stringValue = formatTime(remainingTime)
        
        let progress = totalDuration > 0 ? (totalDuration - remainingTime) / totalDuration : 0
        progressView.progress = progress
        progressView.color = currentType.color
    }
    
    private func updateTimerIcon() {
        switch timerState {
        case .idle:
            timerIconLabel.stringValue = "○"
            timerIconLabel.textColor = NSColor.labelColor.withAlphaComponent(0.7)
        case .running:
            let minutes = Int(remainingTime / 60)
            timerIconLabel.stringValue = "\(minutes)"
            timerIconLabel.textColor = NSColor.systemRed.withAlphaComponent(0.9)
        case .paused:
            timerIconLabel.stringValue = "⏸"
            timerIconLabel.textColor = NSColor.systemYellow.withAlphaComponent(0.9)
        case .completed:
            timerIconLabel.stringValue = "●"
            timerIconLabel.textColor = NSColor.systemGreen.withAlphaComponent(0.9)
        }
    }
    
    private func updateControls() {
        switch timerState {
        case .idle:
            playPauseButton.title = "▶️"
            playPauseButton.isEnabled = remainingTime > 0
            stopButton.isEnabled = false
        case .running:
            playPauseButton.title = "⏸️"
            playPauseButton.isEnabled = true
            stopButton.isEnabled = true
        case .paused:
            playPauseButton.title = "▶️"
            playPauseButton.isEnabled = true
            stopButton.isEnabled = true
        case .completed:
            playPauseButton.title = "🔄"
            playPauseButton.isEnabled = true
            stopButton.isEnabled = false
        }
    }
    
    private func updateSessionCounter() {
        sessionCountLabel.stringValue = "Sessions: \(completedSessions)"
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - Mouse Events & Dropdown (same as other notches)
    
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
            print("⏱️ Click detected - hiding dropdown")
            hideDropdown()
        } else {
            print("⏱️ Click detected - showing dropdown") 
            showDropdown()
        }
    }
    
    private func isMouseInSafeZone(_ mouseLocation: NSPoint) -> Bool {
        guard let window = self.window else { return false }
        
        let iconFrame = timerIconView.frame
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
            timerIconView.layer?.transform = scaleTransform
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            self.dropdownWindow.makeKey()
            print("⏱️ Made timer panel key window")
        }
        
        setupDropdownTracking()
        startGlobalMouseMonitoring()
        startGlobalClickMonitoring()
    }
    
    private func hideDropdown() {
        guard isDropdownVisible else { return }
        isDropdownVisible = false
        
        saveState()
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            dropdownWindow.animator().alphaValue = 0.0
            timerIconView.layer?.transform = CATransform3DIdentity
        }, completionHandler: { [weak self] in
            self?.dropdownWindow.orderOut(nil)
            self?.removeDropdownTracking()
            self?.stopGlobalMouseMonitoring()
            self?.stopGlobalClickMonitoring()
        })
    }
    
    private func positionDropdownWindow() {
        guard let window = self.window else { return }
        
        let iconFrame = timerIconView.frame
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
            print("⏱️ Click detected outside timer area - hiding dropdown")
            hideDropdown()
        }
    }
    
    private func handleGlobalMouseMove(_ event: NSEvent) {
        // Simplified - no longer needed for immediate hiding
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
    
    // MARK: - Notifications
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("⏱️ Notification permission granted")
            } else if let error = error {
                print("⏱️ Notification permission error: \(error)")
            }
        }
    }
    
    private func sendCompletionNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Pomodoro Timer"
        content.body = "\(currentType.rawValue) completed! \(currentType.emoji)"
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("⏱️ Failed to send notification: \(error)")
            }
        }
    }
    
    // MARK: - Persistence
    
    private func saveState() {
        let state = [
            "completedSessions": completedSessions,
            "currentType": currentType.rawValue,
            "totalDuration": totalDuration,
            "remainingTime": remainingTime
        ] as [String : Any]
        
        UserDefaults.standard.set(state, forKey: "PomodoroTimerState")
    }
    
    private func loadSavedState() {
        guard let state = UserDefaults.standard.dictionary(forKey: "PomodoroTimerState") else { return }
        
        completedSessions = state["completedSessions"] as? Int ?? 0
        
        if let typeString = state["currentType"] as? String,
           let type = TimerType(rawValue: typeString) {
            currentType = type
            if let index = TimerType.allCases.firstIndex(of: type) {
                typeSegmentedControl?.selectedSegment = index
            }
        }
        
        totalDuration = state["totalDuration"] as? TimeInterval ?? currentType.defaultDuration
        remainingTime = totalDuration // Always start fresh, don't resume mid-timer
        
        updateUI()
    }
    
    // MARK: - Public Interface
    
    func hideDropdownIfVisible() {
        if isDropdownVisible {
            hideDropdown()
        }
    }
    
    deinit {
        timer?.invalidate()
        mouseExitTimer?.invalidate()
        stopGlobalMouseMonitoring()
        stopGlobalClickMonitoring()
    }
}

// MARK: - Custom Progress View

class TimerProgressView: NSView {
    var progress: Double = 0.0 {
        didSet {
            needsDisplay = true
        }
    }
    
    var color: NSColor = .systemBlue {
        didSet {
            needsDisplay = true
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2 - 4
        
        // Background circle
        NSColor.quaternaryLabelColor.setStroke()
        let backgroundPath = NSBezierPath()
        backgroundPath.lineWidth = 3
        backgroundPath.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
        backgroundPath.stroke()
        
        // Progress arc
        if progress > 0 {
            color.setStroke()
            let progressPath = NSBezierPath()
            progressPath.lineWidth = 3
            let endAngle = 90 - (progress * 360) // Start from top, go clockwise
            progressPath.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: endAngle, clockwise: true)
            progressPath.stroke()
        }
    }
}

// MARK: - Array Extension for Safe Access

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}