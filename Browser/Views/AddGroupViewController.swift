import Cocoa

protocol AddGroupViewControllerDelegate: AnyObject {
    func addGroupViewController(_ controller: AddGroupViewController, didCreateGroup name: String, iconName: String, color: String)
    func addGroupViewControllerDidCancel(_ controller: AddGroupViewController)
}

class AddGroupViewController: NSViewController {
    weak var delegate: AddGroupViewControllerDelegate?
    
    private var nameTextField: NSTextField!
    private var iconPopUpButton: NSPopUpButton!
    private var createButton: NSButton!
    private var cancelButton: NSButton!
    
    private let availableIcons = [
        ("folder", "Mapp"),
        ("star", "Stjärna"),
        ("heart", "Hjärta"), 
        ("bookmark", "Bokmärke"),
        ("tag", "Tagg"),
        ("globe", "Världen"),
        ("house", "Hem"),
        ("briefcase", "Portfölj"),
        ("graduationcap", "Utbildning"),
        ("music.note", "Musik"),
        ("gamecontroller", "Spel"),
        ("camera", "Kamera"),
        ("paintbrush", "Design"),
        ("wrench.and.screwdriver", "Utveckling"),
        ("cart", "Shopping")
    ]
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        view.wantsLayer = true
        view.layer?.backgroundColor = ColorManager.primaryBackground.cgColor
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        // Title label
        let titleLabel = NSTextField(labelWithString: "Skapa ny grupp")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = ColorManager.primaryText
        
        // Name input
        let nameLabel = NSTextField(labelWithString: "Gruppnamn:")
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = NSFont.systemFont(ofSize: 12)
        nameLabel.textColor = ColorManager.primaryText
        
        nameTextField = NSTextField()
        nameTextField.translatesAutoresizingMaskIntoConstraints = false
        nameTextField.placeholderString = "Ange gruppnamn..."
        nameTextField.font = NSFont.systemFont(ofSize: 12)
        nameTextField.target = self
        nameTextField.action = #selector(textFieldChanged)
        
        // Icon selection
        let iconLabel = NSTextField(labelWithString: "Ikon:")
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        iconLabel.font = NSFont.systemFont(ofSize: 12)
        iconLabel.textColor = ColorManager.primaryText
        
        iconPopUpButton = NSPopUpButton()
        iconPopUpButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Populate icon popup
        for (iconName, displayName) in availableIcons {
            let menuItem = NSMenuItem(title: displayName, action: nil, keyEquivalent: "")
            if let image = NSImage(systemSymbolName: iconName, accessibilityDescription: displayName) {
                image.size = NSSize(width: 16, height: 16)
                menuItem.image = image
            }
            iconPopUpButton.menu?.addItem(menuItem)
        }
        iconPopUpButton.selectItem(at: 0) // Default to folder
        
        // Buttons
        createButton = NSButton()
        createButton.translatesAutoresizingMaskIntoConstraints = false
        createButton.title = "Skapa"
        createButton.bezelStyle = .rounded
        createButton.controlSize = .regular
        createButton.target = self
        createButton.action = #selector(createButtonClicked)
        createButton.isEnabled = false
        createButton.keyEquivalent = "\r" // Enter key
        
        cancelButton = NSButton()
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.title = "Avbryt"
        cancelButton.bezelStyle = .rounded
        cancelButton.controlSize = .regular
        cancelButton.target = self
        cancelButton.action = #selector(cancelButtonClicked)
        cancelButton.keyEquivalent = "\u{1B}" // Escape key
        
        // Add all subviews
        view.addSubview(titleLabel)
        view.addSubview(nameLabel)
        view.addSubview(nameTextField)
        view.addSubview(iconLabel)
        view.addSubview(iconPopUpButton)
        view.addSubview(createButton)
        view.addSubview(cancelButton)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            // Title
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // Name input
            nameLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            nameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            nameLabel.widthAnchor.constraint(equalToConstant: 80),
            
            nameTextField.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            nameTextField.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 8),
            nameTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            nameTextField.heightAnchor.constraint(equalToConstant: 22),
            
            // Icon selection
            iconLabel.topAnchor.constraint(equalTo: nameTextField.bottomAnchor, constant: 16),
            iconLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            iconLabel.widthAnchor.constraint(equalToConstant: 80),
            
            iconPopUpButton.centerYAnchor.constraint(equalTo: iconLabel.centerYAnchor),
            iconPopUpButton.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 8),
            iconPopUpButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Buttons
            cancelButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            cancelButton.trailingAnchor.constraint(equalTo: view.centerXAnchor, constant: -8),
            cancelButton.widthAnchor.constraint(equalToConstant: 80),
            
            createButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            createButton.leadingAnchor.constraint(equalTo: view.centerXAnchor, constant: 8),
            createButton.widthAnchor.constraint(equalToConstant: 80)
        ])
        
        // Focus on name field
        DispatchQueue.main.async {
            self.nameTextField.becomeFirstResponder()
        }
    }
    
    @objc private func textFieldChanged() {
        let hasText = !nameTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        createButton.isEnabled = hasText
    }
    
    @objc private func createButtonClicked() {
        let groupName = nameTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !groupName.isEmpty else { return }
        
        let selectedIconIndex = iconPopUpButton.indexOfSelectedItem
        let iconName = selectedIconIndex >= 0 && selectedIconIndex < availableIcons.count 
            ? availableIcons[selectedIconIndex].0 
            : "folder"
        
        // Use systemGray as default color for all groups
        let colorString = "systemGray"
        
        delegate?.addGroupViewController(self, didCreateGroup: groupName, iconName: iconName, color: colorString)
    }
    
    @objc private func cancelButtonClicked() {
        delegate?.addGroupViewControllerDidCancel(self)
    }
}