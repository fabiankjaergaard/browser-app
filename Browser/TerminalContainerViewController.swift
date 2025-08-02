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
        view.layer?.backgroundColor = NSColor.clear.cgColor
        
        // Modern frosted glass background
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
        
        // Add subtle shadow
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
        headerView.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.1).cgColor
        headerView.layer?.cornerRadius = 12
        view.addSubview(headerView)
        
        // Terminal icon and title
        let iconLabel = NSTextField(labelWithString: "💻")
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        iconLabel.font = NSFont.systemFont(ofSize: 18)
        iconLabel.alignment = .center
        headerView.addSubview(iconLabel)
        
        let titleLabel = NSTextField(labelWithString: "Terminal")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = NSColor.labelColor
        headerView.addSubview(titleLabel)
        
        // Close button with modern design
        closeButton = NSButton()
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Close")
        closeButton.bezelStyle = .regularSquare
        closeButton.isBordered = false
        closeButton.contentTintColor = NSColor.tertiaryLabelColor
        closeButton.target = self
        closeButton.action = #selector(closeTerminal)
        
        // Add hover effect
        closeButton.wantsLayer = true
        closeButton.layer?.cornerRadius = 10
        headerView.addSubview(closeButton)
        
        // Status indicator with modern design
        let statusContainer = NSView()
        statusContainer.translatesAutoresizingMaskIntoConstraints = false
        statusContainer.wantsLayer = true
        statusContainer.layer?.backgroundColor = NSColor.systemOrange.withAlphaComponent(0.15).cgColor
        statusContainer.layer?.cornerRadius = 8
        statusContainer.layer?.borderWidth = 1
        statusContainer.layer?.borderColor = NSColor.systemOrange.withAlphaComponent(0.3).cgColor
        headerView.addSubview(statusContainer)
        
        let statusDot = NSView()
        statusDot.translatesAutoresizingMaskIntoConstraints = false
        statusDot.wantsLayer = true
        statusDot.layer?.backgroundColor = NSColor.systemOrange.cgColor
        statusDot.layer?.cornerRadius = 3
        statusContainer.addSubview(statusDot)
        
        let statusLabel = NSTextField(labelWithString: "Ready")
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        statusLabel.textColor = NSColor.systemOrange
        statusContainer.addSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            headerView.heightAnchor.constraint(equalToConstant: 64),
            
            iconLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            iconLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            
            closeButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -12),
            closeButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 20),
            closeButton.heightAnchor.constraint(equalToConstant: 20),
            
            statusContainer.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -12),
            statusContainer.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            statusContainer.heightAnchor.constraint(equalToConstant: 24),
            statusContainer.widthAnchor.constraint(equalToConstant: 60),
            
            statusDot.leadingAnchor.constraint(equalTo: statusContainer.leadingAnchor, constant: 8),
            statusDot.centerYAnchor.constraint(equalTo: statusContainer.centerYAnchor),
            statusDot.widthAnchor.constraint(equalToConstant: 6),
            statusDot.heightAnchor.constraint(equalToConstant: 6),
            
            statusLabel.leadingAnchor.constraint(equalTo: statusDot.trailingAnchor, constant: 6),
            statusLabel.centerYAnchor.constraint(equalTo: statusContainer.centerYAnchor),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: statusContainer.trailingAnchor, constant: -6)
        ])
    }
    
    private func setupContainerView() {
        containerView = TerminalContainerView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.delegate = self
        view.addSubview(containerView)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 16),
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
        layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.05).cgColor
        layer?.cornerRadius = 16
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.2).cgColor
        
        // Add subtle inner shadow for depth
        let innerShadow = CALayer()
        innerShadow.frame = CGRect(x: 0, y: 0, width: 1000, height: 1000) // Will be resized
        innerShadow.backgroundColor = NSColor.black.withAlphaComponent(0.02).cgColor
        innerShadow.cornerRadius = 16
        layer?.addSublayer(innerShadow)
        
        setupPlaceholder()
    }
    
    private func setupPlaceholder() {
        // Icon container with modern background
        let iconContainer = NSView()
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.wantsLayer = true
        iconContainer.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.1).cgColor
        iconContainer.layer?.cornerRadius = 24
        iconContainer.layer?.borderWidth = 1
        iconContainer.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.2).cgColor
        addSubview(iconContainer)
        
        let iconLabel = NSTextField(labelWithString: "💻")
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        iconLabel.alignment = .center
        iconLabel.font = NSFont.systemFont(ofSize: 32)
        iconContainer.addSubview(iconLabel)
        
        // Main title with modern typography
        let titleLabel = NSTextField(labelWithString: "Terminal Emulator")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.alignment = .center
        titleLabel.font = NSFont.systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = NSColor.labelColor
        addSubview(titleLabel)
        
        // Subtitle with better styling
        let subtitleLabel = NSTextField(labelWithString: "Choose your preferred terminal environment")
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.alignment = .center
        subtitleLabel.font = NSFont.systemFont(ofSize: 14, weight: .regular)
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
            iconContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconContainer.topAnchor.constraint(equalTo: topAnchor, constant: 40),
            iconContainer.widthAnchor.constraint(equalToConstant: 80),
            iconContainer.heightAnchor.constraint(equalToConstant: 80),
            
            iconLabel.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconLabel.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: iconContainer.bottomAnchor, constant: 20),
            
            subtitleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            
            buttonContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
            buttonContainer.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 32),
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
    
    private func createTerminalButton(for terminalApp: TerminalApp) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.wantsLayer = true
        
        // Modern card-like design
        container.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.3).cgColor
        container.layer?.cornerRadius = 12
        container.layer?.borderWidth = 1
        container.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.3).cgColor
        
        // Add shadow for depth
        container.shadow = NSShadow()
        container.shadow?.shadowOffset = NSSize(width: 0, height: 1)
        container.shadow?.shadowBlurRadius = 3
        container.shadow?.shadowColor = NSColor.black.withAlphaComponent(0.1)
        
        // Terminal emoji/icon
        let iconLabel = NSTextField(labelWithString: terminalApp.emoji)
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        iconLabel.font = NSFont.systemFont(ofSize: 24)
        iconLabel.alignment = .center
        container.addSubview(iconLabel)
        
        // Terminal name
        let nameLabel = NSTextField(labelWithString: terminalApp.name)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        nameLabel.textColor = NSColor.labelColor
        nameLabel.alignment = .left
        container.addSubview(nameLabel)
        
        // Style label
        let styleLabel = NSTextField(labelWithString: "Style")
        styleLabel.translatesAutoresizingMaskIntoConstraints = false
        styleLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        styleLabel.textColor = NSColor.secondaryLabelColor
        styleLabel.alignment = .left
        container.addSubview(styleLabel)
        
        // Invisible button for click handling
        let button = NSButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.title = ""
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.isTransparent = true
        button.target = self
        button.action = #selector(terminalButtonClicked(_:))
        button.identifier = NSUserInterfaceItemIdentifier(terminalApp.name)
        container.addSubview(button)
        
        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 240),
            container.heightAnchor.constraint(equalToConstant: 56),
            
            iconLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            iconLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            iconLabel.widthAnchor.constraint(equalToConstant: 32),
            
            nameLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -16),
            
            styleLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            styleLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            styleLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -16),
            
            button.topAnchor.constraint(equalTo: container.topAnchor),
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        // Add hover effect
        let trackingArea = NSTrackingArea(
            rect: container.bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: ["container": container]
        )
        container.addTrackingArea(trackingArea)
        
        return container
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
        
        // Create loading container
        let loadingContainer = NSView()
        loadingContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(loadingContainer)
        
        // Loading spinner indicator (using system progress indicator)
        let progressIndicator = NSProgressIndicator()
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        progressIndicator.style = .spinning
        progressIndicator.isIndeterminate = true
        progressIndicator.startAnimation(nil)
        loadingContainer.addSubview(progressIndicator)
        
        // Terminal icon for context
        let iconLabel = NSTextField(labelWithString: terminalApp.emoji)
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        iconLabel.alignment = .center
        iconLabel.font = NSFont.systemFont(ofSize: 24)
        loadingContainer.addSubview(iconLabel)
        
        // Loading text
        let loadingLabel = NSTextField(labelWithString: "Starting \(terminalApp.name)")
        loadingLabel.translatesAutoresizingMaskIntoConstraints = false
        loadingLabel.alignment = .center
        loadingLabel.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        loadingLabel.textColor = NSColor.labelColor
        loadingContainer.addSubview(loadingLabel)
        
        // Status text
        let statusLabel = NSTextField(labelWithString: "Initializing shell environment...")
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.alignment = .center
        statusLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        statusLabel.textColor = NSColor.secondaryLabelColor
        loadingContainer.addSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            loadingContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
            loadingContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            loadingContainer.widthAnchor.constraint(equalToConstant: 240),
            loadingContainer.heightAnchor.constraint(equalToConstant: 120),
            
            progressIndicator.topAnchor.constraint(equalTo: loadingContainer.topAnchor),
            progressIndicator.centerXAnchor.constraint(equalTo: loadingContainer.centerXAnchor),
            
            iconLabel.topAnchor.constraint(equalTo: progressIndicator.bottomAnchor, constant: 12),
            iconLabel.centerXAnchor.constraint(equalTo: loadingContainer.centerXAnchor),
            
            loadingLabel.topAnchor.constraint(equalTo: iconLabel.bottomAnchor, constant: 8),
            loadingLabel.centerXAnchor.constraint(equalTo: loadingContainer.centerXAnchor),
            
            statusLabel.topAnchor.constraint(equalTo: loadingLabel.bottomAnchor, constant: 4),
            statusLabel.centerXAnchor.constraint(equalTo: loadingContainer.centerXAnchor)
        ])
    }
    
    private func createTerminalEmulatorUI(for terminalApp: TerminalApp) {
        // Clear previous content
        subviews.forEach { $0.removeFromSuperview() }
        
        // Create main container with modern design
        let terminalContainer = NSView()
        terminalContainer.translatesAutoresizingMaskIntoConstraints = false
        terminalContainer.wantsLayer = true
        
        // Style based on terminal app
        let (backgroundColor, textColor, font) = getTerminalStyle(for: terminalApp)
        terminalContainer.layer?.backgroundColor = backgroundColor.cgColor
        terminalContainer.layer?.cornerRadius = 12
        terminalContainer.layer?.borderWidth = 1
        terminalContainer.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.2).cgColor
        
        // Add subtle shadow
        terminalContainer.shadow = NSShadow()
        terminalContainer.shadow?.shadowOffset = NSSize(width: 0, height: 2)
        terminalContainer.shadow?.shadowBlurRadius = 8
        terminalContainer.shadow?.shadowColor = NSColor.black.withAlphaComponent(0.1)
        
        addSubview(terminalContainer)
        
        // Create header with modern macOS terminal-like design
        let headerView = NSView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.wantsLayer = true
        headerView.layer?.backgroundColor = backgroundColor.blended(withFraction: 0.05, of: NSColor.white)?.cgColor
        headerView.layer?.cornerRadius = 12
        headerView.layer?.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        terminalContainer.addSubview(headerView)
        
        // Traffic light buttons (macOS style)
        let trafficLightContainer = NSView()
        trafficLightContainer.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(trafficLightContainer)
        
        let closeCircle = NSView()
        closeCircle.translatesAutoresizingMaskIntoConstraints = false
        closeCircle.wantsLayer = true
        closeCircle.layer?.backgroundColor = NSColor.systemRed.cgColor
        closeCircle.layer?.cornerRadius = 6
        trafficLightContainer.addSubview(closeCircle)
        
        let minimizeCircle = NSView()
        minimizeCircle.translatesAutoresizingMaskIntoConstraints = false
        minimizeCircle.wantsLayer = true
        minimizeCircle.layer?.backgroundColor = NSColor.systemYellow.cgColor
        minimizeCircle.layer?.cornerRadius = 6
        trafficLightContainer.addSubview(minimizeCircle)
        
        let maximizeCircle = NSView()
        maximizeCircle.translatesAutoresizingMaskIntoConstraints = false
        maximizeCircle.wantsLayer = true
        maximizeCircle.layer?.backgroundColor = NSColor.systemGreen.cgColor
        maximizeCircle.layer?.cornerRadius = 6
        trafficLightContainer.addSubview(maximizeCircle)
        
        // App name and status
        let titleLabel = NSTextField(labelWithString: "\(terminalApp.emoji) \(terminalApp.name)")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = textColor.withAlphaComponent(0.8)
        titleLabel.backgroundColor = NSColor.clear
        titleLabel.isBordered = false
        titleLabel.alignment = .center
        headerView.addSubview(titleLabel)
        
        // Close button (invisible overlay on red circle)
        let closeButton = NSButton()
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.title = ""
        closeButton.bezelStyle = .regularSquare
        closeButton.isBordered = false
        closeButton.isTransparent = true
        closeButton.target = self
        closeButton.action = #selector(resetToLauncher)
        trafficLightContainer.addSubview(closeButton)
        
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
        
        // Create input area with modern design
        let inputContainer = NSView()
        inputContainer.translatesAutoresizingMaskIntoConstraints = false
        inputContainer.wantsLayer = true
        inputContainer.layer?.backgroundColor = backgroundColor.blended(withFraction: 0.03, of: NSColor.white)?.cgColor
        inputContainer.layer?.cornerRadius = 12
        inputContainer.layer?.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        inputContainer.layer?.borderWidth = 1
        inputContainer.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.1).cgColor
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
            headerView.heightAnchor.constraint(equalToConstant: 36),
            
            // Traffic light container
            trafficLightContainer.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 12),
            trafficLightContainer.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            trafficLightContainer.widthAnchor.constraint(equalToConstant: 54),
            trafficLightContainer.heightAnchor.constraint(equalToConstant: 12),
            
            // Close circle (red)
            closeCircle.leadingAnchor.constraint(equalTo: trafficLightContainer.leadingAnchor),
            closeCircle.centerYAnchor.constraint(equalTo: trafficLightContainer.centerYAnchor),
            closeCircle.widthAnchor.constraint(equalToConstant: 12),
            closeCircle.heightAnchor.constraint(equalToConstant: 12),
            
            // Minimize circle (yellow)
            minimizeCircle.leadingAnchor.constraint(equalTo: closeCircle.trailingAnchor, constant: 9),
            minimizeCircle.centerYAnchor.constraint(equalTo: trafficLightContainer.centerYAnchor),
            minimizeCircle.widthAnchor.constraint(equalToConstant: 12),
            minimizeCircle.heightAnchor.constraint(equalToConstant: 12),
            
            // Maximize circle (green)
            maximizeCircle.leadingAnchor.constraint(equalTo: minimizeCircle.trailingAnchor, constant: 9),
            maximizeCircle.centerYAnchor.constraint(equalTo: trafficLightContainer.centerYAnchor),
            maximizeCircle.widthAnchor.constraint(equalToConstant: 12),
            maximizeCircle.heightAnchor.constraint(equalToConstant: 12),
            
            // Title (centered)
            titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            
            // Close button (overlay on close circle)
            closeButton.topAnchor.constraint(equalTo: closeCircle.topAnchor),
            closeButton.leadingAnchor.constraint(equalTo: closeCircle.leadingAnchor),
            closeButton.trailingAnchor.constraint(equalTo: closeCircle.trailingAnchor),
            closeButton.bottomAnchor.constraint(equalTo: closeCircle.bottomAnchor),
            
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
    
    override func mouseEntered(with event: NSEvent) {
        if let userInfo = event.trackingArea?.userInfo,
           let container = userInfo["container"] as? NSView {
            // Add hover effect
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                container.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.1).cgColor
                container.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.4).cgColor
                let scaleTransform = CATransform3DMakeScale(1.02, 1.02, 1.0)
                container.layer?.transform = scaleTransform
            }
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        if let userInfo = event.trackingArea?.userInfo,
           let container = userInfo["container"] as? NSView {
            // Remove hover effect
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                container.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.3).cgColor
                container.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.3).cgColor
                container.layer?.transform = CATransform3DIdentity
            }
        }
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