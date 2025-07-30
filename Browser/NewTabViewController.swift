import Cocoa

protocol NewTabViewDelegate: AnyObject {
    func newTabView(_ newTabView: NewTabViewController, didNavigateToURL url: URL)
    func newTabViewDidRequestNewTab(_ newTabView: NewTabViewController)
}

class NewTabViewController: NSViewController {
    
    weak var delegate: NewTabViewDelegate?
    
    // UI Components
    private var scrollView: NSScrollView!
    private var contentView: NSView!
    private var logoImageView: NSImageView!
    private var searchTextField: NSTextField!
    private var searchContainer: NSView!
    private var shortcutsStackView: NSStackView!
    
    // Shortcut containers
    private var favoritesContainer: NSView!
    private var recentlyVisitedContainer: NSView!
    private var bookmarksContainer: NSView!
    private var downloadsContainer: NSView!
    private var aiAssistantContainer: NSView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupScrollView()
        setupLogo()
        setupSearchField()
        setupShortcuts()
        setupConstraints()
        loadContent()
    }
    
    private func setupView() {
        view.wantsLayer = true
        view.layer?.backgroundColor = ColorManager.primaryBackground.cgColor
    }
    
    private func setupScrollView() {
        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        
        contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        scrollView.documentView = contentView
        view.addSubview(scrollView)
    }
    
    private func setupLogo() {
        logoImageView = NSImageView()
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        logoImageView.imageScaling = .scaleProportionallyUpOrDown
        logoImageView.wantsLayer = true
        
        // Create a professional browser logo like in the screenshot
        let logoImage = NSImage(size: NSSize(width: 120, height: 120))
        logoImage.lockFocus()
        
        // Main circle background with modern gradient
        let rect = NSRect(x: 10, y: 10, width: 100, height: 100)
        let circlePath = NSBezierPath(ovalIn: rect)
        
        // Create a beautiful gradient from blue to purple
        let gradient = NSGradient(colors: [
            NSColor(red: 0.1, green: 0.4, blue: 1.0, alpha: 1.0),    // Bright blue
            NSColor(red: 0.3, green: 0.2, blue: 0.9, alpha: 1.0),    // Purple-blue
            NSColor(red: 0.0, green: 0.3, blue: 0.8, alpha: 1.0)     // Deep blue
        ])!
        gradient.draw(in: circlePath, angle: 45)
        
        // Add subtle shadow/depth
        let shadowPath = NSBezierPath(ovalIn: NSRect(x: 12, y: 8, width: 100, height: 100))
        NSColor(calibratedWhite: 0.0, alpha: 0.1).set()
        shadowPath.fill()
        
        // Main logo circle
        circlePath.setClip()
        gradient.draw(in: circlePath, angle: 45)
        
        // Add the cross/plus symbol in white with modern styling
        NSColor.white.set()
        
        // Horizontal bar of the cross (wider and more modern)
        let horizontalBar = NSBezierPath(roundedRect: NSRect(x: 35, y: 55, width: 50, height: 10), xRadius: 5, yRadius: 5)
        horizontalBar.fill()
        
        // Vertical bar of the cross
        let verticalBar = NSBezierPath(roundedRect: NSRect(x: 55, y: 35, width: 10, height: 50), xRadius: 5, yRadius: 5)
        verticalBar.fill()
        
        // Add subtle highlight for 3D effect
        let highlightGradient = NSGradient(colors: [
            NSColor(calibratedWhite: 1.0, alpha: 0.3),
            NSColor(calibratedWhite: 1.0, alpha: 0.0)
        ])!
        let highlightPath = NSBezierPath(ovalIn: NSRect(x: 10, y: 40, width: 100, height: 60))
        highlightGradient.draw(in: highlightPath, angle: 90)
        
        logoImage.unlockFocus()
        logoImageView.image = logoImage
        
        // Add subtle drop shadow to the logo
        logoImageView.layer?.shadowColor = NSColor.black.cgColor
        logoImageView.layer?.shadowOffset = CGSize(width: 0, height: -2)
        logoImageView.layer?.shadowRadius = 8
        logoImageView.layer?.shadowOpacity = 0.15
        
        contentView.addSubview(logoImageView)
    }
    
    private func setupSearchField() {
        searchContainer = NSView()
        searchContainer.translatesAutoresizingMaskIntoConstraints = false
        searchContainer.wantsLayer = true
        
        // More elegant search field with subtle styling
        searchContainer.layer?.backgroundColor = NSColor(calibratedWhite: 0.08, alpha: 0.9).cgColor
        searchContainer.layer?.cornerRadius = 24  // Make it more pill-shaped
        searchContainer.layer?.borderWidth = 1
        searchContainer.layer?.borderColor = NSColor(calibratedWhite: 0.2, alpha: 0.4).cgColor
        
        // Add subtle shadow for depth
        searchContainer.layer?.shadowColor = NSColor.black.cgColor
        searchContainer.layer?.shadowOffset = CGSize(width: 0, height: 2)
        searchContainer.layer?.shadowRadius = 8
        searchContainer.layer?.shadowOpacity = 0.1
        
        // Add search icon
        let searchIcon = NSImageView()
        searchIcon.translatesAutoresizingMaskIntoConstraints = false
        searchIcon.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Search")
        searchIcon.contentTintColor = ColorManager.secondaryText
        searchIcon.imageScaling = .scaleProportionallyDown
        
        searchTextField = NSTextField()
        searchTextField.translatesAutoresizingMaskIntoConstraints = false
        searchTextField.placeholderString = "Search or enter website"
        searchTextField.bezelStyle = .roundedBezel
        searchTextField.delegate = self
        searchTextField.font = NSFont.systemFont(ofSize: 16, weight: .regular)
        searchTextField.textColor = ColorManager.primaryText
        searchTextField.backgroundColor = NSColor.clear
        searchTextField.isBordered = false
        searchTextField.focusRingType = .none
        
        searchContainer.addSubview(searchIcon)
        searchContainer.addSubview(searchTextField)
        
        NSLayoutConstraint.activate([
            searchIcon.leadingAnchor.constraint(equalTo: searchContainer.leadingAnchor, constant: 12),
            searchIcon.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),
            searchIcon.widthAnchor.constraint(equalToConstant: 18),
            searchIcon.heightAnchor.constraint(equalToConstant: 18),
            
            searchTextField.leadingAnchor.constraint(equalTo: searchIcon.trailingAnchor, constant: 12),
            searchTextField.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),
            searchTextField.trailingAnchor.constraint(equalTo: searchContainer.trailingAnchor, constant: -20),
            searchTextField.heightAnchor.constraint(equalToConstant: 48),
            
            searchContainer.heightAnchor.constraint(equalToConstant: 48)
        ])
        
        // Add to content view
        contentView.addSubview(searchContainer)
    }
    
    private func setupShortcuts() {
        shortcutsStackView = NSStackView()
        shortcutsStackView.translatesAutoresizingMaskIntoConstraints = false
        shortcutsStackView.orientation = .vertical
        shortcutsStackView.spacing = 20  // More spacing between shortcuts
        shortcutsStackView.alignment = .centerX
        shortcutsStackView.distribution = .fill
        
        // Create shortcut containers
        let shortcutsData = [
            ("clock", "Recently Visited", "View your recently visited websites"),
            ("star.fill", "Bookmarks", "Access your saved bookmarks"),
            ("arrow.down.circle", "Downloads", "View your downloads"),
            ("brain.head.profile", "AI Assistant", "Chat with AI assistant")
        ]
        
        // Create favorites container first (special case)
        favoritesContainer = createShortcutContainer(
            iconName: "heart.fill",
            title: "Favorites",
            subtitle: "Quick access to your favorite sites",
            action: #selector(favoritesClicked)
        )
        shortcutsStackView.addArrangedSubview(favoritesContainer)
        
        // Create other shortcuts
        let containers = shortcutsData.map { iconName, title, subtitle in
            createShortcutContainer(
                iconName: iconName,
                title: title,
                subtitle: subtitle,
                action: #selector(shortcutClicked(_:))
            )
        }
        
        recentlyVisitedContainer = containers[0]
        bookmarksContainer = containers[1]
        downloadsContainer = containers[2]
        aiAssistantContainer = containers[3]
        
        containers.forEach { shortcutsStackView.addArrangedSubview($0) }
        
        contentView.addSubview(shortcutsStackView)
    }
    
    private func createShortcutContainer(iconName: String, title: String, subtitle: String, action: Selector) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.wantsLayer = true
        
        // More elegant styling for shortcuts
        container.layer?.backgroundColor = NSColor(calibratedWhite: 0.05, alpha: 0.8).cgColor
        container.layer?.cornerRadius = 16
        container.layer?.borderWidth = 1
        container.layer?.borderColor = NSColor(calibratedWhite: 0.15, alpha: 0.4).cgColor
        
        // Add subtle shadow
        container.layer?.shadowColor = NSColor.black.cgColor
        container.layer?.shadowOffset = CGSize(width: 0, height: 1)
        container.layer?.shadowRadius = 4
        container.layer?.shadowOpacity = 0.1
        
        // Icon
        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = NSImage(systemSymbolName: iconName, accessibilityDescription: title)
        iconView.contentTintColor = ColorManager.accent
        iconView.imageScaling = .scaleProportionallyDown
        
        // Title
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = ColorManager.primaryText
        
        // Subtitle
        let subtitleLabel = NSTextField(labelWithString: subtitle)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.textColor = ColorManager.secondaryText
        
        container.addSubview(iconView)
        container.addSubview(titleLabel)
        container.addSubview(subtitleLabel)
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 60),
            container.widthAnchor.constraint(equalToConstant: 350),
            
            iconView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 16),
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 22),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -20),
            
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -20)
        ])
        
        // Add click gesture
        let clickGesture = NSClickGestureRecognizer(target: self, action: action)
        container.addGestureRecognizer(clickGesture)
        
        // No hover tracking needed
        
        return container
    }
    
    private func setupConstraints() {
        
        NSLayoutConstraint.activate([
            // Scroll view
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Content view
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Logo
            logoImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 60),
            logoImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: 120),
            logoImageView.heightAnchor.constraint(equalToConstant: 120),
            
            // Search field
            searchContainer.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 32),
            searchContainer.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            searchContainer.widthAnchor.constraint(equalToConstant: 520),
            
            // Shortcuts
            shortcutsStackView.topAnchor.constraint(equalTo: searchContainer.bottomAnchor, constant: 48),
            shortcutsStackView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            shortcutsStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40)
        ])
    }
    
    private func loadContent() {
        // Load recent favorites to show preview in shortcuts
        updateFavoritesPreview()
        updateRecentlyVisitedPreview()
    }
    
    private func updateFavoritesPreview() {
        // This could show a preview of favorite sites
    }
    
    private func updateRecentlyVisitedPreview() {
        // This could show recently visited sites
    }
    
    // MARK: - Actions
    @objc private func favoritesClicked() {
        // Show favorites by navigating to a popular favorite or show sidebar
        print("Favorites clicked")
        
        // Get first favorite and navigate to it, or just show sidebar for now
        // In a real implementation, this could show a dedicated favorites page
        delegate?.newTabView(self, didNavigateToURL: URL(string: "https://www.google.com")!)
    }
    
    @objc private func shortcutClicked(_ sender: NSClickGestureRecognizer) {
        guard let container = sender.view else { return }
        
        switch container {
        case recentlyVisitedContainer:
            print("Recently visited clicked")
            // Navigate to a recently visited site or show history
            if let historyItems = getRecentHistoryItems(), let firstItem = historyItems.first {
                delegate?.newTabView(self, didNavigateToURL: firstItem.url)
            } else {
                // No recent items, navigate to Google
                delegate?.newTabView(self, didNavigateToURL: URL(string: "https://www.google.com")!)
            }
            break
        case bookmarksContainer:
            print("Bookmarks clicked")
            // Navigate to bookmarks or a popular bookmark
            delegate?.newTabView(self, didNavigateToURL: URL(string: "https://www.github.com")!)
            break
        case downloadsContainer:
            print("Downloads clicked")
            // Open downloads folder
            NSWorkspace.shared.open(URL(fileURLWithPath: NSHomeDirectory() + "/Downloads"))
            break
        case aiAssistantContainer:
            print("AI Assistant clicked")
            // Toggle AI sidebar
            NotificationCenter.default.post(name: .toggleAISidebar, object: nil)
            break
        default:
            break
        }
    }
    
    private func getRecentHistoryItems() -> [HistoryItem]? {
        // Get recent history items from HistoryManager
        return HistoryManager.shared.getRecentItems(limit: 5)
    }
    
    // MARK: - Hover Effects
    override func mouseEntered(with event: NSEvent) {
        // No hover animations
    }
    
    override func mouseExited(with event: NSEvent) {
        // No hover animations
    }
}

// MARK: - NSTextFieldDelegate
extension NewTabViewController: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else { return }
        let searchText = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !searchText.isEmpty else { return }
        
        // Determine if it's a URL or search query
        let url: URL
        if searchText.contains(".") && !searchText.contains(" ") {
            // Looks like a URL
            if searchText.hasPrefix("http://") || searchText.hasPrefix("https://") {
                url = URL(string: searchText) ?? URL(string: "https://www.google.com/search?q=\(searchText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!
            } else {
                url = URL(string: "https://\(searchText)") ?? URL(string: "https://www.google.com/search?q=\(searchText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!
            }
        } else {
            // Treat as search query
            url = URL(string: "https://www.google.com/search?q=\(searchText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!
        }
        
        delegate?.newTabView(self, didNavigateToURL: url)
    }
}

