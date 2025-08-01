import Cocoa

// For now, we'll implement a basic terminal without SwiftTerm dependency
// This will be replaced once SwiftTerm is added via Xcode
class SwiftTerminalPanel: NSViewController {
    
    // UI Components
    private var panelView: NSView!
    private var headerView: NSView!
    private var closeButton: NSButton!
    private var titleLabel: NSTextField!
    private var terminalScrollView: NSScrollView!
    private var terminalTextView: NSTextView!
    
    // Terminal state - PTY-based shell session
    private var shellProcess: Process?
    private var masterFileHandle: FileHandle?
    private var slaveFileHandle: FileHandle?
    private var isShellRunning = false
    private var lastTextLength = 0
    
    // Panel state
    var onClose: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupFloatingPanel()
        setupHeader()
        setupTerminalArea() 
        startProperPTYShell()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        // Focus terminal text view when panel opens
        DispatchQueue.main.async {
            self.view.window?.makeFirstResponder(self.terminalTextView)
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
        
        let statusLabel = NSTextField(labelWithString: "PTY Ready")
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
    
    private func setupTerminalArea() {
        terminalScrollView = NSScrollView()
        terminalScrollView.translatesAutoresizingMaskIntoConstraints = false
        terminalScrollView.hasVerticalScroller = true
        terminalScrollView.hasHorizontalScroller = false
        terminalScrollView.autohidesScrollers = true
        terminalScrollView.borderType = .noBorder
        terminalScrollView.drawsBackground = false
        
        terminalTextView = NSTextView()
        terminalTextView.backgroundColor = NSColor.clear
        terminalTextView.textColor = NSColor.white
        terminalTextView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        terminalTextView.isEditable = true
        terminalTextView.isSelectable = true
        terminalTextView.string = ""
        terminalTextView.delegate = self
        
        // Configure for proper scrolling
        terminalTextView.isVerticallyResizable = true
        terminalTextView.isHorizontallyResizable = false
        terminalTextView.autoresizingMask = [.width]
        
        if let textContainer = terminalTextView.textContainer {
            textContainer.containerSize = CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
            textContainer.widthTracksTextView = true
        }
        
        terminalTextView.maxSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        terminalTextView.minSize = CGSize(width: 0, height: 0)
        
        terminalScrollView.documentView = terminalTextView
        view.addSubview(terminalScrollView)
        
        NSLayoutConstraint.activate([
            terminalScrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 12),
            terminalScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            terminalScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            terminalScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20)
        ])
    }
    
    private func startProperPTYShell() {
        // Create a real PTY using POSIX functions
        var masterFD: Int32 = 0
        var slaveFD: Int32 = 0
        
        // Create PTY pair
        masterFD = posix_openpt(O_RDWR)
        guard masterFD >= 0 else {
            appendToTerminal("Failed to create PTY master\n", color: NSColor.systemRed)
            return
        }
        
        guard grantpt(masterFD) == 0 else {
            appendToTerminal("Failed to grant PTY\n", color: NSColor.systemRed)
            close(masterFD)
            return
        }
        
        guard unlockpt(masterFD) == 0 else {
            appendToTerminal("Failed to unlock PTY\n", color: NSColor.systemRed)
            close(masterFD)
            return
        }
        
        // Get slave path and open it
        guard let slavePath = String(cString: ptsname(masterFD), encoding: .utf8) else {
            appendToTerminal("Failed to get PTY slave path\n", color: NSColor.systemRed)
            close(masterFD)
            return
        }
        
        slaveFD = open(slavePath, O_RDWR)
        guard slaveFD >= 0 else {
            appendToTerminal("Failed to open PTY slave\n", color: NSColor.systemRed)
            close(masterFD)
            return
        }
        
        print("✅ Created PTY - master: \(masterFD), slave: \(slaveFD), path: \(slavePath)")
        
        // Create file handles
        masterFileHandle = FileHandle(fileDescriptor: masterFD, closeOnDealloc: true)
        slaveFileHandle = FileHandle(fileDescriptor: slaveFD, closeOnDealloc: true)
        
        // Create and configure shell process
        shellProcess = Process()
        guard let process = shellProcess else {
            appendToTerminal("Failed to create shell process\n", color: NSColor.systemRed)
            return
        }
        
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-i", "-l"]
        
        // Connect process to slave PTY
        process.standardInput = slaveFileHandle
        process.standardOutput = slaveFileHandle
        process.standardError = slaveFileHandle
        
        // Set up environment for proper terminal behavior
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
        
        // Enhance PATH
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
        
        // Set up continuous output reading from master PTY
        guard let masterHandle = masterFileHandle else {
            appendToTerminal("Master file handle is nil\n", color: NSColor.systemRed)
            return
        }
        
        masterHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if !data.isEmpty {
                if let output = String(data: data, encoding: .utf8) {
                    print("📤 Received from PTY: '\(output.debugDescription)' (\(data.count) bytes)")
                    DispatchQueue.main.async {
                        self?.appendToTerminal(output, color: NSColor.white)
                    }
                } else {
                    print("❌ Failed to decode PTY output as UTF-8 (\(data.count) bytes)")
                }
            }
        }
        
        // Handle shell termination
        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.isShellRunning = false
                self?.appendToTerminal("\nShell session ended\n", color: NSColor.systemYellow)
            }
        }
        
        // Start the shell
        do {
            try process.run()
            isShellRunning = true
            print("✅ PTY shell started successfully")
        } catch {
            appendToTerminal("Failed to start shell: \(error.localizedDescription)\n", color: NSColor.systemRed)
        }
    }
    
    @objc private func closePanel() {
        // Terminate shell process
        shellProcess?.terminate()
        shellProcess = nil
        masterFileHandle?.closeFile()
        slaveFileHandle?.closeFile()
        masterFileHandle = nil
        slaveFileHandle = nil
        isShellRunning = false
        
        // Call close callback
        onClose?()
    }
    
    private func appendToTerminal(_ text: String, color: NSColor) {
        DispatchQueue.main.async {
            // Clean ANSI escape sequences
            let cleanedText = self.cleanANSIEscapeSequences(text)
            
            let attributedString = NSAttributedString(
                string: cleanedText,
                attributes: [
                    .foregroundColor: color,
                    .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
                    .backgroundColor: NSColor.clear
                ]
            )
            
            self.terminalTextView.textStorage?.append(attributedString)
            
            // Update our text length tracking
            let textLength = self.terminalTextView.string.count
            self.lastTextLength = textLength
            
            // Auto-scroll to bottom and keep cursor at end
            if textLength > 0 {
                let endRange = NSRange(location: textLength, length: 0)
                self.terminalTextView.setSelectedRange(endRange)
                self.terminalTextView.scrollRangeToVisible(endRange)
            }
        }
    }
    
    private func cleanANSIEscapeSequences(_ text: String) -> String {
        let ansiPattern = "\\x1B\\[[0-9;]*[A-Za-z]"
        
        do {
            let regex = try NSRegularExpression(pattern: ansiPattern, options: [])
            let range = NSRange(location: 0, length: text.count)
            let cleanedText = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
            
            var result = cleanedText
            result = result.replacingOccurrences(of: "\u{1B}[?2004h", with: "")
            result = result.replacingOccurrences(of: "\u{1B}[?2004l", with: "")
            result = result.replacingOccurrences(of: "\u{1B}[H", with: "")
            result = result.replacingOccurrences(of: "\u{1B}[2J", with: "")
            result = result.replacingOccurrences(of: "\u{1B}[K", with: "")
            result = result.replacingOccurrences(of: "\u{07}", with: "")
            
            return result
        } catch {
            return text
        }
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
        
        // Handle Ctrl+C to send interrupt signal to shell
        if event.modifierFlags.contains(.control) && event.charactersIgnoringModifiers == "c" {
            if let masterHandle = masterFileHandle {
                // Send Ctrl+C (ASCII 3) to PTY
                let ctrlC = Data([0x03])
                do {
                    try masterHandle.write(contentsOf: ctrlC)
                    print("✅ Sent Ctrl+C to PTY")
                } catch {
                    print("Failed to send Ctrl+C: \(error)")
                }
            }
            return
        }
        
        super.keyDown(with: event)
    }
}

// MARK: - NSTextViewDelegate  
extension SwiftTerminalPanel: NSTextViewDelegate {
    
    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        // Send ALL commands directly to PTY
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            sendToPTY("\n")
            return true
        }
        else if commandSelector == #selector(NSResponder.deleteBackward(_:)) {
            sendToPTY("\u{7F}") // DEL character
            return true
        }
        else if commandSelector == #selector(NSResponder.moveUp(_:)) {
            sendToPTY("\u{1B}[A") // Up arrow
            return true
        }
        else if commandSelector == #selector(NSResponder.moveDown(_:)) {
            sendToPTY("\u{1B}[B") // Down arrow
            return true
        }
        else if commandSelector == #selector(NSResponder.moveLeft(_:)) {
            sendToPTY("\u{1B}[D") // Left arrow
            return true
        }
        else if commandSelector == #selector(NSResponder.moveRight(_:)) {
            sendToPTY("\u{1B}[C") // Right arrow
            return true
        }
        else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            sendToPTY("\u{03}") // Ctrl+C
            return true
        }
        
        return false
    }
    
    func textDidChange(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView else { return }
        
        let currentText = textView.string
        let currentLength = currentText.count
        
        // Only handle text additions (user typing)
        if currentLength > lastTextLength {
            let addedText = String(currentText.suffix(currentLength - lastTextLength))
            
            // Send the typed characters to PTY
            sendToPTY(addedText)
            print("📝 Sent to PTY: '\(addedText)'")
        }
        
        // Update our length tracking
        lastTextLength = currentLength
    }
    
    // Function to send data directly to PTY
    private func sendToPTY(_ text: String) {
        guard isShellRunning, let masterHandle = masterFileHandle else {
            print("❌ PTY not running - isRunning: \(isShellRunning), handle: \(masterFileHandle != nil)")
            return
        }
        
        if let data = text.data(using: .utf8) {
            do {
                try masterHandle.write(contentsOf: data)
                print("✅ Successfully sent to PTY: '\(text)' (\(data.count) bytes)")
            } catch {
                print("❌ Failed to send to PTY: \(error)")
            }
        } else {
            print("❌ Failed to encode text as UTF-8: '\(text)'")
        }
    }
}