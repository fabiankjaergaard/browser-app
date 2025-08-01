import Cocoa
import WebKit

class WebTerminalPanel: NSViewController {
    
    // UI Components
    private var panelView: NSView!
    private var headerView: NSView!
    private var closeButton: NSButton!
    private var titleLabel: NSTextField!
    private var webView: WKWebView!
    
    // Shell process
    private var shellProcess: Process?
    private var shellInputPipe: Pipe?
    private var shellOutputPipe: Pipe?
    private var isShellRunning = false
    private var currentDirectory = NSHomeDirectory()
    
    // Panel state
    var onClose: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupFloatingPanel()
        setupHeader()
        setupWebView()
        startShellProcess()
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
        
        let statusLabel = NSTextField(labelWithString: "Web Ready")
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
        
        // Add message handlers for terminal communication
        config.userContentController.add(self, name: "terminalInput")
        config.userContentController.add(self, name: "terminalResize")
        config.userContentController.add(self, name: "terminalReady")
        
        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        view.addSubview(webView)
        
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 12),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20)
        ])
        
        // Load terminal HTML
        loadTerminalHTML()
    }
    
    private func loadTerminalHTML() {
        guard let htmlPath = Bundle.main.path(forResource: "terminal", ofType: "html"),
              let htmlContent = try? String(contentsOfFile: htmlPath) else {
            print("❌ Could not load terminal.html")
            return
        }
        
        let baseURL = URL(fileURLWithPath: htmlPath).deletingLastPathComponent()
        webView.loadHTMLString(htmlContent, baseURL: baseURL)
        print("✅ Loading terminal HTML")
    }
    
    private func startShellProcess() {
        shellProcess = Process()
        guard let process = shellProcess else {
            print("❌ Failed to create shell process")
            return
        }
        
        // Start with a simple command for testing
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-i"]
        process.currentDirectoryURL = URL(fileURLWithPath: currentDirectory)
        
        // Create pipes for communication
        shellInputPipe = Pipe()
        shellOutputPipe = Pipe()
        
        guard let inputPipe = shellInputPipe,
              let outputPipe = shellOutputPipe else {
            print("❌ Failed to create pipes")
            return
        }
        
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        
        // Set up environment
        var environment = ProcessInfo.processInfo.environment
        environment["HOME"] = NSHomeDirectory()
        environment["USER"] = NSUserName()
        environment["TERM"] = "xterm-256color"
        environment["SHELL"] = "/bin/zsh"
        environment["LANG"] = "en_US.UTF-8"
        environment["COLUMNS"] = "120"
        environment["LINES"] = "30"
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
        
        // Set up output reading with proper debugging
        let outputHandle = outputPipe.fileHandleForReading
        outputHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            print("📥 Received \(data.count) bytes from shell")
            if !data.isEmpty {
                if let output = String(data: data, encoding: .utf8) {
                    print("📄 Shell output: '\(output.debugDescription)'")
                    DispatchQueue.main.async {
                        self?.sendOutputToTerminal(output)
                    }
                } else {
                    print("❌ Failed to decode shell output as UTF-8")
                }
            } else {
                print("⚪ Empty data received from shell")
            }
        }
        
        // Handle process termination
        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.isShellRunning = false
                self?.sendOutputToTerminal("\n\r[Process completed]\n\r")
            }
        }
        
        // Start the process
        do {
            try process.run()
            isShellRunning = true
            print("✅ Shell process started with PID: \(process.processIdentifier)")
            
            // Send initial newline to get shell prompt
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.sendInputToShell("\n")
                print("🔄 Sent initial newline to get prompt")
            }
        } catch {
            print("❌ Failed to start shell: \(error)")
        }
    }
    
    private func sendInputToShell(_ input: String) {
        guard isShellRunning else {
            print("❌ Shell is not running")
            return
        }
        
        guard let inputPipe = shellInputPipe else {
            print("❌ Input pipe is nil")
            return
        }
        
        guard let data = input.data(using: .utf8) else {
            print("❌ Failed to encode input as UTF-8: '\(input)'")
            return
        }
        
        do {
            try inputPipe.fileHandleForWriting.write(contentsOf: data)
            print("📤 Sent to shell: '\(input.debugDescription)' (\(data.count) bytes)")
        } catch {
            print("❌ Failed to write to shell: \(error)")
        }
    }
    
    private func sendOutputToTerminal(_ output: String) {
        let script = "window.writeToTerminal(\(escapeForJavaScript(output)));"
        webView.evaluateJavaScript(script) { result, error in
            if let error = error {
                print("❌ JavaScript error: \(error)")
            }
        }
    }
    
    private func escapeForJavaScript(_ string: String) -> String {
        let escaped = string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
        
        return "\"\(escaped)\""
    }
    
    @objc private func closePanel() {
        // Terminate shell process
        shellProcess?.terminate()
        shellProcess = nil
        shellInputPipe = nil
        shellOutputPipe = nil
        isShellRunning = false
        
        // Call close callback
        onClose?()
    }
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 600))
    }
    
    override func keyDown(with event: NSEvent) {
        // Handle Esc key to close panel
        if event.keyCode == 53 { // Esc key
            closePanel()
            return
        }
        
        super.keyDown(with: event)
    }
}

// MARK: - WKScriptMessageHandler
extension WebTerminalPanel: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        
        switch message.name {
        case "terminalInput":
            if let body = message.body as? [String: Any],
               let data = body["data"] as? String {
                sendInputToShell(data)
            }
            
        case "terminalResize":
            if let body = message.body as? [String: Any],
               let cols = body["cols"] as? Int,
               let rows = body["rows"] as? Int {
                print("📐 Terminal resized to \(cols)x\(rows)")
                // Update shell environment if needed
            }
            
        case "terminalReady":
            print("✅ Terminal is ready")
            // Send initial prompt or welcome message if needed
            
        default:
            print("❓ Unknown message: \(message.name)")
        }
    }
}

// MARK: - WKNavigationDelegate
extension WebTerminalPanel: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("✅ WebView finished loading")
        
        // Focus the terminal
        webView.evaluateJavaScript("window.focusTerminal();") { result, error in
            if let error = error {
                print("❌ Failed to focus terminal: \(error)")
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("❌ WebView failed to load: \(error)")
    }
}