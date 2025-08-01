import Cocoa

// MARK: - Extensions for Bookmark favicon loading
extension Bookmark {
    /// Loads favicon asynchronously and updates the bookmark
    func loadFavicon(completion: @escaping () -> Void = {}) {
        FaviconManager.shared.fetchFavicon(for: self.url) { [weak self] fetchedFavicon in
            DispatchQueue.main.async {
                self?.favicon = fetchedFavicon
                completion()
            }
        }
    }
}

class BookmarkBar: NSView {
    
    private var stackView: NSStackView!
    private var bookmarkButtons: [NSButton] = []
    private var bookmarkManager: BookmarkManager!
    
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
        
        // Create scroll view for bookmarks
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        
        // Create stack view for bookmark buttons
        stackView = NSStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .horizontal
        stackView.spacing = 6
        stackView.alignment = .centerY
        stackView.distribution = .fill
        
        scrollView.documentView = stackView
        addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])
        
        bookmarkManager = BookmarkManager.shared
        setupNotifications()
        loadBookmarks()
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
        loadBookmarks()
    }
    
    private func loadBookmarks() {
        // Clear existing buttons
        bookmarkButtons.forEach { $0.removeFromSuperview() }
        bookmarkButtons.removeAll()
        
        // Get bookmarks bar folder
        guard let bookmarksBarFolder = bookmarkManager.getBookmarksBarFolder() else { return }
        
        // Create buttons for bookmarks
        for bookmark in bookmarksBarFolder.bookmarks {
            let button = createBookmarkButton(for: bookmark)
            bookmarkButtons.append(button)
            stackView.addArrangedSubview(button)
        }
    }
    
    private func createBookmarkButton(for bookmark: Bookmark) -> NSButton {
        let button = NSButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.title = bookmark.title
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        button.contentTintColor = ColorManager.secondaryText
        button.alignment = .center
        button.target = self
        button.action = #selector(bookmarkClicked(_:))
        button.toolTip = bookmark.url.absoluteString
        
        // Store bookmark reference using tag
        if let bookmarksBarFolder = bookmarkManager.getBookmarksBarFolder() {
            button.tag = bookmarksBarFolder.bookmarks.firstIndex(where: { $0.id == bookmark.id }) ?? 0
        }
        
        // Arc-style pill button design
        button.wantsLayer = true
        button.layer?.cornerRadius = 11
        button.layer?.backgroundColor = NSColor.clear.cgColor
        button.layer?.borderWidth = 1
        button.layer?.borderColor = ColorManager.secondaryBorder.cgColor
        
        // Add hover tracking
        let trackingArea = NSTrackingArea(
            rect: NSRect(x: 0, y: 0, width: 120, height: 22),
            options: [.mouseEnteredAndExited, .activeInKeyWindow],
            owner: self,
            userInfo: ["bookmarkButton": button]
        )
        button.addTrackingArea(trackingArea)
        
        // Set size constraints with pill shape
        NSLayoutConstraint.activate([
            button.heightAnchor.constraint(equalToConstant: 22),
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 50),
            button.widthAnchor.constraint(lessThanOrEqualToConstant: 140)
        ])
        
        return button
    }
    
    @objc private func bookmarkClicked(_ sender: NSButton) {
        guard let bookmarksBarFolder = bookmarkManager.getBookmarksBarFolder(),
              sender.tag >= 0,
              sender.tag < bookmarksBarFolder.bookmarks.count else { return }
        
        let bookmark = bookmarksBarFolder.bookmarks[sender.tag]
        
        // Navigate to bookmark URL in current tab
        if let currentTab = TabManager.shared.activeTab {
            currentTab.navigate(to: bookmark.url)
        }
    }
    
    // Add hover effects for bookmark buttons
    override func mouseEntered(with event: NSEvent) {
        guard let trackingArea = event.trackingArea,
              let button = trackingArea.userInfo?["bookmarkButton"] as? NSButton else { return }
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            
            button.layer?.backgroundColor = ColorManager.tertiaryBackground.cgColor
            button.contentTintColor = ColorManager.primaryText
            button.layer?.transform = CATransform3DMakeScale(1.05, 1.05, 1.0)
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        guard let trackingArea = event.trackingArea,
              let button = trackingArea.userInfo?["bookmarkButton"] as? NSButton else { return }
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            
            button.layer?.backgroundColor = NSColor.clear.cgColor
            button.contentTintColor = ColorManager.secondaryText
            button.layer?.transform = CATransform3DIdentity
        }
    }
}

// MARK: - BookmarkManager
class BookmarkManager: ObservableObject {
    static let shared = BookmarkManager()
    
    @Published var bookmarkFolders: [BookmarkFolder] = []
    
    private let bookmarksFileURL: URL
    
    private init() {
        // Create bookmarks file URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        bookmarksFileURL = documentsPath.appendingPathComponent("Bookmarks.json")
        
        loadBookmarks()
        createDefaultFolders()
    }
    
    private func createDefaultFolders() {
        if bookmarkFolders.isEmpty {
            // Create default folders
            let bookmarksBar = BookmarkFolder(name: "Bookmarks Bar")
            let otherBookmarks = BookmarkFolder(name: "Other Bookmarks")
            
            // Add some default bookmarks to the bar
            let googleBookmark = Bookmark(title: "Google", url: URL(string: "https://www.google.com")!)
            let githubBookmark = Bookmark(title: "GitHub", url: URL(string: "https://github.com")!)
            let stackOverflowBookmark = Bookmark(title: "Stack Overflow", url: URL(string: "https://stackoverflow.com")!)
            let facebookBookmark = Bookmark(title: "Facebook", url: URL(string: "https://www.facebook.com")!)
            
            bookmarksBar.addBookmark(googleBookmark)
            bookmarksBar.addBookmark(githubBookmark)
            bookmarksBar.addBookmark(stackOverflowBookmark)
            bookmarksBar.addBookmark(facebookBookmark)
            
            // Load favicons for default bookmarks
            [googleBookmark, githubBookmark, stackOverflowBookmark, facebookBookmark].forEach { bookmark in
                bookmark.loadFavicon()
            }
            
            bookmarkFolders = [bookmarksBar, otherBookmarks]
            saveBookmarks()
        } else {
            // Load favicons for existing bookmarks that don't have them
            loadFaviconsForExistingBookmarks()
        }
    }
    
    private func loadFaviconsForExistingBookmarks() {
        for folder in bookmarkFolders {
            for bookmark in folder.bookmarks {
                if bookmark.favicon == nil {
                    bookmark.loadFavicon()
                }
            }
        }
    }
    
    func getBookmarksBarFolder() -> BookmarkFolder? {
        return bookmarkFolders.first { $0.name == "Bookmarks Bar" }
    }
    
    func addBookmark(_ bookmark: Bookmark, to folder: BookmarkFolder? = nil) {
        let targetFolder = folder ?? getBookmarksBarFolder() ?? bookmarkFolders.first
        targetFolder?.addBookmark(bookmark)
        
        // Load favicon for new bookmark
        bookmark.loadFavicon { [weak self] in
            self?.saveBookmarks()
        }
        
        saveBookmarks()
        NotificationCenter.default.post(name: .bookmarksUpdated, object: nil)
    }
    
    func removeBookmark(_ bookmark: Bookmark) {
        for folder in bookmarkFolders {
            folder.removeBookmark(bookmark)
        }
        saveBookmarks()
        NotificationCenter.default.post(name: .bookmarksUpdated, object: nil)
    }
    
    private func saveBookmarks() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(bookmarkFolders)
            try data.write(to: bookmarksFileURL)
        } catch {
            print("Failed to save bookmarks: \(error)")
        }
    }
    
    private func loadBookmarks() {
        guard FileManager.default.fileExists(atPath: bookmarksFileURL.path) else { return }
        
        do {
            let data = try Data(contentsOf: bookmarksFileURL)
            let decoder = JSONDecoder()
            bookmarkFolders = try decoder.decode([BookmarkFolder].self, from: data)
        } catch {
            print("Failed to load bookmarks: \(error)")
            bookmarkFolders = []
        }
    }
    func removeFromFavorites(_ bookmark: Bookmark) {
        // Remove from bookmarks bar (simplified)
        removeBookmark(bookmark)
    }
    
    func moveBookmark(_ bookmark: Bookmark, to newIndex: Int, in folder: BookmarkFolder? = nil) {
        let targetFolder = folder ?? getBookmarksBarFolder()
        guard let folder = targetFolder else { return }
        
        // Find current index
        guard let currentIndex = folder.bookmarks.firstIndex(where: { $0.id == bookmark.id }) else { return }
        
        // Remove from current position
        folder.bookmarks.remove(at: currentIndex)
        
        // Insert at new position (clamp to valid range)
        let clampedIndex = min(max(newIndex, 0), folder.bookmarks.count)
        folder.bookmarks.insert(bookmark, at: clampedIndex)
        
        saveBookmarks()
        NotificationCenter.default.post(name: .bookmarksUpdated, object: nil)
        print("📝 Moved bookmark '\(bookmark.title)' from index \(currentIndex) to \(clampedIndex)")
    }
    
    func swapBookmarks(_ bookmark1: Bookmark, _ bookmark2: Bookmark, in folder: BookmarkFolder? = nil) {
        let targetFolder = folder ?? getBookmarksBarFolder()
        guard let folder = targetFolder else { return }
        
        guard let index1 = folder.bookmarks.firstIndex(where: { $0.id == bookmark1.id }),
              let index2 = folder.bookmarks.firstIndex(where: { $0.id == bookmark2.id }) else { return }
        
        // Swap the bookmarks
        folder.bookmarks.swapAt(index1, index2)
        
        saveBookmarks()
        NotificationCenter.default.post(name: .bookmarksUpdated, object: nil)
        print("🔄 Swapped bookmarks: '\(bookmark1.title)' <-> '\(bookmark2.title)'")
    }
}

extension Notification.Name {
    static let bookmarksUpdated = Notification.Name("BookmarksUpdated")
}