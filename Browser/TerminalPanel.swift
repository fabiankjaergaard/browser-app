import Cocoa

class TerminalPanel: NSViewController {
    
    // UI Components
    private var panelView: NSView!
    private var headerView: NSView!
    private var closeButton: NSButton!
    private var titleLabel: NSTextField!
    private var terminalScrollView: NSScrollView!
    private var terminalTextView: NSTextView!
    
    // Terminal state - simple shell session
    private var shellProcess: Process?
    private var shellInputPipe: Pipe?
    private var shellOutputPipe: Pipe?
    private var isShellRunning = false
    private var lastTextLength = 0
    
    // Panel state
    var onClose: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupFloatingPanel()
        setupHeader()
        setupTerminalArea() 
        startPersistentShell()
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
        
        let statusLabel = NSTextField(labelWithString: "Shell Ready")
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
        terminalTextView.isEditable = true  // Make it editable like a real terminal
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
            terminalScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20)  // Remove space for input
        ])
    }
    

    
    private func startPersistentShell() {
        // Use socat to create a real PTY
        shellProcess = Process()
        
        guard let process = shellProcess else {
            appendToTerminal("Failed to create shell process\n", color: NSColor.systemRed)
            return
        }
        
        // Try python3 with pty module as fallback if socat isn't available
        let pythonScript = """
import pty
import subprocess
import sys
import os

# Create a PTY
master, slave = pty.openpty()

# Start zsh with the PTY
proc = subprocess.Popen(['/bin/zsh', '-i', '-l'], 
                       stdin=slave, stdout=slave, stderr=slave,
                       preexec_fn=os.setsid)

# Close slave in parent
os.close(slave)

# Forward data between PTY and stdio
try:
    while proc.poll() is None:
        import select
        r, w, e = select.select([sys.stdin, master], [], [], 0.1)
        
        if sys.stdin in r:
            data = sys.stdin.buffer.read(1024)
            if data:
                os.write(master, data)
        
        if master in r:
            try:
                data = os.read(master, 1024)
                if data:
                    sys.stdout.buffer.write(data)
                    sys.stdout.buffer.flush()
            except OSError:
                break
except KeyboardInterrupt:
    pass
finally:
    proc.terminate()
    os.close(master)
"""
        
        // Write the script to a temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let scriptPath = tempDir.appendingPathComponent("pty_shell.py")
        
        do {
            try pythonScript.write(to: scriptPath, atomically: true, encoding: .utf8)
            process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
            process.arguments = [scriptPath.path]
        } catch {
            // Fallback to direct shell if script creation fails
            print("⚠️ Failed to create PTY script, using direct shell")
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-i", "-l"]
        }
        
        shellInputPipe = Pipe()
        shellOutputPipe = Pipe()
        
        guard let inputPipe = shellInputPipe,
              let outputPipe = shellOutputPipe else {
            appendToTerminal("Failed to create pipes\n", color: NSColor.systemRed)
            return
        }
        
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        
        // Set up environment for proper PTY terminal behavior
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
        
        // Set up continuous output reading
        let outputHandle = outputPipe.fileHandleForReading
        
        outputHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if !data.isEmpty {
                if let output = String(data: data, encoding: .utf8) {
                    print("📤 Received from shell: '\(output.debugDescription)' (\(data.count) bytes)")
                    DispatchQueue.main.async {
                        self?.appendToTerminal(output, color: NSColor.white)
                    }
                } else {
                    print("❌ Failed to decode shell output as UTF-8 (\(data.count) bytes)")
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
            print("✅ Shell started successfully")
        } catch {
            appendToTerminal("Failed to start shell: \(error.localizedDescription)\n", color: NSColor.systemRed)
        }
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
    
    private func appendToTerminal(_ text: String, color: NSColor) {
        DispatchQueue.main.async {
            // Minimal ANSI escape sequence cleaning
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
            if let inputPipe = shellInputPipe {
                // Send Ctrl+C (ASCII 3) to shell
                let ctrlC = Data([0x03])
                do {
                    try inputPipe.fileHandleForWriting.write(contentsOf: ctrlC)
                    print("✅ Sent Ctrl+C to shell")
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
extension TerminalPanel: NSTextViewDelegate {
    
    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        // Send ALL commands directly to shell
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            sendToShell("\n")
            return true
        }
        else if commandSelector == #selector(NSResponder.deleteBackward(_:)) {
            sendToShell("\u{7F}") // DEL character
            return true
        }
        else if commandSelector == #selector(NSResponder.moveUp(_:)) {
            sendToShell("\u{1B}[A") // Up arrow
            return true
        }
        else if commandSelector == #selector(NSResponder.moveDown(_:)) {
            sendToShell("\u{1B}[B") // Down arrow
            return true
        }
        else if commandSelector == #selector(NSResponder.moveLeft(_:)) {
            sendToShell("\u{1B}[D") // Left arrow
            return true
        }
        else if commandSelector == #selector(NSResponder.moveRight(_:)) {
            sendToShell("\u{1B}[C") // Right arrow
            return true
        }
        else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            sendToShell("\u{03}") // Ctrl+C
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
            
            // Send the typed characters to shell
            sendToShell(addedText)
            print("📝 Sent to shell: '\(addedText)'")
            
            // For now, let the text remain visible until shell echoes back
            // (In a real terminal, shell echo would replace this)
        }
        
        // Update our length tracking
        lastTextLength = currentLength
    }
    
    // Simple function to send data directly to shell
    private func sendToShell(_ text: String) {
        guard isShellRunning, let inputPipe = shellInputPipe else {
            print("❌ Shell not running - isRunning: \(isShellRunning), pipe: \(shellInputPipe != nil)")
            return
        }
        
        if let data = text.data(using: .utf8) {
            do {
                try inputPipe.fileHandleForWriting.write(contentsOf: data)
                print("✅ Successfully sent to shell: '\(text)' (\(data.count) bytes)")
            } catch {
                print("❌ Failed to send to shell: \(error)")
            }
        } else {
            print("❌ Failed to encode text as UTF-8: '\(text)'")
        }
    }
}