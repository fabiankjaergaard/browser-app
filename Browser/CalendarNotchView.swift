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
    private var monthYearLabel: NSTextField!
    private var prevMonthButton: NSButton!
    private var nextMonthButton: NSButton!
    private var calendarGridView: NSView!
    private var dayLabels: [NSTextField] = []
    private var dayButtons: [NSButton] = []
    private var statusLabel: NSTextField!
    private var refreshButton: NSButton!
    private var addEventButton: NSButton!
    private var currentDisplayDate = Date()
    
    // State
    private var isDropdownVisible = false
    private var mouseExitTimer: Timer?
    private var globalMouseMonitor: Any?
    private var globalClickMonitor: Any?
    private var events: [CalendarEvent] = []
    private var isLoading = false
    
    // Calendar providers
    private var eventStore: EKEventStore!
    private var hasCalendarAccess = false
    private var calendarProvider: CalendarProvider = .apple
    private var providerButton: NSButton!
    
    enum CalendarProvider: String, CaseIterable {
        case apple = "Apple Calendar"
        case google = "Google Calendar"
        
        var icon: String {
            switch self {
            case .apple: return "calendar"
            case .google: return "globe"
            }
        }
    }
    
    // Constants
    private let dropdownWidth: CGFloat = 420
    private let dropdownHeight: CGFloat = 380
    
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
        
        // Header with month/year navigation
        setupCalendarHeader()
        
        // Calendar grid
        setupCalendarGrid()
        
        // Status label
        statusLabel = NSTextField(labelWithString: "")
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = NSFont.systemFont(ofSize: 9, weight: .regular)
        statusLabel.textColor = NSColor.tertiaryLabelColor
        statusLabel.alignment = .center
        
        // Add all subviews
        calendarContainer.addSubview(headerView)
        calendarContainer.addSubview(calendarGridView)
        calendarContainer.addSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            // Visual effect background
            visualEffect.topAnchor.constraint(equalTo: calendarContainer.topAnchor),
            visualEffect.leadingAnchor.constraint(equalTo: calendarContainer.leadingAnchor),
            visualEffect.trailingAnchor.constraint(equalTo: calendarContainer.trailingAnchor),
            visualEffect.bottomAnchor.constraint(equalTo: calendarContainer.bottomAnchor),
            
            // Header
            headerView.topAnchor.constraint(equalTo: calendarContainer.topAnchor, constant: 12),
            headerView.leadingAnchor.constraint(equalTo: calendarContainer.leadingAnchor, constant: 16),
            headerView.trailingAnchor.constraint(equalTo: calendarContainer.trailingAnchor, constant: -16),
            headerView.heightAnchor.constraint(equalToConstant: 60),
            
            // Calendar grid
            calendarGridView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 8),
            calendarGridView.leadingAnchor.constraint(equalTo: calendarContainer.leadingAnchor, constant: 16),
            calendarGridView.trailingAnchor.constraint(equalTo: calendarContainer.trailingAnchor, constant: -16),
            calendarGridView.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -8),
            
            // Status label
            statusLabel.leadingAnchor.constraint(equalTo: calendarContainer.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: calendarContainer.trailingAnchor, constant: -16),
            statusLabel.bottomAnchor.constraint(equalTo: calendarContainer.bottomAnchor, constant: -8),
            statusLabel.heightAnchor.constraint(equalToConstant: 12)
        ])
    }
    
    private func setupCalendarHeader() {
        headerView = NSView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        
        // Month/Year label
        monthYearLabel = NSTextField(labelWithString: formatMonthYear(currentDisplayDate))
        monthYearLabel.translatesAutoresizingMaskIntoConstraints = false
        monthYearLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        monthYearLabel.textColor = NSColor.labelColor
        monthYearLabel.alignment = .center
        
        // Previous month button
        prevMonthButton = NSButton()
        prevMonthButton.translatesAutoresizingMaskIntoConstraints = false
        prevMonthButton.image = NSImage(systemSymbolName: "chevron.left", accessibilityDescription: "Previous month")
        prevMonthButton.bezelStyle = .regularSquare
        prevMonthButton.isBordered = false
        prevMonthButton.target = self
        prevMonthButton.action = #selector(previousMonth)
        
        // Next month button
        nextMonthButton = NSButton()
        nextMonthButton.translatesAutoresizingMaskIntoConstraints = false
        nextMonthButton.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "Next month")
        nextMonthButton.bezelStyle = .regularSquare
        nextMonthButton.isBordered = false
        nextMonthButton.target = self
        nextMonthButton.action = #selector(nextMonth)
        
        // Provider toggle button
        providerButton = NSButton()
        providerButton.translatesAutoresizingMaskIntoConstraints = false
        providerButton.title = calendarProvider.rawValue
        providerButton.font = NSFont.systemFont(ofSize: 9, weight: .medium)
        providerButton.bezelStyle = .roundRect
        providerButton.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.1).cgColor
        providerButton.layer?.cornerRadius = 6
        providerButton.target = self
        providerButton.action = #selector(toggleProvider)
        providerButton.toolTip = "Switch calendar provider"
        
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
        
        headerView.addSubview(monthYearLabel)
        headerView.addSubview(prevMonthButton)
        headerView.addSubview(nextMonthButton)
        headerView.addSubview(providerButton)
        headerView.addSubview(refreshButton)
        headerView.addSubview(addEventButton)
        
        NSLayoutConstraint.activate([
            // Month/Year label - centered
            monthYearLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            monthYearLabel.topAnchor.constraint(equalTo: headerView.topAnchor),
            
            // Previous month button
            prevMonthButton.centerYAnchor.constraint(equalTo: monthYearLabel.centerYAnchor),
            prevMonthButton.trailingAnchor.constraint(equalTo: monthYearLabel.leadingAnchor, constant: -8),
            prevMonthButton.widthAnchor.constraint(equalToConstant: 20),
            prevMonthButton.heightAnchor.constraint(equalToConstant: 20),
            
            // Next month button
            nextMonthButton.centerYAnchor.constraint(equalTo: monthYearLabel.centerYAnchor),
            nextMonthButton.leadingAnchor.constraint(equalTo: monthYearLabel.trailingAnchor, constant: 8),
            nextMonthButton.widthAnchor.constraint(equalToConstant: 20),
            nextMonthButton.heightAnchor.constraint(equalToConstant: 20),
            
            // Provider button - bottom left
            providerButton.topAnchor.constraint(equalTo: monthYearLabel.bottomAnchor, constant: 8),
            providerButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            providerButton.heightAnchor.constraint(equalToConstant: 18),
            providerButton.widthAnchor.constraint(equalToConstant: 80),
            
            // Add event button - bottom right
            addEventButton.topAnchor.constraint(equalTo: monthYearLabel.bottomAnchor, constant: 8),
            addEventButton.trailingAnchor.constraint(equalTo: refreshButton.leadingAnchor, constant: -4),
            addEventButton.widthAnchor.constraint(equalToConstant: 20),
            addEventButton.heightAnchor.constraint(equalToConstant: 20),
            
            // Refresh button - bottom right
            refreshButton.topAnchor.constraint(equalTo: monthYearLabel.bottomAnchor, constant: 8),
            refreshButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            refreshButton.widthAnchor.constraint(equalToConstant: 20),
            refreshButton.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    private func setupCalendarGrid() {
        calendarGridView = NSView()
        calendarGridView.translatesAutoresizingMaskIntoConstraints = false
        calendarGridView.wantsLayer = true
        
        // Create day labels (Mon, Tue, Wed, etc.)
        let dayNames = ["M", "T", "W", "T", "F", "S", "S"]
        for i in 0..<7 {
            let dayLabel = NSTextField(labelWithString: dayNames[i])
            dayLabel.translatesAutoresizingMaskIntoConstraints = false
            dayLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
            dayLabel.textColor = NSColor.secondaryLabelColor
            dayLabel.alignment = .center
            dayLabels.append(dayLabel)
            calendarGridView.addSubview(dayLabel)
        }
        
        // Create day buttons (42 buttons for 6 rows × 7 days)
        for i in 0..<42 {
            let dayButton = NSButton()
            dayButton.translatesAutoresizingMaskIntoConstraints = false
            dayButton.title = ""
            dayButton.font = NSFont.systemFont(ofSize: 11, weight: .regular)
            dayButton.bezelStyle = .regularSquare
            dayButton.isBordered = false
            dayButton.target = self
            dayButton.action = #selector(dayButtonPressed(_:))
            dayButton.tag = i
            dayButton.wantsLayer = true
            dayButton.layer?.cornerRadius = 4
            dayButtons.append(dayButton)
            calendarGridView.addSubview(dayButton)
        }
        
        setupCalendarConstraints()
        updateCalendarDisplay()
    }
    
    private func setupCalendarConstraints() {
        var constraints: [NSLayoutConstraint] = []
        
        let cellWidth: CGFloat = 50
        let cellHeight: CGFloat = 36
        
        // Day labels constraints
        for (index, dayLabel) in dayLabels.enumerated() {
            constraints.append(contentsOf: [
                dayLabel.topAnchor.constraint(equalTo: calendarGridView.topAnchor),
                dayLabel.leadingAnchor.constraint(equalTo: calendarGridView.leadingAnchor, constant: CGFloat(index) * cellWidth),
                dayLabel.widthAnchor.constraint(equalToConstant: cellWidth),
                dayLabel.heightAnchor.constraint(equalToConstant: 20)
            ])
        }
        
        // Day buttons constraints
        for (index, dayButton) in dayButtons.enumerated() {
            let row = index / 7
            let col = index % 7
            
            constraints.append(contentsOf: [
                dayButton.topAnchor.constraint(equalTo: calendarGridView.topAnchor, constant: 24 + CGFloat(row) * cellHeight),
                dayButton.leadingAnchor.constraint(equalTo: calendarGridView.leadingAnchor, constant: CGFloat(col) * cellWidth),
                dayButton.widthAnchor.constraint(equalToConstant: cellWidth),
                dayButton.heightAnchor.constraint(equalToConstant: cellHeight)
            ])
        }
        
        NSLayoutConstraint.activate(constraints)
    }
    
    // MARK: - Calendar Logic
    
    @objc private func previousMonth() {
        currentDisplayDate = Calendar.current.date(byAdding: .month, value: -1, to: currentDisplayDate) ?? currentDisplayDate
        updateCalendarDisplay()
        loadTodaysEvents()
    }
    
    @objc private func nextMonth() {
        currentDisplayDate = Calendar.current.date(byAdding: .month, value: 1, to: currentDisplayDate) ?? currentDisplayDate
        updateCalendarDisplay()
        loadTodaysEvents()
    }
    
    @objc private func dayButtonPressed(_ sender: NSButton) {
        let dayIndex = sender.tag
        if let date = getDateForDayButton(dayIndex) {
            // Highlight selected day
            updateSelectedDay(dayIndex)
            print("📅 Selected date: \(date)")
        }
    }
    
    private func updateCalendarDisplay() {
        monthYearLabel.stringValue = formatMonthYear(currentDisplayDate)
        
        let calendar = Calendar.current
        let firstOfMonth = calendar.dateInterval(of: .month, for: currentDisplayDate)?.start ?? currentDisplayDate
        let weekdayOfFirst = calendar.component(.weekday, from: firstOfMonth)
        let startOffset = (weekdayOfFirst + 5) % 7 // Adjust for Monday start
        
        let daysInMonth = calendar.range(of: .day, in: .month, for: currentDisplayDate)?.count ?? 30
        let previousMonth = calendar.date(byAdding: .month, value: -1, to: currentDisplayDate) ?? currentDisplayDate
        let daysInPreviousMonth = calendar.range(of: .day, in: .month, for: previousMonth)?.count ?? 30
        
        // Update day buttons
        for (index, button) in dayButtons.enumerated() {
            button.layer?.backgroundColor = NSColor.clear.cgColor
            button.contentTintColor = NSColor.labelColor
            
            if index < startOffset {
                // Previous month days
                let day = daysInPreviousMonth - startOffset + index + 1
                button.title = "\(day)"
                button.contentTintColor = NSColor.tertiaryLabelColor
            } else if index < startOffset + daysInMonth {
                // Current month days
                let day = index - startOffset + 1
                button.title = "\(day)"
                button.contentTintColor = NSColor.labelColor
                
                // Highlight today
                if calendar.isDate(currentDisplayDate, equalTo: Date(), toGranularity: .month) {
                    let today = calendar.component(.day, from: Date())
                    if day == today {
                        button.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
                        button.contentTintColor = NSColor.white
                    }
                }
                
                // Show events indicator
                if hasEventsOnDay(day) {
                    addEventIndicator(to: button)
                }
            } else {
                // Next month days
                let day = index - startOffset - daysInMonth + 1
                button.title = "\(day)"
                button.contentTintColor = NSColor.tertiaryLabelColor
            }
        }
    }
    
    private func updateSelectedDay(_ dayIndex: Int) {
        // Reset all day buttons
        for button in dayButtons {
            if button.layer?.backgroundColor != NSColor.controlAccentColor.cgColor {
                button.layer?.backgroundColor = NSColor.clear.cgColor
            }
        }
        
        // Highlight selected day (unless it's today)
        let selectedButton = dayButtons[dayIndex]
        if selectedButton.layer?.backgroundColor != NSColor.controlAccentColor.cgColor {
            selectedButton.layer?.backgroundColor = NSColor.secondarySystemFill.cgColor
        }
    }
    
    private func getDateForDayButton(_ dayIndex: Int) -> Date? {
        let calendar = Calendar.current
        let firstOfMonth = calendar.dateInterval(of: .month, for: currentDisplayDate)?.start ?? currentDisplayDate
        let weekdayOfFirst = calendar.component(.weekday, from: firstOfMonth)
        let startOffset = (weekdayOfFirst + 5) % 7
        
        if dayIndex >= startOffset {
            let daysInMonth = calendar.range(of: .day, in: .month, for: currentDisplayDate)?.count ?? 30
            if dayIndex < startOffset + daysInMonth {
                let day = dayIndex - startOffset + 1
                return calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth)
            }
        }
        return nil
    }
    
    private func hasEventsOnDay(_ day: Int) -> Bool {
        let calendar = Calendar.current
        let firstOfMonth = calendar.dateInterval(of: .month, for: currentDisplayDate)?.start ?? currentDisplayDate
        guard let dayDate = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) else { return false }
        
        return events.contains { event in
            calendar.isDate(event.startDate, inSameDayAs: dayDate)
        }
    }
    
    private func addEventIndicator(to button: NSButton) {
        // Add small dot to indicate events
        let indicator = NSView()
        indicator.wantsLayer = true
        indicator.layer?.backgroundColor = NSColor.systemOrange.cgColor
        indicator.layer?.cornerRadius = 2
        indicator.translatesAutoresizingMaskIntoConstraints = false
        
        button.addSubview(indicator)
        NSLayoutConstraint.activate([
            indicator.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -4),
            indicator.topAnchor.constraint(equalTo: button.topAnchor, constant: 4),
            indicator.widthAnchor.constraint(equalToConstant: 4),
            indicator.heightAnchor.constraint(equalToConstant: 4)
        ])
    }
    
    private func formatMonthYear(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
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
    
    @objc private func toggleProvider() {
        // Switch between Apple and Google Calendar
        calendarProvider = calendarProvider == .apple ? .google : .apple
        providerButton.title = calendarProvider.rawValue
        
        print("📅 Switched to \(calendarProvider.rawValue)")
        
        // Clear current events and reload
        events = []
        updateCalendarDisplay()
        loadTodaysEvents()
    }
    
    @objc private func addEventPressed() {
        delegate?.calendarNotchDidRequestEventCreation()
        
        switch calendarProvider {
        case .apple:
            // Open Apple Calendar
            if let calendarApp = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
                NSWorkspace.shared.open(calendarApp)
            }
        case .google:
            // Open Google Calendar in browser
            if let googleCalendarURL = URL(string: "https://calendar.google.com/calendar/u/0/r/eventedit") {
                NSWorkspace.shared.open(googleCalendarURL)
            }
        }
    }
    
    private func loadTodaysEvents() {
        guard !isLoading else { return }
        
        switch calendarProvider {
        case .apple:
            loadAppleCalendarEvents()
        case .google:
            loadGoogleCalendarEvents()
        }
    }
    
    private func loadAppleCalendarEvents() {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined:
            requestCalendarAccess()
            return
        case .denied, .restricted:
            events = []
            updateCalendarDisplay()
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
        
        // Load events for the entire displayed month
        let calendar = Calendar.current
        let monthInterval = calendar.dateInterval(of: .month, for: currentDisplayDate)!
        
        let predicate = eventStore.predicateForEvents(withStart: monthInterval.start, end: monthInterval.end, calendars: nil)
        let ekEvents = eventStore.events(matching: predicate)
        
        // Convert EKEvents to CalendarEvents
        events = ekEvents.map { ekEvent in
            CalendarEvent(
                title: ekEvent.title ?? "Untitled Event",
                startDate: ekEvent.startDate,
                endDate: ekEvent.endDate,
                isAllDay: ekEvent.isAllDay,
                calendar: ekEvent.calendar?.title ?? "Apple Calendar",
                location: ekEvent.location
            )
        }.sorted { $0.startDate < $1.startDate }
        
        isLoading = false
        refreshButton.isEnabled = true
        updateCalendarDisplay()
        updateCalendarIcon()
        delegate?.calendarNotchDidUpdateEvents(events)
        updateStatus("Updated \(formatCurrentTime())")
        
        print("📅 Loaded \(events.count) Apple Calendar events for \(formatMonthYear(currentDisplayDate))")
    }
    
    private func loadGoogleCalendarEvents() {
        isLoading = true
        updateStatus("Loading Google Calendar...")
        refreshButton.isEnabled = false
        
        // For now, create sample events distributed across the month
        // In a real implementation, you would use Google Calendar API
        let calendar = Calendar.current
        let monthInterval = calendar.dateInterval(of: .month, for: currentDisplayDate)!
        
        var sampleEvents: [CalendarEvent] = []
        
        // Add a few sample events throughout the month
        if let midMonth = calendar.date(byAdding: .day, value: 15, to: monthInterval.start) {
            sampleEvents.append(CalendarEvent(
                title: "Google Meet",
                startDate: midMonth,
                endDate: calendar.date(byAdding: .hour, value: 1, to: midMonth)!,
                isAllDay: false,
                calendar: "Google Calendar",
                location: "Online"
            ))
        }
        
        if let laterInMonth = calendar.date(byAdding: .day, value: 22, to: monthInterval.start) {
            sampleEvents.append(CalendarEvent(
                title: "Project Deadline",
                startDate: laterInMonth,
                endDate: laterInMonth,
                isAllDay: true,
                calendar: "Google Calendar",
                location: nil
            ))
        }
        
        events = sampleEvents
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isLoading = false
            self?.refreshButton.isEnabled = true
            self?.updateCalendarDisplay()
            self?.updateCalendarIcon()
            self?.delegate?.calendarNotchDidUpdateEvents(self?.events ?? [])
            self?.updateStatus("Google Calendar - click '+' to add events")
            print("📅 Google Calendar mode - showing sample events")
        }
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
        // Always refresh if no events or if it's a new month
        return events.isEmpty || !Calendar.current.isDate(currentDisplayDate, equalTo: Date(), toGranularity: .month)
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