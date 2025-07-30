import Cocoa

protocol SidebarTabViewDelegate: AnyObject {
    func sidebarTabViewDidClick(_ tabView: SidebarTabView)
    func sidebarTabViewDidClickClose(_ tabView: SidebarTabView)
}

class SidebarTabView: NSView, NSDraggingSource {
    let tab: Tab
    weak var delegate: SidebarTabViewDelegate?
    
    private var titleLabel: NSTextField!
    private var closeButton: NSButton!
    private var faviconImageView: NSImageView!
    private var trackingArea: NSTrackingArea?
    
    var isSelected: Bool = false {
        didSet {
            updateAppearance()
        }
    }
    
    private var isHovered: Bool = false {
        didSet {
            updateAppearance()
        }
    }
    
    // Drag & Drop properties
    private var dragStartPoint: NSPoint?
    private var isDragInProgress = false
    
    init(tab: Tab) {
        self.tab = tab
        super.init(frame: NSRect(x: 0, y: 0, width: 180, height: 32))
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.cornerRadius = 6 // Arc-style smaller corner radius
        layer?.masksToBounds = true
        
        // Enable drag & drop
        print("🔧 Setting up SidebarTabView for drag & drop: \(tab.title)")
        
        // Favicon
        faviconImageView = NSImageView()
        faviconImageView.translatesAutoresizingMaskIntoConstraints = false
        faviconImageView.imageScaling = .scaleProportionallyUpOrDown
        faviconImageView.image = NSImage(systemSymbolName: "globe", accessibilityDescription: "Website")
        faviconImageView.contentTintColor = ColorManager.tertiaryText
        
        // Disable mouse events on favicon so SidebarTabView gets them
        faviconImageView.isEnabled = false
        
        // Title label
        titleLabel = NSTextField(labelWithString: tab.title)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.maximumNumberOfLines = 1
        titleLabel.cell?.usesSingleLineMode = true
        titleLabel.cell?.wraps = false
        
        // Disable mouse events on label so SidebarTabView gets them
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
        closeButton.layer?.cornerRadius = 9
        closeButton.layer?.backgroundColor = NSColor.clear.cgColor
        
        addSubview(faviconImageView)
        addSubview(titleLabel)
        addSubview(closeButton)
        
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 32),
            
            faviconImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            faviconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            faviconImageView.widthAnchor.constraint(equalToConstant: 16),
            faviconImageView.heightAnchor.constraint(equalToConstant: 16),
            
            titleLabel.leadingAnchor.constraint(equalTo: faviconImageView.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -4),
            
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            closeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 16),
            closeButton.heightAnchor.constraint(equalToConstant: 16)
        ])
        
        updateAppearance()
    }
    
    override var intrinsicContentSize: NSSize {
        // Arc-style: tabs should fill the full width of the sidebar (200px)
        // This will be constrained by the parent container
        return NSSize(width: NSView.noIntrinsicMetric, height: 32)
    }
    
    private func updateAppearance() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.allowsImplicitAnimation = true
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            
            if isSelected {
                // Active tab styling - Arc-inspired pill
                layer?.backgroundColor = ColorManager.accent.cgColor
                titleLabel.textColor = NSColor.white
                faviconImageView.contentTintColor = NSColor.white
                closeButton.contentTintColor = NSColor.white
                
                // Add subtle glow effect
                layer?.shadowColor = ColorManager.accent.cgColor
                layer?.shadowOffset = CGSize(width: 0, height: 0)
                layer?.shadowRadius = 8
                layer?.shadowOpacity = 0.3
                layer?.masksToBounds = false
                
                // Scale effect
                layer?.transform = CATransform3DMakeScale(1.02, 1.02, 1.0)
                
            } else if isHovered {
                // Hover state - sophisticated background
                layer?.backgroundColor = ColorManager.tertiaryBackground.cgColor
                titleLabel.textColor = ColorManager.primaryText
                faviconImageView.contentTintColor = ColorManager.primaryText
                closeButton.contentTintColor = ColorManager.primaryText
                
                // Remove glow
                layer?.shadowOpacity = 0
                layer?.masksToBounds = true
                
                // Subtle scale
                layer?.transform = CATransform3DMakeScale(1.01, 1.01, 1.0)
                
            } else {
                // Normal state - Arc-style gray background
                layer?.backgroundColor = NSColor(calibratedWhite: 0.4, alpha: 0.6).cgColor
                titleLabel.textColor = NSColor.white
                faviconImageView.contentTintColor = NSColor.white
                closeButton.contentTintColor = NSColor.white
                
                // Remove effects
                layer?.shadowOpacity = 0
                layer?.masksToBounds = true
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
            faviconImageView.contentTintColor = isSelected ? NSColor.white : ColorManager.tertiaryText
        }
    }
    
    @objc private func closeTab() {
        delegate?.sidebarTabViewDidClickClose(self)
    }
    
    override func mouseDown(with event: NSEvent) {
        dragStartPoint = convert(event.locationInWindow, from: nil)
        isDragInProgress = false
        print("🐭 SidebarTabView mouseDown: \(tab.title) at point: \(dragStartPoint ?? .zero)")
        
        // Don't call delegate click immediately - wait to see if this becomes a drag
    }
    
    override func mouseDragged(with event: NSEvent) {
        print("🎯 SidebarTabView mouseDragged: \(tab.title)")
        
        guard let startPoint = dragStartPoint, !isDragInProgress else {
            print("❌ No start point or drag already in progress")
            return
        }
        
        let currentPoint = convert(event.locationInWindow, from: nil)
        let distance = sqrt(pow(currentPoint.x - startPoint.x, 2) + pow(currentPoint.y - startPoint.y, 2))
        
        print("📏 Drag distance: \(distance) pixels")
        
        // Start dragging if we've moved more than 3 pixels
        if distance > 3 {
            print("🎯 Starting drag operation for tab: \(tab.title)")
            isDragInProgress = true
            startDragOperation(with: event)
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        print("🐭 SidebarTabView mouseUp: \(tab.title), was dragging: \(isDragInProgress)")
        
        // If we weren't dragging, treat this as a click
        if !isDragInProgress {
            delegate?.sidebarTabViewDidClick(self)
        }
        
        dragStartPoint = nil
        isDragInProgress = false
    }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    override var mouseDownCanMoveWindow: Bool {
        print("🚫 SidebarTabView mouseDownCanMoveWindow called for: \(tab.title) - returning false")
        return false
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
        isHovered = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            closeButton.animator().isHidden = false
            
            // Add subtle close button background on hover
            closeButton.layer?.backgroundColor = NSColor(calibratedWhite: 0.0, alpha: 0.1).cgColor
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        isHovered = false
        if !isSelected {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                closeButton.animator().isHidden = true
                closeButton.layer?.backgroundColor = NSColor.clear.cgColor
            }
        }
    }
    
    // MARK: - Drag & Drop
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
        pasteboardItem.setString(jsonString, forType: .string)
        
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
        let image = NSImage(size: NSSize(width: 80, height: 24))
        image.lockFocus()
        
        // Draw a simplified version of the tab
        let rect = NSRect(x: 0, y: 0, width: 80, height: 24)
        NSColor.systemGray.set()
        rect.fill()
        
        // Draw favicon if available
        if let favicon = tab.favicon {
            favicon.draw(in: NSRect(x: 4, y: 4, width: 16, height: 16))
        }
        
        // Draw title
        let title = String(tab.title.prefix(8))
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.labelColor
        ]
        (title as NSString).draw(in: NSRect(x: 24, y: 6, width: 50, height: 12), withAttributes: attributes)
        
        image.unlockFocus()
        return image
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