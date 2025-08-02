import Cocoa

protocol ThemePresetViewDelegate: AnyObject {
    func themePresetView(_ presetView: ThemePresetView, didSelectPreset preset: ThemePreset)
}

struct ThemePreset {
    let id: String
    let name: String
    let accentColor: NSColor
    let brightness: Float
    let contrast: Float
    let saturation: Float
    let preview: NSColor
    
    init(name: String, accentColor: NSColor, brightness: Float = 0.5, contrast: Float = 0.5, saturation: Float = 0.8) {
        self.id = UUID().uuidString
        self.name = name
        self.accentColor = accentColor
        self.brightness = brightness
        self.contrast = contrast
        self.saturation = saturation
        
        // Create preview color based on settings
        let hsbColor = accentColor.usingColorSpace(.genericRGB) ?? accentColor
        let adjustedBrightness = CGFloat(brightness) * hsbColor.brightnessComponent
        let adjustedSaturation = CGFloat(saturation) * hsbColor.saturationComponent
        
        self.preview = NSColor(
            calibratedHue: hsbColor.hueComponent,
            saturation: adjustedSaturation,
            brightness: adjustedBrightness,
            alpha: 1.0
        )
    }
    
    static let allPresets: [ThemePreset] = [
        ThemePreset(name: "Ocean Blue", accentColor: NSColor(hex: "007AFF"), brightness: 0.6, contrast: 0.7, saturation: 0.8),
        ThemePreset(name: "Forest Green", accentColor: NSColor(hex: "34C759"), brightness: 0.5, contrast: 0.6, saturation: 0.9),
        ThemePreset(name: "Sunset Orange", accentColor: NSColor(hex: "FF9500"), brightness: 0.7, contrast: 0.8, saturation: 0.9),
        ThemePreset(name: "Royal Purple", accentColor: NSColor(hex: "AF52DE"), brightness: 0.4, contrast: 0.9, saturation: 0.8),
        ThemePreset(name: "Rose Pink", accentColor: NSColor(hex: "FF2D92"), brightness: 0.6, contrast: 0.5, saturation: 0.7),
        ThemePreset(name: "Deep Red", accentColor: NSColor(hex: "FF3B30"), brightness: 0.5, contrast: 0.8, saturation: 0.8),
        ThemePreset(name: "Mint Fresh", accentColor: NSColor(hex: "00C7BE"), brightness: 0.6, contrast: 0.6, saturation: 0.9),
        ThemePreset(name: "Golden Yellow", accentColor: NSColor(hex: "FFCC00"), brightness: 0.8, contrast: 0.7, saturation: 0.8),
        ThemePreset(name: "Midnight", accentColor: NSColor(hex: "5856D6"), brightness: 0.3, contrast: 0.9, saturation: 0.7),
        ThemePreset(name: "Silver", accentColor: NSColor(hex: "8E8E93"), brightness: 0.6, contrast: 0.5, saturation: 0.4)
    ]
}

class ThemePresetView: NSView {
    
    weak var delegate: ThemePresetViewDelegate?
    
    private var scrollView: NSScrollView!
    private var stackView: NSStackView!
    private var presetButtons: [NSButton] = []
    private var selectedPreset: ThemePreset?
    
    // Configuration
    private let presetHeight: CGFloat = 50
    private let presetSpacing: CGFloat = 8
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
        
        setupScrollView()
        setupPresetButtons()
    }
    
    private func setupScrollView() {
        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        
        stackView = NSStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .vertical
        stackView.spacing = presetSpacing
        stackView.alignment = .leading
        stackView.distribution = .fill
        
        scrollView.documentView = stackView
        addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    private func setupPresetButtons() {
        for preset in ThemePreset.allPresets {
            let button = createPresetButton(for: preset)
            presetButtons.append(button)
            stackView.addArrangedSubview(button)
        }
        
        // Select first preset by default
        if let firstButton = presetButtons.first,
           let firstPreset = ThemePreset.allPresets.first {
            selectPresetButton(firstButton, preset: firstPreset)
        }
    }
    
    private func createPresetButton(for preset: ThemePreset) -> NSButton {
        let button = NSButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.title = ""
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.wantsLayer = true
        
        // Store preset in button tag (using index)
        if let index = ThemePreset.allPresets.firstIndex(where: { $0.id == preset.id }) {
            button.tag = index
        }
        
        // Style the button
        button.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.5).cgColor
        button.layer?.cornerRadius = 8
        button.layer?.borderWidth = 2
        button.layer?.borderColor = NSColor.clear.cgColor
        
        // Create content view
        let containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.wantsLayer = true
        
        // Color preview circle
        let colorView = NSView()
        colorView.translatesAutoresizingMaskIntoConstraints = false
        colorView.wantsLayer = true
        colorView.layer?.backgroundColor = preset.preview.cgColor
        colorView.layer?.cornerRadius = 16
        
        // Add subtle shadow to color preview
        colorView.shadow = NSShadow()
        colorView.shadow?.shadowOffset = NSSize(width: 0, height: 1)
        colorView.shadow?.shadowBlurRadius = 3
        colorView.shadow?.shadowColor = NSColor.black.withAlphaComponent(0.2)
        
        // Theme name label
        let nameLabel = NSTextField(labelWithString: preset.name)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        nameLabel.textColor = NSColor.labelColor
        
        // Theme details label
        let detailsLabel = NSTextField(labelWithString: "B:\(Int(preset.brightness * 100))% C:\(Int(preset.contrast * 100))% S:\(Int(preset.saturation * 100))%")
        detailsLabel.translatesAutoresizingMaskIntoConstraints = false
        detailsLabel.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        detailsLabel.textColor = NSColor.secondaryLabelColor
        
        containerView.addSubview(colorView)
        containerView.addSubview(nameLabel)
        containerView.addSubview(detailsLabel)
        button.addSubview(containerView)
        
        NSLayoutConstraint.activate([
            // Container
            containerView.topAnchor.constraint(equalTo: button.topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 12),
            containerView.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -12),
            containerView.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -8),
            
            // Color preview
            colorView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            colorView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            colorView.widthAnchor.constraint(equalToConstant: 32),
            colorView.heightAnchor.constraint(equalToConstant: 32),
            
            // Labels
            nameLabel.leadingAnchor.constraint(equalTo: colorView.trailingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 4),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor),
            
            detailsLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            detailsLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            detailsLabel.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor),
            
            // Button size
            button.heightAnchor.constraint(equalToConstant: presetHeight),
            button.widthAnchor.constraint(equalTo: stackView.widthAnchor)
        ])
        
        button.target = self
        button.action = #selector(presetButtonPressed(_:))
        
        // Add hover tracking
        let trackingArea = NSTrackingArea(
            rect: NSRect(x: 0, y: 0, width: 1000, height: presetHeight), // Large width to cover full button
            options: [.mouseEnteredAndExited, .activeInKeyWindow],
            owner: self,
            userInfo: ["button": button]
        )
        button.addTrackingArea(trackingArea)
        
        return button
    }
    
    @objc private func presetButtonPressed(_ sender: NSButton) {
        let preset = ThemePreset.allPresets[sender.tag]
        selectPresetButton(sender, preset: preset)
        delegate?.themePresetView(self, didSelectPreset: preset)
        
        // Add satisfying click animation
        animateButtonPress(sender)
    }
    
    private func selectPresetButton(_ button: NSButton, preset: ThemePreset) {
        // Deselect previous button
        presetButtons.forEach { btn in
            btn.layer?.borderColor = NSColor.clear.cgColor
            btn.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.5).cgColor
        }
        
        // Select new button
        selectedPreset = preset
        button.layer?.borderColor = NSColor.controlAccentColor.cgColor
        button.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.1).cgColor
    }
    
    private func animateButtonPress(_ button: NSButton) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            button.layer?.transform = CATransform3DMakeScale(0.98, 0.98, 1.0)
        } completionHandler: {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                button.layer?.transform = CATransform3DIdentity
            }
        }
    }
    
    // MARK: - Mouse Events for Hover Effects
    
    override func mouseEntered(with event: NSEvent) {
        guard let trackingArea = event.trackingArea,
              let button = trackingArea.userInfo?["button"] as? NSButton else { return }
        
        // Hover effect for non-selected buttons
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            button.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.8).cgColor
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        guard let trackingArea = event.trackingArea,
              let button = trackingArea.userInfo?["button"] as? NSButton else { return }
        
        // Check if this button is selected
        let isSelected = button.layer?.borderColor == NSColor.controlAccentColor.cgColor
        
        // Remove hover effect for non-selected buttons
        if !isSelected {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                button.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.5).cgColor
            }
        }
    }
    
    // MARK: - Public Interface
    
    func selectPreset(_ preset: ThemePreset) {
        guard let index = ThemePreset.allPresets.firstIndex(where: { $0.id == preset.id }),
              index < presetButtons.count else { return }
        
        selectPresetButton(presetButtons[index], preset: preset)
    }
    
    func getSelectedPreset() -> ThemePreset? {
        return selectedPreset
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        // Tracking areas are managed per button
    }
}