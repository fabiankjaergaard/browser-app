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
    private var webView: WKWebView!
    private var dragOverlay: DragOverlayView?
    
    // ttyd process
    private var ttydProcess: Process?
    private var isttydRunning = false
    private var ttydPort: Int = 7681
    
    // Panel state
    var onClose: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupFloatingPanel()
        setupHeader()
        setupWebView()
        startTTYDProcess()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        // Focus webview when panel opens
        DispatchQueue.main.async {
            self.view.window?.makeFirstResponder(self.webView)
        }
    }
    
    private func setupFloatingPanel() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.95).cgColor
        
        // Add subtle blur effect for sidebar
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = .sidebar
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(visualEffectView)
        
        NSLayoutConstraint.activate([
            visualEffectView.topAnchor.constraint(equalTo: view.topAnchor),
            visualEffectView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupHeader() {
        headerView = NSView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerView)
        
        // Terminal title with icon
        let iconLabel = NSTextField(labelWithString: "🖥️")
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        iconLabel.font = NSFont.systemFont(ofSize: 18)
        headerView.addSubview(iconLabel)
        
        titleLabel = NSTextField(labelWithString: "Terminal")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = NSColor.white
        headerView.addSubview(titleLabel)
        
        // Status indicator
        let statusIndicator = NSView()
        statusIndicator.translatesAutoresizingMaskIntoConstraints = false
        statusIndicator.wantsLayer = true
        statusIndicator.layer?.backgroundColor = NSColor.systemGreen.cgColor
        statusIndicator.layer?.cornerRadius = 4
        headerView.addSubview(statusIndicator)
        
        let statusLabel = NSTextField(labelWithString: "ttyd Ready")
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        statusLabel.textColor = NSColor.secondaryLabelColor
        headerView.addSubview(statusLabel)
        
        // Close button
        closeButton = NSButton()
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close")
        closeButton.bezelStyle = .regularSquare
        closeButton.isBordered = false
        closeButton.contentTintColor = NSColor.secondaryLabelColor
        closeButton.target = self
        closeButton.action = #selector(closePanel)
        headerView.addSubview(closeButton)
        
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            headerView.heightAnchor.constraint(equalToConstant: 44),
            
            iconLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor, constant: -6),
            iconLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            
            titleLabel.centerYAnchor.constraint(equalTo: iconLabel.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 8),
            
            statusIndicator.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            statusIndicator.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            statusIndicator.widthAnchor.constraint(equalToConstant: 8),
            statusIndicator.heightAnchor.constraint(equalToConstant: 8),
            
            statusLabel.centerYAnchor.constraint(equalTo: statusIndicator.centerYAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: statusIndicator.trailingAnchor, constant: 6),
            
            closeButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 24),
            closeButton.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
    
    private func setupWebView() {
        let config = WKWebViewConfiguration()
        
        // Enable debugging in development
        #if DEBUG
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        #endif
        
        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        
        // Disable drag and drop on webView so our container can handle it
        webView.setValue(false, forKey: "allowsLinkPreview")
        
        view.addSubview(webView)
        
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 12),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20)
        ])
        
        // Add a transparent overlay for drag and drop
        setupDragOverlay()
    }
    
    private func setupDragOverlay() {
        // Create a transparent overlay view that sits on top of webView
        let overlayView = DragOverlayView()
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        overlayView.terminalPanel = self
        
        view.addSubview(overlayView)
        
        // Position overlay exactly over the webView
        NSLayoutConstraint.activate([
            overlayView.topAnchor.constraint(equalTo: webView.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: webView.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: webView.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: webView.bottomAnchor)
        ])
        
        // Store reference to overlay
        self.dragOverlay = overlayView
    }
    
    private func startTTYDProcess() {
        // Find available port starting from 7681
        ttydPort = findAvailablePort(startingFrom: 7681)
        
        ttydProcess = Process()
        guard let process = ttydProcess else {
            print("❌ Failed to create ttyd process")
            return
        }
        
        // Configure ttyd process
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/ttyd")
        process.arguments = [
            "--port", String(ttydPort),
            "--interface", "127.0.0.1",  // Only bind to localhost for security
            "--writable",                // Allow input to terminal
            "--once",                   // Exit after one session (we'll restart as needed)
            "/bin/zsh", "-i", "-l"      // Start interactive login shell
        ]
        
        // Set up environment
        var environment = ProcessInfo.processInfo.environment
        environment["HOME"] = NSHomeDirectory()
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
                self?.isttydRunning = false
                print("⚠️ ttyd process terminated")
            }
        }
        
        // Start ttyd
        do {
            try process.run()
            isttydRunning = true
            print("✅ ttyd started on port \(ttydPort)")
            
            // Wait a moment for ttyd to start, then load the web page
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.loadTerminalURL()
            }
        } catch {
            print("❌ Failed to start ttyd: \(error)")
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
    
    private func loadTerminalURL() {
        let url = URL(string: "http://127.0.0.1:\(ttydPort)")!
        let request = URLRequest(url: url)
        webView.load(request)
        print("✅ Loading ttyd terminal at \(url)")
    }
    
    @objc private func closePanel() {
        // Terminate ttyd process
        ttydProcess?.terminate()
        ttydProcess = nil
        isttydRunning = false
        
        // Call close callback
        onClose?()
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
        print("🎯 Attempting to send text to terminal: '\(text)'")
        
        // Strategy 1: Try direct JavaScript injection to ttyd terminal
        sendViaJavaScript(text) { success in
            if !success {
                print("📋 JavaScript failed, trying clipboard method...")
                self.sendViaClipboard(text)
            }
        }
    }
    
    private func sendViaJavaScript(_ text: String, completion: @escaping (Bool) -> Void) {
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
    
    private func sendViaClipboard(_ text: String) {
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
            self?.loadTerminalURL()
        }
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("❌ Failed to load ttyd terminal (provisional): \(error)")
        
        // Retry loading after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.loadTerminalURL()
        }
    }
}