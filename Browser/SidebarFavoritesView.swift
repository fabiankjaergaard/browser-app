import Cocoa

protocol SidebarFavoritesViewDelegate: AnyObject {
    func sidebarFavoritesView(_ favoritesView: SidebarFavoritesView, didClickFavorite bookmark: Bookmark)
}

// MARK: - Favorite Group View (Arc-style)
class FavoriteGroupView: NSView {
    private let group: FavoriteGroup
    private var headerView: NSView!
    private var titleLabel: NSTextField!
    private var iconView: NSImageView!
    private var expandButton: NSButton!
    private var contentStackView: NSStackView!
    private var favoriteButtons: [NSButton] = []
    
    weak var delegate: SidebarFavoritesViewDelegate?
    
    init(group: FavoriteGroup) {
        self.group = group
        super.init(frame: .zero)
        setupView()
        loadBookmarks()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        
        // Minimal style like Arc - no background colors
        // layer?.backgroundColor = getGroupBackgroundColor().cgColor
        // layer?.cornerRadius = 8
        
        // Create main stack view
        let mainStackView = NSStackView()
        mainStackView.translatesAutoresizingMaskIntoConstraints = false
        mainStackView.orientation = .vertical
        mainStackView.spacing = 4
        mainStackView.alignment = .leading
        
        // Create header view
        setupHeaderView()
        
        // Create content stack view for bookmarks
        contentStackView = NSStackView()
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.orientation = .vertical
        contentStackView.spacing = 2
        contentStackView.alignment = .leading
        
        mainStackView.addArrangedSubview(headerView)
        mainStackView.addArrangedSubview(contentStackView)
        
        addSubview(mainStackView)
        
        NSLayoutConstraint.activate([
            mainStackView.topAnchor.constraint(equalTo: topAnchor),
            mainStackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            mainStackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            mainStackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        // Set initial expanded state
        contentStackView.isHidden = !group.isExpanded
    }
    

    
    private func setupHeaderView() {
        headerView = NSView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.wantsLayer = true
        
        // Simple minimal icon like Arc
        iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = NSImage(systemSymbolName: group.iconName, accessibilityDescription: group.name)
        iconView.contentTintColor = ColorManager.secondaryText
        iconView.imageScaling = .scaleProportionallyDown
        
        // Title
        titleLabel = NSTextField(labelWithString: group.name)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = ColorManager.primaryText
        
        // Expand/collapse button - HIDDEN
        expandButton = NSButton()
        expandButton.translatesAutoresizingMaskIntoConstraints = false
        expandButton.image = NSImage(systemSymbolName: group.isExpanded ? "chevron.down" : "chevron.right", accessibilityDescription: "Toggle")
        expandButton.bezelStyle = .regularSquare
        expandButton.isBordered = false
        expandButton.contentTintColor = ColorManager.secondaryText
        expandButton.target = self
        expandButton.action = #selector(toggleExpanded)
        expandButton.isHidden = true  // Hide the expand button
        
        headerView.addSubview(iconView)
        headerView.addSubview(titleLabel)
        headerView.addSubview(expandButton)
        
        NSLayoutConstraint.activate([
            headerView.heightAnchor.constraint(equalToConstant: 24),
            
            iconView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 4),
            iconView.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 6),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -4)
        ])
        
        // Add click gesture to header
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(toggleExpanded))
        headerView.addGestureRecognizer(clickGesture)
        
        // Setup context menu for group actions
        setupGroupContextMenu()
    }
    
    @objc private func toggleExpanded() {
        group.isExpanded.toggle()
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            contentStackView.isHidden = !group.isExpanded
            expandButton.image = NSImage(systemSymbolName: group.isExpanded ? "chevron.down" : "chevron.right", accessibilityDescription: "Toggle")
        }
    }
    
    private func setupGroupContextMenu() {
        // Create context menu for group actions
        let menu = NSMenu()
        
        // Rename group item
        let renameItem = NSMenuItem(title: "Byt namn på grupp", action: #selector(renameGroup), keyEquivalent: "")
        renameItem.target = self
        if let image = NSImage(systemSymbolName: "pencil", accessibilityDescription: "Byt namn") {
            image.size = NSSize(width: 16, height: 16)
            renameItem.image = image
        }
        menu.addItem(renameItem)
        
        // Change icon item
        let changeIconItem = NSMenuItem(title: "Ändra ikon", action: #selector(changeGroupIcon), keyEquivalent: "")
        changeIconItem.target = self
        if let image = NSImage(systemSymbolName: "square.on.circle", accessibilityDescription: "Ändra ikon") {
            image.size = NSSize(width: 16, height: 16)
            changeIconItem.image = image
        }
        menu.addItem(changeIconItem)
        
        // Separator
        menu.addItem(NSMenuItem.separator())
        
        // Delete group item
        let deleteItem = NSMenuItem(title: "Ta bort grupp", action: #selector(deleteGroup), keyEquivalent: "")
        deleteItem.target = self
        if let image = NSImage(systemSymbolName: "trash", accessibilityDescription: "Ta bort") {
            image.size = NSSize(width: 16, height: 16)
            deleteItem.image = image
        }
        menu.addItem(deleteItem)
        
        // Set the menu for the header view
        headerView.menu = menu
    }
    
    @objc private func renameGroup() {
        print("📝 Renaming group: \(group.name)")
        showRenameGroupDialog()
    }
    
    @objc private func changeGroupIcon() {
        print("🎨 Changing icon for group: \(group.name)")
        showChangeIconDialog()
    }
    
    @objc private func deleteGroup() {
        print("🗑️ Deleting group: \(group.name)")
        showDeleteConfirmation()
    }
    
    private func showRenameGroupDialog() {
        let alert = NSAlert()
        alert.messageText = "Byt namn på grupp"
        alert.informativeText = "Ange ett nytt namn för gruppen '\(group.name)':"
        alert.addButton(withTitle: "Spara")
        alert.addButton(withTitle: "Avbryt")
        alert.alertStyle = .informational
        
        // Add text field for new name
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        textField.stringValue = group.name
        textField.placeholderString = "Gruppnamn..."
        alert.accessoryView = textField
        
        if let window = self.window {
            alert.beginSheetModal(for: window) { response in
                if response == .alertFirstButtonReturn {
                    let newName = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !newName.isEmpty && newName != self.group.name {
                        self.performRename(newName: newName)
                    }
                }
            }
        } else {
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                let newName = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if !newName.isEmpty && newName != group.name {
                    performRename(newName: newName)
                }
            }
        }
    }
    
    private func showChangeIconDialog() {
        let alert = NSAlert()
        alert.messageText = "Ändra ikon för grupp"
        alert.informativeText = "Välj en ny ikon för gruppen '\(group.name)':"
        alert.addButton(withTitle: "Spara")
        alert.addButton(withTitle: "Avbryt")
        alert.alertStyle = .informational
        
        // Create popup button for icon selection
        let popupButton = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 300, height: 26))
        
        let availableIcons = [
            ("folder", "Mapp"),
            ("star", "Stjärna"),
            ("heart", "Hjärta"), 
            ("bookmark", "Bokmärke"),
            ("tag", "Tagg"),
            ("globe", "Världen"),
            ("house", "Hem"),
            ("briefcase", "Portfölj"),
            ("graduationcap", "Utbildning"),
            ("music.note", "Musik"),
            ("gamecontroller", "Spel"),
            ("camera", "Kamera"),
            ("paintbrush", "Design"),
            ("wrench.and.screwdriver", "Utveckling"),
            ("cart", "Shopping")
        ]
        
        // Populate icon popup
        for (iconName, displayName) in availableIcons {
            let menuItem = NSMenuItem(title: displayName, action: nil, keyEquivalent: "")
            if let image = NSImage(systemSymbolName: iconName, accessibilityDescription: displayName) {
                image.size = NSSize(width: 16, height: 16)
                menuItem.image = image
            }
            popupButton.menu?.addItem(menuItem)
        }
        
        // Select current icon
        if let currentIndex = availableIcons.firstIndex(where: { $0.0 == group.iconName }) {
            popupButton.selectItem(at: currentIndex)
        }
        
        alert.accessoryView = popupButton
        
        if let window = self.window {
            alert.beginSheetModal(for: window) { response in
                if response == .alertFirstButtonReturn {
                    let selectedIndex = popupButton.indexOfSelectedItem
                    if selectedIndex >= 0 && selectedIndex < availableIcons.count {
                        let newIconName = availableIcons[selectedIndex].0
                        if newIconName != self.group.iconName {
                            self.performIconChange(newIconName: newIconName)
                        }
                    }
                }
            }
        } else {
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                let selectedIndex = popupButton.indexOfSelectedItem
                if selectedIndex >= 0 && selectedIndex < availableIcons.count {
                    let newIconName = availableIcons[selectedIndex].0
                    if newIconName != group.iconName {
                        performIconChange(newIconName: newIconName)
                    }
                }
            }
        }
    }
    
    private func showDeleteConfirmation() {
        let alert = NSAlert()
        alert.messageText = "Ta bort grupp"
        alert.informativeText = "Är du säker på att du vill ta bort gruppen '\(group.name)'? Alla bokmärken i gruppen kommer också att tas bort."
        alert.addButton(withTitle: "Ta bort")
        alert.addButton(withTitle: "Avbryt")
        alert.alertStyle = .warning
        
        if let window = self.window {
            alert.beginSheetModal(for: window) { response in
                if response == .alertFirstButtonReturn {
                    self.performDelete()
                }
            }
        } else {
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                performDelete()
            }
        }
    }
    
    private func performRename(newName: String) {
        BookmarkManager.shared.renameFavoriteGroup(group, newName: newName)
        titleLabel.stringValue = newName
        print("✅ Renamed group to: \(newName)")
    }
    
    private func performIconChange(newIconName: String) {
        BookmarkManager.shared.updateFavoriteGroup(group, iconName: newIconName)
        iconView.image = NSImage(systemSymbolName: newIconName, accessibilityDescription: group.name)
        print("✅ Changed group icon to: \(newIconName)")
    }
    
    private func performDelete() {
        BookmarkManager.shared.deleteFavoriteGroup(group)
        print("✅ Deleted group: \(group.name)")
        
        // The BookmarkManager will send a notification which triggers loadFavoriteGroups
        // But we can also force immediate removal to avoid visual gaps
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Find the SidebarFavoritesView parent to trigger reload
            var parentView: SidebarFavoritesView?
            var currentView: NSView? = self
            while currentView != nil {
                if let favoritesView = currentView as? SidebarFavoritesView {
                    parentView = favoritesView
                    break
                }
                currentView = currentView?.superview
            }
            
            // Trigger immediate reload of groups to prevent gaps
            parentView?.loadFavoriteGroups()
        }
    }
    
    private func loadBookmarks() {
        // Clear existing buttons
        favoriteButtons.forEach { $0.removeFromSuperview() }
        favoriteButtons.removeAll()
        contentStackView.arrangedSubviews.forEach { contentStackView.removeArrangedSubview($0) }
        
        // Create bookmark buttons
        for bookmark in group.bookmarks {
            let button = createBookmarkButton(for: bookmark)
            favoriteButtons.append(button)
            contentStackView.addArrangedSubview(button)
        }
    }
    
    private func createBookmarkButton(for bookmark: Bookmark) -> NSButton {
        let button = NSButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.title = ""
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.target = self
        button.action = #selector(bookmarkClicked(_:))
        button.toolTip = bookmark.title + "\n" + bookmark.url.absoluteString
        
        // Store bookmark reference
        button.tag = group.bookmarks.firstIndex(where: { $0.id == bookmark.id }) ?? 0
        
        // Create horizontal container for icon + text (Arc-style)
        let containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        // Create favicon icon view (smaller than traditional favorites)
        let iconView = NSView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.wantsLayer = true
        iconView.layer?.cornerRadius = 4
        
        // Get colors for this domain
        let (backgroundColor, textColor, iconText) = getIconStyle(for: bookmark)
        iconView.layer?.backgroundColor = backgroundColor.cgColor
        
        // Create title label
        let titleLabel = NSTextField(labelWithString: bookmark.title)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        titleLabel.textColor = ColorManager.primaryText
        titleLabel.alignment = .left
        titleLabel.isEditable = false
        titleLabel.isSelectable = false
        titleLabel.backgroundColor = .clear
        titleLabel.isBordered = false
        
        // Setup favicon or fallback
        if let existingFavicon = bookmark.favicon {
            setupFaviconForGroupItem(iconView: iconView, favicon: existingFavicon, backgroundColor: backgroundColor, fallbackText: iconText, fallbackTextColor: textColor)
        } else {
            setupFallbackIconForGroupItem(iconView: iconView, backgroundColor: backgroundColor, textColor: textColor, iconText: iconText)
            
            // Fetch real favicon asynchronously
            bookmark.loadFavicon { [weak iconView] in
                guard let iconView = iconView else { return }
                
                // Clear existing content but keep background color
                iconView.subviews.forEach { $0.removeFromSuperview() }
                
                if let favicon = bookmark.favicon {
                    self.setupFaviconForGroupItem(iconView: iconView, favicon: favicon, backgroundColor: backgroundColor, fallbackText: iconText, fallbackTextColor: textColor)
                } else {
                    self.setupFallbackIconForGroupItem(iconView: iconView, backgroundColor: backgroundColor, textColor: textColor, iconText: iconText)
                }
            }
        }
        
        // Add to container
        containerView.addSubview(iconView)
        containerView.addSubview(titleLabel)
        button.addSubview(containerView)
        
        NSLayoutConstraint.activate([
            // Button constraints
            button.heightAnchor.constraint(equalToConstant: 24),
            
            // Container constraints
            containerView.topAnchor.constraint(equalTo: button.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 16), // Indent like Arc
            containerView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: button.bottomAnchor),
            
            // Icon constraints (smaller than traditional favorites)
            iconView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            iconView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),
            
            // Title constraints
            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
        ])
        
        return button
    }
    
    // Helper methods for group item favicons (smaller size)
    private func setupFaviconForGroupItem(iconView: NSView, favicon: NSImage, backgroundColor: NSColor, fallbackText: String, fallbackTextColor: NSColor) {
        let imageView = NSImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = favicon
        imageView.imageScaling = .scaleProportionallyUpOrDown
        
        let inset: CGFloat = 2 // Smaller inset for group items
        iconView.addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: iconView.topAnchor, constant: inset),
            imageView.leadingAnchor.constraint(equalTo: iconView.leadingAnchor, constant: inset),
            imageView.trailingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: -inset),
            imageView.bottomAnchor.constraint(equalTo: iconView.bottomAnchor, constant: -inset)
        ])
        
        // Check if we should use fallback text instead
        if favicon.size.width < 16 || favicon.size.height < 16 {
            imageView.removeFromSuperview()
            setupFallbackIconForGroupItem(iconView: iconView, backgroundColor: backgroundColor, textColor: fallbackTextColor, iconText: fallbackText)
        }
    }
    
    private func setupFallbackIconForGroupItem(iconView: NSView, backgroundColor: NSColor, textColor: NSColor, iconText: String) {
        let iconLabel = NSTextField(labelWithString: iconText)
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        iconLabel.font = NSFont.systemFont(ofSize: 9, weight: .medium) // Smaller font for group items
        iconLabel.textColor = textColor
        iconLabel.alignment = .center
        iconLabel.isBezeled = false
        iconLabel.isEditable = false
        iconLabel.isSelectable = false
        iconLabel.backgroundColor = .clear
        
        iconView.addSubview(iconLabel)
        
        NSLayoutConstraint.activate([
            iconLabel.centerXAnchor.constraint(equalTo: iconView.centerXAnchor),
            iconLabel.centerYAnchor.constraint(equalTo: iconView.centerYAnchor)
        ])
    }
    
    // Use the same icon styling as traditional favorites
    private func getIconStyle(for bookmark: Bookmark) -> (NSColor, NSColor, String) {
        let domain = bookmark.url.host?.lowercased() ?? ""
        
        // Return (backgroundColor, textColor, iconText) - EXACT brand colors!
        if domain.contains("youtube.com") {
            return (NSColor(red: 0.898, green: 0.0, blue: 0.0, alpha: 1.0), .white, "▶") // #E50000
        } else if domain.contains("netflix.com") {
            return (NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0), .white, "N") // #000000 (svart bakgrund)
        } else if domain.contains("linkedin.com") {
            return (NSColor(red: 0.0, green: 0.475, blue: 0.714, alpha: 1.0), .white, "in") // #0077B6
        } else if domain.contains("facebook.com") {
            return (NSColor(red: 0.145, green: 0.416, blue: 0.773, alpha: 1.0), .white, "f") // #1877F2 (nyare blå)
        } else if domain.contains("github.com") {
            return (NSColor(red: 0.067, green: 0.067, blue: 0.067, alpha: 1.0), .white, "⚡") // #111111
        } else if domain.contains("chatgpt.com") || domain.contains("openai.com") {
            return (NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0), .black, "GPT") // #FFFFFF (vit bakgrund)
        } else if domain.contains("gmail") || domain.contains("mail.google") {
            return (NSColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0), .white, "M") // #808080 (grå bakgrund)
        } else if domain.contains("google.com") {
            return (NSColor(red: 0.259, green: 0.522, blue: 0.957, alpha: 1.0), .white, "G") // #4285F4
        } else if domain.contains("apple.com") {
            return (NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0), .white, "🍎") // #000000
        } else if domain.contains("twitter.com") || domain.contains("x.com") {
            return (NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0), .white, "𝕏") // X är nu svart
        } else if domain.contains("instagram.com") {
            return (NSColor(red: 0.886, green: 0.243, blue: 0.643, alpha: 1.0), .white, "◉") // #E23EA4 (rosa från gradient)
        } else if domain.contains("discord.com") {
            return (NSColor(red: 0.345, green: 0.396, blue: 0.941, alpha: 1.0), .white, "D") // #5865F0
        } else if domain.contains("spotify.com") {
            return (NSColor(red: 0.114, green: 0.725, blue: 0.329, alpha: 1.0), .white, "♫") // #1DB954
        } else if domain.contains("music.apple.com") {
            return (NSColor(red: 0.984, green: 0.259, blue: 0.573, alpha: 1.0), .white, "♪") // #FB4292
        } else if domain.contains("figma.com") {
            return (NSColor(red: 0.945, green: 0.329, blue: 0.196, alpha: 1.0), .white, "F") // #F14332
        } else if domain.contains("behance.net") {
            return (NSColor(red: 0.0, green: 0.388, blue: 1.0, alpha: 1.0), .white, "Be") // #0063FF
        } else if domain.contains("dribbble.com") {
            return (NSColor(red: 0.918, green: 0.267, blue: 0.537, alpha: 1.0), .white, "D") // #EA4489
        } else if domain.contains("coursera.org") {
            return (NSColor(red: 0.071, green: 0.282, blue: 0.804, alpha: 1.0), .white, "C") // #1248CD
        } else if domain.contains("developer.apple.com") {
            return (NSColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 1.0), .white, "🔨") // #007AFF
        } else {
            // Use first letter of title or domain with a nice default color
            let firstLetter = String(bookmark.title.prefix(1)).uppercased()
            let fallbackLetter = firstLetter.isEmpty ? String(domain.prefix(1)).uppercased() : firstLetter
            return (NSColor(red: 0.478, green: 0.573, blue: 0.729, alpha: 1.0), .white, fallbackLetter) // #7A92BA
        }
    }
    
    @objc private func bookmarkClicked(_ sender: NSButton) {
        guard sender.tag >= 0, sender.tag < group.bookmarks.count else { 
            print("❌ Invalid tag or bookmark index: tag=\(sender.tag), count=\(group.bookmarks.count)")
            return 
        }
        let bookmark = group.bookmarks[sender.tag]
        print("🎯 FavoriteGroupView: bookmark clicked: \(bookmark.title) -> \(bookmark.url)")
        
        // Find the parent SidebarFavoritesView to pass to delegate
        var parentView: SidebarFavoritesView?
        var currentView: NSView? = self
        while currentView != nil {
            if let favoritesView = currentView as? SidebarFavoritesView {
                parentView = favoritesView
                break
            }
            currentView = currentView?.superview
        }
        
        if let parentView = parentView, let delegate = delegate {
            print("✅ FavoriteGroupView: calling delegate with bookmark: \(bookmark.title)")
            delegate.sidebarFavoritesView(parentView, didClickFavorite: bookmark)
        } else {
            print("❌ FavoriteGroupView: parentView=\(parentView != nil), delegate=\(delegate != nil)")
        }
    }
}

class SidebarFavoritesView: NSView {
    weak var delegate: SidebarFavoritesViewDelegate? {
        didSet {
            print("🔗 SidebarFavoritesView.delegate set to: \(delegate != nil ? "✅" : "❌")")
            updateGroupDelegates()
        }
    }
    
    private var stackView: NSStackView!
    
    // Traditional favorites section (from BookmarkManager)
    private var favoritesHeaderLabel: NSTextField!
    private var favoritesStackView: NSStackView!
    private var favoriteButtons: [NSButton] = []
    private var favoriteBookmarks: [Bookmark] = []  // Keep track of bookmarks for button mapping
    
    // Grouped favorites section
    private var favoriteGroups: [FavoriteGroup] = []
    private var groupViews: [FavoriteGroupView] = []
    
    // Track which favorite is currently active/selected
    private var activeFavoriteButton: NSButton?
    
    // Drag-to-remove state
    private var draggedOutsideStartTime: Date?
    private var isDragActive = false
    private var dragStartPoint: NSPoint = NSPoint.zero
    
    // Drag-to-swap state
    private var potentialSwapTarget: NSButton?
    private var isSwapAnimationActive = false
    private var currentSwapTarget: NSButton?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        print("🏗️ SidebarFavoritesView init - delegate: \(delegate != nil ? "✅" : "❌")")
        setupView()
        loadFavoriteGroups()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
        loadFavoriteGroups()
    }
    
    private func setupView() {
        wantsLayer = true
        
        // Create main container stack view for vertical layout (Arc-style)
        stackView = NSStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .vertical
        stackView.spacing = 4
        stackView.alignment = .leading
        stackView.distribution = .fill
        
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6)
        ])
        
        // Setup traditional favorites section
        setupTraditionalFavorites()
        
        // Register for drag and drop
        registerForDraggedTypes([NSPasteboard.PasteboardType("BrowserTab"), .string, .URL])
        
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(bookmarksUpdated),
            name: .bookmarksUpdated,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(favoriteGroupsUpdated),
            name: .favoriteGroupsUpdated,
            object: nil
        )
    }
    
    @objc private func bookmarksUpdated() {
        loadTraditionalFavorites()
        loadFavoriteGroups()
    }
    
    @objc private func favoriteGroupsUpdated() {
        loadFavoriteGroups()
    }
    
    private func setupTraditionalFavorites() {
        // Header label for favorites section
        favoritesHeaderLabel = NSTextField(labelWithString: "Favoriter")
        favoritesHeaderLabel.translatesAutoresizingMaskIntoConstraints = false
        favoritesHeaderLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        favoritesHeaderLabel.textColor = ColorManager.secondaryText
        
        // Stack view for favorite icon buttons (vertical container for rows)
        favoritesStackView = NSStackView()
        favoritesStackView.translatesAutoresizingMaskIntoConstraints = false
        favoritesStackView.orientation = .vertical
        favoritesStackView.spacing = 4  // Less spacing between rows
        favoritesStackView.alignment = .leading
        favoritesStackView.distribution = .fill
        
        // Add to main stack view
        stackView.addArrangedSubview(favoritesHeaderLabel)
        stackView.addArrangedSubview(favoritesStackView)
        
        // Constraints
        NSLayoutConstraint.activate([
            favoritesHeaderLabel.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
            favoritesHeaderLabel.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),
            
            favoritesStackView.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
            favoritesStackView.trailingAnchor.constraint(lessThanOrEqualTo: stackView.trailingAnchor)
        ])
        
        // Load initial favorites
        loadTraditionalFavorites()
    }
    
    private func loadTraditionalFavorites() {
        // Clear existing favorite buttons and rows
        favoriteButtons.forEach { $0.removeFromSuperview() }
        favoriteButtons.removeAll()
        favoriteBookmarks.removeAll()
        favoritesStackView.arrangedSubviews.forEach { 
            favoritesStackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        
        // Get bookmarks from BookmarkManager
        guard let bookmarksBarFolder = BookmarkManager.shared.getBookmarksBarFolder() else { return }
        
        // Group bookmarks into rows of 4 (ENFORCED LIMIT)
        let bookmarks = bookmarksBarFolder.bookmarks
        let iconsPerRow = 4
        let maxFavorites = 16 // Max 4 rows of 4 favorites each
        let limitedBookmarks = Array(bookmarks.prefix(maxFavorites))
        
        // If no favorites, show empty container with drag hint
        if limitedBookmarks.isEmpty {
            createEmptyFavoritesContainer()
            return
        }
        
        for rowIndex in stride(from: 0, to: limitedBookmarks.count, by: iconsPerRow) {
            // Create horizontal stack view for this row
            let rowStackView = NSStackView()
            rowStackView.translatesAutoresizingMaskIntoConstraints = false
            rowStackView.orientation = .horizontal
            rowStackView.spacing = 6  // Less space between icons horizontally
            rowStackView.alignment = .top
            rowStackView.distribution = .fill
            
            // Add up to 4 buttons to this row
            let endIndex = min(rowIndex + iconsPerRow, limitedBookmarks.count)
            for buttonIndex in rowIndex..<endIndex {
                let bookmark = limitedBookmarks[buttonIndex]
                let button = createTraditionalFavoriteButton(for: bookmark, at: buttonIndex)
                favoriteButtons.append(button)
                favoriteBookmarks.append(bookmark)
                rowStackView.addArrangedSubview(button)
            }
            
            // Add row to main favorites stack view
            favoritesStackView.addArrangedSubview(rowStackView)
            
            // Set height constraint for the row
            NSLayoutConstraint.activate([
                rowStackView.heightAnchor.constraint(equalToConstant: 52)  // Slightly more space for larger icons
            ])
        }
        
        // Show warning if there are more than max favorites
        if bookmarks.count > maxFavorites {
            print("⚠️ Too many favorites (\(bookmarks.count)). Only showing first \(maxFavorites).")
        }
        
        // Keep header visible always (user should see "Favoriter" section even when empty)
        favoritesHeaderLabel.isHidden = false
    }
    
    private func createEmptyFavoritesContainer() {
        // Create empty container that shows drag-and-drop hint
        let emptyContainer = NSView()
        emptyContainer.translatesAutoresizingMaskIntoConstraints = false
        emptyContainer.wantsLayer = true
        
        // Subtle border and background to indicate drop zone
        emptyContainer.layer?.borderWidth = 1
        emptyContainer.layer?.borderColor = ColorManager.secondaryText.withAlphaComponent(0.3).cgColor
        emptyContainer.layer?.backgroundColor = ColorManager.secondaryBackground.withAlphaComponent(0.5).cgColor
        emptyContainer.layer?.cornerRadius = 8
        
        // Create icon hint (just the plus icon, no text)
        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = NSImage(systemSymbolName: "plus.circle.dashed", accessibilityDescription: "Add favorites")
        iconView.contentTintColor = ColorManager.secondaryText.withAlphaComponent(0.5)
        iconView.imageScaling = .scaleProportionallyDown
        
        // Add to container
        emptyContainer.addSubview(iconView)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            // Icon centered in container
            iconView.centerXAnchor.constraint(equalTo: emptyContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: emptyContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
            
            // Container size
            emptyContainer.heightAnchor.constraint(equalToConstant: 60)
        ])
        
        // Add to favorites stack view
        favoritesStackView.addArrangedSubview(emptyContainer)
        
        print("📋 Created empty favorites container with drag hint")
    }
    
    private func createTraditionalFavoriteButton(for bookmark: Bookmark, at index: Int) -> NSButton {
        let button = NSButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.title = ""
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.target = self
        button.action = #selector(traditionalFavoriteClicked(_:))
        button.toolTip = bookmark.title + "\n" + bookmark.url.absoluteString
        
        // Store bookmark index using tag
        button.tag = index
        
        // Create icon view
        let iconView = NSView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.wantsLayer = true
        iconView.layer?.cornerRadius = 8  // More rounded like iOS icons
        iconView.layer?.borderWidth = 0  // Start with no border
        iconView.layer?.borderColor = ColorManager.primaryText.withAlphaComponent(0.3).cgColor
        
        // Get colors for this domain (always keep the colored background!)
        let (backgroundColor, textColor, iconText) = getIconStyle(for: bookmark)
        iconView.layer?.backgroundColor = backgroundColor.cgColor
        
        // Try to use existing favicon first, otherwise fetch it
        if let existingFavicon = bookmark.favicon {
            setupFaviconWithColoredBackground(iconView: iconView, favicon: existingFavicon, backgroundColor: backgroundColor, fallbackText: iconText, fallbackTextColor: textColor)
        } else {
            // Show fallback text while loading favicon
            setupFallbackIconView(iconView: iconView, backgroundColor: backgroundColor, textColor: textColor, iconText: iconText)
            
            // Fetch real favicon asynchronously
            bookmark.loadFavicon { [weak self, weak iconView] in
                guard let self = self, let iconView = iconView else { return }
                
                // Clear existing content but keep background color
                iconView.subviews.forEach { $0.removeFromSuperview() }
                
                if let favicon = bookmark.favicon {
                    self.setupFaviconWithColoredBackground(iconView: iconView, favicon: favicon, backgroundColor: backgroundColor, fallbackText: iconText, fallbackTextColor: textColor)
                } else {
                    // Still use fallback text if favicon fetch failed
                    self.setupFallbackIconView(iconView: iconView, backgroundColor: backgroundColor, textColor: textColor, iconText: iconText)
                }
            }
        }
        
        button.addSubview(iconView)
        
        // Add hover tracking for border effect
        let trackingArea = NSTrackingArea(
            rect: NSRect(x: 0, y: 0, width: 44, height: 44),
            options: [.mouseEnteredAndExited, .activeInKeyWindow],
            owner: self,
            userInfo: ["favoriteButton": button, "iconView": iconView]
        )
        button.addTrackingArea(trackingArea)
        
        // Enable drag source for favorite removal
        let dragGestureRecognizer = NSPanGestureRecognizer(target: self, action: #selector(handleFavoriteDrag(_:)))
        button.addGestureRecognizer(dragGestureRecognizer)
        
        // Constraints - make icons larger with less spacing
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 44),
            button.heightAnchor.constraint(equalToConstant: 44),
            
            iconView.topAnchor.constraint(equalTo: button.topAnchor),
            iconView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            iconView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            iconView.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        
        return button
    }
    
    // MARK: - Helper methods for favicon display
    private func setupFaviconWithColoredBackground(iconView: NSView, favicon: NSImage, backgroundColor: NSColor, fallbackText: String, fallbackTextColor: NSColor) {
        // Background is already set by caller
        
        // Try to show the real favicon, but with some smart sizing
        let imageView = NSImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = favicon
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        
        // Make favicon much smaller like in the reference image
        let inset: CGFloat = 8
        
        iconView.addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: iconView.topAnchor, constant: inset),
            imageView.leadingAnchor.constraint(equalTo: iconView.leadingAnchor, constant: inset),
            imageView.trailingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: -inset),
            imageView.bottomAnchor.constraint(equalTo: iconView.bottomAnchor, constant: -inset)
        ])
        
        // For some favicons that might be too small or unclear, check if we should show fallback text instead
        // This is mainly for sites that don't have good quality favicons
        if shouldUseFallbackText(for: iconView, favicon: favicon) {
            imageView.removeFromSuperview()
            setupFallbackIconView(iconView: iconView, backgroundColor: backgroundColor, textColor: fallbackTextColor, iconText: fallbackText)
        }
    }
    
    private func shouldUseFallbackText(for iconView: NSView, favicon: NSImage) -> Bool {
        // Only use fallback for very small or poor quality favicons
        // Most real favicons should be displayed
        return favicon.size.width < 16 || favicon.size.height < 16
    }
    
    private func setupFallbackIconView(iconView: NSView, backgroundColor: NSColor, textColor: NSColor, iconText: String) {
        // Background is already set by caller
        
        let iconLabel = NSTextField(labelWithString: iconText)
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        iconLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)  // Slightly larger and less bold
        iconLabel.textColor = textColor
        iconLabel.alignment = .center
        iconLabel.isBezeled = false
        iconLabel.isEditable = false
        iconLabel.isSelectable = false
        iconLabel.backgroundColor = .clear
        
        iconView.addSubview(iconLabel)
        
        NSLayoutConstraint.activate([
            iconLabel.centerXAnchor.constraint(equalTo: iconView.centerXAnchor),
            iconLabel.centerYAnchor.constraint(equalTo: iconView.centerYAnchor)
        ])
    }
    
    private func getIconStyle(for bookmark: Bookmark) -> (NSColor, NSColor, String) {
        let domain = bookmark.url.host?.lowercased() ?? ""
        
        // Return (backgroundColor, textColor, iconText) - EXACT brand colors!
        if domain.contains("youtube.com") {
            return (NSColor(red: 0.898, green: 0.0, blue: 0.0, alpha: 1.0), .white, "▶") // #E50000
        } else if domain.contains("netflix.com") {
            return (NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0), .white, "N") // #000000 (svart bakgrund)
        } else if domain.contains("linkedin.com") {
            return (NSColor(red: 0.0, green: 0.475, blue: 0.714, alpha: 1.0), .white, "in") // #0077B6
        } else if domain.contains("facebook.com") {
            return (NSColor(red: 0.145, green: 0.416, blue: 0.773, alpha: 1.0), .white, "f") // #1877F2 (nyare blå)
        } else if domain.contains("github.com") {
            return (NSColor(red: 0.067, green: 0.067, blue: 0.067, alpha: 1.0), .white, "⚡") // #111111
        } else if domain.contains("chatgpt.com") || domain.contains("openai.com") {
            return (NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0), .black, "GPT") // #FFFFFF (vit bakgrund)
        } else if domain.contains("gmail") || domain.contains("mail.google") {
            return (NSColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0), .white, "M") // #808080 (grå bakgrund)
        } else if domain.contains("google.com") {
            return (NSColor(red: 0.259, green: 0.522, blue: 0.957, alpha: 1.0), .white, "G") // #4285F4
        } else if domain.contains("apple.com") {
            return (NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0), .white, "") // #000000
        } else if domain.contains("twitter.com") || domain.contains("x.com") {
            return (NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0), .white, "𝕏") // X är nu svart
        } else if domain.contains("instagram.com") {
            return (NSColor(red: 0.886, green: 0.243, blue: 0.643, alpha: 1.0), .white, "◉") // #E23EA4 (rosa från gradient)
        } else if domain.contains("discord.com") {
            return (NSColor(red: 0.345, green: 0.384, blue: 0.918, alpha: 1.0), .white, "◆") // #5865EA
        } else if domain.contains("spotify.com") {
            return (NSColor(red: 0.114, green: 0.725, blue: 0.329, alpha: 1.0), .white, "♪") // #1DB954
        } else if domain.contains("figma.com") {
            return (NSColor(red: 0.945, green: 0.357, blue: 0.224, alpha: 1.0), .white, "◉") // #F15B39
        } else if domain.contains("notion.so") {
            return (NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0), .white, "N") // #000000
        } else if domain.contains("slack.com") {
            return (NSColor(red: 0.286, green: 0.176, blue: 0.467, alpha: 1.0), .white, "#") // #492D77
        } else if domain.contains("microsoft.com") || domain.contains("outlook.com") {
            return (NSColor(red: 0.0, green: 0.471, blue: 0.827, alpha: 1.0), .white, "◉") // #0078D3
        } else if domain.contains("tiktok.com") {
            return (NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0), .white, "♬") // #000000
        } else if domain.contains("pinterest.com") {
            return (NSColor(red: 0.741, green: 0.063, blue: 0.192, alpha: 1.0), .white, "P") // #BD081C
        } else if domain.contains("reddit.com") {
            return (NSColor(red: 1.0, green: 0.271, blue: 0.0, alpha: 1.0), .white, "r") // #FF4500
        } else if domain.contains("whatsapp.com") {
            return (NSColor(red: 0.149, green: 0.776, blue: 0.376, alpha: 1.0), .white, "W") // #25D366
        } else if domain.contains("zoom.us") {
            return (NSColor(red: 0.133, green: 0.455, blue: 0.949, alpha: 1.0), .white, "Z") // #2274F2
        } else if domain.contains("dropbox.com") {
            return (NSColor(red: 0.0, green: 0.467, blue: 0.988, alpha: 1.0), .white, "D") // #0077FC
        } else if domain.contains("amazon.com") {
            return (NSColor(red: 1.0, green: 0.625, blue: 0.0, alpha: 1.0), .black, "A") // #FF9F00
        } else {
            // Use first letter of title or domain with a nice default color
            let firstLetter = String(bookmark.title.prefix(1)).uppercased()
            let fallbackLetter = firstLetter.isEmpty ? String(domain.prefix(1)).uppercased() : firstLetter
            return (NSColor(red: 0.478, green: 0.573, blue: 0.729, alpha: 1.0), .white, fallbackLetter) // #7A92BA
        }
    }
    
    @objc private func traditionalFavoriteClicked(_ sender: NSButton) {
        guard sender.tag >= 0 && sender.tag < favoriteBookmarks.count else { return }
        let bookmark = favoriteBookmarks[sender.tag]
        delegate?.sidebarFavoritesView(self, didClickFavorite: bookmark)
    }
    
    // MARK: - Hover Effects for Favorite Icons
    override func mouseEntered(with event: NSEvent) {
        guard let trackingArea = event.trackingArea,
              let iconView = trackingArea.userInfo?["iconView"] as? NSView else { return }
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            
            // Add subtle border on hover
            iconView.layer?.borderWidth = 2
            
            // Slightly scale up the icon
            iconView.layer?.transform = CATransform3DMakeScale(1.05, 1.05, 1.0)
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        guard let trackingArea = event.trackingArea,
              let iconView = trackingArea.userInfo?["iconView"] as? NSView else { return }
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            
            // Remove border
            iconView.layer?.borderWidth = 0
            
            // Reset scale
            iconView.layer?.transform = CATransform3DIdentity
        }
    }
    
    func loadFavoriteGroups() {
        // Clear existing group views (but keep favorites section)
        groupViews.forEach { $0.removeFromSuperview() }
        groupViews.removeAll()
        
        // Remove only group views from stack view, keep favorites
        let arrangedSubviews = stackView.arrangedSubviews
        for subview in arrangedSubviews {
            // Only remove group views, not favorites header or stack
            if subview != favoritesHeaderLabel && subview != favoritesStackView {
                stackView.removeArrangedSubview(subview)
                subview.removeFromSuperview()
            }
        }
        
        // Force layout update to remove any gaps
        stackView.needsUpdateConstraints = true
        stackView.needsLayout = true
        
        // Load groups from BookmarkManager
        favoriteGroups = BookmarkManager.shared.favoriteGroups
        
        // Add a small separator between favorites and groups (if favorites exist)
        if !favoriteButtons.isEmpty {
            let separator = NSView()
            separator.translatesAutoresizingMaskIntoConstraints = false
            separator.heightAnchor.constraint(equalToConstant: 4).isActive = true
            stackView.addArrangedSubview(separator)
        }
        
        // Create group views with Arc-style spacing
        for (index, group) in favoriteGroups.enumerated() {
            let groupView = FavoriteGroupView(group: group)
            groupView.delegate = delegate
            print("🔗 Setting delegate for group: \(group.name), delegate: \(delegate != nil ? "✅" : "❌")")
            groupViews.append(groupView)
            stackView.addArrangedSubview(groupView)
            
            // Add minimal spacing between groups (except last one)
            if index < favoriteGroups.count - 1 {
                let spacer = NSView()
                spacer.translatesAutoresizingMaskIntoConstraints = false
                spacer.heightAnchor.constraint(equalToConstant: 2).isActive = true
                stackView.addArrangedSubview(spacer)
            }
            
            // Full width constraints
            groupView.leadingAnchor.constraint(equalTo: stackView.leadingAnchor).isActive = true
            groupView.trailingAnchor.constraint(equalTo: stackView.trailingAnchor).isActive = true
        }
        
        // Setup context menu for creating groups
        setupContextMenu()
    }
    
    private func setupContextMenu() {
        // Create context menu
        let menu = NSMenu()
        
        // Add group menu item
        let addGroupItem = NSMenuItem(title: "Lägg till grupp", action: #selector(showAddGroupDialog), keyEquivalent: "")
        addGroupItem.target = self
        if let image = NSImage(systemSymbolName: "folder.badge.plus", accessibilityDescription: "Lägg till grupp") {
            image.size = NSSize(width: 16, height: 16)
            addGroupItem.image = image
        }
        menu.addItem(addGroupItem)
        
        // Add separator
        menu.addItem(NSMenuItem.separator())
        
        // Add other menu items for future functionality
        let refreshItem = NSMenuItem(title: "Uppdatera favoriter", action: #selector(refreshFavorites), keyEquivalent: "")
        refreshItem.target = self
        if let image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Uppdatera") {
            image.size = NSSize(width: 16, height: 16)
            refreshItem.image = image
        }
        menu.addItem(refreshItem)
        
        // Set the menu
        self.menu = menu
    }
    
    @objc private func refreshFavorites() {
        print("🔄 Refreshing favorites...")
        loadTraditionalFavorites()
        loadFavoriteGroups()
    }
    
    // MARK: - Mouse Events for Context Menu
    override func mouseDown(with event: NSEvent) {
        // Check if Control key is held down
        if event.modifierFlags.contains(.control) {
            print("🖱️ Ctrl+click detected - showing context menu")
            
            // Show context menu at mouse location
            guard let menu = self.menu else {
                super.mouseDown(with: event)
                return
            }
            
            // We don't need the mouse location for NSMenu.popUpContextMenu
            
            // Show the context menu
            NSMenu.popUpContextMenu(menu, with: event, for: self)
            return
        }
        
        // Normal click behavior
        super.mouseDown(with: event)
    }
    
    override var intrinsicContentSize: NSSize {
        return NSSize(width: NSView.noIntrinsicMetric, height: stackView.fittingSize.height + 12)
    }
    
    // MARK: - Drag and Drop Support
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        // Check if we're dragging a tab or URL
        let pasteboard = sender.draggingPasteboard
        
        if pasteboard.types?.contains(NSPasteboard.PasteboardType("BrowserTab")) == true ||
           pasteboard.types?.contains(.URL) == true ||
           pasteboard.types?.contains(.string) == true {
            
            // Check if we have space for more favorites (max 16)
            guard let bookmarksBarFolder = BookmarkManager.shared.getBookmarksBarFolder() else {
                return []
            }
            
            if bookmarksBarFolder.bookmarks.count >= 16 {
                print("⚠️ Maximum number of favorites reached (16)")
                return []
            }
            
            // Highlight the favorites area
            addDropHighlight()
            return .copy
        }
        
        return []
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        removeDropHighlight()
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        // Check if we have space for more favorites
        guard let bookmarksBarFolder = BookmarkManager.shared.getBookmarksBarFolder() else {
            return []
        }
        
        if bookmarksBarFolder.bookmarks.count >= 16 {
            return []
        }
        
        return .copy
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        removeDropHighlight()
        
        // Handle tab drag
        if let jsonString = pasteboard.string(forType: NSPasteboard.PasteboardType("BrowserTab")) {
            print("📦 Received BrowserTab data: \(jsonString)")
            return handleTabDrop(jsonData: jsonString)
        }
        
        // Handle URL drag
        if let url = pasteboard.readObjects(forClasses: [NSURL.self], options: nil)?.first as? URL {
            return handleURLDrop(url: url)
        }
        
        // Handle string data drag (could be JSON from tab or plain URL)
        if let stringData = pasteboard.string(forType: .string) {
            // Try to parse as JSON first (tab data)
            if stringData.contains("tab_id") && stringData.contains("{") {
                print("📦 Received string tab data: \(stringData)")
                return handleTabDrop(jsonData: stringData)
            }
            // Otherwise treat as URL
            else if let url = URL(string: stringData) {
                return handleURLDrop(url: url)
            }
        }
        
        return false
    }
    
    private func handleTabDrop(jsonData: String) -> Bool {
        // Parse JSON data
        guard let data = jsonData.data(using: .utf8),
              let tabData = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let tabIDString = tabData["tab_id"],
              let tabID = UUID(uuidString: tabIDString),
              let tabTitle = tabData["tab_title"],
              let tabURLString = tabData["tab_url"],
              let tabURL = URL(string: tabURLString) else {
            print("❌ Failed to parse tab data: \(jsonData)")
            return false
        }
        
        print("📋 Parsed tab data - ID: \(tabID), Title: \(tabTitle), URL: \(tabURL)")
        
        // Find the tab by ID to get favicon
        let tab = TabManager.shared.getAllTabs().first(where: { $0.id == tabID })
        
        // Create bookmark from parsed data
        let bookmark = Bookmark(title: tabTitle, url: tabURL)
        bookmark.favicon = tab?.favicon  // Use tab favicon if available
        
        // Add to favorites
        BookmarkManager.shared.addBookmark(bookmark)
        
        // Refresh the favorites display
        DispatchQueue.main.async {
            self.loadTraditionalFavorites()
        }
        
        print("✅ Added tab '\(tabTitle)' to favorites")
        return true
    }
    
    private func handleURLDrop(url: URL) -> Bool {
        // Create bookmark from URL
        let title = url.host ?? url.absoluteString
        let bookmark = Bookmark(title: title, url: url)
        
        // Load favicon
        bookmark.loadFavicon()
        
        // Add to favorites
        BookmarkManager.shared.addBookmark(bookmark)
        
        // Refresh the favorites display
        DispatchQueue.main.async {
            self.loadTraditionalFavorites()
        }
        
        print("✅ Added URL '\(url.absoluteString)' to favorites")
        return true
    }
    
    private func addDropHighlight() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            favoritesStackView.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.1).cgColor
            favoritesStackView.layer?.borderWidth = 2
            favoritesStackView.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.5).cgColor
            favoritesStackView.layer?.cornerRadius = 8
        }
    }
    
    private func removeDropHighlight() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            favoritesStackView.layer?.backgroundColor = NSColor.clear.cgColor
            favoritesStackView.layer?.borderWidth = 0
        }
    }
    
    // MARK: - Favorite Drag-to-Remove
    
    @objc private func handleFavoriteDrag(_ recognizer: NSPanGestureRecognizer) {
        guard let button = recognizer.view as? NSButton,
              let index = favoriteButtons.firstIndex(of: button),
              index < favoriteBookmarks.count else { return }
        
        let bookmark = favoriteBookmarks[index]
        
        switch recognizer.state {
        case .began:
            // Just record the start point, don't start drag yet
            dragStartPoint = recognizer.location(in: self)
            isDragActive = false
            
        case .changed:
            let currentPoint = recognizer.location(in: self)
            let distance = sqrt(pow(currentPoint.x - dragStartPoint.x, 2) + pow(currentPoint.y - dragStartPoint.y, 2))
            
            // Only start drag if we've moved more than 5 pixels
            if !isDragActive && distance > 5 {
                isDragActive = true
                startFavoriteDrag(button: button, bookmark: bookmark)
                print("🎯 Drag activated after \(distance) pixels")
            }
            
            if isDragActive {
                updateFavoriteDrag(recognizer: recognizer, button: button)
            }
            
        case .ended:
            if isDragActive {
                endFavoriteDrag(recognizer: recognizer, button: button, bookmark: bookmark)
            }
            isDragActive = false
            
        case .cancelled, .failed:
            if isDragActive {
                cancelFavoriteDrag(button: button)   
            }
            isDragActive = false
            
        default:
            break
        }
    }
    
    private func startFavoriteDrag(button: NSButton, bookmark: Bookmark) {
        // Reset drag state
        draggedOutsideStartTime = nil
        
        // Scale down the button to indicate dragging
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            button.layer?.transform = CATransform3DMakeScale(0.8, 0.8, 1.0)
            button.alphaValue = 0.7
        }
        
        print("🎯 Started dragging favorite: \(bookmark.title)")
    }
    
    private func updateFavoriteDrag(recognizer: NSPanGestureRecognizer, button: NSButton) {
        let translation = recognizer.translation(in: self)
        
        // Move the button with the drag
        button.layer?.transform = CATransform3DConcat(
            CATransform3DMakeScale(0.8, 0.8, 1.0),
            CATransform3DMakeTranslation(translation.x, translation.y, 0)
        )
        
        // Check if we're dragging outside the favorites area (for removal)
        let buttonFrame = button.frame
        let buttonCenter = NSPoint(x: buttonFrame.midX + translation.x, y: buttonFrame.midY + translation.y)
        let favoritesFrame = self.bounds  // Use the entire SidebarFavoritesView bounds
        
        let isOutsideFavorites = !favoritesFrame.contains(buttonCenter)
        
        if isOutsideFavorites {
            // Clear any swap target when outside
            clearSwapTarget()
            
            // Start timer if not already started
            if draggedOutsideStartTime == nil {
                draggedOutsideStartTime = Date()
                print("⏱️ Started drag-outside timer for: \(button.tag)")
            }
            
            // Check if we've been outside for 1 second
            let timeOutside = Date().timeIntervalSince(draggedOutsideStartTime!)
            if timeOutside >= 1.0 {
                button.alphaValue = 0.3  // Ready to delete
                print("💀 Ready to delete - held for \(timeOutside) seconds")
            } else {
                button.alphaValue = 0.5  // Getting ready to delete
            }
        } else {
            // Reset timer when back inside
            if draggedOutsideStartTime != nil {
                print("↩️ Back inside favorites area - resetting timer")
            }
            draggedOutsideStartTime = nil
            button.alphaValue = 0.7
            
            // Check for potential swap target
            findSwapTarget(draggedButton: button, at: buttonCenter)
        }
    }
    
    private func endFavoriteDrag(recognizer: NSPanGestureRecognizer, button: NSButton, bookmark: Bookmark) {
        let translation = recognizer.translation(in: self)
        
        // Check if we dragged outside and the remove indicator is showing
        let buttonFrame = button.frame
        let buttonCenter = NSPoint(x: buttonFrame.midX + translation.x, y: buttonFrame.midY + translation.y)
        let favoritesFrame = self.bounds  // Use the entire SidebarFavoritesView bounds
        let isOutsideFavorites = !favoritesFrame.contains(buttonCenter)
        
        print("🏁 End drag for: \(bookmark.title)")
        print("   buttonCenter: \(buttonCenter)")
        print("   favoritesFrame: \(favoritesFrame)")
        print("   isOutsideFavorites: \(isOutsideFavorites)")
        print("   draggedOutsideStartTime: \(draggedOutsideStartTime != nil ? "set" : "nil")")
        print("   potentialSwapTarget: \(potentialSwapTarget != nil ? "set" : "nil")")
        
        // Check what operation to perform
        if isOutsideFavorites && draggedOutsideStartTime != nil {
            let timeOutside = Date().timeIntervalSince(draggedOutsideStartTime!)
            if timeOutside >= 1.0 {
                // Remove the favorite
                removeFavorite(bookmark)
                print("🗑️ Removed favorite: \(bookmark.title) - held outside for \(timeOutside) seconds")
            } else {
                // Reset button position - not held long enough
                resetFavoriteButton(button)
                print("↩️ Reset favorite: \(bookmark.title) - only held outside for \(timeOutside) seconds")
            }
        } else if let swapTarget = potentialSwapTarget {
            // Perform swap operation
            performSwap(draggedButton: button, swapTarget: swapTarget)
            print("🔄 Swapping favorites")
        } else {
            // Reset button position - normal drag within favorites area
            resetFavoriteButton(button)
            print("↩️ Reset favorite: \(bookmark.title) - normal drag within area")
        }
        
        // Clean up drag state
        draggedOutsideStartTime = nil
        clearSwapTarget()
    }
    
    private func cancelFavoriteDrag(button: NSButton) {
        draggedOutsideStartTime = nil
        clearSwapTarget()
        resetFavoriteButton(button)
    }
    
    private func resetFavoriteButton(_ button: NSButton) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            button.layer?.transform = CATransform3DIdentity
            button.alphaValue = 1.0
        }
    }
    
    private func removeFavorite(_ bookmark: Bookmark) {
        BookmarkManager.shared.removeBookmark(bookmark)
        
        // Refresh the favorites display
        DispatchQueue.main.async {
            self.loadTraditionalFavorites()
        }
        
        print("✅ Favorite removed from BookmarkManager")
    }
    
    private func updateGroupDelegates() {
        print("🔗 updateGroupDelegates called - updating \(groupViews.count) group views")
        for groupView in groupViews {
            groupView.delegate = delegate
            print("🔗 Updated delegate for group view")
        }
    }
    
    // MARK: - Swap functionality
    
    private func findSwapTarget(draggedButton: NSButton, at point: NSPoint) {
        var closestButton: NSButton?
        var closestDistance: CGFloat = CGFloat.greatestFiniteMagnitude
        
        // Check all favorite buttons except the dragged one
        for button in favoriteButtons {
            if button == draggedButton { continue }
            
            let buttonCenter = NSPoint(x: button.frame.midX, y: button.frame.midY)
            let distance = sqrt(pow(point.x - buttonCenter.x, 2) + pow(point.y - buttonCenter.y, 2))
            
            // Consider buttons within 30 pixels as potential swap targets
            if distance < 30 && distance < closestDistance {
                closestDistance = distance
                closestButton = button
            }
        }
        
        // Update swap target if changed
        if closestButton != potentialSwapTarget {
            clearSwapTarget()
            
            if let newTarget = closestButton {
                potentialSwapTarget = newTarget
                animateSwapPreview(draggedButton: draggedButton, swapTarget: newTarget)
                print("🎯 Found swap target: button at distance \(closestDistance)")
            }
        }
    }
    
    private func highlightSwapTarget(_ button: NSButton) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            button.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.3).cgColor
            button.layer?.borderWidth = 2
            button.layer?.borderColor = NSColor.controlAccentColor.cgColor
        }
    }
    
    private func clearSwapTarget() {
        // Reset any current swap target animation
        if let currentTarget = currentSwapTarget {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.5  // Längre duration för smidigare återställning
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 0.1, 0.25, 1.0)  // Samma mjuka curve
                currentTarget.layer?.transform = CATransform3DIdentity
                currentTarget.layer?.backgroundColor = NSColor.clear.cgColor
                currentTarget.layer?.borderWidth = 0
            }
        }
        
        potentialSwapTarget = nil
        currentSwapTarget = nil
        isSwapAnimationActive = false
    }
    
    private func animateSwapPreview(draggedButton: NSButton, swapTarget: NSButton) {
        guard !isSwapAnimationActive else { return }
        
        isSwapAnimationActive = true
        currentSwapTarget = swapTarget
        
        // Get the original positions
        let draggedOriginalFrame = draggedButton.frame
        let swapOriginalFrame = swapTarget.frame
        
        // Calculate offset to move swap target to where dragged button originally was
        let swapTargetOffset = NSPoint(
            x: draggedOriginalFrame.midX - swapOriginalFrame.midX,
            y: draggedOriginalFrame.midY - swapOriginalFrame.midY
        )
        
        print("🎬 Animating swap preview - moving target to dragged position")
        
        // Animate the swap target to the dragged button's original position
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.6  // Längre duration för smidigare animation
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 0.1, 0.25, 1.0)  // Mjuk easing curve
            
            // Move swap target to dragged button's original position
            swapTarget.layer?.transform = CATransform3DMakeTranslation(
                swapTargetOffset.x, 
                swapTargetOffset.y, 
                0
            )
            
            // Add subtle highlight to show it's the swap target
            swapTarget.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
            swapTarget.layer?.borderWidth = 1
            swapTarget.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.6).cgColor
        }
    }
    
    private func performSwap(draggedButton: NSButton, swapTarget: NSButton) {
        guard let draggedIndex = favoriteButtons.firstIndex(of: draggedButton),
              let swapIndex = favoriteButtons.firstIndex(of: swapTarget),
              draggedIndex < favoriteBookmarks.count,
              swapIndex < favoriteBookmarks.count else {
            print("❌ Invalid button indices for swap")
            resetFavoriteButton(draggedButton)
            return
        }
        
        let draggedBookmark = favoriteBookmarks[draggedIndex]
        let swapBookmark = favoriteBookmarks[swapIndex]
        
        print("✅ Finalizing swap between favorites at indices \(draggedIndex) and \(swapIndex)")
        
        // Perform the actual swap in BookmarkManager
        BookmarkManager.shared.swapBookmarks(draggedBookmark, swapBookmark)
        
        // Smooth animation to finalize positions
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.4  // Längre för smidigare slutanimation
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 0.1, 0.25, 1.0)  // Samma mjuka curve
            
            // Reset dragged button to normal state
            draggedButton.layer?.transform = CATransform3DIdentity
            draggedButton.alphaValue = 1.0
            
            // Reset swap target to normal state  
            swapTarget.layer?.transform = CATransform3DIdentity
            swapTarget.layer?.backgroundColor = NSColor.clear.cgColor
            swapTarget.layer?.borderWidth = 0
            
        } completionHandler: {
            // Refresh favorites to show new order
            self.loadTraditionalFavorites()
        }
    }
    
    // MARK: - Add Group Dialog
    
    @objc private func showAddGroupDialog() {
        print("🆕 Showing add group dialog")
        
        // Create and configure the add group view controller
        let addGroupViewController = AddGroupViewController()
        addGroupViewController.delegate = self
        
        // Create a window to contain the view controller
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Skapa ny grupp"
        window.contentViewController = addGroupViewController
        window.center()
        window.level = .floating
        
        // Show as a modal sheet if we have a parent window
        if let parentWindow = self.window {
            parentWindow.beginSheet(window) { response in
                // Handle sheet completion if needed
                print("📝 Add group sheet closed")
            }
        } else {
            // Fallback to showing as a regular window
            window.makeKeyAndOrderFront(nil)
        }
    }
}

// MARK: - AddGroupViewControllerDelegate
extension SidebarFavoritesView: AddGroupViewControllerDelegate {
    func addGroupViewController(_ controller: AddGroupViewController, didCreateGroup name: String, iconName: String, color: String) {
        print("✅ Creating new group: \(name) with icon: \(iconName) and color: \(color)")
        
        // Create the group using BookmarkManager
        let newGroup = BookmarkManager.shared.createFavoriteGroup(name: name, iconName: iconName, color: color)
        
        // Close the dialog
        if let window = controller.view.window {
            window.sheetParent?.endSheet(window)
        }
        
        print("🎉 Successfully created group: \(newGroup.name)")
    }
    
    func addGroupViewControllerDidCancel(_ controller: AddGroupViewController) {
        print("❌ Add group dialog cancelled")
        
        // Close the dialog
        if let window = controller.view.window {
            window.sheetParent?.endSheet(window)
        }
    }
}