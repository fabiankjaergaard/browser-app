import Cocoa
import EventKit

protocol CalendarNotchViewDelegate: AnyObject {
    func calendarNotchDidUpdateEvents(_ events: [CalendarEvent])
    func calendarNotchDidRequestEventCreation()
}

struct CalendarEvent {
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendar: String
    let location: String?
    
    var timeString: String {
        let formatter = DateFormatter()
        
        if isAllDay {
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: startDate)
        } else {
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            let startTime = formatter.string(from: startDate)
            let endTime = formatter.string(from: endDate)
            return "\(startTime) - \(endTime)"
        }
    }
    
    var isToday: Bool {
        return Calendar.current.isDate(startDate, inSameDayAs: Date())
    }
    
    var isUpcoming: Bool {
        return startDate > Date()
    }
    
    var statusIcon: String {
        if isAllDay {
            return "📅"
        } else if isToday && isUpcoming {
            return "🔔"
        } else if isToday {
            return "⏰"
        } else {
            return "📆"
        }
    }
}

class CalendarNotchView: NSView {
    
    weak var delegate: CalendarNotchViewDelegate?
    weak var contentViewController: ContentViewController?
    
    // UI Components
    private var calendarIconView: NSView!
    private var calendarIconLabel: NSTextField!
    private var dropdownWindow: KeyablePanel!
    private var calendarContainer: NSView!
    private var headerView: NSView!
    private var eventsScrollView: NSScrollView!
    private var eventsStackView: NSStackView!
    private var noEventsLabel: NSTextField!
    private var statusLabel: NSTextField!
    private var refreshButton: NSButton!
    private var addEventButton: NSButton!
    
    // State
    private var isDropdownVisible = false
    private var mouseExitTimer: Timer?
    private var globalMouseMonitor: Any?
    private var globalClickMonitor: Any?
    private var events: [CalendarEvent] = []
    private var isLoading = false
    
    // EventKit
    private var eventStore: EKEventStore!
    private var hasCalendarAccess = false
    
    // Constants
    private let dropdownWidth: CGFloat = 320
    private let dropdownHeight: CGFloat = 300
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
        setupEventStore()
        loadTodaysEvents()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
        setupEventStore()
        loadTodaysEvents()
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        
        setupCalendarIcon()
        setupDropdownWindow()
        setupLayout()
        setupTrackingArea()
    }
    
    private func setupCalendarIcon() {
        calendarIconView = NSView()
        calendarIconView.translatesAutoresizingMaskIntoConstraints = false
        calendarIconView.wantsLayer = true
        calendarIconView.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.8).cgColor
        calendarIconView.layer?.cornerRadius = 6
        calendarIconView.layer?.borderWidth = 1
        calendarIconView.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.3).cgColor
        
        // Modern minimal shadow
        calendarIconView.shadow = NSShadow()
        calendarIconView.shadow?.shadowOffset = NSSize(width: 0, height: 1)
        calendarIconView.shadow?.shadowBlurRadius = 2
        calendarIconView.shadow?.shadowColor = NSColor.black.withAlphaComponent(0.05)
        
        calendarIconLabel = NSTextField(labelWithString: "1")
        calendarIconLabel.translatesAutoresizingMaskIntoConstraints = false
        calendarIconLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        calendarIconLabel.textColor = NSColor.labelColor.withAlphaComponent(0.8)
        calendarIconLabel.alignment = .center
        
        calendarIconView.addSubview(calendarIconLabel)
        addSubview(calendarIconView)
        
        updateCalendarIcon()
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
        
        setupCalendarContainer()
        dropdownWindow.contentView = calendarContainer
        dropdownWindow.alphaValue = 0
    }
    
    private func setupCalendarContainer() {
        calendarContainer = NSView()
        calendarContainer.wantsLayer = true
        
        let visualEffect = NSVisualEffectView()
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 12
        visualEffect.translatesAutoresizingMaskIntoConstraints = false
        
        calendarContainer.addSubview(visualEffect)
        
        // Header
        let headerLabel = NSTextField(labelWithString: "Today's Events")
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        headerLabel.textColor = NSColor.labelColor
        
        // Refresh button
        refreshButton = NSButton()
        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        refreshButton.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Refresh")
        refreshButton.bezelStyle = .regularSquare
        refreshButton.isBordered = false
        refreshButton.target = self
        refreshButton.action = #selector(refreshEvents)
        
        // Add event button
        addEventButton = NSButton()
        addEventButton.translatesAutoresizingMaskIntoConstraints = false
        addEventButton.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "Add Event")
        addEventButton.bezelStyle = .regularSquare
        addEventButton.isBordered = false
        addEventButton.target = self
        addEventButton.action = #selector(addEventPressed)
        
        // Events scroll view
        setupEventsScrollView()
        
        // No events label
        noEventsLabel = NSTextField(labelWithString: "No events today")
        noEventsLabel.translatesAutoresizingMaskIntoConstraints = false
        noEventsLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        noEventsLabel.textColor = NSColor.secondaryLabelColor
        noEventsLabel.alignment = .center
        noEventsLabel.isHidden = true
        
        // Status label
        statusLabel = NSTextField(labelWithString: "")
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = NSFont.systemFont(ofSize: 9, weight: .regular)
        statusLabel.textColor = NSColor.tertiaryLabelColor
        statusLabel.alignment = .center
        
        // Add all subviews
        calendarContainer.addSubview(headerLabel)
        calendarContainer.addSubview(refreshButton)
        calendarContainer.addSubview(addEventButton)
        calendarContainer.addSubview(eventsScrollView)
        calendarContainer.addSubview(noEventsLabel)
        calendarContainer.addSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            // Visual effect background
            visualEffect.topAnchor.constraint(equalTo: calendarContainer.topAnchor),
            visualEffect.leadingAnchor.constraint(equalTo: calendarContainer.leadingAnchor),
            visualEffect.trailingAnchor.constraint(equalTo: calendarContainer.trailingAnchor),
            visualEffect.bottomAnchor.constraint(equalTo: calendarContainer.bottomAnchor),
            
            // Header
            headerLabel.topAnchor.constraint(equalTo: calendarContainer.topAnchor, constant: 12),
            headerLabel.leadingAnchor.constraint(equalTo: calendarContainer.leadingAnchor, constant: 16),
            
            // Add event button
            addEventButton.topAnchor.constraint(equalTo: calendarContainer.topAnchor, constant: 8),
            addEventButton.trailingAnchor.constraint(equalTo: refreshButton.leadingAnchor, constant: -4),
            addEventButton.widthAnchor.constraint(equalToConstant: 24),
            addEventButton.heightAnchor.constraint(equalToConstant: 24),
            
            // Refresh button
            refreshButton.topAnchor.constraint(equalTo: calendarContainer.topAnchor, constant: 8),
            refreshButton.trailingAnchor.constraint(equalTo: calendarContainer.trailingAnchor, constant: -12),
            refreshButton.widthAnchor.constraint(equalToConstant: 24),
            refreshButton.heightAnchor.constraint(equalToConstant: 24),
            
            // Events scroll view
            eventsScrollView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 8),
            eventsScrollView.leadingAnchor.constraint(equalTo: calendarContainer.leadingAnchor, constant: 16),
            eventsScrollView.trailingAnchor.constraint(equalTo: calendarContainer.trailingAnchor, constant: -16),
            eventsScrollView.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -8),
            
            // No events label
            noEventsLabel.centerXAnchor.constraint(equalTo: eventsScrollView.centerXAnchor),
            noEventsLabel.centerYAnchor.constraint(equalTo: eventsScrollView.centerYAnchor),
            
            // Status label
            statusLabel.leadingAnchor.constraint(equalTo: calendarContainer.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: calendarContainer.trailingAnchor, constant: -16),
            statusLabel.bottomAnchor.constraint(equalTo: calendarContainer.bottomAnchor, constant: -8)
        ])
    }
    
    private func setupEventsScrollView() {
        eventsScrollView = NSScrollView()
        eventsScrollView.translatesAutoresizingMaskIntoConstraints = false
        eventsScrollView.hasVerticalScroller = true
        eventsScrollView.hasHorizontalScroller = false
        eventsScrollView.autohidesScrollers = true
        eventsScrollView.borderType = .noBorder
        eventsScrollView.drawsBackground = false
        
        eventsStackView = NSStackView()
        eventsStackView.translatesAutoresizingMaskIntoConstraints = false
        eventsStackView.orientation = .vertical
        eventsStackView.spacing = 6
        eventsStackView.distribution = .fill
        eventsStackView.alignment = .leading
        
        eventsScrollView.documentView = eventsStackView
        
        NSLayoutConstraint.activate([
            eventsStackView.topAnchor.constraint(equalTo: eventsScrollView.contentView.topAnchor),
            eventsStackView.leadingAnchor.constraint(equalTo: eventsScrollView.contentView.leadingAnchor),
            eventsStackView.trailingAnchor.constraint(equalTo: eventsScrollView.contentView.trailingAnchor),
            eventsStackView.widthAnchor.constraint(equalTo: eventsScrollView.widthAnchor, constant: -16)
        ])
    }
    
    private func setupEventStore() {
        eventStore = EKEventStore()
    }
    
    private func setupLayout() {
        NSLayoutConstraint.activate([
            calendarIconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            calendarIconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            calendarIconView.widthAnchor.constraint(equalToConstant: 24),
            calendarIconView.heightAnchor.constraint(equalToConstant: 24),
            
            calendarIconLabel.centerXAnchor.constraint(equalTo: calendarIconView.centerXAnchor),
            calendarIconLabel.centerYAnchor.constraint(equalTo: calendarIconView.centerYAnchor)
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
    
    // MARK: - Calendar Access & Events
    
    private func requestCalendarAccess() {
        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToEvents { [weak self] granted, error in
                DispatchQueue.main.async {
                    self?.hasCalendarAccess = granted
                    if granted {
                        self?.loadTodaysEvents()
                    } else {
                        self?.updateStatus("Calendar access denied")
                        print("📅 Calendar access denied: \(error?.localizedDescription ?? "Unknown error")")
                    }
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { [weak self] granted, error in
                DispatchQueue.main.async {
                    self?.hasCalendarAccess = granted
                    if granted {
                        self?.loadTodaysEvents()
                    } else {
                        self?.updateStatus("Calendar access denied")
                        print("📅 Calendar access denied: \(error?.localizedDescription ?? "Unknown error")")
                    }
                }
            }
        }
    }
    
    @objc private func refreshEvents() {
        loadTodaysEvents()
    }
    
    @objc private func addEventPressed() {
        delegate?.calendarNotchDidRequestEventCreation()
        
        // For now, open Calendar app
        if let calendarApp = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
            NSWorkspace.shared.open(calendarApp)
        }
    }
    
    private func loadTodaysEvents() {
        guard !isLoading else { return }
        
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined:
            requestCalendarAccess()
            return
        case .denied, .restricted:
            events = []
            updateEventsDisplay()
            updateStatus("Calendar access required")
            return
        case .authorized:
            hasCalendarAccess = true
        case .fullAccess:
            hasCalendarAccess = true
        case .writeOnly:
            hasCalendarAccess = true
        @unknown default:
            break
        }
        
        isLoading = true
        updateStatus("Loading events...")
        refreshButton.isEnabled = false
        
        let today = Date()
        let startOfDay = Calendar.current.startOfDay(for: today)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let ekEvents = eventStore.events(matching: predicate)
        
        // Convert EKEvents to CalendarEvents
        events = ekEvents.map { ekEvent in
            CalendarEvent(
                title: ekEvent.title ?? "Untitled Event",
                startDate: ekEvent.startDate,
                endDate: ekEvent.endDate,
                isAllDay: ekEvent.isAllDay,
                calendar: ekEvent.calendar?.title ?? "Unknown",
                location: ekEvent.location
            )
        }.sorted { $0.startDate < $1.startDate }
        
        isLoading = false
        refreshButton.isEnabled = true
        updateEventsDisplay()
        updateCalendarIcon()
        delegate?.calendarNotchDidUpdateEvents(events)
        updateStatus("Updated \(formatCurrentTime())")
        
        print("📅 Loaded \(events.count) events for today")
    }
    
    private func updateEventsDisplay() {
        // Clear existing event views
        eventsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        if events.isEmpty {
            noEventsLabel.isHidden = false
        } else {
            noEventsLabel.isHidden = true
            
            for event in events {
                let eventView = createEventView(for: event)
                eventsStackView.addArrangedSubview(eventView)
            }
        }
    }
    
    private func createEventView(for event: CalendarEvent) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.3).cgColor
        container.layer?.cornerRadius = 6
        
        // Icon
        let iconLabel = NSTextField(labelWithString: event.statusIcon)
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        iconLabel.font = NSFont.systemFont(ofSize: 12)
        iconLabel.alignment = .center
        
        // Title
        let titleLabel = NSTextField(labelWithString: event.title)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = NSColor.labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        
        // Time
        let timeLabel = NSTextField(labelWithString: event.timeString)
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        timeLabel.textColor = NSColor.secondaryLabelColor
        
        // Location (if available)
        var locationLabel: NSTextField?
        if let location = event.location, !location.isEmpty {
            locationLabel = NSTextField(labelWithString: "📍 \(location)")
            locationLabel!.translatesAutoresizingMaskIntoConstraints = false
            locationLabel!.font = NSFont.systemFont(ofSize: 9, weight: .regular)
            locationLabel!.textColor = NSColor.tertiaryLabelColor
            locationLabel!.lineBreakMode = .byTruncatingTail
        }
        
        container.addSubview(iconLabel)
        container.addSubview(titleLabel)
        container.addSubview(timeLabel)
        if let locationLabel = locationLabel {
            container.addSubview(locationLabel)
        }
        
        var constraints: [NSLayoutConstraint] = [
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: locationLabel != nil ? 52 : 40),
            
            iconLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            iconLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
            iconLabel.widthAnchor.constraint(equalToConstant: 16),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 6),
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -8),
            
            timeLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 6),
            timeLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            timeLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -8)
        ]
        
        if let locationLabel = locationLabel {
            constraints.append(contentsOf: [
                locationLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 6),
                locationLabel.topAnchor.constraint(equalTo: timeLabel.bottomAnchor, constant: 1),
                locationLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -8),
                locationLabel.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -4)
            ])
        } else {
            constraints.append(
                timeLabel.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -4)
            )
        }
        
        NSLayoutConstraint.activate(constraints)
        
        return container
    }
    
    private func updateCalendarIcon() {
        let today = Calendar.current.component(.day, from: Date())
        calendarIconLabel.stringValue = "\(today)"
        
        // Update text color based on event count for subtle indication
        if events.isEmpty {
            calendarIconLabel.textColor = NSColor.labelColor.withAlphaComponent(0.6)
        } else if events.count >= 1 {
            calendarIconLabel.textColor = NSColor.labelColor.withAlphaComponent(0.9)
        }
    }
    
    private func formatCurrentTime() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }
    
    private func updateStatus(_ status: String) {
        statusLabel.stringValue = status
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            if self?.statusLabel.stringValue == status {
                self?.statusLabel.stringValue = ""
            }
        }
    }
    
    // MARK: - Mouse Events & Dropdown (same pattern as other notches)
    
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
            print("📅 Click detected - hiding dropdown")
            hideDropdown()
        } else {
            print("📅 Click detected - showing dropdown") 
            showDropdown()
        }
    }
    
    private func isMouseInSafeZone(_ mouseLocation: NSPoint) -> Bool {
        guard let window = self.window else { return false }
        
        let iconFrame = calendarIconView.frame
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
        
        // Refresh events when showing
        if events.isEmpty || shouldRefreshEvents() {
            loadTodaysEvents()
        }
        
        positionDropdownWindow()
        dropdownWindow.orderFront(nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            dropdownWindow.animator().alphaValue = 1.0
            let scaleTransform = CATransform3DMakeScale(1.1, 1.1, 1.0)
            calendarIconView.layer?.transform = scaleTransform
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            self.dropdownWindow.makeKey()
            print("📅 Made calendar panel key window")
        }
        
        setupDropdownTracking()
        startGlobalMouseMonitoring()
        startGlobalClickMonitoring()
    }
    
    private func shouldRefreshEvents() -> Bool {
        // Always refresh if no events or if it's a new day
        return events.isEmpty || !Calendar.current.isDateInToday(events.first?.startDate ?? Date.distantPast)
    }
    
    private func hideDropdown() {
        guard isDropdownVisible else { return }
        isDropdownVisible = false
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            dropdownWindow.animator().alphaValue = 0.0
            calendarIconView.layer?.transform = CATransform3DIdentity
        }, completionHandler: { [weak self] in
            self?.dropdownWindow.orderOut(nil)
            self?.removeDropdownTracking()
            self?.stopGlobalMouseMonitoring()
            self?.stopGlobalClickMonitoring()
        })
    }
    
    private func positionDropdownWindow() {
        guard let window = self.window else { return }
        
        let iconFrame = calendarIconView.frame
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
            print("📅 Click detected outside calendar area - hiding dropdown")
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