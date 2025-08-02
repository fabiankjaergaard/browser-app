import Cocoa

protocol TodoNotchViewDelegate: AnyObject {
    func todoNotchDidUpdateTodos(_ todos: [TodoItem])
    func todoNotchDidRequestKeyboardShortcut()
}

struct TodoItem: Codable {
    var id: UUID
    var text: String
    var isCompleted: Bool
    var createdAt: Date
    
    init(text: String) {
        self.id = UUID()
        self.text = text
        self.isCompleted = false
        self.createdAt = Date()
    }
}

class TodoNotchView: NSView {
    
    weak var delegate: TodoNotchViewDelegate?
    weak var contentViewController: ContentViewController?
    
    // UI Components
    private var todoIconView: NSView!
    private var todoIconLabel: NSTextField!
    private var dropdownWindow: KeyablePanel!
    private var todoContainer: NSView!
    private var headerView: NSView!
    private var todoScrollView: NSScrollView!
    private var todoTableView: NSTableView!
    private var addTodoField: NSTextField!
    private var addButton: NSButton!
    private var statusLabel: NSTextField!
    
    // State
    private var isDropdownVisible = false
    private var mouseExitTimer: Timer?
    private var autoSaveTimer: Timer?
    private var globalMouseMonitor: Any?
    private var globalClickMonitor: Any?
    private var isTextFieldFocused = false
    private var todos: [TodoItem] = []
    
    // Constants
    private let dropdownWidth: CGFloat = 300
    private let dropdownHeight: CGFloat = 320
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
        loadSavedTodos()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView() 
        loadSavedTodos()
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        
        setupTodoIcon()
        setupDropdownWindow()
        setupLayout()
        setupTrackingArea()
    }
    
    private func setupTodoIcon() {
        todoIconView = NSView()
        todoIconView.translatesAutoresizingMaskIntoConstraints = false
        todoIconView.wantsLayer = true
        todoIconView.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.8).cgColor
        todoIconView.layer?.cornerRadius = 6
        todoIconView.layer?.borderWidth = 1
        todoIconView.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.3).cgColor
        
        // Modern minimal shadow
        todoIconView.shadow = NSShadow()
        todoIconView.shadow?.shadowOffset = NSSize(width: 0, height: 1)
        todoIconView.shadow?.shadowBlurRadius = 2
        todoIconView.shadow?.shadowColor = NSColor.black.withAlphaComponent(0.05)
        
        todoIconLabel = NSTextField(labelWithString: "✓")
        todoIconLabel.translatesAutoresizingMaskIntoConstraints = false
        todoIconLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        todoIconLabel.textColor = NSColor.labelColor.withAlphaComponent(0.8)
        todoIconLabel.alignment = .center
        
        todoIconView.addSubview(todoIconLabel)
        addSubview(todoIconView)
    }
    
    private func setupDropdownWindow() {
        // Create a borderless panel that acts as dropdown
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
        
        // Setup the content view with todo list
        setupTodoContainer()
        dropdownWindow.contentView = todoContainer
        
        // Initially hidden
        dropdownWindow.alphaValue = 0
    }
    
    private func setupTodoContainer() {
        todoContainer = NSView()
        todoContainer.wantsLayer = true
        
        // Modern frosted glass effect
        let visualEffect = NSVisualEffectView()
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 12
        visualEffect.translatesAutoresizingMaskIntoConstraints = false
        
        todoContainer.addSubview(visualEffect)
        
        // Header with title
        let headerLabel = NSTextField(labelWithString: "Todo List")
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        headerLabel.textColor = NSColor.labelColor
        
        // Setup todo table view
        setupTodoTableView()
        
        // Add todo field and button
        setupAddTodoControls()
        
        // Status label
        statusLabel = NSTextField(labelWithString: "")
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        statusLabel.textColor = NSColor.secondaryLabelColor
        
        // Add all subviews
        todoContainer.addSubview(headerLabel)
        todoContainer.addSubview(todoScrollView)
        todoContainer.addSubview(addTodoField)
        todoContainer.addSubview(addButton)
        todoContainer.addSubview(statusLabel)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            // Visual effect background
            visualEffect.topAnchor.constraint(equalTo: todoContainer.topAnchor),
            visualEffect.leadingAnchor.constraint(equalTo: todoContainer.leadingAnchor),
            visualEffect.trailingAnchor.constraint(equalTo: todoContainer.trailingAnchor),
            visualEffect.bottomAnchor.constraint(equalTo: todoContainer.bottomAnchor),
            
            // Header
            headerLabel.topAnchor.constraint(equalTo: todoContainer.topAnchor, constant: 12),
            headerLabel.leadingAnchor.constraint(equalTo: todoContainer.leadingAnchor, constant: 16),
            
            // Todo table view
            todoScrollView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 8),
            todoScrollView.leadingAnchor.constraint(equalTo: todoContainer.leadingAnchor, constant: 16),
            todoScrollView.trailingAnchor.constraint(equalTo: todoContainer.trailingAnchor, constant: -16),
            todoScrollView.bottomAnchor.constraint(equalTo: addTodoField.topAnchor, constant: -8),
            
            // Add todo field
            addTodoField.leadingAnchor.constraint(equalTo: todoContainer.leadingAnchor, constant: 16),
            addTodoField.trailingAnchor.constraint(equalTo: addButton.leadingAnchor, constant: -8),
            addTodoField.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -8),
            addTodoField.heightAnchor.constraint(equalToConstant: 24),
            
            // Add button
            addButton.trailingAnchor.constraint(equalTo: todoContainer.trailingAnchor, constant: -16),
            addButton.centerYAnchor.constraint(equalTo: addTodoField.centerYAnchor),
            addButton.widthAnchor.constraint(equalToConstant: 30),
            addButton.heightAnchor.constraint(equalToConstant: 24),
            
            // Status label
            statusLabel.leadingAnchor.constraint(equalTo: todoContainer.leadingAnchor, constant: 16),
            statusLabel.bottomAnchor.constraint(equalTo: todoContainer.bottomAnchor, constant: -12)
        ])
    }
    
    private func setupTodoTableView() {
        todoScrollView = NSScrollView()
        todoScrollView.translatesAutoresizingMaskIntoConstraints = false
        todoScrollView.hasVerticalScroller = true
        todoScrollView.hasHorizontalScroller = false
        todoScrollView.autohidesScrollers = true
        todoScrollView.borderType = .noBorder
        todoScrollView.drawsBackground = false
        
        todoTableView = NSTableView()
        todoTableView.backgroundColor = NSColor.clear
        todoTableView.delegate = self
        todoTableView.dataSource = self
        todoTableView.headerView = nil
        todoTableView.intercellSpacing = NSSize(width: 0, height: 2)
        todoTableView.rowHeight = 24
        
        // Add column
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("TodoColumn"))
        column.title = "Todo"
        column.minWidth = 200
        todoTableView.addTableColumn(column)
        
        todoScrollView.documentView = todoTableView
    }
    
    private func setupAddTodoControls() {
        addTodoField = NSTextField()
        addTodoField.translatesAutoresizingMaskIntoConstraints = false
        addTodoField.placeholderString = "Add new todo..."
        addTodoField.font = NSFont.systemFont(ofSize: 12)
        addTodoField.delegate = self
        addTodoField.target = self
        addTodoField.action = #selector(addTodoPressed)
        
        addButton = NSButton()
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.title = "+"
        addButton.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        addButton.bezelStyle = .regularSquare
        addButton.isBordered = true
        addButton.target = self
        addButton.action = #selector(addTodoPressed)
    }
    
    private func setupLayout() {
        NSLayoutConstraint.activate([
            // Todo icon view - always visible, small and centered
            todoIconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            todoIconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            todoIconView.widthAnchor.constraint(equalToConstant: 24),
            todoIconView.heightAnchor.constraint(equalToConstant: 24),
            
            // Todo icon label - centered in icon view
            todoIconLabel.centerXAnchor.constraint(equalTo: todoIconView.centerXAnchor),
            todoIconLabel.centerYAnchor.constraint(equalTo: todoIconView.centerYAnchor)
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
            if !isTextFieldFocused {
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
            print("📝 Click detected - hiding dropdown")
            hideDropdown()
        } else {
            print("📝 Click detected - showing dropdown")
            showDropdown()
        }
    }
    
    private func isMouseInSafeZone(_ mouseLocation: NSPoint) -> Bool {
        guard let window = self.window else { return false }
        
        // Get icon bounds in screen coordinates
        let iconFrame = todoIconView.frame
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
        
        // Position dropdown below the todo icon
        positionDropdownWindow()
        
        // Show dropdown
        dropdownWindow.orderFront(nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            
            // Animate dropdown in with fade
            dropdownWindow.animator().alphaValue = 1.0
            
            // Subtle scale effect on todo icon
            let scaleTransform = CATransform3DMakeScale(1.1, 1.1, 1.0)
            todoIconView.layer?.transform = scaleTransform
        }
        
        // Make dropdown key window for input
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            self.dropdownWindow.makeKey()
            print("✓ Made todo panel key window")
        }
        
        // Add tracking to dropdown window and start global monitoring
        setupDropdownTracking()
        startGlobalMouseMonitoring()
        startGlobalClickMonitoring()
    }
    
    private func hideDropdown() {
        guard isDropdownVisible else { return }
        isDropdownVisible = false
        
        // Save todos before hiding
        saveTodos()
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            
            // Animate dropdown out
            dropdownWindow.animator().alphaValue = 0.0
            
            // Reset todo icon scale
            todoIconView.layer?.transform = CATransform3DIdentity
            
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
        
        let iconFrame = todoIconView.frame
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
            print("✓ Click detected outside todo area - hiding dropdown")
            hideDropdown()
        }
    }
    
    private func handleGlobalMouseMove(_ event: NSEvent) {
        // Simplified - no longer needed for immediate hiding
    }
    
    // MARK: - Todo Management
    
    @objc private func addTodoPressed() {
        let text = addTodoField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !text.isEmpty else { return }
        
        let newTodo = TodoItem(text: text)
        todos.append(newTodo)
        
        // Clear the field
        addTodoField.stringValue = ""
        
        // Refresh table
        todoTableView.reloadData()
        
        // Auto-save and update status
        saveTodos()
        updateStatus("Added todo")
        updateTodoIcon()
        
        // Focus back to text field for quick entry
        DispatchQueue.main.async { [weak self] in
            self?.dropdownWindow.makeFirstResponder(self?.addTodoField)
        }
    }
    
    private func toggleTodo(at index: Int) {
        guard index < todos.count else { return }
        
        todos[index].isCompleted.toggle()
        todoTableView.reloadData(forRowIndexes: IndexSet(integer: index), columnIndexes: IndexSet(integer: 0))
        
        saveTodos()
        updateStatus(todos[index].isCompleted ? "Todo completed" : "Todo uncompleted")
        updateTodoIcon()
    }
    
    private func deleteTodo(at index: Int) {
        guard index < todos.count else { return }
        
        todos.remove(at: index)
        todoTableView.removeRows(at: IndexSet(integer: index), withAnimation: .slideUp)
        
        saveTodos()
        updateStatus("Todo deleted")
        updateTodoIcon()
    }
    
    private func loadSavedTodos() {
        if let data = UserDefaults.standard.data(forKey: "TodoList"),
           let savedTodos = try? JSONDecoder().decode([TodoItem].self, from: data) {
            todos = savedTodos
            todoTableView?.reloadData()
            updateTodoIcon()
            updateStatus("Loaded todos")
        }
    }
    
    private func saveTodos() {
        if let data = try? JSONEncoder().encode(todos) {
            UserDefaults.standard.set(data, forKey: "TodoList")
            delegate?.todoNotchDidUpdateTodos(todos)
        }
    }
    
    private func updateTodoIcon() {
        let completedCount = todos.filter { $0.isCompleted }.count
        let totalCount = todos.count
        
        if totalCount == 0 {
            todoIconLabel.stringValue = "✓"
            todoIconLabel.textColor = NSColor.labelColor.withAlphaComponent(0.6)
        } else if completedCount == totalCount {
            todoIconLabel.stringValue = "✓"
            todoIconLabel.textColor = NSColor.systemGreen.withAlphaComponent(0.9)
        } else {
            todoIconLabel.stringValue = "\(totalCount - completedCount)"
            todoIconLabel.textColor = NSColor.labelColor.withAlphaComponent(0.9)
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

// MARK: - NSTableViewDataSource
extension TodoNotchView: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return todos.count
    }
}

// MARK: - NSTableViewDelegate
extension TodoNotchView: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < todos.count else { return nil }
        
        let todo = todos[row]
        let cellView = NSView()
        cellView.wantsLayer = true
        
        // Checkbox
        let checkbox = NSButton()
        checkbox.setButtonType(.switch)
        checkbox.state = todo.isCompleted ? .on : .off
        checkbox.target = self
        checkbox.action = #selector(checkboxToggled(_:))
        checkbox.tag = row
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        
        // Text label
        let textLabel = NSTextField(labelWithString: todo.text)
        textLabel.font = NSFont.systemFont(ofSize: 12)
        textLabel.textColor = todo.isCompleted ? NSColor.secondaryLabelColor : NSColor.labelColor
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        
        if todo.isCompleted {
            textLabel.attributedStringValue = NSAttributedString(
                string: todo.text,
                attributes: [.strikethroughStyle: NSUnderlineStyle.single.rawValue]
            )
        }
        
        // Delete button
        let deleteButton = NSButton()
        deleteButton.image = NSImage(systemSymbolName: "trash", accessibilityDescription: "Delete")
        deleteButton.bezelStyle = .regularSquare
        deleteButton.isBordered = false
        deleteButton.target = self
        deleteButton.action = #selector(deleteButtonPressed(_:))
        deleteButton.tag = row
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        
        cellView.addSubview(checkbox)
        cellView.addSubview(textLabel)
        cellView.addSubview(deleteButton)
        
        NSLayoutConstraint.activate([
            checkbox.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
            checkbox.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
            
            textLabel.leadingAnchor.constraint(equalTo: checkbox.trailingAnchor, constant: 8),
            textLabel.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
            textLabel.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -8),
            
            deleteButton.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -4),
            deleteButton.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
            deleteButton.widthAnchor.constraint(equalToConstant: 20),
            deleteButton.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        return cellView
    }
    
    @objc private func checkboxToggled(_ sender: NSButton) {
        toggleTodo(at: sender.tag)
    }
    
    @objc private func deleteButtonPressed(_ sender: NSButton) {
        deleteTodo(at: sender.tag)
    }
}

// MARK: - NSTextFieldDelegate
extension TodoNotchView: NSTextFieldDelegate {
    func controlTextDidBeginEditing(_ obj: Notification) {
        isTextFieldFocused = true
        // Cancel any pending hide while user is typing
        mouseExitTimer?.invalidate()
        print("✓ Started editing todo field - preventing auto-hide")
    }
    
    func controlTextDidEndEditing(_ obj: Notification) {
        isTextFieldFocused = false
        print("✓ Finished editing todo field - re-enabling auto-hide")
    }
}