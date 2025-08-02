import Cocoa
import WebKit

class ContentViewController: NSViewController {
    
    var webViewContainer: NSView!
    var currentTab: Tab?
    var findInPageView: FindInPageView!
    private var dragBar: NSView!
    private var blankStartViewController: BlankStartViewController?
    private var mediaNotchView: MediaNotchView!
    private var notesNotchView: NotesNotchView!
    private var todoNotchView: TodoNotchView!
    private var timerNotchView: TimerNotchView!
    private var weatherNotchView: WeatherNotchView!
    private var calendarNotchView: CalendarNotchView!
    private var themeNotchView: ThemeNotchView!
    private var settingsNotchView: SettingsNotchView!
    
    
    private var isSmartModeEnabled = false
    private var quickSearchViewController: QuickSearchViewController?
    private var autoHideTrackingArea: NSTrackingArea?
    private var hoverTimer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
        setupDragBar()
        // setupThemeNotifications() // Temporarily disabled
        setupMediaNotch()
        setupNotesNotch()
        setupTodoNotch()
        setupTimerNotch()
        setupWeatherNotch()
        setupCalendarNotch()
        setupThemeNotch()
        setupSettingsNotch()
        setupFindInPageView()
        setupWebViewContainer()
        setupNotifications()
        setupKeyboardShortcuts()
        
        // Apply saved notch visibility settings
        updateNotchVisibility()
        
        // Load initial tab if available, otherwise show blank start page
        if let firstTab = TabManager.shared.activeTab {
            loadTab(firstTab)
        } else {
            showBlankStartPage()
        }
    }
    
    private func setupView() {
        view.wantsLayer = true
        view.layer?.backgroundColor = ColorManager.primaryBackground.cgColor
    }
    
    private func setupDragBar() {
        dragBar = DraggableView()
        dragBar.translatesAutoresizingMaskIntoConstraints = false
        dragBar.wantsLayer = true
        // Transparent so it doesn't interfere visually
        dragBar.layer?.backgroundColor = NSColor.clear.cgColor
        view.addSubview(dragBar)
        
        NSLayoutConstraint.activate([
            dragBar.topAnchor.constraint(equalTo: view.topAnchor),
            dragBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dragBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dragBar.heightAnchor.constraint(equalToConstant: 45) // Height of draggable area
        ])
    }
    
    private func setupMediaNotch() {
        mediaNotchView = MediaNotchView()
        mediaNotchView.translatesAutoresizingMaskIntoConstraints = false
        mediaNotchView.delegate = self
        // Set reference to content view controller for coordination
        mediaNotchView.contentViewController = self
        dragBar.addSubview(mediaNotchView)
        
        
        NSLayoutConstraint.activate([
            // Position media notch from the right edge
            mediaNotchView.trailingAnchor.constraint(equalTo: dragBar.trailingAnchor, constant: -240),
            mediaNotchView.centerYAnchor.constraint(equalTo: dragBar.centerYAnchor),
            mediaNotchView.widthAnchor.constraint(equalToConstant: 32),
            mediaNotchView.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
    
    private func setupNotesNotch() {
        notesNotchView = NotesNotchView()
        notesNotchView.translatesAutoresizingMaskIntoConstraints = false
        notesNotchView.delegate = self
        // Set reference to content view controller for coordination
        notesNotchView.contentViewController = self
        dragBar.addSubview(notesNotchView)
        
        
        NSLayoutConstraint.activate([
            // Position notes notch from the right edge
            notesNotchView.trailingAnchor.constraint(equalTo: dragBar.trailingAnchor, constant: -320),
            notesNotchView.centerYAnchor.constraint(equalTo: dragBar.centerYAnchor),
            notesNotchView.widthAnchor.constraint(equalToConstant: 32),
            notesNotchView.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
    
    private func setupTodoNotch() {
        todoNotchView = TodoNotchView()
        todoNotchView.translatesAutoresizingMaskIntoConstraints = false
        todoNotchView.delegate = self
        // Set reference to content view controller for coordination
        todoNotchView.contentViewController = self
        dragBar.addSubview(todoNotchView)
        
        
        NSLayoutConstraint.activate([
            // Position todo notch from the right edge
            todoNotchView.trailingAnchor.constraint(equalTo: dragBar.trailingAnchor, constant: -280),
            todoNotchView.centerYAnchor.constraint(equalTo: dragBar.centerYAnchor),
            todoNotchView.widthAnchor.constraint(equalToConstant: 32),
            todoNotchView.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
    
    private func setupTimerNotch() {
        timerNotchView = TimerNotchView()
        timerNotchView.translatesAutoresizingMaskIntoConstraints = false
        timerNotchView.delegate = self
        timerNotchView.contentViewController = self
        dragBar.addSubview(timerNotchView)
        
        
        NSLayoutConstraint.activate([
            // Position timer notch from the right edge
            timerNotchView.trailingAnchor.constraint(equalTo: dragBar.trailingAnchor, constant: -200),
            timerNotchView.centerYAnchor.constraint(equalTo: dragBar.centerYAnchor),
            timerNotchView.widthAnchor.constraint(equalToConstant: 32),
            timerNotchView.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
    
    private func setupWeatherNotch() {
        weatherNotchView = WeatherNotchView()
        weatherNotchView.translatesAutoresizingMaskIntoConstraints = false
        weatherNotchView.delegate = self
        weatherNotchView.contentViewController = self
        dragBar.addSubview(weatherNotchView)
        
        
        NSLayoutConstraint.activate([
            // Position weather notch from the right edge
            weatherNotchView.trailingAnchor.constraint(equalTo: dragBar.trailingAnchor, constant: -160),
            weatherNotchView.centerYAnchor.constraint(equalTo: dragBar.centerYAnchor),
            weatherNotchView.widthAnchor.constraint(equalToConstant: 32),
            weatherNotchView.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
    
    private func setupCalendarNotch() {
        calendarNotchView = CalendarNotchView()
        calendarNotchView.translatesAutoresizingMaskIntoConstraints = false
        calendarNotchView.delegate = self
        calendarNotchView.contentViewController = self
        dragBar.addSubview(calendarNotchView)
        
        
        NSLayoutConstraint.activate([
            // Position calendar notch from the right edge
            calendarNotchView.trailingAnchor.constraint(equalTo: dragBar.trailingAnchor, constant: -120),
            calendarNotchView.centerYAnchor.constraint(equalTo: dragBar.centerYAnchor),
            calendarNotchView.widthAnchor.constraint(equalToConstant: 32),
            calendarNotchView.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
    
    private func setupThemeNotch() {
        themeNotchView = ThemeNotchView()
        themeNotchView.translatesAutoresizingMaskIntoConstraints = false
        themeNotchView.delegate = self
        themeNotchView.contentViewController = self
        dragBar.addSubview(themeNotchView)
        
        
        NSLayoutConstraint.activate([
            // Position theme notch from the right edge
            themeNotchView.trailingAnchor.constraint(equalTo: dragBar.trailingAnchor, constant: -80),
            themeNotchView.centerYAnchor.constraint(equalTo: dragBar.centerYAnchor),
            themeNotchView.widthAnchor.constraint(equalToConstant: 32),
            themeNotchView.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
    
    private func setupSettingsNotch() {
        settingsNotchView = SettingsNotchView()
        settingsNotchView.translatesAutoresizingMaskIntoConstraints = false
        // Set reference to content view controller for coordination
        settingsNotchView.contentViewController = self
        dragBar.addSubview(settingsNotchView)
        
        NSLayoutConstraint.activate([
            // Position settings notch from the right edge
            settingsNotchView.trailingAnchor.constraint(equalTo: dragBar.trailingAnchor, constant: -40),
            settingsNotchView.centerYAnchor.constraint(equalTo: dragBar.centerYAnchor),
            settingsNotchView.widthAnchor.constraint(equalToConstant: 32),
            settingsNotchView.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
    
    private func setupTabBar() {
        // Tab bar removed - tabs now handled in sidebar
    }
    
    
    
    private func setupWebViewContainer() {
        webViewContainer = NSView()
        webViewContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webViewContainer)
        
        NSLayoutConstraint.activate([
            webViewContainer.topAnchor.constraint(equalTo: dragBar.bottomAnchor),
            webViewContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webViewContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webViewContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupFindInPageView() {
        findInPageView = FindInPageView()
        findInPageView.translatesAutoresizingMaskIntoConstraints = false
        findInPageView.isHidden = true
        view.addSubview(findInPageView)
        
        NSLayoutConstraint.activate([
            findInPageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            findInPageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            findInPageView.heightAnchor.constraint(equalToConstant: 32),
            findInPageView.widthAnchor.constraint(equalToConstant: 360)
        ])
    }
    
    private func setupKeyboardShortcuts() {
        // Add Cmd+F shortcut for find in page
        let findShortcut = NSLocalizedString("f", comment: "Find shortcut")
        let findMenuItem = NSMenuItem(title: "Find in Page", action: #selector(showFindInPage), keyEquivalent: findShortcut)
        findMenuItem.keyEquivalentModifierMask = .command
        findMenuItem.target = self
        
        // Note: In a real app, this would be added to the main menu
        // For now, we'll handle it via keyDown override
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(tabSelected(_:)),
            name: .tabSelected,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showQuickSearch),
            name: .showQuickSearch,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hideQuickSearchFromNotification),
            name: .hideQuickSearch,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showFindInPage),
            name: .showFindInPage,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(allTabsClosed),
            name: .allTabsClosed,
            object: nil
        )
    }
    
    @objc private func tabSelected(_ notification: Notification) {
        guard let tab = notification.object as? Tab else { 
            showBlankStartPage()
            return 
        }
        loadTab(tab)
    }
    
    @objc private func allTabsClosed(_ notification: Notification) {
        print("📺 ContentViewController received allTabsClosed notification - showing blank start page")
        showBlankStartPage()
    }
    
    private func loadTab(_ tab: Tab) {
        // Clean up previous tab
        currentTab?.webView.removeFromSuperview()
        currentTab?.newTabViewController?.view.removeFromSuperview()
        currentTab?.newTabViewController?.removeFromParent()
        
        // Hide blank start page if showing
        hideBlankStartPage()
        
        currentTab = tab
        
        if tab.isShowingNewTabPage {
            // Show new tab page
            if tab.newTabViewController == nil {
                tab.newTabViewController = NewTabViewController()
                tab.newTabViewController?.delegate = self
            }
            
            if let newTabVC = tab.newTabViewController {
                addChild(newTabVC)
                webViewContainer.addSubview(newTabVC.view)
                newTabVC.view.translatesAutoresizingMaskIntoConstraints = false
                
                NSLayoutConstraint.activate([
                    newTabVC.view.topAnchor.constraint(equalTo: webViewContainer.topAnchor),
                    newTabVC.view.leadingAnchor.constraint(equalTo: webViewContainer.leadingAnchor),
                    newTabVC.view.trailingAnchor.constraint(equalTo: webViewContainer.trailingAnchor),
                    newTabVC.view.bottomAnchor.constraint(equalTo: webViewContainer.bottomAnchor)
                ])
            }
        } else {
            // Show web view
            webViewContainer.addSubview(tab.webView)
            tab.webView.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                tab.webView.topAnchor.constraint(equalTo: webViewContainer.topAnchor),
                tab.webView.leadingAnchor.constraint(equalTo: webViewContainer.leadingAnchor),
                tab.webView.trailingAnchor.constraint(equalTo: webViewContainer.trailingAnchor),
                tab.webView.bottomAnchor.constraint(equalTo: webViewContainer.bottomAnchor)
            ])
            
            tab.webView.navigationDelegate = self
            
            if let title = tab.webView.title, !title.isEmpty {
                tab.title = title
            }
        }
    }
    
    private func showBlankStartPage() {
        print("📺 Showing blank start page")
        
        // Hide any existing tab content
        currentTab?.webView.removeFromSuperview()
        currentTab?.newTabViewController?.view.removeFromSuperview()
        currentTab?.newTabViewController?.removeFromParent()
        currentTab = nil
        
        // Make sure we clean up any existing blank start page first
        hideBlankStartPage()
        
        // Show blank start page
        blankStartViewController = BlankStartViewController()
        
        if let blankStartVC = blankStartViewController {
            addChild(blankStartVC)
            webViewContainer.addSubview(blankStartVC.view)
            blankStartVC.view.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                blankStartVC.view.topAnchor.constraint(equalTo: webViewContainer.topAnchor),
                blankStartVC.view.leadingAnchor.constraint(equalTo: webViewContainer.leadingAnchor),
                blankStartVC.view.trailingAnchor.constraint(equalTo: webViewContainer.trailingAnchor),
                blankStartVC.view.bottomAnchor.constraint(equalTo: webViewContainer.bottomAnchor)
            ])
            
            print("✅ Blank start page added to view hierarchy")
        }
    }
    
    private func hideBlankStartPage() {
        if let blankStartVC = blankStartViewController {
            blankStartVC.view.removeFromSuperview()
            blankStartVC.removeFromParent()
            blankStartViewController = nil
        }
    }
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
    }
    
    @objc private func showFindInPage() {
        guard let currentTab = currentTab else { return }
        findInPageView.showWithWebView(currentTab.webView)
    }
    
    @objc private func showQuickSearch() {
        // Toggle functionality - if already visible, hide it
        if quickSearchViewController != nil {
            hideQuickSearch()
            return
        }
        
        // Hide blank start page temporarily while quick search is shown
        if blankStartViewController != nil {
            hideBlankStartPage()
        }
        
        quickSearchViewController = QuickSearchViewController()
        quickSearchViewController?.delegate = self
        
        if let quickSearch = quickSearchViewController {
            addChild(quickSearch)
            view.addSubview(quickSearch.view)
            
            quickSearch.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                quickSearch.view.topAnchor.constraint(equalTo: view.topAnchor),
                quickSearch.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                quickSearch.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                quickSearch.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
            
            // Animate in
            quickSearch.view.alphaValue = 0
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                quickSearch.view.animator().alphaValue = 1.0
            }
        }
    }
    
    @objc private func hideQuickSearchFromNotification() {
        // Hide quick search when called from notification (e.g., when clicking favorites)
        hideQuickSearch()
    }
    
    private func hideQuickSearch() {
        guard let quickSearch = quickSearchViewController else { return }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            quickSearch.view.animator().alphaValue = 0.0
        }, completionHandler: {
            quickSearch.view.removeFromSuperview()
            quickSearch.removeFromParent()
            self.quickSearchViewController = nil
        })
    }
    
    
    func updateNotchVisibility() {
        let settings = NotchSettings.shared
        
        // Update visibility
        mediaNotchView.isHidden = !settings.mediaNotchVisible
        notesNotchView.isHidden = !settings.notesNotchVisible
        todoNotchView.isHidden = !settings.todoNotchVisible
        timerNotchView.isHidden = !settings.timerNotchVisible
        weatherNotchView.isHidden = !settings.weatherNotchVisible
        calendarNotchView.isHidden = !settings.calendarNotchVisible
        themeNotchView.isHidden = !settings.themeNotchVisible
        
        // Reposition all notches to remove gaps
        repositionNotches()
        
        print("⚙️ Updated notch visibility and repositioned notches")
    }
    
    private func repositionNotches() {
        // Remove all existing trailing constraints for notches
        dragBar.constraints.filter { constraint in
            return (constraint.firstItem === settingsNotchView || 
                   constraint.firstItem === themeNotchView ||
                   constraint.firstItem === calendarNotchView ||
                   constraint.firstItem === weatherNotchView ||
                   constraint.firstItem === timerNotchView ||
                   constraint.firstItem === todoNotchView ||
                   constraint.firstItem === notesNotchView ||
                   constraint.firstItem === mediaNotchView) &&
                   constraint.firstAttribute == .trailing
        }.forEach { dragBar.removeConstraint($0) }
        
        // Create array of visible notches in right-to-left order
        var visibleNotches: [NSView] = []
        
        if !settingsNotchView.isHidden { visibleNotches.append(settingsNotchView) }
        if !themeNotchView.isHidden { visibleNotches.append(themeNotchView) }
        if !calendarNotchView.isHidden { visibleNotches.append(calendarNotchView) }
        if !weatherNotchView.isHidden { visibleNotches.append(weatherNotchView) }
        if !timerNotchView.isHidden { visibleNotches.append(timerNotchView) }
        if !todoNotchView.isHidden { visibleNotches.append(todoNotchView) }
        if !notesNotchView.isHidden { visibleNotches.append(notesNotchView) }
        if !mediaNotchView.isHidden { visibleNotches.append(mediaNotchView) }
        
        // Position notches from right edge with 40px spacing between them
        let spacing: CGFloat = 40
        var currentOffset: CGFloat = -40 // Start 40px from right edge
        
        for notch in visibleNotches {
            notch.trailingAnchor.constraint(equalTo: dragBar.trailingAnchor, constant: currentOffset).isActive = true
            currentOffset -= spacing // Move further left for next notch
        }
    }
    
    
    override func keyDown(with event: NSEvent) {
        // Handle Cmd+F for find in page
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "f" {
            showFindInPage()
            return
        }
        
        // Handle Cmd+T for toggle quick search
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "t" {
            showQuickSearch()  // This now toggles the quick search
            return
        }
        
        super.keyDown(with: event)
    }
    
    // MARK: - Notch Coordination
    
    func notchWillShow(_ notch: NSView) {
        // Hide all other notches when one is about to show
        if notch !== mediaNotchView {
            mediaNotchView.hideDropdownIfVisible()
        }
        if notch !== notesNotchView {
            notesNotchView.hideDropdownIfVisible()
        }
        if notch !== todoNotchView {
            todoNotchView.hideDropdownIfVisible()
        }
        if notch !== timerNotchView {
            timerNotchView.hideDropdownIfVisible()
        }
        if notch !== weatherNotchView {
            weatherNotchView.hideDropdownIfVisible()
        }
        if notch !== calendarNotchView {
            calendarNotchView.hideDropdownIfVisible()
        }
        if notch !== themeNotchView {
            themeNotchView.hideDropdownIfVisible()
        }
        if notch !== settingsNotchView {
            settingsNotchView.hideDropdownIfVisible()
        }
    }
    
    // MARK: - Auto-Hide Tracking Area
    func setupAutoHideTrackingArea() {
        guard isViewLoaded else {
            print("⚠️ View not loaded yet, skipping tracking area setup")
            return
        }
        
        removeAutoHideTrackingArea() // Remove existing if any
        
        // Very narrow tracking area at the left edge (3px wide)
        let trackingRect = NSRect(x: 0, y: 0, width: 3, height: view.bounds.height)
        autoHideTrackingArea = NSTrackingArea(
            rect: trackingRect,
            options: [.mouseEnteredAndExited, .activeInKeyWindow],
            owner: self,
            userInfo: nil
        )
        
        view.addTrackingArea(autoHideTrackingArea!)
        print("✅ Auto-hide tracking area added: \(trackingRect) - 3px wide at left edge")
    }
    
    func removeAutoHideTrackingArea() {
        guard isViewLoaded else {
            print("⚠️ View not loaded yet, skipping tracking area removal")
            return
        }
        
        // Cancel any pending hover timer
        hoverTimer?.invalidate()
        hoverTimer = nil
        
        if let trackingArea = autoHideTrackingArea {
            view.removeTrackingArea(trackingArea)
            autoHideTrackingArea = nil
            print("🗑️ Auto-hide tracking area removed")
        }
    }
    
    override func mouseEntered(with event: NSEvent) {
        if let trackingArea = event.trackingArea, trackingArea == autoHideTrackingArea {
            // Double-check that mouse is actually at the left edge
            let mouseLocation = view.convert(event.locationInWindow, from: nil)
            
            if mouseLocation.x <= 3 {
                print("🐭 Mouse entered auto-hide area (3px at left edge) at x=\(mouseLocation.x) - starting 0.5s timer")
                
                // Start timer for 0.5 second delay
                hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
                    print("⏰ Hover timer completed - showing sidebar")
                    if let windowController = self?.view.window?.windowController as? BrowserWindowController {
                        windowController.showSidebarTemporarily()
                    }
                }
            } else {
                print("❌ Mouse not at left edge (x=\(mouseLocation.x)), ignoring")
            }
        }
        super.mouseEntered(with: event)
    }
    
    override func mouseExited(with event: NSEvent) {
        if let trackingArea = event.trackingArea, trackingArea == autoHideTrackingArea {
            print("🐭 Mouse exited auto-hide area - canceling timer")
            
            // Cancel the hover timer if mouse exits before 0.5s
            hoverTimer?.invalidate()
            hoverTimer = nil
            
            // Also hide sidebar if it was shown
            if let windowController = view.window?.windowController as? BrowserWindowController {
                windowController.hideSidebarIfAutoHidden()
            }
        }
        super.mouseExited(with: event)
    }
    
}

// Address bar delegate functionality moved to sidebar

extension ContentViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        // Progress indicator is now in sidebar
        currentTab?.isLoading = true
    }
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        // Progress handled by sidebar
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Progress indicator is now in sidebar
        currentTab?.isLoading = false
        
        if let url = webView.url {
            // Address bar is now in sidebar - will be updated via notifications
            currentTab?.url = url
        }
        
        if let title = webView.title, !title.isEmpty {
            print("🏷️ Updating tab title to: \(title)")
            currentTab?.title = title
        } else {
            print("⚠️ No title found for webView, keeping: \(currentTab?.title ?? "nil")")
        }
        
        // Load favicon when page finishes loading and add to history
        if let url = webView.url {
            currentTab?.loadFavicon(from: url)
            
            // Add to history
            let pageTitle = webView.title ?? url.absoluteString
            HistoryManager.shared.addHistoryItem(url: url, title: pageTitle)
        }
        
        // Security indicator is now in sidebar
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        // Progress indicator is now in sidebar
        currentTab?.isLoading = false
    }
}

// MARK: - UI Helper Methods
extension ContentViewController {
}


extension Notification.Name {
    static let smartModeToggled = Notification.Name("SmartModeToggled")
    static let showQuickSearch = Notification.Name("ShowQuickSearch")
    static let hideQuickSearch = Notification.Name("HideQuickSearch")
    static let showFindInPage = Notification.Name("ShowFindInPage")
    static let toggleSidebar = Notification.Name("ToggleSidebar")
}

// MARK: - NewTabViewDelegate
extension ContentViewController: NewTabViewDelegate {
    func newTabView(_ newTabView: NewTabViewController, didNavigateToURL url: URL) {
        guard let currentTab = currentTab else { return }
        currentTab.navigate(to: url)
        loadTab(currentTab)
    }
    
    func newTabViewDidRequestNewTab(_ newTabView: NewTabViewController) {
        TabManager.shared.createNewTab()
    }
}

// MARK: - QuickSearchDelegate
extension ContentViewController: QuickSearchDelegate {
    func quickSearchDidCreateNewTab(with url: URL) {
        // Create tab in the active space if available, otherwise as loose tab
        TabManager.shared.createNewTab(in: TabManager.shared.activeSpace)
        if let newTab = TabManager.shared.activeTab {
            newTab.navigate(to: url)
            loadTab(newTab)
        }
        hideQuickSearch()
    }
    
    func quickSearchDidCancel() {
        hideQuickSearch()
        
        // Show blank start page again if no tabs are open
        if currentTab == nil {
            showBlankStartPage()
        }
    }
    
    // MARK: - Theme Management
    // Temporarily disabled to fix build issues
    /*
    private func setupThemeNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChange(_:)),
            name: .themeDidChange,
            object: nil
        )
    }
    */
}

// MARK: - MediaNotchViewDelegate
extension ContentViewController: MediaNotchViewDelegate {
    func mediaNotchDidPressPrevious() {
        print("🎵 Previous track pressed")
        // Here you can implement integration with media players like Spotify, Apple Music, etc.
        // For now, we'll use AppleScript to control iTunes/Music app
        executeAppleScript("tell application \"Music\" to previous track")
    }
    
    func mediaNotchDidPressPlayPause() {
        print("🎵 Play/Pause pressed")
        executeAppleScript("tell application \"Music\" to playpause")
    }
    
    func mediaNotchDidPressNext() {
        print("🎵 Next track pressed")
        executeAppleScript("tell application \"Music\" to next track")
    }
    
    private func executeAppleScript(_ script: String) {
        guard let appleScript = NSAppleScript(source: script) else {
            print("❌ Failed to create AppleScript")
            return
        }
        
        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)
        
        if let error = error {
            print("❌ AppleScript error: \(error)")
            // Fallback: try Spotify if Music app fails
            if script.contains("Music") {
                let spotifyScript = script.replacingOccurrences(of: "Music", with: "Spotify")
                executeSpotifyFallback(spotifyScript)
            }
        } else {
            print("✅ AppleScript executed successfully: \(result)")
        }
    }
    
    private func executeSpotifyFallback(_ script: String) {
        guard let appleScript = NSAppleScript(source: script) else { return }
        var error: NSDictionary?
        appleScript.executeAndReturnError(&error)
        
        if let error = error {
            print("❌ Spotify AppleScript also failed: \(error)")
        }
    }
}

// MARK: - NotesNotchViewDelegate
extension ContentViewController: NotesNotchViewDelegate {
    func notesNotchDidUpdateText(_ text: String) {
        print("📝 Notes updated: \(text.count) characters")
        // Here you could implement sync with cloud services, notifications, etc.
    }
    
    func notesNotchDidRequestKeyboardShortcut() {
        print("📝 Keyboard shortcut requested for notes")
        // Future implementation for global keyboard shortcuts
    }
}

// MARK: - TodoNotchViewDelegate
extension ContentViewController: TodoNotchViewDelegate {
    func todoNotchDidUpdateTodos(_ todos: [TodoItem]) {
        print("✓ Todos updated: \(todos.count) total, \(todos.filter { $0.isCompleted }.count) completed")
        // Here you could implement sync with cloud services, notifications, etc.
    }
    
    func todoNotchDidRequestKeyboardShortcut() {
        print("✓ Keyboard shortcut requested for todos")
        // Future implementation for global keyboard shortcuts
    }
}

// MARK: - TimerNotchViewDelegate
extension ContentViewController: TimerNotchViewDelegate {
    func timerNotchDidComplete(_ type: TimerType) {
        print("⏱️ Timer completed: \(type.rawValue)")
        // Here you could implement additional actions like system notifications
    }
    
    func timerNotchDidStart(_ type: TimerType) {
        print("⏱️ Timer started: \(type.rawValue)")
        // Here you could implement focus mode integrations
    }
    
    func timerNotchDidStop() {
        print("⏱️ Timer stopped")
    }
}

// MARK: - WeatherNotchViewDelegate
extension ContentViewController: WeatherNotchViewDelegate {
    func weatherNotchDidUpdateWeather(_ weather: WeatherData) {
        print("🌤️ Weather updated: \(weather.temperatureString) in \(weather.city)")
        // Here you could implement weather-based suggestions or integrations
    }
    
    func weatherNotchDidFailToLoad(_ error: String) {
        print("🌤️ Weather failed to load: \(error)")
        // Here you could implement error handling or fallback behavior
    }
}

// MARK: - CalendarNotchViewDelegate
extension ContentViewController: CalendarNotchViewDelegate {
    func calendarNotchDidUpdateEvents(_ events: [CalendarEvent]) {
        print("📅 Calendar updated: \(events.count) events today")
        // Here you could implement event-based notifications or integrations
    }
    
    func calendarNotchDidRequestEventCreation() {
        print("📅 Event creation requested")
        // Here you could implement custom event creation interface
    }
}

// MARK: - ThemeNotchViewDelegate
extension ContentViewController: ThemeNotchViewDelegate {
    func themeNotchDidToggleTheme(_ isDarkMode: Bool) {
        print("🎨 Theme toggled: \(isDarkMode ? "Dark" : "Light") mode")
        // Here you could implement additional theme-based changes or integrations
    }
}

// MARK: - DraggableView
class DraggableView: NSView {
    override func mouseDown(with event: NSEvent) {
        // Pass the mouse down event to the window to enable dragging
        window?.performDrag(with: event)
    }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}