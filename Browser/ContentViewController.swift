import Cocoa
import WebKit

class ContentViewController: NSViewController {
    
    var webViewContainer: NSView!
    var currentTab: Tab?
    var findInPageView: FindInPageView!
    private var dragBar: NSView!
    private var blankStartViewController: BlankStartViewController?
    
    private var isSmartModeEnabled = false
    private var quickSearchViewController: QuickSearchViewController?
    private var autoHideTrackingArea: NSTrackingArea?
    private var hoverTimer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
        setupDragBar()
        setupFindInPageView()
        setupWebViewContainer()
        setupNotifications()
        setupKeyboardShortcuts()
        
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
        // Don't show if already visible
        guard quickSearchViewController == nil else { return }
        
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
    
    override func keyDown(with event: NSEvent) {
        // Handle Cmd+F for find in page
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "f" {
            showFindInPage()
            return
        }
        
        // Handle Cmd+T for new tab
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "t" {
            TabManager.shared.createNewTab()
            return
        }
        
        super.keyDown(with: event)
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