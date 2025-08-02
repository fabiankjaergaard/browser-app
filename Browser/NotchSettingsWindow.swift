import Cocoa

class NotchSettings {
    static let shared = NotchSettings()
    
    // User defaults keys
    private let mediaNotchKey = "mediaNotchVisible"
    private let notesNotchKey = "notesNotchVisible"
    private let todoNotchKey = "todoNotchVisible"
    private let timerNotchKey = "timerNotchVisible"
    private let weatherNotchKey = "weatherNotchVisible"
    private let calendarNotchKey = "calendarNotchVisible"
    private let themeNotchKey = "themeNotchVisible"
    
    private init() {}
    
    // Get visibility state for each notch (default: true)
    var mediaNotchVisible: Bool {
        get { UserDefaults.standard.object(forKey: mediaNotchKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: mediaNotchKey) }
    }
    
    var notesNotchVisible: Bool {
        get { UserDefaults.standard.object(forKey: notesNotchKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: notesNotchKey) }
    }
    
    var todoNotchVisible: Bool {
        get { UserDefaults.standard.object(forKey: todoNotchKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: todoNotchKey) }
    }
    
    var timerNotchVisible: Bool {
        get { UserDefaults.standard.object(forKey: timerNotchKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: timerNotchKey) }
    }
    
    var weatherNotchVisible: Bool {
        get { UserDefaults.standard.object(forKey: weatherNotchKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: weatherNotchKey) }
    }
    
    var calendarNotchVisible: Bool {
        get { UserDefaults.standard.object(forKey: calendarNotchKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: calendarNotchKey) }
    }
    
    var themeNotchVisible: Bool {
        get { UserDefaults.standard.object(forKey: themeNotchKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: themeNotchKey) }
    }
}

class NotchSettingsWindow: NSWindow {
    
    weak var browserContentViewController: ContentViewController?
    
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        setupWindow()
        setupUI()
    }
    
    private func setupWindow() {
        title = "Notch Settings"
        center()
        isReleasedWhenClosed = false
        
        // Modern window appearance
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        
        // Set background
        backgroundColor = NSColor.controlBackgroundColor
    }
    
    private func setupUI() {
        let contentView = NSView()
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        
        // Title
        let titleLabel = NSTextField(labelWithString: "Choose which notches to display")
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Stack view for checkboxes
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 12
        stackView.alignment = .leading
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Create checkboxes for each notch
        let notchConfigs = [
            ("🎵", "Media Controls", "mediaNotchVisible"),
            ("📄", "Notes", "notesNotchVisible"),
            ("📝", "Todo List", "todoNotchVisible"),
            ("⏱️", "Timer", "timerNotchVisible"),
            ("🌤️", "Weather", "weatherNotchVisible"),
            ("📅", "Calendar", "calendarNotchVisible"),
            ("🎨", "Theme Switcher", "themeNotchVisible")
        ]
        
        var checkboxes: [NSButton] = []
        
        for (emoji, title, key) in notchConfigs {
            let checkbox = NSButton(checkboxWithTitle: "\(emoji) \(title)", target: self, action: #selector(checkboxChanged(_:)))
            checkbox.identifier = NSUserInterfaceItemIdentifier(key)
            checkbox.font = NSFont.systemFont(ofSize: 14)
            
            // Set initial state based on UserDefaults
            let settings = NotchSettings.shared
            switch key {
            case "mediaNotchVisible":
                checkbox.state = settings.mediaNotchVisible ? .on : .off
            case "notesNotchVisible":
                checkbox.state = settings.notesNotchVisible ? .on : .off
            case "todoNotchVisible":
                checkbox.state = settings.todoNotchVisible ? .on : .off
            case "timerNotchVisible":
                checkbox.state = settings.timerNotchVisible ? .on : .off
            case "weatherNotchVisible":
                checkbox.state = settings.weatherNotchVisible ? .on : .off
            case "calendarNotchVisible":
                checkbox.state = settings.calendarNotchVisible ? .on : .off
            case "themeNotchVisible":
                checkbox.state = settings.themeNotchVisible ? .on : .off
            default:
                break
            }
            
            stackView.addArrangedSubview(checkbox)
            checkboxes.append(checkbox)
        }
        
        // Close button
        let closeButton = NSButton(title: "Close", target: self, action: #selector(closeWindow))
        closeButton.bezelStyle = .rounded
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Add to content view
        contentView.addSubview(titleLabel)
        contentView.addSubview(stackView)
        contentView.addSubview(closeButton)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 30),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            stackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 30),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            
            closeButton.topAnchor.constraint(equalTo: stackView.bottomAnchor, constant: 30),
            closeButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            closeButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            closeButton.widthAnchor.constraint(equalToConstant: 80)
        ])
        
        self.contentView = contentView
    }
    
    @objc private func checkboxChanged(_ sender: NSButton) {
        guard let identifier = sender.identifier?.rawValue else { return }
        
        let isChecked = sender.state == .on
        let settings = NotchSettings.shared
        
        // Update settings
        switch identifier {
        case "mediaNotchVisible":
            settings.mediaNotchVisible = isChecked
        case "notesNotchVisible":
            settings.notesNotchVisible = isChecked
        case "todoNotchVisible":
            settings.todoNotchVisible = isChecked
        case "timerNotchVisible":
            settings.timerNotchVisible = isChecked
        case "weatherNotchVisible":
            settings.weatherNotchVisible = isChecked
        case "calendarNotchVisible":
            settings.calendarNotchVisible = isChecked
        case "themeNotchVisible":
            settings.themeNotchVisible = isChecked
        default:
            break
        }
        
        print("⚙️ \(identifier) changed to: \(isChecked)")
        
        // Update notch visibility
        browserContentViewController?.updateNotchVisibility()
    }
    
    @objc private func closeWindow() {
        close()
    }
}