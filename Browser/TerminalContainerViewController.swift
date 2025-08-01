import Cocoa

// MARK: - Terminal App Model
struct TerminalApp: Hashable {
    let name: String
    let path: String
    let emoji: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(path)
    }
}

class TerminalContainerViewController: NSViewController {
    
    private var headerView: NSView!
    private var containerView: TerminalContainerView!
    private var closeButton: NSButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupHeader()
        setupContainerView()
    }
    
    private func setupView() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.95).cgColor
        
        // Add subtle blur effect
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
        headerView.wantsLayer = true
        view.addSubview(headerView)
        
        // Terminal title
        let titleLabel = NSTextField(labelWithString: "Terminal Container")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = NSColor.white
        headerView.addSubview(titleLabel)
        
        // Close button
        closeButton = NSButton()
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close")
        closeButton.bezelStyle = .regularSquare
        closeButton.isBordered = false
        closeButton.contentTintColor = NSColor.secondaryLabelColor
        closeButton.target = self
        closeButton.action = #selector(closeTerminal)
        headerView.addSubview(closeButton)
        
        // Status indicator
        let statusIndicator = NSView()
        statusIndicator.translatesAutoresizingMaskIntoConstraints = false
        statusIndicator.wantsLayer = true
        statusIndicator.layer?.backgroundColor = NSColor.systemOrange.cgColor
        statusIndicator.layer?.cornerRadius = 4
        headerView.addSubview(statusIndicator)
        
        let statusLabel = NSTextField(labelWithString: "Choose Terminal App")
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        statusLabel.textColor = NSColor.secondaryLabelColor
        headerView.addSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 60),
            
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor, constant: -8),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            
            closeButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 20),
            closeButton.heightAnchor.constraint(equalToConstant: 20),
            
            statusIndicator.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            statusIndicator.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            statusIndicator.widthAnchor.constraint(equalToConstant: 8),
            statusIndicator.heightAnchor.constraint(equalToConstant: 8),
            
            statusLabel.centerYAnchor.constraint(equalTo: statusIndicator.centerYAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: statusIndicator.trailingAnchor, constant: 6)
        ])
    }
    
    private func setupContainerView() {
        containerView = TerminalContainerView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.delegate = self
        view.addSubview(containerView)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16)
        ])
    }
    
    @objc private func closeTerminal() {
        NotificationCenter.default.post(name: .toggleTerminal, object: nil)
    }
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 600))
    }
}

// MARK: - TerminalContainerViewDelegate
extension TerminalContainerViewController: TerminalContainerViewDelegate {
    func terminalContainerView(_ containerView: TerminalContainerView, didLaunchTerminal terminalApp: TerminalApp) {
        print("🖥️ Terminal launched: \(terminalApp.name)")
    }
}

// MARK: - Protocol for Terminal Container View
protocol TerminalContainerViewDelegate: AnyObject {
    func terminalContainerView(_ containerView: TerminalContainerView, didLaunchTerminal terminalApp: TerminalApp)
}

// MARK: - Terminal Container View with Emulator
class TerminalContainerView: NSView {
    
    weak var delegate: TerminalContainerViewDelegate?
    
    // Terminal emulator properties
    private var terminalTextView: NSTextView?
    private var terminalInputField: NSTextField?
    private var shellProcess: Process?
    private var shellInputPipe: Pipe?
    private var shellOutputPipe: Pipe?
    private var shellErrorPipe: Pipe?
    private var commandHistory: [String] = []
    private var historyIndex = -1
    private var isShellRunning = false
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setup()
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.3).cgColor
        layer?.cornerRadius = 12
        layer?.borderWidth = 2
        layer?.borderColor = NSColor.tertiaryLabelColor.cgColor
        
        setupPlaceholder()
    }
    
    private func setupPlaceholder() {
        // Main title
        let titleLabel = NSTextField(labelWithString: "🖥️ Terminal Emulator")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.alignment = .center
        titleLabel.font = NSFont.systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = NSColor.labelColor
        addSubview(titleLabel)
        
        // Subtitle
        let subtitleLabel = NSTextField(labelWithString: "Choose your terminal style:")
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.alignment = .center
        subtitleLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        subtitleLabel.textColor = NSColor.secondaryLabelColor
        addSubview(subtitleLabel)
        
        // Terminal app buttons container
        let buttonContainer = NSStackView()
        buttonContainer.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.orientation = .vertical
        buttonContainer.spacing = 12
        buttonContainer.alignment = .centerX
        addSubview(buttonContainer)
        
        // Detect available terminal apps
        let terminalApps = detectAvailableTerminals()
        
        for terminalApp in terminalApps {
            let button = createTerminalButton(for: terminalApp)
            buttonContainer.addArrangedSubview(button)
        }
        
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 60),
            
            subtitleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            
            buttonContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
            buttonContainer.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 24),
            buttonContainer.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 20),
            buttonContainer.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20)
        ])
    }
    
    private func detectAvailableTerminals() -> [TerminalApp] {
        // Return all terminal styles (not checking for actual apps)
        return [
            TerminalApp(name: "Terminal", path: "/Applications/Utilities/Terminal.app", emoji: "🖥️"),
            TerminalApp(name: "Warp", path: "/Applications/Warp.app", emoji: "🚀"),
            TerminalApp(name: "iTerm2", path: "/Applications/iTerm.app", emoji: "🔥"),
            TerminalApp(name: "Hyper", path: "/Applications/Hyper.app", emoji: "💫"),
            TerminalApp(name: "VS Code", path: "/Applications/Visual Studio Code.app", emoji: "💻")
        ]
    }
    
    private func createTerminalButton(for terminalApp: TerminalApp) -> NSButton {
        let button = NSButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.title = "\(terminalApp.emoji) \(terminalApp.name) Style"
        button.bezelStyle = .rounded
        button.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        button.contentTintColor = NSColor.controlAccentColor
        button.target = self
        button.action = #selector(terminalButtonClicked(_:))
        
        // Store terminal app in button's identifier
        button.identifier = NSUserInterfaceItemIdentifier(terminalApp.name)
        
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 200),
            button.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        return button
    }
    
    @objc private func terminalButtonClicked(_ sender: NSButton) {
        guard let identifier = sender.identifier?.rawValue else { return }
        
        // Find the terminal app by name
        let terminalApps = detectAvailableTerminals()
        guard let terminalApp = terminalApps.first(where: { $0.name == identifier }) else { return }
        
        startTerminalEmulator(for: terminalApp)
    }
    
    private func startTerminalEmulator(for terminalApp: TerminalApp) {
        print("🚀 Starting terminal emulator for \(terminalApp.name)")
        
        // Show loading message
        showLoadingState(for: terminalApp)
        
        // Start the emulator after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.createTerminalEmulatorUI(for: terminalApp)
            self.startShellProcess(for: terminalApp)
        }
    }
    
    private func showLoadingState(for terminalApp: TerminalApp) {
        subviews.forEach { $0.removeFromSuperview() }
        
        let loadingLabel = NSTextField(labelWithString: "🔄 Starting \(terminalApp.name) style emulator...")
        loadingLabel.translatesAutoresizingMaskIntoConstraints = false
        loadingLabel.alignment = .center
        loadingLabel.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        loadingLabel.textColor = NSColor.labelColor
        addSubview(loadingLabel)
        
        NSLayoutConstraint.activate([
            loadingLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            loadingLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    
    private func createTerminalEmulatorUI(for terminalApp: TerminalApp) {
        // Clear previous content
        subviews.forEach { $0.removeFromSuperview() }
        
        // Create main container
        let terminalContainer = NSView()
        terminalContainer.translatesAutoresizingMaskIntoConstraints = false
        terminalContainer.wantsLayer = true
        
        // Style based on terminal app
        let (backgroundColor, textColor, font) = getTerminalStyle(for: terminalApp)
        terminalContainer.layer?.backgroundColor = backgroundColor.cgColor
        terminalContainer.layer?.cornerRadius = 8
        addSubview(terminalContainer)
        
        // Create header
        let headerView = NSView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.wantsLayer = true
        headerView.layer?.backgroundColor = backgroundColor.blended(withFraction: 0.1, of: NSColor.white)?.cgColor
        terminalContainer.addSubview(headerView)
        
        // App name and status
        let titleLabel = NSTextField(labelWithString: "\(terminalApp.emoji) \(terminalApp.name) Emulator")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = textColor
        titleLabel.backgroundColor = NSColor.clear
        titleLabel.isBordered = false
        headerView.addSubview(titleLabel)
        
        // Close button
        let closeButton = NSButton()
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.title = "×"
        closeButton.bezelStyle = .regularSquare
        closeButton.isBordered = false
        closeButton.font = NSFont.systemFont(ofSize: 14, weight: .bold)
        closeButton.contentTintColor = textColor.withAlphaComponent(0.7)
        closeButton.target = self
        closeButton.action = #selector(resetToLauncher)
        headerView.addSubview(closeButton)
        
        // Create terminal text area
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        terminalContainer.addSubview(scrollView)
        
        let textView = NSTextView()
        textView.backgroundColor = backgroundColor
        textView.textColor = textColor
        textView.font = font
        textView.isEditable = false
        textView.isSelectable = true
        textView.string = "Welcome to \(terminalApp.name) Emulator\n\nInitializing shell...\n"
        
        // Configure for terminal-like behavior
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.maxSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        
        scrollView.documentView = textView
        self.terminalTextView = textView
        
        // Create input area
        let inputContainer = NSView()
        inputContainer.translatesAutoresizingMaskIntoConstraints = false
        inputContainer.wantsLayer = true
        inputContainer.layer?.backgroundColor = backgroundColor.blended(withFraction: 0.05, of: NSColor.white)?.cgColor
        terminalContainer.addSubview(inputContainer)
        
        // Prompt label
        let promptLabel = NSTextField(labelWithString: getPromptStyle(for: terminalApp))
        promptLabel.translatesAutoresizingMaskIntoConstraints = false
        promptLabel.font = font
        promptLabel.textColor = getPromptColor(for: terminalApp)
        promptLabel.backgroundColor = NSColor.clear
        promptLabel.isBordered = false
        inputContainer.addSubview(promptLabel)
        
        // Input field
        let inputField = NSTextField()
        inputField.translatesAutoresizingMaskIntoConstraints = false
        inputField.font = font
        inputField.textColor = textColor
        inputField.backgroundColor = NSColor.clear
        inputField.isBordered = false
        inputField.focusRingType = .none
        inputField.target = self
        inputField.action = #selector(executeCommand(_:))
        inputField.delegate = self
        inputContainer.addSubview(inputField)
        self.terminalInputField = inputField
        
        // Set up constraints
        NSLayoutConstraint.activate([
            // Main container
            terminalContainer.topAnchor.constraint(equalTo: topAnchor),
            terminalContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            terminalContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            terminalContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            // Header
            headerView.topAnchor.constraint(equalTo: terminalContainer.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: terminalContainer.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: terminalContainer.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 30),
            
            // Title
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 12),
            
            // Close button
            closeButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -8),
            closeButton.widthAnchor.constraint(equalToConstant: 20),
            closeButton.heightAnchor.constraint(equalToConstant: 20),
            
            // Terminal text area
            scrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: terminalContainer.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: terminalContainer.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: inputContainer.topAnchor),
            
            // Input container
            inputContainer.leadingAnchor.constraint(equalTo: terminalContainer.leadingAnchor),
            inputContainer.trailingAnchor.constraint(equalTo: terminalContainer.trailingAnchor),
            inputContainer.bottomAnchor.constraint(equalTo: terminalContainer.bottomAnchor),
            inputContainer.heightAnchor.constraint(equalToConstant: 40),
            
            // Prompt
            promptLabel.centerYAnchor.constraint(equalTo: inputContainer.centerYAnchor),
            promptLabel.leadingAnchor.constraint(equalTo: inputContainer.leadingAnchor, constant: 12),
            
            // Input field
            inputField.centerYAnchor.constraint(equalTo: inputContainer.centerYAnchor),
            inputField.leadingAnchor.constraint(equalTo: promptLabel.trailingAnchor, constant: 4),
            inputField.trailingAnchor.constraint(equalTo: inputContainer.trailingAnchor, constant: -12)
        ])
        
        // Focus on input field
        DispatchQueue.main.async {
            inputField.becomeFirstResponder()
        }
        
        // Notify delegate
        delegate?.terminalContainerView(self, didLaunchTerminal: terminalApp)
    }
    
    private func getTerminalStyle(for terminalApp: TerminalApp) -> (NSColor, NSColor, NSFont) {
        let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        
        switch terminalApp.name.lowercased() {
        case "warp":
            return (NSColor(red: 0.12, green: 0.12, blue: 0.16, alpha: 1.0), 
                   NSColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0), font)
        case "iterm2":
            return (NSColor(red: 0.07, green: 0.07, blue: 0.07, alpha: 1.0), 
                   NSColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1.0), font)
        case "hyper":
            return (NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0), 
                   NSColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0), font)
        case "vs code":
            return (NSColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0), 
                   NSColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1.0), font)
        default: // Terminal
            return (NSColor.black, NSColor.green, font)
        }
    }
    
    private func getPromptStyle(for terminalApp: TerminalApp) -> String {
        switch terminalApp.name.lowercased() {
        case "warp":
            return "❯"
        case "iterm2":
            return "$ "
        case "hyper":
            return "→ "
        case "vs code":
            return "PS> "
        default: // Terminal
            return "$ "
        }
    }
    
    private func getPromptColor(for terminalApp: TerminalApp) -> NSColor {
        switch terminalApp.name.lowercased() {
        case "warp":
            return NSColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 1.0)
        case "iterm2":
            return NSColor.systemGreen
        case "hyper":
            return NSColor.systemGreen
        case "vs code":
            return NSColor.systemBlue
        default: // Terminal
            return NSColor.systemGreen
        }
    }
    
    private func startShellProcess(for terminalApp: TerminalApp) {
        print("🐚 Starting shell process...")
        
        // Start a shell process
        shellProcess = Process()
        shellInputPipe = Pipe()
        shellOutputPipe = Pipe()
        shellErrorPipe = Pipe()
        
        guard let process = shellProcess,
              let inputPipe = shellInputPipe,
              let outputPipe = shellOutputPipe,
              let errorPipe = shellErrorPipe else {
            appendToTerminal("\nFailed to create shell process\n", color: NSColor.systemRed)
            return
        }
        
        // Use script command to create proper PTY
        process.executableURL = URL(fileURLWithPath: "/usr/bin/script")
        process.arguments = ["-q", "-t", "0", "/dev/null", "/bin/zsh", "-i"]
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Set up environment with proper terminal settings
        var environment = ProcessInfo.processInfo.environment
        environment["HOME"] = NSHomeDirectory()
        environment["USER"] = NSUserName()
        environment["TERM"] = "xterm-256color"
        environment["SHELL"] = "/bin/zsh"
        environment["LANG"] = "en_US.UTF-8"
        environment["COLUMNS"] = "80"
        environment["LINES"] = "24"
        environment["FORCE_COLOR"] = "1"
        
        // Enhance PATH
        if let currentPath = environment["PATH"] {
            let additionalPaths = [
                "/opt/homebrew/bin",
                "/opt/homebrew/sbin", 
                "/usr/local/bin",
                "/Users/\(NSUserName())/.bun/bin",
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
        
        // Set up output handling
        let outputHandle = outputPipe.fileHandleForReading
        let errorHandle = errorPipe.fileHandleForReading
        
        outputHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            print("📤 Got output data: \(data.count) bytes")
            if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                print("📝 Output: '\(output)'")
                DispatchQueue.main.async {
                    self?.appendToTerminal(output, color: NSColor.labelColor)
                }
            }
        }
        
        errorHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if !data.isEmpty, let errorOutput = String(data: data, encoding: .utf8) {
                print("❌ Error output: '\(errorOutput)'")
                DispatchQueue.main.async {
                    self?.appendToTerminal(errorOutput, color: NSColor.systemRed)
                }
            }
        }
        
        process.terminationHandler = { [weak self] _ in
            print("🔚 Shell process terminated")
            DispatchQueue.main.async {
                self?.isShellRunning = false
                self?.appendToTerminal("\nShell session ended\n", color: NSColor.systemYellow)
            }
        }
        
        // Start the process
        do {
            try process.run()
            isShellRunning = true
            print("✅ Shell process started successfully")
            appendToTerminal("Shell starting...\n", color: NSColor.systemGreen)
            
            // Send initial setup after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.sendInitialSetup(for: terminalApp)
            }
            
        } catch {
            print("❌ Failed to start shell: \(error)")
            appendToTerminal("\nFailed to start shell: \(error.localizedDescription)\n", color: NSColor.systemRed)
        }
    }
    
    private func sendInitialSetup(for terminalApp: TerminalApp) {
        guard let inputPipe = shellInputPipe, isShellRunning else { return }
        
        print("🔧 Sending initial setup...")
        
        // Send setup commands
        let setupCommands = [
            "export PS1='\(getPromptStyle(for: terminalApp)) '",
            "clear",
            "echo 'Terminal ready! Type your commands:'",
            ""
        ]
        
        for command in setupCommands {
            let commandWithNewline = command + "\n"
            if let data = commandWithNewline.data(using: .utf8) {
                do {
                    try inputPipe.fileHandleForWriting.write(contentsOf: data)
                    print("📤 Sent setup command: '\(command)'")
                } catch {
                    print("❌ Failed to send setup command: \(error)")
                }
            }
        }
    }
    
    @objc private func executeCommand(_ sender: NSTextField) {
        print("⚡ executeCommand called")
        
        guard isShellRunning, let inputPipe = shellInputPipe else {
            print("❌ Shell not running or no input pipe")
            appendToTerminal("Shell not running\n", color: NSColor.systemRed)
            return
        }
        
        let command = sender.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        print("📝 Executing command: '\(command)'")
        
        // Send command directly to shell (including empty commands for interactive programs)
        let commandWithNewline = (command.isEmpty ? "" : command) + "\n"
        if let data = commandWithNewline.data(using: .utf8) {
            do {
                try inputPipe.fileHandleForWriting.write(contentsOf: data)
                if command.isEmpty {
                    print("✅ Empty Enter sent to shell for interactive program")
                } else {
                    print("✅ Command sent to shell successfully")
                    // Show the command in terminal first only for non-empty commands
                    appendToTerminal("\(getPromptStyle(for: detectAvailableTerminals().first ?? TerminalApp(name: "Terminal", path: "", emoji: "🖥️"))) \(command)\n", color: NSColor.systemBlue)
                    
                    // Add to history only for non-empty commands
                    if commandHistory.isEmpty || commandHistory.last != command {
                        commandHistory.append(command)
                        if commandHistory.count > 100 {
                            commandHistory.removeFirst()
                        }
                    }
                    historyIndex = commandHistory.count
                }
            } catch {
                print("❌ Failed to send command: \(error)")
                appendToTerminal("Failed to send command: \(error.localizedDescription)\n", color: NSColor.systemRed)
            }
        }
        
        // Clear input
        sender.stringValue = ""
        print("🧹 Input field cleared")
    }
    
    private func appendToTerminal(_ text: String, color: NSColor) {
        print("📝 appendToTerminal called with: '\(text.replacingOccurrences(of: "\n", with: "\\n"))'")
        
        guard let textView = terminalTextView else { 
            print("❌ No textView available")
            return 
        }
        
        let cleanedText = cleanANSIEscapeSequences(text)
        
        let attributedString = NSAttributedString(
            string: cleanedText,
            attributes: [
                .foregroundColor: color,
                .font: textView.font ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
                .backgroundColor: NSColor.clear
            ]
        )
        
        textView.textStorage?.append(attributedString)
        
        // Scroll to bottom
        let textLength = textView.string.count
        if textLength > 0 {
            let range = NSRange(location: textLength - 1, length: 1)
            textView.scrollRangeToVisible(range)
        }
        
        print("✅ Text appended to terminal, total length: \((textView.string.count))")
    }
    
    private func cleanANSIEscapeSequences(_ text: String) -> String {
        // Remove ANSI escape sequences for cleaner output
        let ansiPattern = "\\x1B\\[[0-9;]*[A-Za-z]"
        
        do {
            let regex = try NSRegularExpression(pattern: ansiPattern, options: [])
            let range = NSRange(location: 0, length: text.count)
            let cleanedText = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
            
            // Also remove some common control characters
            var result = cleanedText
            result = result.replacingOccurrences(of: "\u{1B}[?2004h", with: "") // Bracketed paste mode
            result = result.replacingOccurrences(of: "\u{1B}[?2004l", with: "") // Disable bracketed paste
            result = result.replacingOccurrences(of: "\u{1B}[?1h", with: "")    // Application cursor keys
            result = result.replacingOccurrences(of: "\u{1B}[?1l", with: "")    // Normal cursor keys
            result = result.replacingOccurrences(of: "\u{07}", with: "")        // Bell character
            
            return result
        } catch {
            print("❌ Error cleaning ANSI sequences: \(error)")
            return text
        }
    }
    
    @objc private func resetToLauncher() {
        // Stop shell process
        shellProcess?.terminate()
        shellProcess = nil
        shellInputPipe = nil
        shellOutputPipe = nil
        shellErrorPipe = nil
        isShellRunning = false
        
        // Clear references
        terminalTextView = nil
        terminalInputField = nil
        
        // Reset to launcher
        subviews.forEach { $0.removeFromSuperview() }
        setupPlaceholder()
    }
    
    deinit {
        // Clean up
        shellProcess?.terminate()
    }
}

// MARK: - NSTextFieldDelegate
extension TerminalContainerView: NSTextFieldDelegate {
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        print("🎯 Key command: \(commandSelector)")
        
        // Handle arrow keys - send directly to shell for interactive programs
        if commandSelector == #selector(NSResponder.moveUp(_:)) {
            print("⬆️ Up arrow pressed - sending to shell")
            sendArrowKeyToShell("A") // Up arrow ANSI code
            return true
        } else if commandSelector == #selector(NSResponder.moveDown(_:)) {
            print("⬇️ Down arrow pressed - sending to shell")
            sendArrowKeyToShell("B") // Down arrow ANSI code
            return true
        } else if commandSelector == #selector(NSResponder.moveLeft(_:)) {
            print("⬅️ Left arrow pressed - sending to shell")
            sendArrowKeyToShell("D") // Left arrow ANSI code
            return true
        } else if commandSelector == #selector(NSResponder.moveRight(_:)) {
            print("➡️ Right arrow pressed - sending to shell")
            sendArrowKeyToShell("C") // Right arrow ANSI code
            return true
        } else if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            print("⏎ Enter key pressed - executing command")
            // Handle Enter normally
            if let inputField = terminalInputField {
                executeCommand(inputField)
            }
            return true
        } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            print("⎋ Escape key pressed - sending to shell")
            sendEscapeToShell()
            return true
        }
        
        return false
    }
    
    private func sendArrowKeyToShell(_ direction: String) {
        guard isShellRunning, let inputPipe = shellInputPipe else {
            print("❌ Shell not running, can't send arrow key")
            return
        }
        
        // Send ANSI escape sequence for arrow keys: ESC[A/B/C/D
        let arrowSequence = "\u{1B}[\(direction)"
        if let data = arrowSequence.data(using: .utf8) {
            do {
                try inputPipe.fileHandleForWriting.write(contentsOf: data)
                print("✅ Sent arrow key sequence: \\e[\(direction)")
            } catch {
                print("❌ Failed to send arrow key: \(error)")
            }
        }
    }
    
    private func sendEnterToShell() {
        guard isShellRunning, let inputPipe = shellInputPipe else {
            print("❌ Shell not running, can't send Enter")
            return
        }
        
        // Send Enter key directly to shell for interactive programs
        let enterSequence = "\n"
        if let data = enterSequence.data(using: .utf8) {
            do {
                try inputPipe.fileHandleForWriting.write(contentsOf: data)
                print("✅ Sent Enter key to shell for interactive program")
            } catch {
                print("❌ Failed to send Enter key: \(error)")
            }
        }
    }
    
    private func sendEscapeToShell() {
        guard isShellRunning, let inputPipe = shellInputPipe else {
            print("❌ Shell not running, can't send Escape")
            return
        }
        
        // Send Escape key
        let escapeSequence = "\u{1B}"
        if let data = escapeSequence.data(using: .utf8) {
            do {
                try inputPipe.fileHandleForWriting.write(contentsOf: data)
                print("✅ Sent Escape key to shell")
            } catch {
                print("❌ Failed to send Escape key: \(error)")
            }
        }
    }
}