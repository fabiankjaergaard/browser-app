import Cocoa

class TerminalViewController: NSViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupMinimalTerminal()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
    }
    
    private func setupView() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
    }
    
    private func setupMinimalTerminal() {
        // Create a simple text label showing just the prompt
        let promptLabel = NSTextField(labelWithString: "(base) fabiankjaergaard@MacBookPro ~ %")
        promptLabel.translatesAutoresizingMaskIntoConstraints = false
        promptLabel.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        promptLabel.textColor = NSColor.white
        promptLabel.backgroundColor = NSColor.clear
        promptLabel.isBordered = false
        view.addSubview(promptLabel)
        
        NSLayoutConstraint.activate([
            promptLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            promptLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16)
        ])
    }
    
    @objc private func closeTerminal() {
        NotificationCenter.default.post(name: .toggleTerminal, object: nil)
    }
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 600))
    }
}

// Update notification name for terminal
extension Notification.Name {
    static let toggleTerminal = Notification.Name("ToggleTerminal")
}