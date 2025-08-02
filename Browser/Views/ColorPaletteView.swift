import Cocoa

protocol ColorPaletteViewDelegate: AnyObject {
    func colorPaletteView(_ paletteView: ColorPaletteView, didSelectColor color: NSColor)
}

class ColorPaletteView: NSView {
    
    weak var delegate: ColorPaletteViewDelegate?
    
    private var colorButtons: [NSButton] = []
    private var selectedColorButton: NSButton?
    private var scrollView: NSScrollView!
    private var stackView: NSStackView!
    
    // Grid configuration
    private let colorsPerRow = 3
    private let buttonSize: CGFloat = 32
    private let buttonSpacing: CGFloat = 12
    
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
        
        // Create scroll view for color grid
        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        
        // Create container for color grid
        let containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add dotted background pattern (Arc-style)
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.3).cgColor
        containerView.layer?.cornerRadius = 12
        
        scrollView.documentView = containerView
        addSubview(scrollView)
        
        // Setup color buttons
        setupColorButtons(in: containerView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    private func setupColorButtons(in containerView: NSView) {
        let colors = ArcColorPalette.allCases
        let totalRows = (colors.count + colorsPerRow - 1) / colorsPerRow
        let totalWidth = CGFloat(colorsPerRow) * buttonSize + CGFloat(colorsPerRow - 1) * buttonSpacing + 32 // padding
        let totalHeight = CGFloat(totalRows) * buttonSize + CGFloat(totalRows - 1) * buttonSpacing + 32 // padding
        
        // Set container size
        containerView.widthAnchor.constraint(equalToConstant: totalWidth).isActive = true
        containerView.heightAnchor.constraint(equalToConstant: totalHeight).isActive = true
        
        for (index, colorPalette) in colors.enumerated() {
            let button = createColorButton(for: colorPalette.color, index: index)
            colorButtons.append(button)
            containerView.addSubview(button)
            
            // Calculate position
            let row = index / colorsPerRow
            let col = index % colorsPerRow
            
            let x = 16 + CGFloat(col) * (buttonSize + buttonSpacing)
            let y = 16 + CGFloat(row) * (buttonSize + buttonSpacing)
            
            NSLayoutConstraint.activate([
                button.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: x),
                button.topAnchor.constraint(equalTo: containerView.topAnchor, constant: y),
                button.widthAnchor.constraint(equalToConstant: buttonSize),
                button.heightAnchor.constraint(equalToConstant: buttonSize)
            ])
        }
        
        // Select first color by default
        if let firstButton = colorButtons.first {
            selectColorButton(firstButton)
        }
    }
    
    private func createColorButton(for color: NSColor, index: Int) -> NSButton {
        let button = NSButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.title = ""
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.wantsLayer = true
        button.tag = index
        
        // Style the button as a color circle
        button.layer?.backgroundColor = color.cgColor
        button.layer?.cornerRadius = buttonSize / 2
        button.layer?.borderWidth = 3
        button.layer?.borderColor = NSColor.clear.cgColor
        
        // Add shadow for depth
        button.shadow = NSShadow()
        button.shadow?.shadowOffset = NSSize(width: 0, height: 2)
        button.shadow?.shadowBlurRadius = 4
        button.shadow?.shadowColor = NSColor.black.withAlphaComponent(0.2)
        
        button.target = self
        button.action = #selector(colorButtonPressed(_:))
        
        // Add hover tracking
        let trackingArea = NSTrackingArea(
            rect: NSRect(x: 0, y: 0, width: buttonSize, height: buttonSize),
            options: [.mouseEnteredAndExited, .activeInKeyWindow],
            owner: self,
            userInfo: ["button": button]
        )
        button.addTrackingArea(trackingArea)
        
        return button
    }
    
    @objc private func colorButtonPressed(_ sender: NSButton) {
        selectColorButton(sender)
        
        let selectedColor = ArcColorPalette.allCases[sender.tag].color
        delegate?.colorPaletteView(self, didSelectColor: selectedColor)
        
        // Add satisfying click animation
        animateButtonPress(sender)
    }
    
    private func selectColorButton(_ button: NSButton) {
        // Deselect previous button
        selectedColorButton?.layer?.borderColor = NSColor.clear.cgColor
        selectedColorButton?.layer?.transform = CATransform3DIdentity
        
        // Select new button
        selectedColorButton = button
        button.layer?.borderColor = NSColor.white.cgColor
        button.layer?.transform = CATransform3DMakeScale(1.1, 1.1, 1.0)
        
        // Add selection glow
        button.layer?.shadowColor = button.layer?.backgroundColor
        button.layer?.shadowOpacity = 0.8
        button.layer?.shadowRadius = 8
    }
    
    private func animateButtonPress(_ button: NSButton) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            button.layer?.transform = CATransform3DMakeScale(0.95, 0.95, 1.0)
        } completionHandler: {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                button.layer?.transform = CATransform3DMakeScale(1.1, 1.1, 1.0)
            }
        }
    }
    
    // MARK: - Mouse Events for Hover Effects
    
    override func mouseEntered(with event: NSEvent) {
        guard let trackingArea = event.trackingArea,
              let button = trackingArea.userInfo?["button"] as? NSButton,
              button != selectedColorButton else { return }
        
        // Hover effect for non-selected buttons
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            button.layer?.transform = CATransform3DMakeScale(1.05, 1.05, 1.0)
            button.layer?.shadowRadius = 6
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        guard let trackingArea = event.trackingArea,
              let button = trackingArea.userInfo?["button"] as? NSButton,
              button != selectedColorButton else { return }
        
        // Remove hover effect for non-selected buttons
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            button.layer?.transform = CATransform3DIdentity
            button.layer?.shadowRadius = 4
        }
    }
    
    // MARK: - Public Interface
    
    func selectColor(_ color: NSColor) {
        // Find button with matching color and select it
        for (index, palette) in ArcColorPalette.allCases.enumerated() {
            if palette.color.isEqual(color) {
                selectColorButton(colorButtons[index])
                break
            }
        }
    }
    
    func getSelectedColor() -> NSColor? {
        guard let selectedButton = selectedColorButton else { return nil }
        return ArcColorPalette.allCases[selectedButton.tag].color
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        // Tracking areas are managed per button
    }
}