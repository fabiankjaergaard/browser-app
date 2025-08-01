import Cocoa

class TabBarView: NSView {
    
    private var tabViews: [TabItemView] = []
    private var stackView: NSStackView!
    private var addButton: NSButton!
    
    override func mouseDown(with event: NSEvent) {
        print("📍 TabBarView mouseDown - event should reach TabItemView instead")
        super.mouseDown(with: event)
    }
    
    override func mouseDragged(with event: NSEvent) {
        print("📍 TabBarView mouseDragged - event should reach TabItemView instead")
        super.mouseDragged(with: event)
    }
    
    override var mouseDownCanMoveWindow: Bool {
        print("📍 TabBarView mouseDownCanMoveWindow called")
        return true // Allow window dragging from empty areas of tab bar
    }
    
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
        layer?.backgroundColor = ColorManager.secondaryBackground.cgColor
        
        // Add subtle bottom border
        let borderLayer = CALayer()
        borderLayer.backgroundColor = ColorManager.primaryBorder.cgColor
        borderLayer.frame = CGRect(x: 0, y: 0, width: 2000, height: 1)
        layer?.addSublayer(borderLayer)
        
        // Create stack view for tabs
        stackView = NSStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .horizontal
        stackView.spacing = 1
        stackView.distribution = .fillProportionally
        stackView.alignment = .centerY
        
        // Create add button with modern styling
        addButton = NSButton(image: NSImage(systemSymbolName: "plus", accessibilityDescription: "New Tab")!, target: self, action: #selector(addNewTab))
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.bezelStyle = .regularSquare
        addButton.isBordered = false
        addButton.contentTintColor = ColorManager.tertiaryText
        addButton.toolTip = "Open a new tab"
        addButton.wantsLayer = true
        
        // Add modern button styling with hover effect
        if let buttonLayer = addButton.layer {
            buttonLayer.cornerRadius = 6
            buttonLayer.backgroundColor = NSColor.clear.cgColor
        }
        
        addSubview(stackView)
        addSubview(addButton)
        
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            
            addButton.leadingAnchor.constraint(equalTo: stackView.trailingAnchor, constant: 4),
            addButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            addButton.widthAnchor.constraint(equalToConstant: 28),
            addButton.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -4)
        ])
        
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleTabCreated(_:)), name: .tabCreated, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleTabClosed(_:)), name: .tabClosed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleTabSelected(_:)), name: .tabSelected, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleTabUpdated(_:)), name: .tabUpdated, object: nil)
    }
    
    @objc private func addNewTab() {
        NotificationCenter.default.post(name: .showQuickSearch, object: nil)
    }
    
    @objc private func handleTabCreated(_ notification: Notification) {
        refreshTabs()
    }
    
    @objc private func handleTabClosed(_ notification: Notification) {
        refreshTabs()
    }
    
    @objc private func handleTabSelected(_ notification: Notification) {
        guard let selectedTab = notification.object as? Tab else { return }
        updateTabSelection(selectedTab)
    }
    
    @objc private func handleTabUpdated(_ notification: Notification) {
        guard let tab = notification.object as? Tab,
              let tabView = tabViews.first(where: { $0.tab.id == tab.id }) else { return }
        tabView.updateTitle(tab.title)
        tabView.updateFavicon(tab.favicon)
    }
    
    private func refreshTabs() {
        print("🔄 Starting refreshTabs()")
        
        // Remove all existing tab views
        tabViews.forEach { $0.removeFromSuperview() }
        tabViews.removeAll()
        
        // Add tabs from active space
        if let activeSpace = TabManager.shared.activeSpace {
            print("📱 Active space found with \(activeSpace.tabs.count) tabs")
            for (index, tab) in activeSpace.tabs.enumerated() {
                print("🏭 Creating TabItemView \(index + 1)/\(activeSpace.tabs.count) for: \(tab.title)")
                let tabView = TabItemView(tab: tab)
                tabView.delegate = self
                tabView.updateFavicon(tab.favicon) // Set initial favicon
                tabViews.append(tabView)
                stackView.addArrangedSubview(tabView)
                print("📍 Added TabItemView for: \(tab.title), frame: \(tabView.frame)")
            }
        } else {
            print("❌ No active space found")
        }
        
        print("✅ refreshTabs() completed - total TabItemViews: \(tabViews.count)")
        
        // Update selection
        if let activeTab = TabManager.shared.activeTab {
            updateTabSelection(activeTab)
        }
    }
    
    private func updateTabSelection(_ selectedTab: Tab) {
        tabViews.forEach { tabView in
            tabView.isSelected = tabView.tab.id == selectedTab.id
        }
    }
}

// MARK: - TabItemViewDelegate
extension TabBarView: TabItemViewDelegate {
    func tabItemViewDidClick(_ tabItemView: TabItemView) {
        TabManager.shared.switchToTab(tabItemView.tab)
    }
    
    func tabItemViewDidClickClose(_ tabItemView: TabItemView) {
        TabManager.shared.closeTab(tabItemView.tab)
    }
}

// MARK: - Tab Item View
protocol TabItemViewDelegate: AnyObject {
    func tabItemViewDidClick(_ tabItemView: TabItemView)
    func tabItemViewDidClickClose(_ tabItemView: TabItemView)
}

class TabItemView: NSView, NSDraggingSource {
    let tab: Tab
    weak var delegate: TabItemViewDelegate?
    
    private var titleLabel: NSTextField!
    private var closeButton: NSButton!
    private var faviconImageView: NSImageView!
    private var trackingArea: NSTrackingArea?
    
    var isSelected: Bool = false {
        didSet {
            updateAppearance()
        }
    }
    
    init(tab: Tab) {
        self.tab = tab
        super.init(frame: NSRect(x: 0, y: 0, width: 200, height: 32))
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.shadowColor = ColorManager.lightShadow.cgColor
        layer?.shadowOpacity = 0.8
        layer?.shadowOffset = CGSize(width: 0, height: 1)
        layer?.shadowRadius = 4
        
        // Enable mouse events for dragging
        print("🔧 Setting up TabItemView for: \(tab.title)")
        
        // Favicon
        faviconImageView = NSImageView()
        faviconImageView.translatesAutoresizingMaskIntoConstraints = false
        faviconImageView.imageScaling = .scaleProportionallyUpOrDown
        faviconImageView.image = NSImage(systemSymbolName: "globe", accessibilityDescription: "Website")
        faviconImageView.contentTintColor = ColorManager.tertiaryText
        
        // Disable mouse events on favicon so TabItemView gets them
        faviconImageView.isEnabled = false
        
        // Title label
        titleLabel = NSTextField(labelWithString: tab.title)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.font = NSFont.systemFont(ofSize: 12)
        
        // Disable mouse events on label so TabItemView gets them
        titleLabel.isEnabled = false
        
        // Close button
        closeButton = NSButton(image: NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close Tab")!, target: self, action: #selector(closeTab))
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.bezelStyle = .regularSquare
        closeButton.isBordered = false
        closeButton.imageScaling = .scaleProportionallyDown
        closeButton.contentTintColor = ColorManager.tertiaryText
        closeButton.isHidden = true
        closeButton.wantsLayer = true
        
        // Add modern close button styling
        if let closeLayer = closeButton.layer {
            closeLayer.cornerRadius = 8
            closeLayer.backgroundColor = NSColor.clear.cgColor
        }
        
        addSubview(faviconImageView)
        addSubview(titleLabel)
        addSubview(closeButton)
        
        NSLayoutConstraint.activate([
            widthAnchor.constraint(greaterThanOrEqualToConstant: 120),
            widthAnchor.constraint(lessThanOrEqualToConstant: 200),
            
            faviconImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            faviconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            faviconImageView.widthAnchor.constraint(equalToConstant: 16),
            faviconImageView.heightAnchor.constraint(equalToConstant: 16),
            
            titleLabel.leadingAnchor.constraint(equalTo: faviconImageView.trailingAnchor, constant: 6),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -4),
            
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            closeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 16),
            closeButton.heightAnchor.constraint(equalToConstant: 16)
        ])
        
        updateAppearance()
    }
    
    private func updateAppearance() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.allowsImplicitAnimation = true
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            
            if isSelected {
                // Active tab styling with modern appearance
                layer?.backgroundColor = ColorManager.activeTab.cgColor
                layer?.cornerRadius = 8
                layer?.borderWidth = 1
                layer?.borderColor = ColorManager.primaryBorder.cgColor
                layer?.shadowColor = ColorManager.mediumShadow.cgColor
                layer?.shadowOpacity = 1.0
                layer?.shadowOffset = CGSize(width: 0, height: 2)
                layer?.shadowRadius = 6
                titleLabel.textColor = ColorManager.primaryText
                
                // Subtle scale effect for active tab using layer transform
                layer?.transform = CATransform3DMakeScale(1.02, 1.02, 1.0)
            } else {
                // Inactive tab styling
                layer?.backgroundColor = ColorManager.inactiveTab.cgColor
                layer?.cornerRadius = 8
                layer?.borderWidth = 0
                layer?.shadowOpacity = 0
                titleLabel.textColor = ColorManager.tertiaryText
                
                // Reset transform
                layer?.transform = CATransform3DIdentity
            }
        }
    }
    
    func updateTitle(_ title: String) {
        titleLabel.stringValue = title
    }
    
    func updateFavicon(_ favicon: NSImage?) {
        if let favicon = favicon {
            faviconImageView.image = favicon
            faviconImageView.contentTintColor = nil
        } else {
            faviconImageView.image = NSImage(systemSymbolName: "globe", accessibilityDescription: "Website")
            faviconImageView.contentTintColor = ColorManager.tertiaryText
        }
    }
    
    @objc private func closeTab() {
        delegate?.tabItemViewDidClickClose(self)
    }
    
    private var dragStartPoint: NSPoint?
    private var isDragInProgress = false
    
    override func mouseDown(with event: NSEvent) {
        dragStartPoint = convert(event.locationInWindow, from: nil)
        isDragInProgress = false
        print("🐭 TabItemView mouseDown: \(tab.title) at point: \(dragStartPoint ?? .zero)")
        
        // Don't call delegate click immediately - wait to see if this becomes a drag
        // We'll call it in mouseUp if it wasn't a drag
    }
    
    override func mouseDragged(with event: NSEvent) {
        print("🎯 TabItemView mouseDragged: \(tab.title)")
        
        guard let startPoint = dragStartPoint, !isDragInProgress else {
            print("❌ No start point or drag already in progress")
            return
        }
        
        let currentPoint = convert(event.locationInWindow, from: nil)
        let distance = sqrt(pow(currentPoint.x - startPoint.x, 2) + pow(currentPoint.y - startPoint.y, 2))
        
        print("📏 Drag distance: \(distance) pixels")
        
        // Start dragging if we've moved more than 3 pixels (lower threshold)
        if distance > 3 {
            print("🎯 Starting drag operation for tab: \(tab.title)")
            isDragInProgress = true
            startDragOperation(with: event)
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        print("🐭 TabItemView mouseUp: \(tab.title), was dragging: \(isDragInProgress)")
        
        // If we weren't dragging, treat this as a click
        if !isDragInProgress {
            delegate?.tabItemViewDidClick(self)
        }
        
        dragStartPoint = nil
        isDragInProgress = false
    }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        // Allow immediate interaction without needing to focus the window first
        return true
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        // Make sure this view gets the mouse events instead of parent views
        let result = super.hitTest(point)
        print("🎯 TabItemView hitTest: \(tab.title), point: \(point), result: \(result?.className ?? "nil")")
        return result
    }
    
    override var mouseDownCanMoveWindow: Bool {
        // Prevent this view from allowing window dragging
        print("🚫 mouseDownCanMoveWindow called for: \(tab.title) - returning false")
        return false
    }
    
    private func startDragOperation(with event: NSEvent) {
        guard let url = tab.url else {
            print("❌ No URL for tab: \(tab.title)")
            return
        }
        
        print("🚀 Creating drag data for: \(tab.title) -> \(url.absoluteString)")
        
        // Create drag data
        let dragData = [
            "tab_id": tab.id.uuidString,
            "tab_title": tab.title,
            "tab_url": url.absoluteString
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: dragData),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("❌ Failed to create JSON data")
            return
        }
        
        print("📦 Drag data JSON: \(jsonString)")
        
        // Create pasteboard item
        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(jsonString, forType: NSPasteboard.PasteboardType("BrowserTab"))
        pasteboardItem.setString(jsonString, forType: .string)  // Fallback for compatibility
        
        // Create drag image (small version of the tab)
        let dragImage = createDragImage()
        print("🖼️ Created drag image: \(dragImage.size)")
        
        // Create dragging item
        let dragItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
        
        // Set the dragging frame and image components
        let dragFrame = NSRect(origin: NSPoint(x: bounds.midX - dragImage.size.width / 2,
                                              y: bounds.midY - dragImage.size.height / 2),
                              size: dragImage.size)
        dragItem.draggingFrame = dragFrame
        
        // Set the drag image components
        let imageComponent = NSDraggingImageComponent(key: .icon)
        imageComponent.contents = dragImage
        imageComponent.frame = NSRect(origin: NSPoint.zero, size: dragImage.size)
        dragItem.imageComponentsProvider = {
            print("🎨 Providing image components")
            return [imageComponent]
        }
        
        print("🎬 Beginning dragging session...")
        // Begin the dragging session
        beginDraggingSession(with: [dragItem], event: event, source: self)
    }
    
    private func createDragImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 60, height: 20))
        image.lockFocus()
        
        // Draw a simplified version of the tab
        let rect = NSRect(x: 0, y: 0, width: 60, height: 20)
        NSColor.systemGray.set()
        rect.fill()
        
        // Draw favicon if available
        if let favicon = tab.favicon {
            favicon.draw(in: NSRect(x: 4, y: 2, width: 16, height: 16))
        }
        
        // Draw title
        let title = String(tab.title.prefix(6))
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.labelColor
        ]
        (title as NSString).draw(in: NSRect(x: 22, y: 4, width: 35, height: 12), withAttributes: attributes)
        
        image.unlockFocus()
        return image
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        
        if let trackingArea = trackingArea {
            addTrackingArea(trackingArea)
        }
    }
    
    override func mouseEntered(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            closeButton.animator().isHidden = false
            
            if !isSelected {
                layer?.backgroundColor = ColorManager.tabHover.cgColor
                titleLabel.textColor = ColorManager.secondaryText
                
                // Subtle lift effect on hover
                layer?.shadowColor = ColorManager.lightShadow.cgColor
                layer?.shadowOpacity = 0.5
                layer?.shadowOffset = CGSize(width: 0, height: 2)
                layer?.shadowRadius = 4
            }
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            
            if !isSelected {
                closeButton.animator().isHidden = true
                layer?.backgroundColor = ColorManager.inactiveTab.cgColor
                titleLabel.textColor = ColorManager.tertiaryText
                
                // Remove hover shadow
                layer?.shadowOpacity = 0
            }
        }
    }
    
    // MARK: - NSDraggingSource
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        print("🔍 Drag source operation mask requested - returning .copy")
        return .copy
    }
    
    func draggingSession(_ session: NSDraggingSession, willBeginAt screenPoint: NSPoint) {
        print("🌟 Drag session will begin at: \(screenPoint)")
        // Visual feedback when drag begins
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            self.layer?.opacity = 0.7
        }
    }
    
    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        print("🏁 Drag session ended at: \(screenPoint), operation: \(operation)")
        // Restore appearance when drag ends
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            self.layer?.opacity = 1.0
        }
    }
}

// MARK: - Notification Extension
extension Notification.Name {
    static let tabUpdated = Notification.Name("TabUpdated")
}