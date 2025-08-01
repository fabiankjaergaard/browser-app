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
        iconView.image = NSImage(systemSymbolName: "folder", accessibilityDescription: group.name)
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
        guard sender.tag >= 0, sender.tag < group.bookmarks.count else { return }
        let bookmark = group.bookmarks[sender.tag]
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
        delegate?.sidebarFavoritesView(parentView!, didClickFavorite: bookmark)
    }
}

class SidebarFavoritesView: NSView {
    weak var delegate: SidebarFavoritesViewDelegate?
    
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
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
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
    }
    
    @objc private func bookmarksUpdated() {
        loadTraditionalFavorites()
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
        
        // Hide header if no favorites
        favoritesHeaderLabel.isHidden = limitedBookmarks.isEmpty
        favoritesStackView.isHidden = limitedBookmarks.isEmpty
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
    
    private func loadFavoriteGroups() {
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
        
        // Create demo groups like Arc
        createDemoGroups()
        
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
    }
    
    private func createDemoGroups() {
        // Clear existing groups
        favoriteGroups.removeAll()
        
        // Create Arc-style demo groups
        let fabianGroup = FavoriteGroup(name: "Fabian", iconName: "globe", color: "systemBlue")
        fabianGroup.addBookmark(Bookmark(title: "GitHub", url: URL(string: "https://github.com")!))
        fabianGroup.addBookmark(Bookmark(title: "Personal Site", url: URL(string: "https://fabiankjaergaard.com")!))
        
        let portfolioGroup = FavoriteGroup(name: "Portfolio", iconName: "folder", color: "systemGray")
        portfolioGroup.addBookmark(Bookmark(title: "Behance", url: URL(string: "https://behance.net")!))
        portfolioGroup.addBookmark(Bookmark(title: "Dribbble", url: URL(string: "https://dribbble.com")!))
        
        let uxuiGroup = FavoriteGroup(name: "UX/UI", iconName: "folder", color: "systemGray")
        uxuiGroup.addBookmark(Bookmark(title: "Figma", url: URL(string: "https://figma.com")!))
        uxuiGroup.addBookmark(Bookmark(title: "Adobe XD", url: URL(string: "https://adobe.com/xd")!))
        
        let pluggGroup = FavoriteGroup(name: "PLUGG", iconName: "folder", color: "systemGray")
        pluggGroup.addBookmark(Bookmark(title: "Canvas", url: URL(string: "https://canvas.com")!))
        pluggGroup.addBookmark(Bookmark(title: "Coursera", url: URL(string: "https://coursera.org")!))
        
        let appbyggGroup = FavoriteGroup(name: "Appbygg", iconName: "folder", color: "systemGray")
        appbyggGroup.addBookmark(Bookmark(title: "Xcode Cloud", url: URL(string: "https://developer.apple.com")!))
        appbyggGroup.addBookmark(Bookmark(title: "TestFlight", url: URL(string: "https://testflight.apple.com")!))
        
        let musikGroup = FavoriteGroup(name: "MUSIK", iconName: "folder", color: "systemGray")
        musikGroup.addBookmark(Bookmark(title: "Spotify", url: URL(string: "https://spotify.com")!))
        musikGroup.addBookmark(Bookmark(title: "Apple Music", url: URL(string: "https://music.apple.com")!))
        
        favoriteGroups = [fabianGroup, portfolioGroup, uxuiGroup, pluggGroup, appbyggGroup, musikGroup]
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
            startFavoriteDrag(button: button, bookmark: bookmark)
        case .changed:
            updateFavoriteDrag(recognizer: recognizer, button: button)
        case .ended:
            endFavoriteDrag(recognizer: recognizer, button: button, bookmark: bookmark)
        case .cancelled, .failed:
            cancelFavoriteDrag(button: button)
        default:
            break
        }
    }
    
    private func startFavoriteDrag(button: NSButton, bookmark: Bookmark) {
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
            CATransform3DMakeTranslation(translation.x, -translation.y, 0)
        )
        
        // Check if we're dragging outside the favorites area (for removal)
        let buttonFrame = button.frame
        let buttonCenter = NSPoint(x: buttonFrame.midX + translation.x, y: buttonFrame.midY - translation.y)
        let favoritesFrame = favoritesStackView.frame
        
        if !favoritesFrame.contains(buttonCenter) {
            // Show removal indicator
            button.alphaValue = 0.3
        } else {
            button.alphaValue = 0.7
        }
    }
    
    private func endFavoriteDrag(recognizer: NSPanGestureRecognizer, button: NSButton, bookmark: Bookmark) {
        let translation = recognizer.translation(in: self)
        
        // Check if we dragged outside the favorites area
        let buttonFrame = button.frame
        let buttonCenter = NSPoint(x: buttonFrame.midX + translation.x, y: buttonFrame.midY - translation.y)
        let favoritesFrame = favoritesStackView.frame
        
        if !favoritesFrame.contains(buttonCenter) {
            // Remove the favorite
            removeFavorite(bookmark)
            print("🗑️ Removed favorite: \(bookmark.title)")
        } else {
            // Reset button position
            resetFavoriteButton(button)
        }
    }
    
    private func cancelFavoriteDrag(button: NSButton) {
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
        print("✅ Favorite removed from BookmarkManager")
    }
}