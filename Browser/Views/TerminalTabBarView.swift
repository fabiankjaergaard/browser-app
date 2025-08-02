import Cocoa

class HoverButton: NSButton {
    var normalColor: NSColor = NSColor.tertiaryLabelColor
    var hoverColor: NSColor = NSColor.labelColor
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        contentTintColor = hoverColor
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        contentTintColor = normalColor
    }
}

class TerminalTabBarView: NSView {
    
    private var scrollView: NSScrollView!
    private var stackView: NSStackView!
    private var addButton: HoverButton!
    
    weak var terminalPanel: TTYDTerminalPanel?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupTabBar()
        setupNotifications()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTabBar()
        setupNotifications()
    }
    
    private func setupTabBar() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        
        // Create horizontal stack view for tabs
        stackView = NSStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .horizontal
        stackView.spacing = 4
        stackView.alignment = .centerY
        stackView.distribution = .gravityAreas
        
        // Create scroll view to handle overflow
        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.documentView = stackView
        
        addSubview(scrollView)
        
        // Create add tab button with hover effect
        addButton = HoverButton()
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "New Terminal Tab")
        addButton.bezelStyle = .regularSquare
        addButton.isBordered = false
        addButton.contentTintColor = NSColor.tertiaryLabelColor
        addButton.normalColor = NSColor.tertiaryLabelColor
        addButton.hoverColor = NSColor.labelColor
        addButton.target = self
        addButton.action = #selector(addNewTab)
        
        addSubview(addButton)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: addButton.leadingAnchor, constant: -4),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            addButton.topAnchor.constraint(equalTo: topAnchor),
            addButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            addButton.bottomAnchor.constraint(equalTo: bottomAnchor),
            addButton.widthAnchor.constraint(equalToConstant: 20),
            
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])
        
        refreshTabs()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(terminalTabCreated(_:)),
            name: .terminalTabCreated,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(terminalTabClosed(_:)),
            name: .terminalTabClosed,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(terminalTabSelected(_:)),
            name: .terminalTabSelected,
            object: nil
        )
    }
    
    @objc private func addNewTab() {
        let newTab = TerminalTabManager.shared.createNewTerminalTab()
        terminalPanel?.switchToTerminalTab(newTab)
    }
    
    @objc private func terminalTabCreated(_ notification: Notification) {
        DispatchQueue.main.async {
            self.refreshTabs()
        }
    }
    
    @objc private func terminalTabClosed(_ notification: Notification) {
        DispatchQueue.main.async {
            self.refreshTabs()
        }
    }
    
    @objc private func terminalTabSelected(_ notification: Notification) {
        DispatchQueue.main.async {
            self.refreshTabs()
        }
    }
    
    private func refreshTabs() {
        // Remove existing tab views
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Add tab views for each terminal tab
        for terminalTab in TerminalTabManager.shared.terminalTabs {
            let tabView = createTabView(for: terminalTab)
            stackView.addArrangedSubview(tabView)
        }
    }
    
    private func createTabView(for terminalTab: TerminalTab) -> NSView {
        let tabContainer = NSView()
        tabContainer.wantsLayer = true
        
        // Configure appearance based on active state
        if terminalTab.isActive {
            tabContainer.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.08).cgColor
        } else {
            tabContainer.layer?.backgroundColor = NSColor.clear.cgColor
        }
        
        tabContainer.layer?.cornerRadius = 4
        
        // Tab title label
        let titleLabel = NSTextField(labelWithString: terminalTab.title)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 10, weight: terminalTab.isActive ? .medium : .regular)
        titleLabel.textColor = terminalTab.isActive ? NSColor.labelColor : NSColor.secondaryLabelColor
        titleLabel.backgroundColor = NSColor.clear
        titleLabel.maximumNumberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        
        // Close button with hover effect
        let closeButton = HoverButton()
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close Tab")
        closeButton.bezelStyle = .regularSquare
        closeButton.isBordered = false
        closeButton.contentTintColor = NSColor.tertiaryLabelColor
        closeButton.normalColor = NSColor.tertiaryLabelColor
        closeButton.hoverColor = NSColor.labelColor
        closeButton.target = self
        closeButton.action = #selector(closeTab(_:))
        closeButton.tag = terminalTab.id.hashValue // Use ID hash as tag for identification
        
        tabContainer.addSubview(titleLabel)
        tabContainer.addSubview(closeButton)
        
        // Click gesture for tab selection
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(selectTab(_:)))
        clickGesture.numberOfClicksRequired = 1
        tabContainer.addGestureRecognizer(clickGesture)
        
        // Store reference to terminal tab for gesture handling
        tabContainer.identifier = NSUserInterfaceItemIdentifier(terminalTab.id.uuidString)
        
        NSLayoutConstraint.activate([
            tabContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
            tabContainer.widthAnchor.constraint(lessThanOrEqualToConstant: 140),
            
            titleLabel.leadingAnchor.constraint(equalTo: tabContainer.leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -4),
            titleLabel.centerYAnchor.constraint(equalTo: tabContainer.centerYAnchor),
            
            closeButton.trailingAnchor.constraint(equalTo: tabContainer.trailingAnchor, constant: -6),
            closeButton.centerYAnchor.constraint(equalTo: tabContainer.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 12),
            closeButton.heightAnchor.constraint(equalToConstant: 12)
        ])
        
        return tabContainer
    }
    
    @objc private func selectTab(_ gesture: NSClickGestureRecognizer) {
        guard let tabContainer = gesture.view,
              let identifier = tabContainer.identifier,
              let terminalTab = TerminalTabManager.shared.terminalTabs.first(where: { $0.id.uuidString == identifier.rawValue }) else {
            return
        }
        
        TerminalTabManager.shared.setActiveTab(terminalTab)
        terminalPanel?.switchToTerminalTab(terminalTab)
    }
    
    @objc private func closeTab(_ sender: NSButton) {
        // Find the terminal tab by checking all tabs and their hash values
        if let terminalTab = TerminalTabManager.shared.terminalTabs.first(where: { $0.id.hashValue == sender.tag }) {
            TerminalTabManager.shared.closeTerminalTab(terminalTab)
            
            // If no more tabs, hide the terminal panel
            if !TerminalTabManager.shared.hasAnyTabs() {
                terminalPanel?.closePanel()
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}