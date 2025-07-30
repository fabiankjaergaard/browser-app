import Cocoa


// MARK: - Draggable Tabs Scroll View
class DroppableTabsScrollView: NSScrollView {
    weak var sidebarController: SidebarViewController?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        registerForDraggedTypes([.string])
        wantsLayer = true
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.string])
        wantsLayer = true
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.string])
        wantsLayer = true
    }
    
    // MARK: - NSDraggingDestination
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        print("🎯 Drag entered tabs area")
        
        guard isValidFavoriteRemovalData(sender) else {
            print("❌ Invalid favorite removal data")
            return []
        }
        
        print("✅ Valid favorite removal data - showing drop zone feedback")
        
        // Add visual feedback for drop zone
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            self.layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.1).cgColor
            self.layer?.borderWidth = 2
            self.layer?.borderColor = NSColor.systemRed.withAlphaComponent(0.3).cgColor
            self.layer?.cornerRadius = 8
        }
        
        return .move
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        print("🚪 Drag exited tabs area")
        // Remove visual feedback
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            self.layer?.backgroundColor = NSColor.clear.cgColor
            self.layer?.borderWidth = 0
        }
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard isValidFavoriteRemovalData(sender) else {
            return []
        }
        return .move
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        print("💫 Performing favorite removal operation")
        
        guard let dragData = getFavoriteRemovalData(sender) else {
            print("❌ Failed to get favorite removal data")
            return false
        }
        
        print("📊 Favorite removal data received: \(dragData)")
        
        // Remove from favorites
        guard let favoriteId = dragData["favorite_id"],
              let favoriteUUID = UUID(uuidString: favoriteId) else {
            print("❌ Invalid favorite ID")
            return false
        }
        
        // Find and remove the favorite
        if let favorites = BookmarkManager.shared.getBookmarksBarFolder()?.bookmarks,
           let bookmarkToRemove = favorites.first(where: { $0.id == favoriteUUID }) {
            print("🗑️ Removing favorite: \(bookmarkToRemove.title)")
            BookmarkManager.shared.removeFromFavorites(bookmarkToRemove)
        }
        
        // Remove visual feedback
        draggingExited(nil)
        
        return true
    }
    
    private func isValidFavoriteRemovalData(_ sender: NSDraggingInfo) -> Bool {
        guard let string = sender.draggingPasteboard.string(forType: .string),
              let data = string.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              json["drag_type"] == "remove_favorite",
              json["favorite_id"] != nil else {
            return false
        }
        return true
    }
    
    private func getFavoriteRemovalData(_ sender: NSDraggingInfo) -> [String: String]? {
        guard let string = sender.draggingPasteboard.string(forType: .string),
              let data = string.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return nil
        }
        return json
    }
}

class SidebarViewController: NSViewController {
    
    // Navigation section
    private var navigationToolbar: NSView!
    private var addressBar: NSTextField!
    private var backButton: NSButton!
    private var forwardButton: NSButton!
    private var refreshButton: NSButton!
    private var securityIndicator: NSImageView!
    
    // Favorites section
    private var favoritesView: SidebarFavoritesView!
    
    // Tab management
    internal var tabScrollView: DroppableTabsScrollView!
    private var tabStackView: NSStackView!
    private var sidebarTabViews: [SidebarTabView] = []
    private var toolbar: NSView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
        setupNavigationToolbar()
        setupFavoritesSection()
        setupTabSection()
        setupToolbar()
        setupNotifications()
        setupAutoHideInteraction()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        // Debug frame after layout
        print("🔍 After layout - tabStackView frame: \(tabStackView.frame)")
        print("🔍 After layout - tabScrollView frame: \(tabScrollView.frame)")
        print("🔍 After layout - tabScrollView isHidden: \(tabScrollView.isHidden)")
        print("🔍 After layout - newTabButton frame: \((view.subviews.first { $0 is NSButton && ($0 as! NSButton).title == "+ New Tab" })?.frame ?? .zero)")
        
        // Update border position
        updateRightBorder()
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
        // Update border position when view resizes
        updateRightBorder()
    }
    
    private func setupView() {
        view.wantsLayer = true
        view.layer?.backgroundColor = ColorManager.secondaryBackground.cgColor
        
        // Add subtle right border to separate from content
        let borderLayer = CALayer()
        borderLayer.backgroundColor = ColorManager.primaryBorder.cgColor
        borderLayer.name = "rightBorder"
        view.layer?.addSublayer(borderLayer)
        
        // Update border position when view resizes
        updateRightBorder()
    }
    
    private func updateRightBorder() {
        guard let borderLayer = view.layer?.sublayers?.first(where: { $0.name == "rightBorder" }) else { return }
        
        let viewWidth = view.bounds.width
        borderLayer.frame = CGRect(x: viewWidth - 1, y: 0, width: 1, height: view.bounds.height)
    }
    
    
    private func setupNavigationToolbar() {
        navigationToolbar = NSView()
        navigationToolbar.translatesAutoresizingMaskIntoConstraints = false
        navigationToolbar.wantsLayer = true
        
        // Create navigation buttons - positioned at title bar level, not in toolbar
        backButton = createNavigationButton(systemName: "chevron.left", action: #selector(goBack), tooltip: "Go back")
        forwardButton = createNavigationButton(systemName: "chevron.right", action: #selector(goForward), tooltip: "Go forward")
        refreshButton = createNavigationButton(systemName: "arrow.clockwise", action: #selector(refresh), tooltip: "Refresh page")
        
        // Add navigation buttons directly to main view (not toolbar) to match title bar level
        view.addSubview(backButton)
        view.addSubview(forwardButton)
        view.addSubview(refreshButton)
        
        NSLayoutConstraint.activate([
            // Position at exact traffic light level (macOS traffic lights are at Y=8)
            backButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 78),
            backButton.widthAnchor.constraint(equalToConstant: 20),
            backButton.heightAnchor.constraint(equalToConstant: 20),
            
            forwardButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            forwardButton.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 4),
            forwardButton.widthAnchor.constraint(equalToConstant: 20),
            forwardButton.heightAnchor.constraint(equalToConstant: 20),
            
            refreshButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            refreshButton.leadingAnchor.constraint(equalTo: forwardButton.trailingAnchor, constant: 4),
            refreshButton.widthAnchor.constraint(equalToConstant: 20),
            refreshButton.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        // Address bar container
        let addressBarContainer = NSView()
        addressBarContainer.translatesAutoresizingMaskIntoConstraints = false
        
        // Copy URL button container (background) - exactly like address bar
        let copyURLContainer = NSTextField()
        copyURLContainer.translatesAutoresizingMaskIntoConstraints = false
        copyURLContainer.placeholderString = ""
        copyURLContainer.bezelStyle = .roundedBezel
        copyURLContainer.backgroundColor = NSColor(calibratedWhite: 0.12, alpha: 0.9)
        copyURLContainer.textColor = ColorManager.primaryText
        copyURLContainer.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        copyURLContainer.wantsLayer = true
        copyURLContainer.layer?.cornerRadius = 10
        copyURLContainer.layer?.borderWidth = 1
        copyURLContainer.layer?.borderColor = NSColor(calibratedWhite: 0.3, alpha: 0.5).cgColor
        copyURLContainer.focusRingType = .none
        copyURLContainer.isEditable = false
        copyURLContainer.isSelectable = false
        copyURLContainer.stringValue = ""
        
        // Copy URL button
        let copyURLButton = NSButton()
        copyURLButton.translatesAutoresizingMaskIntoConstraints = false
        copyURLButton.image = NSImage(systemSymbolName: "link", accessibilityDescription: "Copy URL")
        copyURLButton.bezelStyle = .regularSquare
        copyURLButton.isBordered = false
        copyURLButton.contentTintColor = ColorManager.secondaryText
        copyURLButton.target = self
        copyURLButton.action = #selector(copyURLAction)
        copyURLButton.toolTip = "Copy URL"
        copyURLButton.wantsLayer = true
        
        // Security indicator
        securityIndicator = NSImageView()
        securityIndicator.translatesAutoresizingMaskIntoConstraints = false
        securityIndicator.imageScaling = .scaleProportionallyDown
        
        // Address bar
        addressBar = NSTextField()
        addressBar.translatesAutoresizingMaskIntoConstraints = false
        addressBar.placeholderString = "Search or enter URL..."
        addressBar.bezelStyle = .roundedBezel
        addressBar.delegate = self
        addressBar.backgroundColor = NSColor(calibratedWhite: 0.12, alpha: 0.9)
        addressBar.textColor = ColorManager.primaryText
        addressBar.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        addressBar.wantsLayer = true
        addressBar.layer?.cornerRadius = 10
        addressBar.layer?.borderWidth = 1
        addressBar.layer?.borderColor = NSColor(calibratedWhite: 0.3, alpha: 0.5).cgColor
        addressBar.focusRingType = .none
        
        addressBarContainer.addSubview(addressBar)
        addressBarContainer.addSubview(copyURLContainer)
        copyURLContainer.addSubview(copyURLButton)
        
        NSLayoutConstraint.activate([
            // Address bar with space for button container
            addressBar.leadingAnchor.constraint(equalTo: addressBarContainer.leadingAnchor, constant: 8),
            addressBar.centerYAnchor.constraint(equalTo: addressBarContainer.centerYAnchor),
            addressBar.trailingAnchor.constraint(equalTo: copyURLContainer.leadingAnchor, constant: -8),
            addressBar.heightAnchor.constraint(equalToConstant: 34),
            
            // Copy URL container positioned on the right - same height as address bar
            copyURLContainer.trailingAnchor.constraint(equalTo: addressBarContainer.trailingAnchor, constant: -8),
            copyURLContainer.centerYAnchor.constraint(equalTo: addressBarContainer.centerYAnchor),
            copyURLContainer.widthAnchor.constraint(equalToConstant: 34),
            copyURLContainer.heightAnchor.constraint(equalToConstant: 34),
            
            // Copy URL button centered in container
            copyURLButton.centerXAnchor.constraint(equalTo: copyURLContainer.centerXAnchor),
            copyURLButton.centerYAnchor.constraint(equalTo: copyURLContainer.centerYAnchor),
            copyURLButton.widthAnchor.constraint(equalToConstant: 18),
            copyURLButton.heightAnchor.constraint(equalToConstant: 18),
            
            addressBarContainer.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        // Add address bar container to navigation toolbar
        navigationToolbar.addSubview(addressBarContainer)
        view.addSubview(navigationToolbar)
        
        NSLayoutConstraint.activate([
            // Position toolbar below title bar area where navigation buttons are
            navigationToolbar.topAnchor.constraint(equalTo: view.topAnchor, constant: 45),
            navigationToolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
            navigationToolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
            navigationToolbar.heightAnchor.constraint(equalToConstant: 40),
            
            // Address bar takes full toolbar space
            addressBarContainer.topAnchor.constraint(equalTo: navigationToolbar.topAnchor),
            addressBarContainer.leadingAnchor.constraint(equalTo: navigationToolbar.leadingAnchor),
            addressBarContainer.trailingAnchor.constraint(equalTo: navigationToolbar.trailingAnchor),
            addressBarContainer.bottomAnchor.constraint(equalTo: navigationToolbar.bottomAnchor)
        ])
    }
    
    private func setupFavoritesSection() {
        favoritesView = SidebarFavoritesView()
        favoritesView.translatesAutoresizingMaskIntoConstraints = false
        favoritesView.delegate = self
        view.addSubview(favoritesView)
        
        NSLayoutConstraint.activate([
            favoritesView.topAnchor.constraint(equalTo: navigationToolbar.bottomAnchor, constant: 16),
            favoritesView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
            favoritesView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
        ])
    }
    
    private func setupTabSection() {        
        // Add separator line above + New Tab button
        let separatorLine = NSView()
        separatorLine.translatesAutoresizingMaskIntoConstraints = false
        separatorLine.wantsLayer = true
        separatorLine.layer?.backgroundColor = ColorManager.primaryBorder.cgColor
        view.addSubview(separatorLine)
        
        // Add New Tab button (Arc-style clean design)
        let newTabButton = NSButton(title: "+ New Tab", target: self, action: #selector(addNewTab))
        newTabButton.translatesAutoresizingMaskIntoConstraints = false
        newTabButton.bezelStyle = .regularSquare
        newTabButton.isBordered = false
        newTabButton.contentTintColor = ColorManager.secondaryText
        newTabButton.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        newTabButton.alignment = .left
        newTabButton.wantsLayer = true
        view.addSubview(newTabButton)
        
        // Create scroll view for tabs
        tabScrollView = DroppableTabsScrollView()
        tabScrollView.translatesAutoresizingMaskIntoConstraints = false
        tabScrollView.hasVerticalScroller = true
        tabScrollView.hasHorizontalScroller = false
        tabScrollView.autohidesScrollers = true
        tabScrollView.borderType = .noBorder
        tabScrollView.sidebarController = self
        
        print("🔧 Created DroppableTabsScrollView")
        tabScrollView.drawsBackground = false
        
        // Create stack view for tabs
        tabStackView = NSStackView()
        tabStackView.translatesAutoresizingMaskIntoConstraints = false
        tabStackView.orientation = .vertical
        tabStackView.spacing = 3
        tabStackView.alignment = .leading
        tabStackView.distribution = .gravityAreas
        
        tabScrollView.documentView = tabStackView
        view.addSubview(tabScrollView)
        
        NSLayoutConstraint.activate([
            // Separator line above + New Tab button
            separatorLine.topAnchor.constraint(equalTo: favoritesView.bottomAnchor, constant: 16),
            separatorLine.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            separatorLine.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            separatorLine.heightAnchor.constraint(equalToConstant: 1),
            
            // New Tab button - after separator line
            newTabButton.topAnchor.constraint(equalTo: separatorLine.bottomAnchor, constant: 16),
            newTabButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            newTabButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            newTabButton.heightAnchor.constraint(equalToConstant: 32),
            
            // Tab scroll view - directly under + New Tab
            tabScrollView.topAnchor.constraint(equalTo: newTabButton.bottomAnchor, constant: 8),
            tabScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
            tabScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
            
            // Tab stack view - properly sized content
            tabStackView.topAnchor.constraint(equalTo: tabScrollView.topAnchor),
            tabStackView.leadingAnchor.constraint(equalTo: tabScrollView.leadingAnchor),
            tabStackView.trailingAnchor.constraint(equalTo: tabScrollView.trailingAnchor),
            tabStackView.bottomAnchor.constraint(equalTo: tabScrollView.bottomAnchor),
            tabStackView.widthAnchor.constraint(equalTo: tabScrollView.widthAnchor)
        ])
        
        refreshTabs()
        
        // Force layout update
        view.layoutSubtreeIfNeeded()
        
        // Debug: Check if tabStackView is visible
        print("🔍 tabStackView frame: \(tabStackView.frame)")
        print("🔍 tabScrollView frame: \(tabScrollView.frame)")
        print("🔍 tabStackView has \(tabStackView.arrangedSubviews.count) subviews")
    }
    
    private func setupToolbar() {
        toolbar = NSView()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.wantsLayer = true
        
        let historyButton = NSButton(image: NSImage(systemSymbolName: "clock", accessibilityDescription: "History")!, target: self, action: #selector(showHistory))
        historyButton.translatesAutoresizingMaskIntoConstraints = false
        historyButton.bezelStyle = .regularSquare
        historyButton.isBordered = false
        historyButton.contentTintColor = ColorManager.secondaryText
        historyButton.toolTip = "Show history"
        historyButton.wantsLayer = true
        
        // Add hover effect for history button
        if let historyLayer = historyButton.layer {
            historyLayer.cornerRadius = 6
        }
        
        toolbar.addSubview(historyButton)
        view.addSubview(toolbar)
        
        NSLayoutConstraint.activate([
            // Toolbar constrained to bottom, but tabs can expand above it
            toolbar.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8),
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 36),
            
            // Tab scroll view should not overlap with toolbar
            tabScrollView.bottomAnchor.constraint(lessThanOrEqualTo: toolbar.topAnchor, constant: -8),
            
            historyButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            historyButton.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor, constant: -12),
            historyButton.widthAnchor.constraint(equalToConstant: 28)
        ])
    }
    
    
    @objc private func addNewTab() {
        NotificationCenter.default.post(name: .showQuickSearch, object: nil)
    }
    
    @objc private func showHistory() {
        let historyViewController = HistoryViewController()
        let window = NSWindow(contentViewController: historyViewController)
        window.title = "History"
        window.setContentSize(NSSize(width: 800, height: 600))
        window.center()
        window.makeKeyAndOrderFront(nil)
    }
    
    
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleTabCreated(_:)), name: .tabCreated, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleTabClosed(_:)), name: .tabClosed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleSpaceChanged(_:)), name: .spaceChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleTabUpdated(_:)), name: .tabUpdated, object: nil)
    }
    
    @objc private func handleTabCreated(_ notification: Notification) {
        refreshTabs()
    }
    
    @objc private func handleTabClosed(_ notification: Notification) {
        refreshTabs()
    }
    
    @objc private func handleSpaceChanged(_ notification: Notification) {
        refreshTabs()
    }
    
    @objc private func handleTabUpdated(_ notification: Notification) {
        guard let tab = notification.object as? Tab else { 
            print("⚠️ handleTabUpdated: No tab in notification")
            return 
        }
        
        print("🔔 Tab updated notification: \(tab.title)")
        
        guard let tabView = sidebarTabViews.first(where: { $0.tab.id == tab.id }) else { 
            print("⚠️ No matching tabView found for tab: \(tab.title)")
            return 
        }
        
        print("✅ Updating SidebarTabView title to: \(tab.title)")
        tabView.updateTitle(tab.title)
        tabView.updateFavicon(tab.favicon)
        
        // Update address bar if this is the active tab
        if TabManager.shared.activeTab?.id == tab.id {
            updateAddressBar(for: tab)
        }
    }
    
    private func refreshTabs() {
        print("🔄 refreshTabs() called - looseTabs count: \(TabManager.shared.looseTabs.count)")
        
        // Remove all existing tab views
        sidebarTabViews.forEach { $0.removeFromSuperview() }
        sidebarTabViews.removeAll()
        
        // Add loose tabs first (directly under + New Tab)
        for tab in TabManager.shared.looseTabs {
            print("📋 Adding loose tab: \(tab.title)")
            let tabView = SidebarTabView(tab: tab)
            tabView.delegate = self
            tabView.updateFavicon(tab.favicon)
            sidebarTabViews.append(tabView)
            tabStackView.addArrangedSubview(tabView)
            print("📍 Added tab view to tabStackView at position \(tabStackView.arrangedSubviews.count - 1)")
            
            // Arc-style: tabs fill the full width of the sidebar
            tabView.leadingAnchor.constraint(equalTo: tabStackView.leadingAnchor, constant: 6).isActive = true
            tabView.trailingAnchor.constraint(equalTo: tabStackView.trailingAnchor, constant: -6).isActive = true
        }
        
        // Then add tabs from spaces
        for space in TabManager.shared.spaces {
            for tab in space.tabs {
                let tabView = SidebarTabView(tab: tab)
                tabView.delegate = self
                tabView.updateFavicon(tab.favicon)
                sidebarTabViews.append(tabView)
                tabStackView.addArrangedSubview(tabView)
                
                // Arc-style: tabs fill the full width of the sidebar
                tabView.leadingAnchor.constraint(equalTo: tabStackView.leadingAnchor, constant: 6).isActive = true
                tabView.trailingAnchor.constraint(equalTo: tabStackView.trailingAnchor, constant: -6).isActive = true
            }
        }
        
        // Update selection
        updateTabSelection()
    }
    
    private func updateAddressBar(for tab: Tab) {
        DispatchQueue.main.async { [weak self] in
            if let url = tab.url {
                // Display only the domain name (host) without protocol and www
                var displayURL = url.host ?? url.absoluteString
                if displayURL.hasPrefix("www.") {
                    displayURL = String(displayURL.dropFirst(4))
                }
                self?.addressBar.stringValue = displayURL
                print("🌐 Updated address bar to: \(displayURL)")
            } else {
                self?.addressBar.stringValue = ""
                print("🌐 Cleared address bar")
            }
        }
    }
    
    private func updateTabSelection() {
        guard let activeTab = TabManager.shared.activeTab else { return }
        sidebarTabViews.forEach { tabView in
            tabView.isSelected = tabView.tab.id == activeTab.id
        }
    }
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 600))
    }
    
    // MARK: - Navigation Actions
    @objc private func goBack() {
        TabManager.shared.activeTab?.webView.goBack()
    }
    
    @objc private func goForward() {
        TabManager.shared.activeTab?.webView.goForward()
    }
    
    @objc private func refresh() {
        guard let activeTab = TabManager.shared.activeTab else { return }
        if activeTab.isLoading {
            activeTab.webView.stopLoading()
        } else {
            activeTab.webView.reload()
        }
    }
    
    @objc private func copyURLAction() {
        print("🔘 Copy URL button clicked!")
        
        guard let currentURL = TabManager.shared.activeTab?.url else { 
            print("⚠️ No active tab or URL to copy")
            return 
        }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(currentURL.absoluteString, forType: .string)
        
        // Provide visual feedback
        print("📋 URL copied to clipboard: \(currentURL.absoluteString)")
        
        // Show notification popup
        showCopyNotification()
    }
    
    private func showCopyNotification() {
        // Create notification view
        let notificationView = NSView()
        notificationView.translatesAutoresizingMaskIntoConstraints = false
        notificationView.wantsLayer = true
        notificationView.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        notificationView.layer?.cornerRadius = 6
        
        // Create label
        let label = NSTextField(labelWithString: "URL copied!")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = NSColor.white
        label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        label.alignment = .center
        
        notificationView.addSubview(label)
        view.addSubview(notificationView)
        
        NSLayoutConstraint.activate([
            // Center the notification horizontally and position it below the address bar
            notificationView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            notificationView.topAnchor.constraint(equalTo: navigationToolbar.bottomAnchor, constant: 8),
            notificationView.widthAnchor.constraint(equalToConstant: 100),
            notificationView.heightAnchor.constraint(equalToConstant: 28),
            
            // Center label in notification
            label.centerXAnchor.constraint(equalTo: notificationView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: notificationView.centerYAnchor)
        ])
        
        // Animate in
        notificationView.layer?.opacity = 0.0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            notificationView.layer?.opacity = 1.0
        }
        
        // Animate out and remove after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                notificationView.layer?.opacity = 0.0
            }) {
                notificationView.removeFromSuperview()
            }
        }
    }
    
    
    // MARK: - Helper Methods
    private func createNavigationButton(systemName: String, action: Selector, tooltip: String) -> NSButton {
        let button = NSButton(
            image: NSImage(systemSymbolName: systemName, accessibilityDescription: tooltip)!,
            target: self,
            action: action
        )
        
        button.translatesAutoresizingMaskIntoConstraints = false
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.contentTintColor = ColorManager.secondaryText
        button.toolTip = tooltip
        button.wantsLayer = true
        
        // Arc-style button styling
        if let buttonLayer = button.layer {
            buttonLayer.cornerRadius = 6
            buttonLayer.backgroundColor = NSColor.clear.cgColor
        }
        
        return button
    }
    
    // MARK: - Auto-Hide Interaction
    private func setupAutoHideInteraction() {
        // Add tracking area to cancel auto-hide when mouse enters sidebar
        let trackingArea = NSTrackingArea(
            rect: view.bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: ["type": "sidebar"]
        )
        view.addTrackingArea(trackingArea)
    }
    
    override func mouseEntered(with event: NSEvent) {
        if let userInfo = event.trackingArea?.userInfo,
           let type = userInfo["type"] as? String,
           type == "sidebar" {
            // Only handle auto-hide interaction if sidebar is currently auto-hidden
            if let windowController = view.window?.windowController as? BrowserWindowController {
                print("🐭 Mouse entered sidebar - canceling auto-hide")
                windowController.cancelAutoHide()
            }
        }
        super.mouseEntered(with: event)
    }
    
    override func mouseExited(with event: NSEvent) {
        if let userInfo = event.trackingArea?.userInfo,
           let type = userInfo["type"] as? String,
           type == "sidebar" {
            // Only handle auto-hide interaction if sidebar is currently auto-hidden
            if let windowController = view.window?.windowController as? BrowserWindowController {
                print("🐭 Mouse exited sidebar - scheduling auto-hide")
                windowController.hideSidebarIfAutoHidden()
            }
        }
        super.mouseExited(with: event)
    }
}

// MARK: - SidebarFavoritesViewDelegate
extension SidebarViewController: SidebarFavoritesViewDelegate {
    func sidebarFavoritesView(_ favoritesView: SidebarFavoritesView, didClickFavorite bookmark: Bookmark) {
        // Navigate to favorite URL in current tab, or create new tab if none exists
        if let currentTab = TabManager.shared.activeTab {
            currentTab.navigate(to: bookmark.url)
        } else {
            // No active tab, create a new one with the favorite URL
            TabManager.shared.createNewTab(with: bookmark.url)
        }
    }
}

// MARK: - SidebarTabViewDelegate
extension SidebarViewController: SidebarTabViewDelegate {
    func sidebarTabViewDidClick(_ tabView: SidebarTabView) {
        TabManager.shared.switchToTab(tabView.tab)
        updateTabSelection()
        updateAddressBar(for: tabView.tab)
    }
    
    func sidebarTabViewDidClickClose(_ tabView: SidebarTabView) {
        // TabManager will automatically determine if it's a loose tab or space tab
        TabManager.shared.closeTab(tabView.tab)
    }
}

// MARK: - NSTextFieldDelegate
extension SidebarViewController: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField, textField == addressBar else { return }
        
        let urlString = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !urlString.isEmpty else { return }
        
        // Determine if it's a URL or search query
        let finalURL: URL
        if urlString.contains(".") && !urlString.contains(" ") {
            // Looks like a URL
            if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
                finalURL = URL(string: urlString) ?? URL(string: "https://www.google.com/search?q=\(urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!
            } else {
                finalURL = URL(string: "https://\(urlString)") ?? URL(string: "https://www.google.com/search?q=\(urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!
            }
        } else {
            // Treat as search query
            finalURL = URL(string: "https://www.google.com/search?q=\(urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!
        }
        
        // Navigate to the URL
        TabManager.shared.activeTab?.navigate(to: finalURL)
    }
}


extension Notification.Name {
    static let tabSelected = Notification.Name("TabSelected")
}

extension NSView {
    var allSubviews: [NSView] {
        var result: [NSView] = []
        for subview in subviews {
            result.append(subview)
            result.append(contentsOf: subview.allSubviews)
        }
        return result
    }
}