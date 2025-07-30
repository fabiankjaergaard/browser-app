import Cocoa

class AISidebarViewController: NSViewController {
    
    private var headerView: NSView!
    private var chatScrollView: NSScrollView!
    private var chatStackView: NSStackView!
    private var inputContainer: NSView!
    private var inputTextField: NSTextField!
    private var sendButton: NSButton!
    private var closeButton: NSButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupHeader()
        setupChatArea()
        setupInputArea()
        addWelcomeMessage()
    }
    
    private func setupView() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(calibratedRed: 0.05, green: 0.05, blue: 0.05, alpha: 0.95).cgColor
        
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
        
        // AI Assistant title
        let titleLabel = NSTextField(labelWithString: "AI Assistant")
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
        closeButton.action = #selector(closeAISidebar)
        headerView.addSubview(closeButton)
        
        // Status indicator
        let statusIndicator = NSView()
        statusIndicator.translatesAutoresizingMaskIntoConstraints = false
        statusIndicator.wantsLayer = true
        statusIndicator.layer?.backgroundColor = NSColor.systemGreen.cgColor
        statusIndicator.layer?.cornerRadius = 4
        headerView.addSubview(statusIndicator)
        
        let statusLabel = NSTextField(labelWithString: "Local AI")
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
    
    private func setupChatArea() {
        chatScrollView = NSScrollView()
        chatScrollView.translatesAutoresizingMaskIntoConstraints = false
        chatScrollView.hasVerticalScroller = true
        chatScrollView.hasHorizontalScroller = false
        chatScrollView.autohidesScrollers = true
        chatScrollView.borderType = .noBorder
        chatScrollView.drawsBackground = false
        
        chatStackView = NSStackView()
        chatStackView.translatesAutoresizingMaskIntoConstraints = false
        chatStackView.orientation = .vertical
        chatStackView.spacing = 12
        chatStackView.alignment = .leading
        chatStackView.distribution = .gravityAreas
        
        chatScrollView.documentView = chatStackView
        view.addSubview(chatScrollView)
        
        NSLayoutConstraint.activate([
            chatScrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 8),
            chatScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            chatScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            chatScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -80),
            
            chatStackView.topAnchor.constraint(equalTo: chatScrollView.topAnchor),
            chatStackView.leadingAnchor.constraint(equalTo: chatScrollView.leadingAnchor),
            chatStackView.trailingAnchor.constraint(equalTo: chatScrollView.trailingAnchor),
            chatStackView.widthAnchor.constraint(equalTo: chatScrollView.widthAnchor)
        ])
    }
    
    private func setupInputArea() {
        inputContainer = NSView()
        inputContainer.translatesAutoresizingMaskIntoConstraints = false
        inputContainer.wantsLayer = true
        inputContainer.layer?.backgroundColor = NSColor(calibratedWhite: 0.1, alpha: 0.8).cgColor
        inputContainer.layer?.cornerRadius = 12
        view.addSubview(inputContainer)
        
        inputTextField = NSTextField()
        inputTextField.translatesAutoresizingMaskIntoConstraints = false
        inputTextField.placeholderString = "Ask about this page..."
        inputTextField.font = NSFont.systemFont(ofSize: 13)
        inputTextField.textColor = NSColor.white
        inputTextField.backgroundColor = NSColor.clear
        inputTextField.isBordered = false
        inputTextField.target = self
        inputTextField.action = #selector(sendMessage)
        inputContainer.addSubview(inputTextField)
        
        sendButton = NSButton()
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.image = NSImage(systemSymbolName: "paperplane.fill", accessibilityDescription: "Send")
        sendButton.bezelStyle = .regularSquare
        sendButton.isBordered = false
        sendButton.contentTintColor = NSColor.systemBlue
        sendButton.target = self
        sendButton.action = #selector(sendMessage)
        inputContainer.addSubview(sendButton)
        
        NSLayoutConstraint.activate([
            inputContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
            inputContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            inputContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            inputContainer.heightAnchor.constraint(equalToConstant: 44),
            
            inputTextField.centerYAnchor.constraint(equalTo: inputContainer.centerYAnchor),
            inputTextField.leadingAnchor.constraint(equalTo: inputContainer.leadingAnchor, constant: 12),
            inputTextField.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -8),
            
            sendButton.centerYAnchor.constraint(equalTo: inputContainer.centerYAnchor),
            sendButton.trailingAnchor.constraint(equalTo: inputContainer.trailingAnchor, constant: -12),
            sendButton.widthAnchor.constraint(equalToConstant: 24),
            sendButton.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
    
    private func addWelcomeMessage() {
        let welcomeMessage = createMessageView(
            text: "Hi! I'm your AI assistant. I can help you analyze web pages, answer questions, and provide insights about the content you're browsing.",
            isUser: false
        )
        chatStackView.addArrangedSubview(welcomeMessage)
    }
    
    private func createMessageView(text: String, isUser: Bool) -> NSView {
        let messageContainer = NSView()
        messageContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let messageView = NSView()
        messageView.translatesAutoresizingMaskIntoConstraints = false
        messageView.wantsLayer = true
        
        if isUser {
            messageView.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.8).cgColor
        } else {
            messageView.layer?.backgroundColor = NSColor(calibratedWhite: 0.15, alpha: 0.9).cgColor
        }
        messageView.layer?.cornerRadius = 12
        
        let textLabel = NSTextField(wrappingLabelWithString: text)
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        textLabel.font = NSFont.systemFont(ofSize: 13)
        textLabel.textColor = NSColor.white
        textLabel.backgroundColor = NSColor.clear
        textLabel.isEditable = false
        textLabel.isSelectable = true
        messageView.addSubview(textLabel)
        
        messageContainer.addSubview(messageView)
        
        NSLayoutConstraint.activate([
            messageView.topAnchor.constraint(equalTo: messageContainer.topAnchor),
            messageView.bottomAnchor.constraint(equalTo: messageContainer.bottomAnchor),
            messageView.widthAnchor.constraint(lessThanOrEqualToConstant: 280),
            
            textLabel.topAnchor.constraint(equalTo: messageView.topAnchor, constant: 8),
            textLabel.leadingAnchor.constraint(equalTo: messageView.leadingAnchor, constant: 12),
            textLabel.trailingAnchor.constraint(equalTo: messageView.trailingAnchor, constant: -12),
            textLabel.bottomAnchor.constraint(equalTo: messageView.bottomAnchor, constant: -8)
        ])
        
        if isUser {
            NSLayoutConstraint.activate([
                messageView.trailingAnchor.constraint(equalTo: messageContainer.trailingAnchor, constant: -16),
                messageContainer.widthAnchor.constraint(equalToConstant: 300)
            ])
        } else {
            NSLayoutConstraint.activate([
                messageView.leadingAnchor.constraint(equalTo: messageContainer.leadingAnchor, constant: 16),
                messageContainer.widthAnchor.constraint(equalToConstant: 300)
            ])
        }
        
        return messageContainer
    }
    
    @objc private func sendMessage() {
        guard !inputTextField.stringValue.isEmpty else { return }
        
        let userMessage = inputTextField.stringValue
        inputTextField.stringValue = ""
        
        // Add user message
        let userMessageView = createMessageView(text: userMessage, isUser: true)
        chatStackView.addArrangedSubview(userMessageView)
        
        // Simulate AI response after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let responses = [
                "I can see you're interested in that topic. As a local AI, I process everything on-device for your privacy.",
                "That's a great question! While I'm currently in demo mode, future versions will provide detailed analysis of web content.",
                "I notice you're browsing \(self.getCurrentPageTitle()). Would you like me to summarize the key points?",
                "Interesting! I can help analyze the content, check for key insights, or answer specific questions about what you're reading."
            ]
            
            let randomResponse = responses.randomElement() ?? responses[0]
            let aiMessageView = self.createMessageView(text: randomResponse, isUser: false)
            self.chatStackView.addArrangedSubview(aiMessageView)
            
            // Scroll to bottom
            self.chatScrollView.documentView?.scroll(NSPoint(x: 0, y: self.chatStackView.frame.height))
        }
    }
    
    private func getCurrentPageTitle() -> String {
        // This would normally get the current page title from the browser
        return "this page"
    }
    
    @objc private func closeAISidebar() {
        NotificationCenter.default.post(name: .toggleAISidebar, object: nil)
    }
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 600))
    }
}

extension Notification.Name {
    static let toggleAISidebar = Notification.Name("ToggleAISidebar")
}