import Cocoa
import WebKit

// Custom view that handles drag and drop operations
class DragDropView: NSView {
    weak var terminalPanel: TTYDTerminalPanel?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupDragAndDrop()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupDragAndDrop()
    }
    
    private func setupDragAndDrop() {
        registerForDraggedTypes([
            .fileURL,
            .URL,
            .string,
            .tiff,
            .png
        ])
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self], options: nil) {
            return .copy
        }
        return []
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return terminalPanel?.handleDragOperation(sender) ?? false
    }
}

// Transparent overlay view for drag and drop over webView
class DragOverlayView: NSView {
    weak var terminalPanel: TTYDTerminalPanel?
    private var isDragActive = false
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        // Transparent background
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        
        // Register for drag and drop
        registerForDraggedTypes([
            .fileURL,
            .URL,
            .string,
            .tiff,
            .png
        ])
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        isDragActive = true
        
        // Add visual feedback - semi-transparent blue overlay
        layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.1).cgColor
        
        if sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self], options: nil) {
            return .copy
        }
        return []
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        isDragActive = false
        // Remove visual feedback
        layer?.backgroundColor = NSColor.clear.cgColor
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isDragActive = false
        // Remove visual feedback
        layer?.backgroundColor = NSColor.clear.cgColor
        
        // Handle the drop operation
        return terminalPanel?.handleDragOperation(sender) ?? false
    }
    
    // Allow mouse events to pass through to webView below
    override func hitTest(_ point: NSPoint) -> NSView? {
        // Only intercept during drag operations
        return isDragActive ? self : nil
    }
}

class TTYDTerminalPanel: NSViewController {
    
    // UI Components
    private var panelView: NSView!
    private var headerView: NSView!
    private var closeButton: NSButton!
    private var titleLabel: NSTextField!
    private var tabBarView: TerminalTabBarView!
    private var terminalContainer: NSView!
    private var webViewsContainer: NSView!
    private var dragOverlay: DragOverlayView?
    
    // Terminal management
    private var terminalWebViews: [UUID: WKWebView] = [:]
    private var terminalProcesses: [UUID: Process] = [:]
    private var terminalPorts: [UUID: Int] = [:]
    private var currentTerminalTab: TerminalTab?
    
    // Panel state
    var onClose: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupFloatingPanel()
        setupHeader()
        setupTabBar()
        setupTerminalContainer()
        setupNotifications()
        
        // Create initial terminal tab if none exist
        if !TerminalTabManager.shared.hasAnyTabs() {
            let initialTab = TerminalTabManager.shared.createNewTerminalTab()
            switchToTerminalTab(initialTab)
        } else if let activeTab = TerminalTabManager.shared.activeTerminalTab {
            switchToTerminalTab(activeTab)
        }
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        // Focus current webview when panel opens
        if let currentTab = currentTerminalTab,
           let webView = terminalWebViews[currentTab.id] {
            DispatchQueue.main.async {
                self.view.window?.makeFirstResponder(webView)
            }
        }
    }
    
    private func setupFloatingPanel() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        
        // Modern frosted glass background with rounded corners
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = .popover
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 16
        visualEffectView.layer?.borderWidth = 1
        visualEffectView.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.2).cgColor
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(visualEffectView)
        
        // Add subtle shadow for depth
        visualEffectView.shadow = NSShadow()
        visualEffectView.shadow?.shadowOffset = NSSize(width: 0, height: 4)
        visualEffectView.shadow?.shadowBlurRadius = 12
        visualEffectView.shadow?.shadowColor = NSColor.black.withAlphaComponent(0.15)
        
        NSLayoutConstraint.activate([
            visualEffectView.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            visualEffectView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            visualEffectView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            visualEffectView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8)
        ])
    }
    
    private func setupHeader() {
        headerView = NSView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.wantsLayer = true
        
        // Create container with subtle background
        let headerBackground = NSView()
        headerBackground.translatesAutoresizingMaskIntoConstraints = false
        headerBackground.wantsLayer = true
        headerBackground.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.05).cgColor
        headerBackground.layer?.cornerRadius = 8
        headerView.addSubview(headerBackground)
        
        view.addSubview(headerView)
        
        
        // Terminal title with modern typography
        titleLabel = NSTextField(labelWithString: "Terminal")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = NSColor.labelColor
        titleLabel.backgroundColor = NSColor.clear
        titleLabel.isBordered = false
        headerView.addSubview(titleLabel)
        
        // Status indicator with modern design
        let statusContainer = NSView()
        statusContainer.translatesAutoresizingMaskIntoConstraints = false
        statusContainer.wantsLayer = true
        statusContainer.layer?.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.15).cgColor
        statusContainer.layer?.cornerRadius = 10
        headerView.addSubview(statusContainer)
        
        let statusDot = NSView()
        statusDot.translatesAutoresizingMaskIntoConstraints = false
        statusDot.wantsLayer = true
        statusDot.layer?.backgroundColor = NSColor.systemGreen.cgColor
        statusDot.layer?.cornerRadius = 3
        statusContainer.addSubview(statusDot)
        
        let statusLabel = NSTextField(labelWithString: "Ready")
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        statusLabel.textColor = NSColor.systemGreen
        statusLabel.backgroundColor = NSColor.clear
        statusLabel.isBordered = false
        statusContainer.addSubview(statusLabel)
        
        // Modern close button
        closeButton = NSButton()
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Close")
        closeButton.bezelStyle = .regularSquare
        closeButton.isBordered = false
        closeButton.contentTintColor = NSColor.tertiaryLabelColor
        closeButton.target = self
        closeButton.action = #selector(closePanel)
        
        // Hover effect for close button
        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect],
            owner: closeButton,
            userInfo: nil
        )
        closeButton.addTrackingArea(trackingArea)
        
        headerView.addSubview(closeButton)
        
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            headerView.heightAnchor.constraint(equalToConstant: 40),
            
            headerBackground.topAnchor.constraint(equalTo: headerView.topAnchor),
            headerBackground.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            headerBackground.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            headerBackground.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            
            
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            
            statusContainer.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            statusContainer.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -12),
            statusContainer.heightAnchor.constraint(equalToConstant: 20),
            
            statusDot.centerYAnchor.constraint(equalTo: statusContainer.centerYAnchor),
            statusDot.leadingAnchor.constraint(equalTo: statusContainer.leadingAnchor, constant: 6),
            statusDot.widthAnchor.constraint(equalToConstant: 6),
            statusDot.heightAnchor.constraint(equalToConstant: 6),
            
            statusLabel.centerYAnchor.constraint(equalTo: statusContainer.centerYAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: statusDot.trailingAnchor, constant: 4),
            statusLabel.trailingAnchor.constraint(equalTo: statusContainer.trailingAnchor, constant: -6),
            
            closeButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -12),
            closeButton.widthAnchor.constraint(equalToConstant: 20),
            closeButton.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    private func setupTabBar() {
        tabBarView = TerminalTabBarView()
        tabBarView.translatesAutoresizingMaskIntoConstraints = false
        tabBarView.terminalPanel = self
        view.addSubview(tabBarView)
        
        NSLayoutConstraint.activate([
            tabBarView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 4),
            tabBarView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            tabBarView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            tabBarView.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
    
    private func setupTerminalContainer() {
        // Create container for terminal content
        terminalContainer = NSView()
        terminalContainer.translatesAutoresizingMaskIntoConstraints = false
        terminalContainer.wantsLayer = true
        terminalContainer.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.03).cgColor
        terminalContainer.layer?.cornerRadius = 12
        terminalContainer.layer?.borderWidth = 1
        terminalContainer.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.1).cgColor
        view.addSubview(terminalContainer)
        
        // Create container for web views
        webViewsContainer = NSView()
        webViewsContainer.translatesAutoresizingMaskIntoConstraints = false
        terminalContainer.addSubview(webViewsContainer)
        
        NSLayoutConstraint.activate([
            terminalContainer.topAnchor.constraint(equalTo: tabBarView.bottomAnchor, constant: 4),
            terminalContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            terminalContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            terminalContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -24),
            
            webViewsContainer.topAnchor.constraint(equalTo: terminalContainer.topAnchor, constant: 8),
            webViewsContainer.leadingAnchor.constraint(equalTo: terminalContainer.leadingAnchor, constant: 8),
            webViewsContainer.trailingAnchor.constraint(equalTo: terminalContainer.trailingAnchor, constant: -8),
            webViewsContainer.bottomAnchor.constraint(equalTo: terminalContainer.bottomAnchor, constant: -8)
        ])
        
        // Setup drag overlay for the container
        setupDragOverlay()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(terminalTabSelected(_:)),
            name: .terminalTabSelected,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(allTerminalTabsClosed(_:)),
            name: .allTerminalTabsClosed,
            object: nil
        )
    }
    
    
    private func createWebViewForTerminalTab(_ terminalTab: TerminalTab) -> WKWebView {
        let config = WKWebViewConfiguration()
        
        // Enable debugging in development
        #if DEBUG
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        #endif
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.wantsLayer = true
        webView.layer?.cornerRadius = 8
        webView.layer?.masksToBounds = true
        
        // Modern terminal styling
        webView.setValue(false, forKey: "allowsLinkPreview")
        webView.setValue(false, forKey: "drawsBackground")
        
        // Initially hidden
        webView.isHidden = true
        
        // Add to container
        webViewsContainer.addSubview(webView)
        
        // Full size constraints
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: webViewsContainer.topAnchor),
            webView.leadingAnchor.constraint(equalTo: webViewsContainer.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: webViewsContainer.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: webViewsContainer.bottomAnchor)
        ])
        
        return webView
    }
    
    private func setupDragOverlay() {
        // Create a transparent overlay view that sits on top of webViewsContainer
        let overlayView = DragOverlayView()
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        overlayView.terminalPanel = self
        
        view.addSubview(overlayView)
        
        // Position overlay exactly over the webViewsContainer
        NSLayoutConstraint.activate([
            overlayView.topAnchor.constraint(equalTo: webViewsContainer.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: webViewsContainer.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: webViewsContainer.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: webViewsContainer.bottomAnchor)
        ])
        
        // Store reference to overlay
        self.dragOverlay = overlayView
    }
    
    // MARK: - Terminal Tab Management
    
    func switchToTerminalTab(_ terminalTab: TerminalTab) {
        // Hide current terminal if any
        if let currentTab = currentTerminalTab,
           let currentWebView = terminalWebViews[currentTab.id] {
            currentWebView.isHidden = true
        }
        
        // Get or create web view for this terminal tab
        let webView: WKWebView
        if let existingWebView = terminalWebViews[terminalTab.id] {
            webView = existingWebView
        } else {
            // Create new web view and start ttyd process
            webView = createWebViewForTerminalTab(terminalTab)
            terminalWebViews[terminalTab.id] = webView
            startTTYDProcessForTab(terminalTab)
        }
        
        // Show the web view for this tab
        webView.isHidden = false
        currentTerminalTab = terminalTab
        
        // Update title in header
        titleLabel.stringValue = "Terminal"
        
        // Focus the web view
        DispatchQueue.main.async {
            self.view.window?.makeFirstResponder(webView)
        }
        
        print("🎯 Switched to terminal tab: \(terminalTab.title)")
    }
    
    @objc private func terminalTabSelected(_ notification: Notification) {
        guard let terminalTab = notification.object as? TerminalTab else { return }
        switchToTerminalTab(terminalTab)
    }
    
    @objc private func allTerminalTabsClosed(_ notification: Notification) {
        // Close the terminal panel when all tabs are closed
        closePanel()
    }
    
    private func startTTYDProcessForTab(_ terminalTab: TerminalTab) {
        // Find available port starting from 7681
        let port = findAvailablePort(startingFrom: 7681)
        terminalPorts[terminalTab.id] = port
        
        let process = Process()
        terminalProcesses[terminalTab.id] = process
        
        // Configure ttyd process
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/ttyd")
        process.arguments = [
            "--port", String(port),
            "--interface", "127.0.0.1",  // Only bind to localhost for security
            "--writable",                // Allow input to terminal
            "--once",                   // Exit after one session (we'll restart as needed)
            "/bin/zsh", "-i", "-l"      // Start interactive login shell
        ]
        
        // Set up environment
        var environment = ProcessInfo.processInfo.environment
        environment["HOME"] = terminalTab.workingDirectory
        environment["USER"] = NSUserName()
        environment["TERM"] = "xterm-256color"
        environment["SHELL"] = "/bin/zsh"
        environment["LANG"] = "en_US.UTF-8"
        environment["FORCE_COLOR"] = "1"
        environment["CLICOLOR"] = "1"
        environment["CLICOLOR_FORCE"] = "1"
        
        // Enhance PATH for Claude CLI and other tools
        if let currentPath = environment["PATH"] {
            let additionalPaths = [
                "/Users/\(NSUserName())/.bun/bin",
                "/opt/homebrew/bin",
                "/opt/homebrew/sbin", 
                "/usr/local/bin",
                "/Users/\(NSUserName())/.local/bin",
                "/Users/\(NSUserName())/.cargo/bin"
            ]
            
            let pathComponents = currentPath.components(separatedBy: ":")
            var updatedPaths = pathComponents
            for path in additionalPaths {
                if !pathComponents.contains(path) {
                    updatedPaths.append(path)
                }
            }
            environment["PATH"] = updatedPaths.joined(separator: ":")
        }
        
        process.environment = environment
        
        // Handle process termination
        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.terminalProcesses.removeValue(forKey: terminalTab.id)
                self?.terminalPorts.removeValue(forKey: terminalTab.id)
                print("⚠️ ttyd process terminated for tab: \(terminalTab.title)")
            }
        }
        
        // Start ttyd
        do {
            try process.run()
            print("✅ ttyd started on port \(port) for tab: \(terminalTab.title)")
            
            // Wait a moment for ttyd to start, then load the web page
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.loadTerminalURLForTab(terminalTab)
            }
        } catch {
            print("❌ Failed to start ttyd for tab \(terminalTab.title): \(error)")
        }
    }
    
    private func findAvailablePort(startingFrom port: Int) -> Int {
        for testPort in port...(port + 10) {
            if isPortAvailable(testPort) {
                return testPort
            }
        }
        return port // Fallback to original port
    }
    
    private func isPortAvailable(_ port: Int) -> Bool {
        let sockfd = socket(AF_INET, SOCK_STREAM, 0)
        guard sockfd != -1 else { return false }
        
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(port).bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        
        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(sockfd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        
        close(sockfd)
        return result == 0
    }
    
    private func loadTerminalURLForTab(_ terminalTab: TerminalTab) {
        guard let port = terminalPorts[terminalTab.id],
              let webView = terminalWebViews[terminalTab.id] else {
            print("❌ No port or webView found for terminal tab: \(terminalTab.title)")
            return
        }
        
        let url = URL(string: "http://127.0.0.1:\(port)")!
        let request = URLRequest(url: url)
        webView.load(request)
        print("✅ Loading ttyd terminal at \(url) for tab: \(terminalTab.title)")
    }
    
    @objc func closePanel() {
        // Don't terminate ttyd process when just closing panel
        // Keep it running so terminal state is preserved
        
        // Call close callback
        onClose?()
    }
    
    // Method to actually terminate all processes when needed
    func terminateProcess() {
        for (tabId, process) in terminalProcesses {
            process.terminate()
            print("🛑 ttyd process terminated for tab: \(tabId)")
        }
        terminalProcesses.removeAll()
        terminalPorts.removeAll()
        terminalWebViews.removeAll()
    }
    
    override func loadView() {
        let dragDropView = DragDropView(frame: NSRect(x: 0, y: 0, width: 320, height: 600))
        dragDropView.terminalPanel = self
        view = dragDropView
    }
    
    override func keyDown(with event: NSEvent) {
        // Handle Esc key to close panel
        if event.keyCode == 53 { // Esc key
            closePanel()
            return
        }
        
        super.keyDown(with: event)
    }
    
    // MARK: - Drag and Drop Support
    func handleDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        
        // Handle file URLs
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            let filePaths = urls.map { url in
                let path = url.path
                // Quote paths with spaces
                return path.contains(" ") ? "\"\(path)\"" : path
            }
            
            let pathsString = filePaths.joined(separator: " ")
            
            // Send the file paths to terminal
            sendTextToTerminal(pathsString)
            
            print("✅ Dropped \(urls.count) file(s): \(pathsString)")
            return true
        }
        
        // Handle plain text
        if let string = pasteboard.string(forType: .string) {
            sendTextToTerminal(string)
            print("✅ Dropped text: \(string)")
            return true
        }
        
        return false
    }
    
    private func sendTextToTerminal(_ text: String) {
        guard let currentTab = currentTerminalTab,
              let webView = terminalWebViews[currentTab.id] else {
            print("❌ No active terminal tab to send text to")
            return
        }
        
        print("🎯 Attempting to send text to terminal: '\(text)'")
        
        // Strategy 1: Try direct JavaScript injection to ttyd terminal
        sendViaJavaScript(text, webView: webView) { success in
            if !success {
                print("📋 JavaScript failed, trying clipboard method...")
                self.sendViaClipboard(text, webView: webView)
            }
        }
    }
    
    private func sendViaJavaScript(_ text: String, webView: WKWebView, completion: @escaping (Bool) -> Void) {
        let escapedText = text.replacingOccurrences(of: "'", with: "\\'")
                             .replacingOccurrences(of: "\\", with: "\\\\")
                             .replacingOccurrences(of: "\n", with: "\\n")
                             .replacingOccurrences(of: "\r", with: "\\r")
        
        // Very basic approach - just try to get text into the terminal
        let script = """
        (function() {
            console.log('🎯 Attempting to send text to terminal:', '\(escapedText)');
            
            // Try to find terminal element and focus it
            document.body.focus();
            document.body.click();
            
            // Wait a moment then try direct text insertion
            setTimeout(function() {
                // Method 1: Try direct paste simulation
                if (document.execCommand) {
                    try {
                        document.execCommand('insertText', false, '\(escapedText)');
                        console.log('✅ Text inserted via execCommand');
                        return true;
                    } catch (e) {
                        console.log('⚠️ execCommand failed:', e);
                    }
                }
                
                // Method 2: Try dispatching input events to active element
                const activeElement = document.activeElement;
                if (activeElement) {
                    const event = new Event('input', { bubbles: true });
                    event.data = '\(escapedText)';
                    activeElement.dispatchEvent(event);
                    console.log('✅ Input event dispatched to active element');
                    return true;
                }
                
                console.log('⚠️ All methods failed');
                return false;
            }, 100);
            
            return true;
        })();
        """
        
        webView.evaluateJavaScript(script) { result, error in
            let success = (result as? Bool) ?? false
            if let error = error {
                print("❌ JavaScript error: \(error)")
            }
            print(success ? "✅ JavaScript basic send attempted" : "⚠️ JavaScript basic send failed")
            completion(success)
        }
    }
    
    private func sendViaClipboard(_ text: String, webView: WKWebView) {
        print("📋 Using clipboard method as fallback for text: '\(text)'")
        
        // Store current clipboard content
        let pasteboard = NSPasteboard.general
        let originalClipboard = pasteboard.string(forType: .string)
        
        // Set our text to clipboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // Very simple paste attempt
        let pasteScript = """
        (function() {
            console.log('📋 Attempting clipboard paste');
            
            // Focus and click to ensure terminal is active
            document.body.focus();
            document.body.click();
            
            // Try multiple paste methods
            setTimeout(function() {
                try {
                    // Method 1: execCommand paste
                    if (document.execCommand('paste')) {
                        console.log('✅ Paste via execCommand succeeded');
                        return;
                    }
                } catch (e) {
                    console.log('⚠️ execCommand paste failed:', e);
                }
                
                // Method 2: Keyboard event simulation for Cmd+V
                const pasteEvent = new KeyboardEvent('keydown', {
                    key: 'v',
                    code: 'KeyV',
                    metaKey: true,
                    bubbles: true
                });
                document.dispatchEvent(pasteEvent);
                console.log('✅ Cmd+V event dispatched');
            }, 50);
            
            return true;
        })();
        """
        
        webView.evaluateJavaScript(pasteScript) { result, error in
            if let error = error {
                print("❌ Clipboard paste failed: \(error)")
            } else {
                print("✅ Clipboard paste attempted")
            }
            
            // Restore original clipboard after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                pasteboard.clearContents()
                if let original = originalClipboard {
                    pasteboard.setString(original, forType: .string)
                }
            }
        }
    }
}

// MARK: - WKNavigationDelegate
extension TTYDTerminalPanel: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("✅ ttyd terminal loaded successfully")
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("❌ Failed to load ttyd terminal: \(error)")
        
        // Retry loading after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            if let currentTab = self?.currentTerminalTab {
                self?.loadTerminalURLForTab(currentTab)
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("❌ Failed to load ttyd terminal (provisional): \(error)")
        
        // Retry loading after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            if let currentTab = self?.currentTerminalTab {
                self?.loadTerminalURLForTab(currentTab)
            }
        }
    }
}