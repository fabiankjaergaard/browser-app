import Cocoa



class BrowserWindowController: NSWindowController {
    
    var splitViewController: NSSplitViewController!
    var sidebarViewController: SidebarViewController!
    var browserContentViewController: ContentViewController!
    var aiSidebarViewController: AISidebarViewController!
    
    private var aiSidebarItem: NSSplitViewItem?
    private var isAISidebarVisible = false
    private var sidebarItem: NSSplitViewItem?
    private var isSidebarVisible = true
    internal var isSidebarAutoHidden = false
    private var autoHideTimer: Timer?
    
    
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1400, height: 900),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // Modern window styling
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.toolbar = NSToolbar()
        window.isMovableByWindowBackground = true
        window.backgroundColor = ColorManager.primaryBackground
        
        // Enable native fullscreen with animations
        window.collectionBehavior = [.fullScreenPrimary, .fullScreenAllowsTiling]
        
        // Modern window appearance
        window.hasShadow = true
        window.isOpaque = false
        
        self.init(window: window)
        
        setupSplitView()
        setupNotifications()
        setupWindowObservers()
    }
    
    private func setupSplitView() {
        splitViewController = NSSplitViewController()
        splitViewController.splitView.dividerStyle = .thin
        splitViewController.splitView.isVertical = true
        
        // Allow user to resize by dragging dividers
        
        sidebarViewController = SidebarViewController()
        sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarViewController)
        sidebarItem!.minimumThickness = 160
        sidebarItem!.maximumThickness = 400  // Increased from 280 to give more flexibility
        sidebarItem!.canCollapse = false
        
        browserContentViewController = ContentViewController()
        let contentItem = NSSplitViewItem(viewController: browserContentViewController)
        
        // Setup AI sidebar (initially hidden)
        aiSidebarViewController = AISidebarViewController()
        aiSidebarItem = NSSplitViewItem(viewController: aiSidebarViewController)
        aiSidebarItem!.minimumThickness = 320
        aiSidebarItem!.maximumThickness = 400
        aiSidebarItem!.isCollapsed = true
        
        splitViewController.splitViewItems = [sidebarItem!, contentItem, aiSidebarItem!]
        
        window?.contentViewController = splitViewController
    }
    
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(toggleAISidebar),
            name: .toggleAISidebar,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(toggleSidebar),
            name: .toggleSidebar,
            object: nil
        )
    }
    
    @objc func toggleAISidebar() {
        guard let aiSidebarItem = aiSidebarItem else { return }
        
        isAISidebarVisible.toggle()
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            aiSidebarItem.animator().isCollapsed = !isAISidebarVisible
        }
    }
    
    @objc func toggleSidebar() {
        print("🎯 toggleSidebar called")
        guard let sidebarItem = sidebarItem else { 
            print("❌ No sidebarItem found")
            return 
        }
        
        let wasVisible = isSidebarVisible
        isSidebarVisible.toggle()
        isSidebarAutoHidden = false // Reset auto-hide state when manually toggling
        autoHideTimer?.invalidate() // Cancel any pending auto-hide
        autoHideTimer = nil
        
        print("📱 Sidebar visibility: \(wasVisible) → \(isSidebarVisible)")
        
        // Update traffic lights immediately BEFORE animation starts
        if isSidebarVisible {
            // Show traffic lights immediately when showing sidebar
            window?.standardWindowButton(.closeButton)?.isHidden = false
            window?.standardWindowButton(.miniaturizeButton)?.isHidden = false
            window?.standardWindowButton(.zoomButton)?.isHidden = false
        }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            sidebarItem.animator().isCollapsed = !isSidebarVisible
        }, completionHandler: { [weak self] in
            // Hide traffic lights AFTER animation completes (only if hiding sidebar)
            if self?.isSidebarVisible == false {
                self?.updateTrafficLightsVisibility()
            }
        })
        
        // Setup or remove tracking area based on sidebar visibility (keep async for non-visual updates)
        DispatchQueue.main.async { [weak self] in
            if self?.isSidebarVisible == true {
                // Sidebar is now visible - remove auto-hide tracking
                self?.browserContentViewController.removeAutoHideTrackingArea()
                print("📱 Sidebar visible - auto-hide disabled")
            } else {
                // Sidebar is now hidden - enable auto-hide tracking
                self?.browserContentViewController.setupAutoHideTrackingArea()
                print("📱 Sidebar hidden - auto-hide enabled")
            }
        }
    }
    
    // MARK: - Auto-Hide Functionality
    func showSidebarTemporarily() {
        guard !isSidebarVisible, let sidebarItem = sidebarItem else { return }
        
        // Cancel any pending auto-hide
        autoHideTimer?.invalidate()
        autoHideTimer = nil
        
        isSidebarAutoHidden = true
        
        // Show traffic lights immediately when sidebar starts to appear
        window?.standardWindowButton(.closeButton)?.isHidden = false
        window?.standardWindowButton(.miniaturizeButton)?.isHidden = false
        window?.standardWindowButton(.zoomButton)?.isHidden = false
        
        // Try using the same animation settings as toggleSidebar for consistency
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            sidebarItem.animator().isCollapsed = false
        }
    }
    
    func hideSidebarIfAutoHidden() {
        guard isSidebarAutoHidden, let sidebarItem = sidebarItem else { return }
        
        // Add small delay to allow user to move to sidebar
        autoHideTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3  // Match the show animation duration
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                context.allowsImplicitAnimation = true
                sidebarItem.animator().isCollapsed = true
            }
            self?.isSidebarAutoHidden = false
            
            // Hide traffic lights when sidebar disappears (if in fullscreen)
            self?.updateTrafficLightsVisibility()
        }
    }
    
    func cancelAutoHide() {
        autoHideTimer?.invalidate()
        autoHideTimer = nil
    }
    
    private func setupWindowObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillEnterFullScreen),
            name: NSWindow.willEnterFullScreenNotification,
            object: window
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillExitFullScreen),
            name: NSWindow.willExitFullScreenNotification,
            object: window
        )
    }
    
    @objc private func windowWillEnterFullScreen() {
        // Optimize layout for fullscreen
        if isAISidebarVisible {
            aiSidebarItem?.maximumThickness = 450
        }
        // Enable auto-hiding scrollers for cleaner fullscreen experience
        sidebarViewController.tabScrollView?.autohidesScrollers = true
    }
    
    @objc private func windowWillExitFullScreen() {
        // Restore normal layout
        aiSidebarItem?.maximumThickness = 400
        sidebarViewController.tabScrollView?.autohidesScrollers = true
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        // Modern window positioning with better size
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1400, height: 900)
        let windowWidth: CGFloat = min(1400, screenFrame.width * 0.85)
        let windowHeight: CGFloat = min(900, screenFrame.height * 0.85)
        
        let windowFrame = NSRect(
            x: (screenFrame.width - windowWidth) / 2,
            y: (screenFrame.height - windowHeight) / 2,
            width: windowWidth,
            height: windowHeight
        )
        
        window?.setFrame(windowFrame, display: true, animate: false)
        
        // Set minimum window size for usability
        window?.minSize = NSSize(width: 800, height: 600)
        
        // Add subtle window animations
        window?.animationBehavior = .documentWindow
        
    }
    
    // MARK: - Sidebar Management
    
    // MARK: - Traffic Lights Management
    private func updateTrafficLightsVisibility() {
        guard let window = window else { return }
        
        // Hide traffic lights when sidebar is hidden AND not temporarily shown
        let shouldHideTrafficLights = !isSidebarVisible && !isSidebarAutoHidden
        
        window.standardWindowButton(.closeButton)?.isHidden = shouldHideTrafficLights
        window.standardWindowButton(.miniaturizeButton)?.isHidden = shouldHideTrafficLights
        window.standardWindowButton(.zoomButton)?.isHidden = shouldHideTrafficLights
        
        print("🚦 Traffic lights \(shouldHideTrafficLights ? "hidden" : "visible") - Sidebar: \(isSidebarVisible), AutoHidden: \(isSidebarAutoHidden)")
    }
    

    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}